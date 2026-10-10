extends "res://scripts/ui/BoundedTooltipControl.gd"

signal stack_focus_requested(battle_id: String)
# A click on an enemy, or Enter on it, with the order the cursor showed:
# {"action": "strike" or "shoot", "approach": the hex to strike from}.
signal stack_order_requested(battle_id: String, order: Dictionary)
signal hex_destination_requested(q: int, r: int)
signal controller_navigation_cancelled
signal hero_figure_pressed(side: String)
# The right button went down over a stack on the field ("stack"), its ribbon
# chip ("chip": id is the stack's) or a hero ("hero": id is its side), with
# the rect the details card stands beside; kind is "" over anything else.
# details_released follows when the button comes up.
signal details_pressed(kind: String, id: String, anchor: Rect2)
signal details_released

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const AudioPaletteScript = preload("res://scripts/audio/AudioPalette.gd")
const RuntimeAudioLoaderScript = preload("res://scripts/audio/RuntimeAudioLoader.gd")
const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")
const BattleGlyphsScript = preload("res://scripts/ui/BattleGlyphs.gd")

const HEX_COLUMNS := BattleRulesScript.BATTLE_HEX_COLUMNS
const HEX_ROWS := BattleRulesScript.BATTLE_HEX_ROWS
const SQRT_3 := 1.7320508075688772
# The field is seen at an angle: each row is squashed to this share of its
# height (docs/battle-rework.md).
const HEX_VERTICAL_SCALE := 0.82
# The hexes fill the middle of the window. The margins are for a 1920x1080
# window and scale with it (ui_scale): the heroes stand in the side margins,
# the turn ribbon sits above the field and the command bar below it.
const FIELD_REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const FIELD_MARGIN_SIDE := 250.0
const FIELD_MARGIN_TOP := 165.0
const FIELD_MARGIN_BOTTOM := 90.0
# The hex radius the sizes below were drawn for (a 1920x1080 window).
const REFERENCE_HEX_RADIUS := 71.29
const BATTLEFIELD_VIGNETTE_COLOR := Color(0.031, 0.024, 0.012, 0.42)
const BATTLEFIELD_GRID_LINE := Color(1.0, 0.973, 0.871, 0.27)
const BATTLEFIELD_GRID_SHADOW := Color(0.125, 0.094, 0.031, 0.2)
# A hero stands beside its army, HERO_FOOT_OUTSET_RADII hex radii outside the
# grid and a quarter of the way down it, its canvas drawn
# HERO_FIGURE_CANVAS_RADII radii tall. Its casts start HERO_CAST_POINT_RADII
# above its feet.
const HERO_FOOT_OUTSET_RADII := 1.515
const HERO_FOOT_GRID_FRACTION := 0.254
const HERO_FIGURE_CANVAS_RADII := 3.34
const HERO_HIT_HALF_WIDTH_RADII := 1.09
const HERO_HIT_TOP_RADII := 3.2
const HERO_HIT_BOTTOM_RADII := 0.2
const HERO_CAST_POINT_RADII := 1.55
const HERO_READY_GLOW := Color(1.0, 0.84, 0.44)
# The turn ribbon across the top of the window (sizes for 1920x1080).
const RIBBON_MAX_WIDTH := 1390.0
const RIBBON_PADDING_TOP := 8.0
const RIBBON_PADDING_BOTTOM := 13.0
const RIBBON_PADDING_SIDE := 16.0
const RIBBON_GAP := 6.0
const RIBBON_ACTIVE_CHIP := 74.0
const RIBBON_CHIP := 52.0
const RIBBON_NEXT_CHIP := 40.0
const RIBBON_FILL := Color(0.055, 0.043, 0.027, 0.78)
const UI_GOLD := Color(0.878, 0.722, 0.4)
const UI_GOLD_HI := Color(0.965, 0.863, 0.604)
const UI_GOLD_DIM := Color(0.878, 0.722, 0.4, 0.45)
const UI_GOLD_FAINT := Color(0.878, 0.722, 0.4, 0.18)
const UI_CREAM := Color(0.953, 0.918, 0.831)
const UI_MUTED := Color(0.737, 0.682, 0.561)
const UI_PANEL := Color(0.063, 0.047, 0.031, 0.93)
const UI_PLAYER := Color(0.42, 0.659, 0.902)
const UI_PLAYER_DEEP := Color(0.106, 0.216, 0.337)
const UI_ENEMY := Color(0.839, 0.38, 0.329)
const UI_ENEMY_DEEP := Color(0.337, 0.106, 0.086)
const UI_ACTIVE := Color(0.988, 0.878, 0.478)
# The board draws its own cursor over the field: a sword turned toward the
# struck side cannot be a system cursor. While the battle is open this shape
# shows a blank image, so the system cursor hides where the board draws.
const FIELD_CURSOR_SHAPE := Control.CURSOR_CROSS
const FIELD_CURSOR_INPUT_SHAPE := Input.CURSOR_CROSS
# The drawn cursor's length at 1920x1080 (ui_scale).
const FIELD_CURSOR_EXTENT := 34.0
const FIELD_CURSOR_OUTLINE := Color(0.051, 0.039, 0.024, 0.92)
const FIELD_CURSOR_BLADE := Color(0.925, 0.922, 0.886)
const FIELD_CURSOR_BLOCKED := Color(0.902, 0.329, 0.271)
const FIELD_CURSOR_SPELL := Color(0.62, 0.84, 1.0)
# Within this share of a target's body, measured from its middle, the pointer
# names no side: the strike comes from where the stack stands, or from the
# nearest hex (melee_approach_cells' first entry).
const APPROACH_NEUTRAL_SHARE := 0.25
const APPROACH_GHOST_ALPHA := 0.5
const APPROACH_PATH_DOT := Color(0.988, 0.878, 0.478, 0.9)
# The glyphs _draw_field_cursor() draws in place of the system cursor.
const FIELD_CURSOR_GLYPHS := ["sword", "arrow", "broken_arrow", "boot", "spark", "blocked"]
# The forecast badge's colours: the headline, losses, no losses, a warning.
const FORECAST_HEAD := Color(1.0, 0.902, 0.651)
const FORECAST_LOSS := Color(0.957, 0.706, 0.647)
const FORECAST_GOOD := Color(0.624, 0.863, 0.573)
const FORECAST_WARN := Color(1.0, 0.761, 0.478)
# Stack plates: the fill of each side, the ink of the count and glyphs, the
# shots, a strike-back pip still to use and one spent, and the flags.
const PLATE_PLAYER_FILL := Color(0.153, 0.302, 0.459)
const PLATE_ENEMY_FILL := Color(0.451, 0.173, 0.141)
const PLATE_INK := Color(1.0, 0.98, 0.941)
const PLATE_GLYPH := Color(1.0, 0.925, 0.8)
const PLATE_SHOTS := Color(1.0, 0.886, 0.627)
const PLATE_PIP := Color(1.0, 0.851, 0.541)
const PLATE_PIP_EDGE := Color(0.361, 0.247, 0.071)
const PLATE_PIP_SPENT := Color(1.0, 0.925, 0.784, 0.55)
const PLATE_FLAG := Color(1.0, 0.945, 0.812)
# Each effect icon on a plate takes this many icon widths, its foundation's.
const PLATE_EFFECT_STEP := 1.36
# The first hovers over a stack, a chip or a hero say how to see its details;
# hovering the enemy's hero always does, as a click on it does nothing.
const DETAILS_HINT_HOVERS := 6
const DETAILS_HINT_TEXT := "Hold the right button for details"
const BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS := 320
const BATTLE_BOARD_CURSOR_SEMANTIC_DEBOUNCE_SECONDS := 0.42
const BATTLE_BOARD_CURSOR_RESULT_VISIBLE_SECONDS := 1.20

const FRAME_FILL := Color(0.045, 0.052, 0.061, 1.0)
const BOARD_FILL := Color(0.072, 0.078, 0.070, 1.0)
const FRAME_COLOR := Color(0.82, 0.67, 0.37, 0.94)
const TEXT_COLOR := Color(0.96, 0.94, 0.89, 1.0)
const SUBTEXT_COLOR := Color(0.83, 0.87, 0.91, 0.95)
const PLAYER_COLOR := Color(0.42, 0.66, 0.90, 0.98)
const ENEMY_COLOR := Color(0.84, 0.38, 0.33, 0.98)
const NEUTRAL_COLOR := Color(0.68, 0.72, 0.78, 0.94)
const ACTIVE_COLOR := Color(0.99, 0.88, 0.48, 1.0)
const TARGET_COLOR := Color(0.97, 0.64, 0.38, 0.98)
const BLOCKED_TARGET_COLOR := Color(0.78, 0.20, 0.18, 0.96)
const STACK_TOKEN_PRESENTATION_MODEL := "grounded_full_body_standee_event_animation_swap"
const STACK_TOKEN_INNER_FILL := Color(0.035, 0.045, 0.055, 0.32)
const STACK_TOKEN_SIDE_RIM_ALPHA := 0.78
const STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR := 0.07
const STACK_TOKEN_RADIUS_FACTOR := 0.68
const STACK_TOKEN_RADIUS_MIN := 15.0
const STACK_TOKEN_RADIUS_MAX := 52.0
const STACK_HIT_RADIUS_FACTOR := 0.58
const STACK_HIT_RADIUS_MIN := 13.0
const STACK_HIT_RADIUS_MAX := 46.0
const STACK_HIT_RADIUS_PADDING := 10.0
const STACK_ANIMATION_ART_EXTENT_FACTOR := 1.96
const STACK_ICON_ART_EXTENT_FACTOR := 1.86
const STACK_STANDEE_ART_HEIGHT_FACTOR := 2.55
const STACK_STANDEE_ART_HEIGHT_MIN := 70.0
const STACK_STANDEE_ART_HEIGHT_MAX := 260.0
const STACK_STANDEE_ASPECT := 192.0 / 224.0
const STACK_STANDEE_GROUND_OFFSET_FACTOR := 0.28
const MOVE_COLOR := Color(0.42, 0.82, 0.66, 0.58)
const MOVE_RANGE_VISUAL_MODEL := "broken_exposed_edge_perimeter_center_pips_near_transparent_fill"
const MOVE_RANGE_FILL_RADIUS_FACTOR := 0.58
const MOVE_RANGE_FILL_ALPHA := 0.012
const MOVE_RANGE_CONTOUR_RADIUS_FACTOR := 0.90
const MOVE_RANGE_CONTOUR_SEGMENT_FACTOR := 0.72
const MOVE_RANGE_CONTOUR_ALPHA := 0.48
const MOVE_RANGE_CONTOUR_WIDTH := 1.6
const MOVE_RANGE_PIP_RADIUS_FACTOR := 0.040
const MOVE_RANGE_PIP_ALPHA := 0.46
const LEGAL_MELEE_COLOR := Color(1.0, 0.78, 0.36, 0.90)
const LEGAL_RANGED_COLOR := Color(0.72, 0.88, 1.0, 0.82)
const CONTROLLER_CURSOR_COLOR := Color(1.0, 0.92, 0.58, 1.0)
const CONTROLLER_CURSOR_BLOCKED_COLOR := Color(0.94, 0.48, 0.32, 1.0)
const SHADOW_COLOR := Color(0.025, 0.028, 0.031, 0.32)
# Each battle terrain is fought on one of the painted battlefields, with that
# battlefield's props (tools/build_battlefield_art.py); a terrain without its
# own painting uses the nearest one, and an unknown terrain the meadow.
const BATTLEFIELD_FAMILIES := {
	"plains": "grass",
	"grass": "grass",
	"forest": "forest",
	"swamp": "swamp",
	"marsh": "swamp",
	"mire": "mire",
	"rough": "rough",
	"hills": "rough",
	"highland": "rough",
	"badlands": "rough",
	"road": "road",
	"snow": "snow",
	"coast": "coast",
	"sand": "sand",
	"lava": "lava",
	"underground": "underground",
}
const BATTLEFIELD_ART_ROOT := "res://art/battle/runtime/battlefields"
# The ground colour under the painting, and the hexes' colour without one.
const TERRAIN_COLORS := {
	"grass": Color(0.31, 0.40, 0.24, 1.0),
	"forest": Color(0.18, 0.31, 0.22, 1.0),
	"swamp": Color(0.24, 0.29, 0.22, 1.0),
	"rough": Color(0.37, 0.32, 0.24, 1.0),
	"road": Color(0.35, 0.30, 0.24, 1.0),
	"mire": Color(0.21, 0.27, 0.22, 1.0),
	"snow": Color(0.58, 0.66, 0.69, 1.0),
	"coast": Color(0.31, 0.48, 0.49, 1.0),
	"sand": Color(0.62, 0.52, 0.34, 1.0),
	"lava": Color(0.28, 0.20, 0.17, 1.0),
	"underground": Color(0.20, 0.27, 0.29, 1.0),
}
const TERRAIN_AMBIENT_MODEL := "deterministic_terrain_specific_passive_motes"
const TERRAIN_AMBIENT_DRAW_ORDER := ["terrain", "ambient_motes", "hero_figures", "hex_grid", "objectives", "movement_affordances", "controller_cursor", "battle_vfx", "stack_tokens", "turn_ribbon", "hover_forecast"]
const TERRAIN_AMBIENT_PHASE_SPEED := 0.52
const TERRAIN_AMBIENT_STATIC_PHASE := 0.0
const TERRAIN_AMBIENT_PROFILES := {
	"grass": {"id": "sunlit_pollen", "kind": "pollen", "count": 14, "color": Color(0.96, 0.88, 0.52, 1.0), "alpha": 0.16, "radius_factor": 0.0024, "drift": Vector2(0.010, 0.014)},
	"forest": {"id": "forest_fireflies", "kind": "firefly", "count": 11, "color": Color(0.91, 0.94, 0.48, 1.0), "alpha": 0.22, "radius_factor": 0.0025, "drift": Vector2(0.009, 0.012)},
	"swamp": {"id": "swamp_wisps", "kind": "wisp", "count": 10, "color": Color(0.48, 0.82, 0.76, 1.0), "alpha": 0.17, "radius_factor": 0.0028, "drift": Vector2(0.012, 0.008)},
	"rough": {"id": "roughland_dust", "kind": "dust", "count": 12, "color": Color(0.88, 0.70, 0.43, 1.0), "alpha": 0.13, "radius_factor": 0.0022, "drift": Vector2(0.016, 0.006)},
	"road": {"id": "roadside_dust", "kind": "dust", "count": 9, "color": Color(0.86, 0.72, 0.50, 1.0), "alpha": 0.12, "radius_factor": 0.0021, "drift": Vector2(0.018, 0.005)},
	"mire": {"id": "mire_wisps", "kind": "wisp", "count": 12, "color": Color(0.50, 0.78, 0.69, 1.0), "alpha": 0.18, "radius_factor": 0.0027, "drift": Vector2(0.011, 0.009)},
	"snow": {"id": "snow_spindrift", "kind": "flake", "count": 10, "color": Color(0.86, 0.94, 1.0, 1.0), "alpha": 0.16, "radius_factor": 0.0022, "drift": Vector2(0.015, 0.010)},
	"coast": {"id": "coastal_spray", "kind": "spray", "count": 10, "color": Color(0.66, 0.91, 0.91, 1.0), "alpha": 0.15, "radius_factor": 0.0023, "drift": Vector2(0.014, 0.007)},
	"sand": {"id": "desert_dust", "kind": "dust", "count": 10, "color": Color(0.96, 0.84, 0.58, 1.0), "alpha": 0.12, "radius_factor": 0.0022, "drift": Vector2(0.017, 0.005)},
	"lava": {"id": "ember_drift", "kind": "ember", "count": 9, "color": Color(1.0, 0.54, 0.26, 1.0), "alpha": 0.18, "radius_factor": 0.0022, "drift": Vector2(0.008, -0.013)},
	"underground": {"id": "glasscap_motes", "kind": "spore", "count": 11, "color": Color(0.43, 0.88, 0.86, 1.0), "alpha": 0.17, "radius_factor": 0.0024, "drift": Vector2(0.009, 0.008)},
}
# Each battlefield has its own props: of each kind, three one-hex and two
# two-hex ones, which the obstacle's variant picks from. A prop's canvas has
# OBSTACLE_ART_PIXELS_PER_HEX pixels per hex width and the centre of its ground
# tuft halfway across at OBSTACLE_ART_ANCHOR_Y; that point stands on the hex
# centre, or on the seam of a two-hex obstacle (tools/build_battlefield_art.py).
const OBSTACLE_ART_ROOT := "res://art/battle/runtime/obstacles"
const OBSTACLE_ART_VARIANTS := {1: 3, 2: 2}
const OBSTACLE_ART_CANVAS := {1: Vector2(288.0, 352.0), 2: Vector2(512.0, 352.0)}
const OBSTACLE_ART_PIXELS_PER_HEX := 216.0
const OBSTACLE_ART_ANCHOR_Y := 256.0
const OBSTACLE_SHADOW_COLOR := Color(0.02, 0.025, 0.02, 0.34)
const TERRAIN_HEX_FALLBACK_INSET := 0.975
const STACK_ANIMATION_EVENT_PLAYBACK_MSEC := 760
const STACK_ANIMATION_REACTION_DELAY_MSEC := 70
const BATTLE_VFX_PROJECTILE_COLOR := Color(0.94, 0.96, 0.74, 0.88)
const BATTLE_VFX_STATUS_COLOR := Color(0.50, 0.86, 0.74, 0.76)
const BATTLE_VFX_DAMAGE_COLOR := Color(1.0, 0.55, 0.32, 0.82)
const BATTLE_VFX_CAST_COLOR := Color(0.72, 0.80, 1.0, 0.78)
const BATTLE_AUDIO_SAMPLE_RATE := 22050.0
const BATTLE_AUDIO_MAX_ACTIVE_PLAYERS := 8
const BATTLE_AUDIO_REDUCED_REPETITION_MAX_ACTIVE_PLAYERS := 4
const BATTLE_AUDIO_REDUCED_REPETITION_COOLDOWN_MULTIPLIER := 2
const BATTLE_AUDIO_BUS := "Effects"
const BATTLE_SFX_MANIFEST_PATH := "res://content/battle_sfx_manifest.json"
const BATTLE_VFX_MANIFEST_PATH := "res://content/battle_vfx_manifest.json"
const CombatVfxMotion = preload("res://scripts/ui/CombatVfxMotion.gd")
const BattleUnitPose = preload("res://scripts/ui/BattleUnitPose.gd")
const BattleHeroFigureScript = preload("res://scripts/ui/BattleHeroFigure.gd")
const BATTLE_FIELD_OBJECTIVE_ART_MANIFEST_PATH := "res://content/battle_field_objective_art_manifest.json"
const BATTLE_FIELD_OBJECTIVE_ART_PRESENTATION_MODEL := "type_distinct_imported_landmark_with_non_color_control_shape_and_legacy_geometry_fallback"
const BATTLE_STATUS_EFFECT_ART_MANIFEST_PATH := "res://content/battle_status_effect_art_manifest.json"
const BATTLE_STATUS_EFFECT_ART_PRESENTATION_MODEL := "compact_imported_status_badges_with_non_color_polarity_foundation_and_procedural_mark_fallback"
const BATTLE_AUDIO_PRIORITY_VALUES := {"low": 1, "normal": 2, "high": 3, "critical": 4}
const BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS := "normal"
const BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC := 80
const BATTLE_CAMERA_MAX_OFFSET_PX := 8.0

var _session = null
var _battle: Dictionary = {}
var _player_stacks: Array = []
var _enemy_stacks: Array = []
var _active_stack: Dictionary = {}
var _target_stack: Dictionary = {}
var _field_objectives: Array = []
# This round from the active stack, the waiting stacks, then the predicted
# next round (BattleRules.turn_order_forecast), refreshed with each battle state.
var _turn_forecast: Dictionary = {}
var _stack_hit_shapes: Array = []
var _hover_destination_cell := Vector2i(-1, -1)
var _consequence_preview: Dictionary = {}
var _spell_target_candidates: Array = []
var _spell_target_previews: Dictionary = {}
var _spell_target_mode := false

func set_spell_target_candidates(ids: Array, previews: Dictionary = {}, targeting_active: bool = false) -> void:
	_spell_target_candidates = ids.duplicate()
	_spell_target_previews = previews.duplicate(true)
	_spell_target_mode = targeting_active
	_consequence_hover_key = ""
	queue_redraw()
var _consequence_hover_key := ""
var _controller_cursor_cell := Vector2i(-1, -1)
# Keys or a controller are steering the board (see _input()).
var _keyboard_cursor_active := false
# Loaded battlefield paintings by path; null for one that failed to load.
var _battlefield_textures: Dictionary = {}
var _obstacle_textures: Dictionary = {}
var _obstacle_texture_missing: Dictionary = {}
var _unit_battle_icon_textures: Dictionary = {}
var _unit_battle_icon_missing: Dictionary = {}
var _unit_battle_standee_textures: Dictionary = {}
var _unit_battle_standee_missing: Dictionary = {}
var _unit_animation_sheet_textures: Dictionary = {}
var _unit_animation_sheet_missing: Dictionary = {}
var _stack_animation_playback_records: Dictionary = {}
var _stack_animation_playback_until_msec: Dictionary = {}
var _latest_animation_serial_by_stack: Dictionary = {}
var _stack_animation_cue_playback_records: Dictionary = {}
var _stack_animation_audio_playback_records: Dictionary = {}
var _active_audio_players: Array = []
var _battle_sfx_manifest: Dictionary = {}
var _battle_sfx_manifest_loaded := false
var _battle_vfx_manifest: Dictionary = {}
var _battle_vfx_manifest_loaded := false
var _battle_vfx_textures: Dictionary = {}
var _battle_vfx_texture_missing: Dictionary = {}
var _field_objective_art_manifest: Dictionary = {}
var _field_objective_art_manifest_loaded := false
var _field_objective_art_textures: Dictionary = {}
var _field_objective_art_texture_missing: Dictionary = {}
var _battle_status_effect_art_manifest: Dictionary = {}
var _battle_status_effect_art_manifest_loaded := false
var _battle_status_effect_art_textures: Dictionary = {}
var _battle_status_effect_art_texture_missing: Dictionary = {}
var _audio_last_started_msec_by_cue: Dictionary = {}
var _audio_mix_counters: Dictionary = {
	"played": 0,
	"suppressed": 0,
	"evicted": 0,
	"suppressed_by_reason": {},
}
var _presentation_speed := BattleRulesScript.PRESENTATION_SPEED_NORMAL
var _battle_board_cursor_semantic_timer: Timer = null
var _battle_board_cursor_semantic_generation := 0
var _battle_board_cursor_semantic_pending: Dictionary = {}
var _battle_board_cursor_result_request_generation := 0
var _controller_dispatch_in_progress := false
var _terrain_ambient_phase := TERRAIN_AMBIENT_STATIC_PHASE
# Rules queries (legal moves, targets, footer labels) that drawing, hover and
# the footer would otherwise repeat every frame. Resolved once per battle
# state; see _board_queries().
var _board_query_cache: Dictionary = {}
var _board_query_signature := 0
var _board_query_in_draw := false
var _presentation_was_animating := false
# Each side's hero as BattleRules.hero_presentation describes it, plus the
# figure's texture path (figure_path) when it has one.
var _hero_presentations: Dictionary = {}
var _hero_figure_textures: Dictionary = {}
var _hero_cast_ready := false
var _hover_hero_side := ""
var _hover_ribbon_battle_id := ""
var _pointer_position := Vector2(-1.0, -1.0)
var _vignette_texture: GradientTexture2D = null
var _soft_glow_texture: GradientTexture2D = null
var _ribbon_style: StyleBoxFlat = null
var _forecast_style: StyleBoxFlat = null
var _box_style: StyleBoxFlat = null
var _hover_stack_id := ""
# What a click at the pointer, or Enter on the keyboard cursor, orders, and the
# cursor that shows it (_resolve_order).
var _hover_order: Dictionary = {}
# The side the player strikes the hovered enemy from: the one the pointer
# points at, or the one Q and E turned to while the pointer stays in that
# sector ({"target_id", "sector", "q", "r"}).
var _approach_choice: Dictionary = {}
# Ctrl is held: a shooter strikes the enemy it points at instead of shooting.
var _strike_forced := false
# What the screen's details card shows while the right button is held
# ({"kind": "stack" or "hero", "id"}), or {} while it is closed.
var _details_subject: Dictionary = {}
# The thing the pointer last hovered that the details hint names, and how
# many such hovers there have been.
var _details_hint_subject := ""
var _details_hint_hovers := 0
# Each plate as last drawn ({"rect", "model"} by battle id), for checks.
var _stack_plate_records: Dictionary = {}
var _plate_icon_textures: Dictionary = {}
var _plate_font_variation: FontVariation = null
static var _blank_cursor: ImageTexture = null
# The ribbon's layout for one battle state and board size (_turn_ribbon_layout).
var _ribbon_cache: Dictionary = {}
var _ribbon_cache_key := ""
# The battle is over (settle_final_field): the field stands still under the result.
var _field_final := false

@onready var _battle_board_cursor_live_label: Label = get_node_or_null("%BattleBoardCursorLive") as Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(620.0, 320.0)
	tooltip_text = "Outlined hex click moves. Highlighted enemy click attacks; blocked enemies need movement."
	focus_entered.connect(_on_controller_focus_entered)
	focus_exited.connect(_on_controller_focus_exited)
	mouse_exited.connect(_on_pointer_left)
	_configure_battle_board_cursor_semantic_timer()
	_load_battle_vfx_manifest()
	_load_field_objective_art_manifest()
	_load_battle_status_effect_art_manifest()
	_hide_system_cursor_on_field(true)

func _exit_tree() -> void:
	_cancel_battle_board_cursor_semantic()
	_hide_system_cursor_on_field(false)

## While the battle is open the field cursor shape shows a blank image, so the
## system cursor hides where the board draws its own.
func _hide_system_cursor_on_field(hidden: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not hidden:
		Input.set_custom_mouse_cursor(null, FIELD_CURSOR_INPUT_SHAPE)
		return
	if _blank_cursor == null:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
		_blank_cursor = ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(_blank_cursor, FIELD_CURSOR_INPUT_SHAPE, Vector2.ZERO)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_RESIZED, NOTIFICATION_THEME_CHANGED, NOTIFICATION_VISIBILITY_CHANGED]:
		queue_redraw()

func _process(delta: float) -> void:
	if not _battle.is_empty():
		if _terrain_ambient_should_animate():
			_terrain_ambient_phase = fmod(_terrain_ambient_phase + delta * TERRAIN_AMBIENT_PHASE_SPEED, TAU)
		else:
			_terrain_ambient_phase = TERRAIN_AMBIENT_STATIC_PHASE
		_expire_animation_playback_records()
		_activate_due_audio_cue_playback()
		_cleanup_audio_players()
		# Idle loops, ambient motes and playback need every frame. With reduced
		# motion and nothing playing the board is static; state, hover, focus
		# and cursor changes queue their own redraw. One more frame after
		# motion stops draws the resting pose.
		var animating := _presentation_animating()
		if animating or _presentation_was_animating:
			queue_redraw()
		_presentation_was_animating = animating
	if String(_battle_board_cursor_semantic_pending.get("kind", "")) == "result_clear" and not _battle_board_cursor_result_guard_matches(_battle_board_cursor_semantic_pending):
		_cancel_battle_board_cursor_semantic()

func _presentation_animating() -> bool:
	return (
		not SettingsService.reduced_motion_enabled()
		or not _stack_animation_playback_until_msec.is_empty()
		or not _stack_animation_cue_playback_records.is_empty()
	)

## The keyboard cursor shows while keys or a controller drive the board. The
## shell keeps the board focused for its keys, so focus alone does not mean
## the player is steering with keys: moving or clicking the mouse hands the
## forecast back to the pointer. Holding or letting go of Ctrl turns a
## shooter's order between shooting and striking at once.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_CTRL and not (event as InputEventKey).echo:
		var held := (event as InputEventKey).pressed
		if held != _strike_forced:
			_strike_forced = held
			_refresh_hover_order()
	if not _keyboard_cursor_active:
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		_set_keyboard_cursor_active(false)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_set_keyboard_cursor_active(false)

## The stack under the pointer, or under the keyboard cursor while keys
## steer the board.
func _pointed_stack_id() -> String:
	if _keyboard_cursor_shown():
		return _stack_id_at_cell(_controller_cursor_cell)
	return _hover_stack_id

func _keyboard_cursor_shown() -> bool:
	return _keyboard_cursor_active and has_focus()

func _set_keyboard_cursor_active(active: bool) -> void:
	if _keyboard_cursor_active == active:
		return
	_keyboard_cursor_active = active
	if active:
		_ensure_controller_cursor()
		_sync_controller_cursor_preview()
	elif _pointer_position.x >= 0.0 and not _battle.is_empty() and not _battle.has("playback_event"):
		_update_pointer_hover(_pointer_position)
		_preview_position(_pointer_position)
	else:
		_hover_destination_cell = Vector2i(-1, -1)
		_hover_order = {}
		set_consequence_preview({})
		_apply_field_cursor_shape()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _handle_controller_navigation_input(event):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		_pointer_position = motion_event.position
		_strike_forced = motion_event.ctrl_pressed
		_update_pointer_hover(motion_event.position)
		_preview_position(motion_event.position)
		var hovered_cell := _hex_cell_at_position(motion_event.position)
		if not _is_legal_destination_cell(hovered_cell):
			hovered_cell = Vector2i(-1, -1)
		if hovered_cell != _hover_destination_cell:
			_hover_destination_cell = hovered_cell
			queue_redraw()
		_note_details_hint_subject()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	# Holding the right button shows the details of what it went down on.
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_event.pressed:
			var subject := _details_subject_at_position(mouse_event.position)
			details_pressed.emit(String(subject.get("kind", "")), String(subject.get("id", "")), Rect2(subject.get("anchor", Rect2())))
		else:
			details_released.emit()
		accept_event()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var hero_side := _hero_side_at_position(mouse_event.position)
	if hero_side != "":
		hero_figure_pressed.emit(hero_side)
		accept_event()
		return
	if _ribbon_rect().has_point(mouse_event.position):
		accept_event()
		return
	var dispatch := _dispatch_board_click_at_position(mouse_event.position, mouse_event.ctrl_pressed)
	if bool(dispatch.get("accepted", false)):
		accept_event()

func _handle_controller_navigation_input(event: InputEvent) -> bool:
	if not has_focus():
		return false
	if event.is_action_pressed("ui_up"):
		_set_keyboard_cursor_active(true)
		_move_controller_cursor(Vector2i.UP, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_down"):
		_set_keyboard_cursor_active(true)
		_move_controller_cursor(Vector2i.DOWN, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_left"):
		_set_keyboard_cursor_active(true)
		_move_controller_cursor(Vector2i.LEFT, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_right"):
		_set_keyboard_cursor_active(true)
		_move_controller_cursor(Vector2i.RIGHT, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_accept"):
		if event is InputEventKey and event.echo: return true
		if not _keyboard_cursor_active:
			# The first Enter shows the cursor where it stands; the next acts.
			_set_keyboard_cursor_active(true)
			return true
		return _dispatch_controller_cursor()
	if event.is_action_pressed("ui_cancel"):
		return handle_root_controller_navigation_cancel()
	return false

func handle_root_controller_navigation_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or not has_focus():
		return false
	release_focus()
	controller_navigation_cancelled.emit()
	_queue_battle_board_cursor_semantic_result("Battle board navigation ended. Focus returned to battle commands.")
	return true

func _on_controller_focus_entered() -> void:
	_cancel_battle_board_cursor_semantic()
	# Tab into the board steers it with keys.
	if Input.is_action_pressed("ui_focus_next") or Input.is_action_pressed("ui_focus_prev"):
		_keyboard_cursor_active = true
	_ensure_controller_cursor()
	_sync_controller_cursor_preview()
	queue_redraw()

func _on_controller_focus_exited() -> void:
	_cancel_battle_board_cursor_semantic(false)
	if _keyboard_cursor_active:
		_hover_destination_cell = Vector2i(-1, -1)
		_hover_order = {}
		set_consequence_preview({})
		_apply_field_cursor_shape()
	queue_redraw()

func _ensure_controller_cursor() -> void:
	if _cell_in_bounds(_controller_cursor_cell):
		return
	var selected_id := String(_battle.get("selected_target_id", ""))
	var selected_cell := _stack_cell_for_battle_id(selected_id)
	if _cell_in_bounds(selected_cell):
		_controller_cursor_cell = selected_cell
		return
	for destination in _legal_destinations():
		if destination is Dictionary:
			var destination_cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if _cell_in_bounds(destination_cell):
				_controller_cursor_cell = destination_cell
				return
	var active_cell := _stack_cell_for_battle_id(String(_battle.get("active_stack_id", "")))
	_controller_cursor_cell = active_cell if _cell_in_bounds(active_cell) else Vector2i(int(HEX_COLUMNS / 2), int(HEX_ROWS / 2))

func _move_controller_cursor(delta: Vector2i, announce_semantic: bool = false) -> void:
	_ensure_controller_cursor()
	var previous_cell := _controller_cursor_cell
	_controller_cursor_cell = Vector2i(
		clampi(_controller_cursor_cell.x + delta.x, 0, HEX_COLUMNS - 1),
		clampi(_controller_cursor_cell.y + delta.y, 0, HEX_ROWS - 1)
	)
	_sync_controller_cursor_preview()
	queue_redraw()
	if announce_semantic and _controller_cursor_cell != previous_cell:
		_schedule_battle_board_cursor_semantic()

func _sync_controller_cursor_preview() -> void:
	if not _keyboard_cursor_shown():
		return
	_hover_destination_cell = _controller_cursor_cell if _is_legal_destination_cell(_controller_cursor_cell) else Vector2i(-1, -1)
	_preview_position(_hex_center(_controller_cursor_cell, _current_hex_layout()), true)

func set_consequence_preview(preview: Dictionary) -> void:
	_consequence_preview = preview.duplicate(true) if not _battle.has("playback_event") else {}
	_consequence_hover_key = ""
	queue_redraw()

func preview_attack(action: String, target_id: String) -> void:
	if _spell_target_mode: return
	if String(_active_stack.get("side", "")) != "player" or _battle.has("playback_event"):
		set_consequence_preview({})
		return
	set_consequence_preview(BattleRulesScript.attack_consequence_preview(_battle, action, target_id))

## Shows what a click at position, or Enter on the keyboard cursor (focused),
## would order: the cursor, the forecast and the walk to the strike.
func _preview_position(position: Vector2, focused: bool = false) -> void:
	_set_hover_order(_resolve_order(position, focused, _strike_forced))

## The order under the pointer or the keyboard cursor again, after Ctrl or the
## chosen approach changed.
func _refresh_hover_order() -> void:
	if _keyboard_cursor_shown():
		_preview_position(_hex_center(_controller_cursor_cell, _current_hex_layout()), true)
	elif _pointer_position.x >= 0.0:
		_preview_position(_pointer_position)

func _set_hover_order(order: Dictionary) -> void:
	_hover_order = order
	# A turn with Q or E holds only while the pointer stays where it was made.
	if not _approach_choice.is_empty() and (String(order.get("kind", "")) != "strike" or String(order.get("target_id", "")) != String(_approach_choice.get("target_id", "")) or String(order.get("sector", "")) != String(_approach_choice.get("sector", ""))):
		_approach_choice = {}
	var key := _order_key(order)
	if key != _consequence_hover_key:
		set_consequence_preview(order.get("preview", {}))
		_consequence_hover_key = key
	_apply_field_cursor_shape()
	queue_redraw()

func _dispatch_controller_cursor() -> bool:
	_ensure_controller_cursor()
	if _battle.is_empty() or not _cell_in_bounds(_controller_cursor_cell):
		return false
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	var order := _resolve_order(_hex_center(_controller_cursor_cell, _current_hex_layout()), true, _strike_forced or Input.is_key_pressed(KEY_CTRL)) if battle_id != "" else {}
	_controller_dispatch_in_progress = true
	if _is_attack_order(order, battle_id):
		stack_order_requested.emit(battle_id, _order_payload(order))
	elif battle_id != "":
		stack_focus_requested.emit(battle_id)
	else:
		hex_destination_requested.emit(_controller_cursor_cell.x, _controller_cursor_cell.y)
	_controller_dispatch_in_progress = false
	return true

## A click on a stack: an attack order goes out with the hex the strike is
## made from; anything else lets the shell explain or cast.
func _emit_stack_order(battle_id: String, order: Dictionary) -> void:
	if _is_attack_order(order, battle_id):
		stack_order_requested.emit(battle_id, _order_payload(order))
	else:
		stack_focus_requested.emit(battle_id)

func _is_attack_order(order: Dictionary, battle_id: String) -> bool:
	return battle_id != "" and String(order.get("kind", "")) in ["strike", "shoot"] and String(order.get("target_id", "")) == battle_id

## An order as the shell takes it: {"action", "approach": {"q", "r"}}.
func _order_payload(order: Dictionary) -> Dictionary:
	var payload := {"action": String(order.get("kind", ""))}
	var approach: Dictionary = order.get("approach", {})
	if not approach.is_empty():
		payload["approach"] = {"q": int(approach.get("q", -1)), "r": int(approach.get("r", -1))}
	return payload

func publish_controller_action_result(result: Dictionary, completed_playback: bool = false) -> void:
	if not _controller_dispatch_in_progress and not completed_playback:
		return
	var result_message := String(result.get("message", "")).strip_edges()
	if result_message == "":
		result_message = String(result.get("preview_message", "")).strip_edges()
	if result_message == "":
		result_message = "The selected battle-board action did not report a result."
	_queue_battle_board_cursor_semantic_result(
		"Battle board result: %s" % result_message
	)

func _configure_battle_board_cursor_semantic_timer() -> void:
	if _battle_board_cursor_semantic_timer != null and is_instance_valid(_battle_board_cursor_semantic_timer):
		return
	_battle_board_cursor_semantic_timer = Timer.new()
	_battle_board_cursor_semantic_timer.name = "BattleBoardCursorSemanticTimer"
	_battle_board_cursor_semantic_timer.one_shot = true
	_battle_board_cursor_semantic_timer.timeout.connect(_on_battle_board_cursor_semantic_timeout)
	add_child(_battle_board_cursor_semantic_timer)

func _schedule_battle_board_cursor_semantic() -> void:
	_cancel_battle_board_cursor_semantic()
	if not _battle_board_cursor_context_owned():
		return
	_battle_board_cursor_semantic_pending = {
		"kind": "context",
		"generation": _battle_board_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": _battle_board_cursor_session_id(),
		"battle_ref": _battle,
		"battle_identity": _battle_board_cursor_battle_identity(),
		"turn_signature": _battle_board_cursor_turn_signature(),
		"cursor_cell": _battle_board_cursor_cell_payload(_controller_cursor_cell),
		"label_ref": _battle_board_cursor_live_label,
	}
	_battle_board_cursor_semantic_timer.start(BATTLE_BOARD_CURSOR_SEMANTIC_DEBOUNCE_SECONDS)

func _queue_battle_board_cursor_semantic_result(text: String) -> void:
	var bounded_text := _bounded_battle_board_cursor_semantic_text(
		text,
		BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS
	)
	if bounded_text == "" or not is_inside_tree() or _session == null or _battle.is_empty():
		return
	_cancel_battle_board_cursor_semantic(false)
	_battle_board_cursor_result_request_generation += 1
	var request_generation := _battle_board_cursor_result_request_generation
	call_deferred(
		"_publish_battle_board_cursor_semantic_result",
		bounded_text,
		request_generation,
		_session,
		_battle,
		_battle_board_cursor_session_id(),
		_battle_board_cursor_battle_identity(),
		_battle_board_cursor_turn_signature()
	)

func _publish_battle_board_cursor_semantic_result(
	text: String,
	request_generation: int,
	source_session,
	source_battle: Dictionary,
	source_session_id: String,
	battle_identity: String,
	turn_signature: String
) -> void:
	if (
		request_generation != _battle_board_cursor_result_request_generation
		or not is_inside_tree()
		or _session == null
		or not is_same(source_session, _session)
		or source_session_id != _battle_board_cursor_session_id()
		or not is_same(source_battle, _battle)
		or battle_identity != _battle_board_cursor_battle_identity()
		or turn_signature != _battle_board_cursor_turn_signature()
		or _battle_board_cursor_modal_owner_open()
		or not is_instance_valid(_battle_board_cursor_live_label)
	):
		return
	var expected_focus := get_viewport().gui_get_focus_owner() as Control
	if not _battle_board_cursor_focus_owned_by_shell(expected_focus):
		return
	_cancel_battle_board_cursor_semantic(false)
	_battle_board_cursor_live_label.text = text
	_battle_board_cursor_semantic_pending = {
		"kind": "result_clear",
		"generation": _battle_board_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": _battle_board_cursor_session_id(),
		"battle_ref": _battle,
		"battle_identity": _battle_board_cursor_battle_identity(),
		"turn_signature": _battle_board_cursor_turn_signature(),
		"focus_ref": expected_focus,
		"label_ref": _battle_board_cursor_live_label,
		"label_text": text,
	}
	_battle_board_cursor_semantic_timer.start(BATTLE_BOARD_CURSOR_RESULT_VISIBLE_SECONDS)

func _on_battle_board_cursor_semantic_timeout() -> void:
	var pending := _battle_board_cursor_semantic_pending
	if pending.is_empty() or int(pending.get("generation", -1)) != _battle_board_cursor_semantic_generation:
		return
	_battle_board_cursor_semantic_pending = {}
	match String(pending.get("kind", "")):
		"context":
			_publish_pending_battle_board_cursor_context(pending)
		"result_clear":
			_clear_battle_board_cursor_semantic_result(pending)
		_:
			_cancel_battle_board_cursor_semantic()

func _publish_pending_battle_board_cursor_context(pending: Dictionary) -> void:
	var cursor_value: Variant = pending.get("cursor_cell", {})
	var cursor_payload: Dictionary = cursor_value if cursor_value is Dictionary else {}
	var pending_cell := Vector2i(
		int(cursor_payload.get("q", -1)),
		int(cursor_payload.get("r", -1))
	)
	if (
		not _battle_board_cursor_context_owned()
		or not is_same(pending.get("session_ref"), _session)
		or String(pending.get("session_id", "")) != _battle_board_cursor_session_id()
		or not is_same(pending.get("battle_ref"), _battle)
		or String(pending.get("battle_identity", "")) != _battle_board_cursor_battle_identity()
		or String(pending.get("turn_signature", "")) != _battle_board_cursor_turn_signature()
		or pending_cell != _controller_cursor_cell
		or not is_same(pending.get("label_ref"), _battle_board_cursor_live_label)
	):
		_cancel_battle_board_cursor_semantic()
		return
	var context := _battle_board_cursor_semantic_context()
	if context == "":
		_cancel_battle_board_cursor_semantic()
		return
	_battle_board_cursor_live_label.text = context

func _clear_battle_board_cursor_semantic_result(pending: Dictionary) -> void:
	if int(pending.get("generation", -1)) != _battle_board_cursor_semantic_generation:
		return
	if not _battle_board_cursor_result_guard_matches(pending):
		_cancel_battle_board_cursor_semantic()
		return
	_battle_board_cursor_semantic_generation += 1
	if _battle_board_cursor_live_label.text == String(pending.get("label_text", "")):
		_battle_board_cursor_live_label.text = ""

func _battle_board_cursor_result_guard_matches(pending: Dictionary) -> bool:
	var expected_focus: Variant = pending.get("focus_ref")
	return (
		is_inside_tree()
		and _session != null
		and is_same(pending.get("session_ref"), _session)
		and String(pending.get("session_id", "")) == _battle_board_cursor_session_id()
		and is_same(pending.get("battle_ref"), _battle)
		and String(pending.get("battle_identity", "")) == _battle_board_cursor_battle_identity()
		and String(pending.get("turn_signature", "")) == _battle_board_cursor_turn_signature()
		and is_instance_valid(expected_focus)
		and get_viewport().gui_get_focus_owner() == expected_focus
		and _battle_board_cursor_focus_owned_by_shell(expected_focus)
		and not _battle_board_cursor_modal_owner_open()
		and is_same(pending.get("label_ref"), _battle_board_cursor_live_label)
		and _battle_board_cursor_live_label.text == String(pending.get("label_text", ""))
	)

func _battle_board_cursor_semantic_context() -> String:
	if _battle.is_empty() or not _cell_in_bounds(_controller_cursor_cell):
		return ""
	var role := _controller_cursor_cell_role().replace("_", " ")
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	var active_side := String(_active_stack.get("side", ""))
	var detail := ""
	var action := "check this hex"
	if battle_id != "":
		var stack := _stack_by_id(battle_id)
		var side := String(stack.get("side", "unknown"))
		var name := _bounded_battle_board_cursor_semantic_text(
			String(stack.get("name", stack.get("unit_id", "Stack"))),
			48
		)
		var active_prefix := "active " if battle_id == String(_battle.get("active_stack_id", "")) else ""
		detail = "%s%s stack %s, %d units. %s" % [
			active_prefix,
			side,
			name,
			_stack_alive_count(stack),
			_stack_board_tooltip(battle_id),
		]
		if active_side == "player" and side == "enemy":
			var attack_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, battle_id)
			var action_label := String(attack_intent.get("label", "")).strip_edges()
			action = action_label if action_label != "" else "select this target"
	else:
		var movement_intent := BattleRulesScript.movement_intent_for_destination(
			_battle,
			_controller_cursor_cell.x,
			_controller_cursor_cell.y
		)
		detail = String(movement_intent.get("message", _movement_board_tooltip(_controller_cursor_cell)))
		action = "move here" if bool(movement_intent.get("movable", false)) else "check this blocked hex"
	if active_side != "player":
		action = "unavailable while input is locked"
	detail = _bounded_battle_board_cursor_semantic_text(detail, 150)
	action = _bounded_battle_board_cursor_semantic_text(action, 44)
	return _bounded_battle_board_cursor_semantic_text(
		"Hex %d,%d; %s. %s A/Enter: %s. B/Escape: return to battle commands." % [
			_controller_cursor_cell.x,
			_controller_cursor_cell.y,
			role,
			detail,
			action,
		],
		BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS
	)

func _battle_board_cursor_context_owned() -> bool:
	return (
		is_inside_tree()
		and has_focus()
		and _session != null
		and not _battle.is_empty()
		and _cell_in_bounds(_controller_cursor_cell)
		and not _battle_board_cursor_modal_owner_open()
		and is_instance_valid(_battle_board_cursor_live_label)
	)

func _battle_board_cursor_modal_owner_open() -> bool:
	var shell := owner
	if shell == null or not is_instance_valid(shell):
		return true
	for dialog_name in [
		"QuickResolveConfirmationDialog",
		"WithdrawalConfirmationDialog",
		"ManualSaveOverwriteDialog",
	]:
		var dialog := shell.get_node_or_null(NodePath(dialog_name))
		if dialog is Window and dialog.visible:
			return true
	var settings_dialog := shell.get_node_or_null(NodePath("ActivePlaySettingsDialog"))
	return (
		settings_dialog != null
		and settings_dialog.has_method("is_open")
		and bool(settings_dialog.call("is_open"))
	)

func _battle_board_cursor_focus_owned_by_shell(focus: Control) -> bool:
	var shell := owner
	return (
		focus != null
		and is_instance_valid(focus)
		and shell != null
		and is_instance_valid(shell)
		and (focus == shell or shell.is_ancestor_of(focus))
	)

func _battle_board_cursor_session_id() -> String:
	return String(_session.session_id) if _session != null else ""

func _battle_board_cursor_battle_identity() -> String:
	return String(_battle.get("encounter_id", ""))

func _battle_board_cursor_turn_signature() -> String:
	return "%d|%d|%s|%s" % [
		int(_battle.get("round", 0)),
		int(_battle.get("turn_index", -1)),
		String(_battle.get("active_stack_id", "")),
		String(_active_stack.get("side", "")),
	]

func _battle_board_cursor_cell_payload(cell: Vector2i) -> Dictionary:
	return {"q": cell.x, "r": cell.y}

func _cancel_battle_board_cursor_semantic(invalidate_staged_result: bool = true) -> void:
	_battle_board_cursor_semantic_generation += 1
	_battle_board_cursor_semantic_pending.clear()
	if invalidate_staged_result:
		_battle_board_cursor_result_request_generation += 1
	if _battle_board_cursor_semantic_timer != null and is_instance_valid(_battle_board_cursor_semantic_timer):
		_battle_board_cursor_semantic_timer.stop()
	if _battle_board_cursor_live_label != null and is_instance_valid(_battle_board_cursor_live_label):
		_battle_board_cursor_live_label.text = ""

func _bounded_battle_board_cursor_semantic_text(value: String, maximum_characters: int) -> String:
	var normalized := " ".join(value.replace("\r", "\n").split("\n", false)).strip_edges()
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.left(maximum_characters)

## force_strike: Ctrl was held, so a shooter strikes instead of shooting.
func _dispatch_board_click_at_position(position: Vector2, force_strike: bool = false) -> Dictionary:
	var target_cell := _hex_cell_at_position(position)
	var cell_battle_id := _stack_id_at_cell(target_cell)
	var battle_id := _stack_id_at_board_position(position, target_cell)
	if _spell_target_mode and battle_id != "":
		stack_focus_requested.emit(battle_id)
		return {"accepted": true, "dispatch": "spell_target", "battle_id": battle_id}
	if cell_battle_id != "":
		var hex_order := _resolve_order(position, false, force_strike)
		_emit_stack_order(cell_battle_id, hex_order)
		return {
			"accepted": true,
			"dispatch": "stack_hex",
			"battle_id": cell_battle_id,
			"q": target_cell.x,
			"r": target_cell.y,
			"order": _order_payload(hex_order),
		}
	if battle_id == "":
		if target_cell.x < 0:
			return {
				"accepted": false,
				"dispatch": "",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
			}
		if not _is_legal_destination_cell(target_cell):
			var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, target_cell.x, target_cell.y)
			hex_destination_requested.emit(target_cell.x, target_cell.y)
			return {
				"accepted": true,
				"dispatch": "destination_blocked",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
				"message": String(movement_intent.get("message", "")),
			}
		hex_destination_requested.emit(target_cell.x, target_cell.y)
		return {
			"accepted": true,
			"dispatch": "destination",
			"battle_id": "",
			"q": target_cell.x,
			"r": target_cell.y,
		}
	var body_order := _resolve_order(position, false, force_strike)
	_emit_stack_order(battle_id, body_order)
	var stack_cell := _stack_cell_for_battle_id(battle_id)
	return {
		"accepted": true,
		"dispatch": "stack_token",
		"battle_id": battle_id,
		"q": stack_cell.x,
		"r": stack_cell.y,
		"order": _order_payload(body_order),
	}

func _get_tooltip(at_position: Vector2) -> String:
	var turn_strip_entry := _turn_ribbon_chip_at_position(at_position)
	if not turn_strip_entry.is_empty():
		return _turn_ribbon_chip_tooltip(turn_strip_entry, _turn_ribbon_chips().size())
	var hero_side := _hero_side_at_position(at_position)
	if hero_side != "":
		return _hero_tooltip(hero_side)
	var destination_cell := _hex_cell_at_position(at_position)
	var battle_id := _stack_id_at_board_position(at_position, destination_cell)
	if battle_id != "":
		return _stack_board_tooltip(battle_id)
	if _spell_target_mode:
		return ""
	if _is_legal_destination_cell(destination_cell):
		return _movement_board_tooltip(destination_cell)
	if _cell_in_bounds(destination_cell):
		var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, destination_cell.x, destination_cell.y)
		var message := String(movement_intent.get("message", ""))
		if bool(movement_intent.get("blocked", false)) and message != "":
			return message
		return _fallback_board_tooltip()
	# The painted scenery around the field has no tooltip.
	return ""

func contextual_inspection_text() -> String:
	return _get_tooltip(_hex_center(_controller_cursor_cell, _current_hex_layout())) if _keyboard_cursor_shown() else get_tooltip(get_local_mouse_position())

func contextual_help_exclusion_rects() -> Array:
	return [Rect2(_turn_ribbon_layout().get("rect", Rect2()))]

func set_battle_state(session) -> void:
	_session = session
	var battle := {}
	if session != null and session.battle is Dictionary:
		battle = session.battle
	_apply_battle_dictionary(battle)

func set_battle_presentation_snapshot(battle_snapshot: Dictionary, preserve_contact_action: bool = false) -> void:
	_session = null
	if battle_snapshot.has("playback_event") and not preserve_contact_action:
		_stack_animation_playback_records.clear()
		_stack_animation_playback_until_msec.clear()
		_stack_animation_cue_playback_records.clear()
		_stack_animation_audio_playback_records.clear()
		_latest_animation_serial_by_stack.clear()
	var presentation := battle_snapshot.duplicate(true)
	# This flag lives only in the transient render snapshot, never in session
	# state. Contact reactions begin while the attack plays its recovery poses.
	if preserve_contact_action: presentation["_fluid_contact_reaction"] = true
	_apply_battle_dictionary(presentation)

func can_overlap_action_contact(next_event: Dictionary) -> bool:
	var current: Dictionary = _battle.get("playback_event", {})
	# An attack may damage several targets, or emit hit then death. Keep all
	# of that contact's reactions together while the attacker recovers.
	if bool(_battle.get("_fluid_contact_reaction", false)) and String(next_event.get("event_id", "")) in ["battle_unit_hit", "battle_unit_death", "battle_status_applied"]:
		return String(next_event.get("source_battle_id", "")) == String(current.get("source_battle_id", ""))
	if String(current.get("event_id", "")) not in ["battle_unit_melee_attack", "battle_unit_ranged_attack", "battle_retaliation", "battle_unit_cast"]:
		return false
	if String(next_event.get("event_id", "")) not in ["battle_unit_hit", "battle_unit_death", "battle_status_applied"]:
		return false
	if String(next_event.get("source_battle_id", "")) != String(current.get("battle_id", "")):
		return false
	var actor := BattleRulesScript._get_stack_by_id(_battle, String(current.get("battle_id", "")))
	var animation := ContentService.get_unit_animation(String(actor.get("unit_id", "")))
	var state_name := String(current.get("state", ""))
	var spec := BattleUnitPose.clip(animation, state_name)
	return animation.get("pose_clips", {}).has(BattleUnitPose.clip_name(state_name)) and bool(spec.get("authored_timing", false)) and spec.has("contact_frame") and not SettingsService.reduced_motion_enabled()

func action_playback_wait_msec(at_contact: bool = false) -> int:
	var now := int(Time.get_ticks_msec())
	if at_contact:
		if bool(_battle.get("_fluid_contact_reaction", false)): return 1
		var event: Dictionary = _battle.get("playback_event", {})
		var record := _animation_playback_record_for_stack(String(event.get("battle_id", "")))
		var actor := BattleRulesScript._get_stack_by_id(_battle, String(event.get("battle_id", "")))
		var spec := BattleUnitPose.clip(ContentService.get_unit_animation(String(actor.get("unit_id", ""))), String(event.get("state", "")))
		return maxi(1, int(record.get("impact_at_msec", int(record.get("started_at_msec", now)) + _presentation_duration_msec(BattleUnitPose.contact_msec(spec)))) - now)
	var remaining := 1
	for expires in _stack_animation_playback_until_msec.values():
		remaining = maxi(remaining, int(expires) - now)
	return remaining + 16

func finish_action_playback(session) -> void:
	_stack_animation_playback_records.clear()
	_stack_animation_playback_until_msec.clear()
	_stack_animation_cue_playback_records.clear()
	_stack_animation_audio_playback_records.clear()
	_latest_animation_serial_by_stack.clear()
	if session != null:
		for event in BattleRulesScript.animation_event_queue(session.battle):
			_latest_animation_serial_by_stack[String(event.get("battle_id", ""))] = int(event.get("serial", 0))
	set_battle_state(session)

## The battle is over and the session holds no battle any more: the board
## keeps the field as the last exchange left it, still, under the result.
func settle_final_field() -> void:
	_stack_animation_playback_records.clear()
	_stack_animation_playback_until_msec.clear()
	_stack_animation_cue_playback_records.clear()
	_stack_animation_audio_playback_records.clear()
	_session = null
	_hero_cast_ready = false
	if _battle.is_empty():
		queue_redraw()
		return
	var still := _battle.duplicate(true)
	still.erase("playback_event")
	still.erase("_fluid_contact_reaction")
	# It is nobody's turn: no active stack, movement range, target line or
	# turn ribbon over the field the result is read against.
	still["active_stack_id"] = ""
	still["selected_target_id"] = ""
	_field_final = true
	_apply_battle_dictionary(still)

func _apply_battle_dictionary(battle: Dictionary) -> void:
	set_meta("contextual_help_revision", int(get_meta("contextual_help_revision", 0)) + 1)
	_board_query_cache = {}
	_cancel_battle_board_cursor_semantic()
	_consequence_preview = {}
	_consequence_hover_key = ""
	_hover_order = {}
	_battle = {}
	_player_stacks = []
	_enemy_stacks = []
	_active_stack = {}
	_target_stack = {}
	_field_objectives = []
	_turn_forecast = {}
	_hero_presentations = {}
	_ribbon_cache = {}
	_ribbon_cache_key = ""
	_stack_hit_shapes = []
	if battle.is_empty():
		_controller_cursor_cell = Vector2i(-1, -1)
	if not _is_legal_destination_cell(_hover_destination_cell):
		_hover_destination_cell = Vector2i(-1, -1)
	if not battle.is_empty():
		_battle = battle
		_presentation_speed = String(_battle.get(BattleRulesScript.PRESENTATION_SPEED_KEY, BattleRulesScript.PRESENTATION_SPEED_NORMAL))
		_sync_animation_playback_records()
		_active_stack = BattleRulesScript.get_active_stack(_battle)
		_target_stack = BattleRulesScript.get_selected_target(_battle)
		_field_objectives = _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []).duplicate(true) if _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []) is Array else []
		_turn_forecast = BattleRulesScript.turn_order_forecast(_battle)
		for side in ["player", "enemy"]:
			var presentation := BattleRulesScript.hero_presentation(_battle, side)
			if bool(presentation.get("has_figure", false)):
				presentation["figure_path"] = BattleHeroFigureScript.figure_path(String(presentation.get("hero_id", "")), String(presentation.get("faction_id", "")))
				presentation["has_figure"] = String(presentation.get("figure_path", "")) != ""
			_hero_presentations[side] = presentation
		for stack in _battle.get("stacks", []):
			if not (stack is Dictionary) or not _stack_visible_for_presentation(stack):
				continue
			if String(stack.get("side", "")) == "player":
				_player_stacks.append(stack)
			elif String(stack.get("side", "")) == "enemy":
				_enemy_stacks.append(stack)
	if has_focus():
		_ensure_controller_cursor()
	if _keyboard_cursor_shown():
		_sync_controller_cursor_preview()
	elif _pointer_position.x >= 0.0 and not _battle.is_empty() and not _battle.has("playback_event"):
		_update_pointer_hover(_pointer_position)
		_preview_position(_pointer_position)
	elif not _target_stack.is_empty():
		var intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, String(_target_stack.get("battle_id", "")))
		preview_attack(String(intent.get("action", "")), String(_target_stack.get("battle_id", "")))
	_apply_field_cursor_shape()
	queue_redraw()

func validation_hex_layout_summary() -> Dictionary:
	var stack_cells := _stack_cells()
	var hex_state := BattleRulesScript.battle_hex_state_summary(_battle) if not _battle.is_empty() else {}
	var layout := _current_hex_layout()
	var hex_radius := float(layout.get("radius", 1.0))
	var terrain_id := _battle_terrain_id()
	var player_input_active := String(_active_stack.get("side", "")) == "player" and not _battle.has("playback_event")
	var legal_destinations: Array = hex_state.get("legal_destinations", []) if hex_state.get("legal_destinations", []) is Array else []
	var legal_melee_targets: Array = hex_state.get("legal_melee_targets", []) if hex_state.get("legal_melee_targets", []) is Array else []
	var legal_ranged_targets: Array = hex_state.get("legal_ranged_targets", []) if hex_state.get("legal_ranged_targets", []) is Array else []
	var selected_legality: Dictionary = hex_state.get("selected_target_legality", {}) if hex_state.get("selected_target_legality", {}) is Dictionary else {}
	var selected_click_intent: Dictionary = hex_state.get("selected_target_board_click_intent", {}) if hex_state.get("selected_target_board_click_intent", {}) is Dictionary else {}
	var selected_direct_actionable := bool(hex_state.get("selected_target_direct_actionable", false))
	var selected_continuity_context: Dictionary = hex_state.get("selected_target_continuity_context", {}) if hex_state.get("selected_target_continuity_context", {}) is Dictionary else {}
	var selected_closing_context: Dictionary = hex_state.get("selected_target_closing_context", {}) if hex_state.get("selected_target_closing_context", {}) is Dictionary else {}
	var movement_click_intent: Dictionary = hex_state.get("active_movement_board_click_intent", {}) if hex_state.get("active_movement_board_click_intent", {}) is Dictionary else {}
	var legal_movement_intents: Array = hex_state.get("legal_movement_intents", []) if hex_state.get("legal_movement_intents", []) is Array else []
	if not player_input_active:
		legal_destinations = []
		legal_melee_targets = []
		legal_ranged_targets = []
		legal_movement_intents = []
		if not selected_legality.is_empty():
			selected_legality = selected_legality.duplicate(true)
			selected_legality["melee"] = false
			selected_legality["ranged"] = false
			selected_legality["attackable"] = false
			selected_legality["blocked"] = false
			selected_legality["input_locked"] = true
		if not selected_click_intent.is_empty():
			selected_click_intent = selected_click_intent.duplicate(true)
			selected_click_intent["action"] = ""
			selected_click_intent["label"] = ""
			selected_click_intent["attackable"] = false
			selected_click_intent["blocked"] = false
			selected_click_intent["message"] = "Input locked: it is not the player's turn."
	var hovered_destination_preview := _hover_destination_preview()
	var movement_range_region := _movement_range_contour_summary(legal_destinations)
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	var selected_target_blocked := selected_target_id != "" and bool(selected_legality.get("blocked", false))
	var stack_entries := []
	for stack in _all_visible_stacks():
		var battle_id := String(stack.get("battle_id", ""))
		var cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		stack_entries.append(
			{
				"battle_id": battle_id,
				"side": String(stack.get("side", "")),
				"unit_id": String(stack.get("unit_id", "")),
				"q": cell.x,
				"r": cell.y,
				"alive_count": _stack_alive_count(stack),
				"active": battle_id == String(_battle.get("active_stack_id", "")),
				"selected_target": battle_id == selected_target_id,
				"preserved_setup_target": battle_id == selected_target_id and not selected_continuity_context.is_empty(),
				"ordinary_closing_target": battle_id == selected_target_id and not selected_closing_context.is_empty(),
				"selected_target_blocked": battle_id == selected_target_id and selected_target_blocked,
				"legal_melee_target": battle_id in legal_melee_targets,
				"legal_ranged_target": battle_id in legal_ranged_targets,
				"legal_attack_target": battle_id in legal_melee_targets or battle_id in legal_ranged_targets,
				"status_effect_badges": _stack_status_effect_badge_summary(stack),
			}
		)

	var objective_entries := []
	for index in range(_field_objectives.size()):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var objective_type := String(objective.get("type", ""))
		var cell := _objective_cell(index, objective_type)
		var art_profile := _field_objective_art_profile(objective_type)
		var control_side := String(objective.get("control_side", "neutral"))
		var render_spec: Dictionary = _field_objective_art_manifest.get("render", {}) if _field_objective_art_manifest.get("render", {}) is Dictionary else {}
		var landmark_extent := clampf(
			hex_radius * float(render_spec.get("extent_factor", 0.82)),
			float(render_spec.get("extent_min", 19.0)),
			float(render_spec.get("extent_max", 28.0))
		)
		var landmark_center := _hex_center(cell, layout)
		objective_entries.append(
			{
				"id": String(objective.get("id", "")),
				"type": objective_type,
				"q": cell.x,
				"r": cell.y,
				"control_side": control_side,
				"control_shape": _field_objective_control_shape(control_side),
				"art_id": String(art_profile.get("art_id", "")),
				"art_path": String(art_profile.get("art_path", "")),
				"alt_text": String(art_profile.get("alt_text", "")),
				"art_loaded": bool(art_profile.get("art_loaded", false)),
				"uses_legacy_geometry_fallback": bool(art_profile.get("uses_legacy_geometry_fallback", true)),
				"marker_rect": Rect2(
					landmark_center - Vector2(landmark_extent, landmark_extent),
					Vector2(landmark_extent * 2.0, landmark_extent * 2.0)
				),
			}
		)

	var obstacle_entries := []
	for obstacle in BattleRulesScript.battle_obstacles(_battle):
		var obstacle_path := obstacle_art_path(_battle_terrain_id(), obstacle)
		obstacle_entries.append({
			"id": String(obstacle.get("id", "")),
			"kind": String(obstacle.get("kind", "")),
			"cells": obstacle.get("cells", []),
			"art_path": obstacle_path,
			"art_loaded": _obstacle_texture(obstacle_path) != null,
			"art_rect": _obstacle_art_rect(obstacle, layout),
			"art_anchor": _obstacle_center(obstacle, layout),
		})

	return {
		"presentation": "hex",
		"columns": HEX_COLUMNS,
		"rows": HEX_ROWS,
		"obstacles": obstacle_entries,
		"hex_count": HEX_COLUMNS * HEX_ROWS,
		"hex_radius": hex_radius,
		"board_rect": Rect2(Vector2.ZERO, size),
		"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
		"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
		"terrain": terrain_id,
		"battlefield_family": battlefield_family(terrain_id),
		"battlefield_path": battlefield_art_path(terrain_id),
		"battlefield_loaded": _battlefield_texture() != null,
		"hex_grid_mode": SettingsService.battle_hex_grid_mode_id(),
		"distance": int(_battle.get("distance", 1)),
		"player_stack_count": _player_stacks.size(),
		"enemy_stack_count": _enemy_stacks.size(),
		"stack_cells": stack_entries,
		"field_objective_cells": objective_entries,
		"occupied_hexes": hex_state.get("occupied_hexes", {}),
		"legal_destinations": legal_destinations,
		"legal_destination_count": legal_destinations.size(),
		"movement_range_visual_model": MOVE_RANGE_VISUAL_MODEL,
		"movement_range_cell_count": legal_destinations.size(),
		"movement_range_fill_radius_factor": MOVE_RANGE_FILL_RADIUS_FACTOR,
		"movement_range_fill_alpha": MOVE_RANGE_FILL_ALPHA,
		"movement_range_contour_radius_factor": MOVE_RANGE_CONTOUR_RADIUS_FACTOR,
		"movement_range_contour_segment_factor": MOVE_RANGE_CONTOUR_SEGMENT_FACTOR,
		"movement_range_contour_alpha": MOVE_RANGE_CONTOUR_ALPHA,
		"movement_range_contour_width": MOVE_RANGE_CONTOUR_WIDTH,
		"movement_range_boundary_segment_count": int(movement_range_region.get("boundary_segment_count", 0)),
		"movement_range_internal_shared_edge_count": int(movement_range_region.get("internal_shared_edge_count", 0)),
		"movement_range_region_edge_balance_exact": bool(movement_range_region.get("edge_balance_exact", false)),
		"movement_range_internal_edges_drawn": false,
		"movement_range_destination_pip_count": legal_destinations.size(),
		"movement_range_pip_radius_factor": MOVE_RANGE_PIP_RADIUS_FACTOR,
		"movement_range_pip_alpha": MOVE_RANGE_PIP_ALPHA,
		"movement_range_complete_cell_outlines": false,
		"movement_range_all_legal_cells_drawn": _movement_range_shown(),
		"movement_range_hover_only": false,
		"movement_range_below_active_targets_and_stacks": true,
		"movement_range_action_authority": "legal_destinations_for_active_stack",
		"legal_movement_intents": legal_movement_intents,
		"hovered_destination_preview": hovered_destination_preview,
		"hovered_destination_detail": String(hovered_destination_preview.get("destination_detail", "")),
		"hovered_destination_sets_up_selected_target_attack": bool(hovered_destination_preview.get("sets_up_selected_target_attack", false)),
		"hovered_destination_closes_on_selected_target": bool(hovered_destination_preview.get("closes_on_selected_target", false)),
		"controller_board_focused": has_focus(),
		"controller_cursor_q": _controller_cursor_cell.x,
		"controller_cursor_r": _controller_cursor_cell.y,
		"controller_cursor_cell_role": _controller_cursor_cell_role(),
		"controller_cursor_battle_id": _stack_id_at_cell(_controller_cursor_cell),
		"controller_cursor_legal_destination": _is_legal_destination_cell(_controller_cursor_cell),
		"active_movement_board_click_intent": movement_click_intent,
		"active_movement_board_click_action": String(movement_click_intent.get("action", "")),
		"active_movement_board_click_label": String(movement_click_intent.get("label", "")),
		"legal_melee_targets": legal_melee_targets,
		"legal_ranged_targets": legal_ranged_targets,
		"legal_attack_target_count": _unique_target_count(legal_melee_targets, legal_ranged_targets),
		"selected_target_battle_id": selected_target_id,
		"selected_target_legality": selected_legality,
		"selected_target_board_click_intent": selected_click_intent,
		"selected_target_board_click_action": String(selected_click_intent.get("action", "")),
		"selected_target_board_click_label": String(selected_click_intent.get("label", "")),
		"selected_target_direct_actionable": selected_direct_actionable,
		"selected_target_continuity_context": selected_continuity_context,
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_continuity_emphasis": String(selected_continuity_context.get("emphasis", "")),
		"selected_target_closing_context": selected_closing_context,
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"selected_target_closing_emphasis": String(selected_closing_context.get("emphasis", "")),
		"selected_target_footer_label": _target_state_label(),
		"selected_target_blocked": selected_target_blocked,
		"selected_target_attackable": bool(selected_legality.get("attackable", false)),
		"has_active_cell": _stack_has_cell(String(_battle.get("active_stack_id", "")), stack_cells),
		"has_selected_target_cell": _stack_has_cell(selected_target_id, stack_cells),
	}

## What the board draws under the stacks: the battlefield painting and the part
## of it that fills the window, the props, and the grid the Options ask for.
func validation_battlefield_summary() -> Dictionary:
	var terrain_id := _battle_terrain_id()
	var texture := _battlefield_texture()
	var board_rect := Rect2(Vector2.ZERO, size)
	var layout := _current_hex_layout()
	var props := []
	for obstacle in BattleRulesScript.battle_obstacles(_battle):
		var path := obstacle_art_path(terrain_id, obstacle)
		var cell_centers := []
		for cell in obstacle.get("cells", []):
			if cell is Dictionary:
				cell_centers.append(_hex_center(Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0))), layout))
		props.append({
			"id": String(obstacle.get("id", "")),
			"kind": String(obstacle.get("kind", "")),
			"size": int(obstacle.get("size", 1)),
			"path": path,
			"loaded": _obstacle_texture(path) != null,
			"texture_size": _obstacle_texture(path).get_size() if _obstacle_texture(path) != null else Vector2.ZERO,
			"rect": _obstacle_art_rect(obstacle, layout),
			"anchor": _obstacle_center(obstacle, layout),
			"cell_centers": cell_centers,
		})
	return {
		"terrain": terrain_id,
		"family": battlefield_family(terrain_id),
		"path": battlefield_art_path(terrain_id),
		"loaded": texture != null,
		"texture_size": texture.get_size() if texture != null else Vector2.ZERO,
		"board_rect": board_rect,
		"cover_region": _cover_region(texture.get_size(), board_rect.size) if texture != null else Rect2(),
		"hex_width": float(layout.get("hex_width", 0.0)),
		"props": props,
		"hex_grid_mode": SettingsService.battle_hex_grid_mode_id(),
		"hex_grid_cells": _hex_grid_cells().size(),
		"movement_range_shown": _movement_range_shown(),
		"ambient_profile": String(_terrain_ambient_profile().get("id", "")),
	}

func validation_terrain_ambient_summary() -> Dictionary:
	var profile := _terrain_ambient_profile()
	var field_rect := _current_field_rect()
	var enabled := _terrain_ambient_available()
	var reduced_motion := SettingsService.reduced_motion_enabled()
	var phase := TERRAIN_AMBIENT_STATIC_PHASE if reduced_motion else _terrain_ambient_phase
	var entries: Array = _terrain_ambient_entries(field_rect, phase) if enabled else []
	var all_contained := enabled and not entries.is_empty()
	var identities: Array = []
	for entry_value in entries:
		if not entry_value is Dictionary:
			all_contained = false
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("contained", false)):
			all_contained = false
		identities.append({
			"index": int(entry.get("index", -1)),
			"profile_id": String(entry.get("profile_id", "")),
			"kind": String(entry.get("kind", "")),
			"base_normalized": entry.get("base_normalized", Vector2(-1.0, -1.0)),
		})
	return {
		"model": TERRAIN_AMBIENT_MODEL,
		"draw_order": TERRAIN_AMBIENT_DRAW_ORDER.duplicate(),
		"terrain": _battle_terrain_id(),
		"terrain_profile_key": battlefield_family(_battle_terrain_id()),
		"profile_id": String(profile.get("id", "")),
		"kind": String(profile.get("kind", "")),
		"profile_count": int(profile.get("count", 0)),
		"enabled": enabled,
		"reduced_motion": reduced_motion,
		"high_contrast": FrontierVisualKitScript.high_contrast_enabled(),
		"animating": _terrain_ambient_should_animate(),
		"phase": phase,
		"phase_speed": TERRAIN_AMBIENT_PHASE_SPEED,
		"static_phase": TERRAIN_AMBIENT_STATIC_PHASE,
		"field_rect": field_rect,
		"entry_count": entries.size(),
		"entries": entries.duplicate(true),
		"identities": identities,
		"all_contained": all_contained,
		"session_mutation_source": "none_presentation_only",
	}

func validation_color_cue_summary() -> Dictionary:
	return {
		"mode": FrontierVisualKitScript.color_cue_mode(),
		"assisted": FrontierVisualKitScript.color_cue_assist_enabled(),
		"player_color": _side_color("player"),
		"enemy_color": _side_color("enemy"),
		"neutral_color": _controller_color("neutral"),
		"player_side_mark": "circle_P" if FrontierVisualKitScript.color_cue_assist_enabled() else "none",
		"enemy_side_mark": "triangle_E" if FrontierVisualKitScript.color_cue_assist_enabled() else "none",
		"side_marks_drawn_with_stack_tokens": FrontierVisualKitScript.color_cue_assist_enabled(),
		"board_tooltip_uses_color_independent_move_wording": "outlined hex" in tooltip_text.to_lower() and "green" not in tooltip_text.to_lower(),
	}

func validation_unit_art_summary() -> Dictionary:
	var stack_entries := []
	var loaded_count := 0
	var missing := []
	var standee_loaded_count := 0
	var missing_standees := []
	var presentation_motion_count := 0
	var presentation_motion_roles := {}
	var token_art_source_counts := {
		"resting_battle_standee": 0,
		"resting_battle_icon": 0,
		"event_animation_sheet": 0,
		"animation_sheet_fallback": 0,
		"procedural_glyph_fallback": 0,
	}
	var stack_cells := _stack_cells()
	var hex_layout := _current_hex_layout()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		var cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		var presentation := _stack_presentation_summary(stack, cell, hex_layout, stack_cells)
		var unit_id := String(stack.get("unit_id", ""))
		var art := ContentService.get_unit_art(unit_id)
		var path := String(art.get("battle_icon", ""))
		var texture := _unit_battle_icon_for_stack(stack)
		var standee_path := String(art.get("battle_standee", ""))
		var standee_texture := _unit_battle_standee_for_stack(stack)
		var animation := ContentService.get_unit_animation(unit_id)
		var animation_path := String(animation.get("sprite_sheet", ""))
		var animation_sheet := _unit_animation_sheet_for_stack(stack)
		var loaded := texture != null
		var standee_loaded := standee_texture != null
		var animation_loaded := animation_sheet != null
		var token_art_source := _stack_token_art_source(stack)
		token_art_source_counts[token_art_source] = int(token_art_source_counts.get(token_art_source, 0)) + 1
		if loaded:
			loaded_count += 1
		else:
			missing.append(unit_id)
		if standee_loaded:
			standee_loaded_count += 1
		else:
			missing_standees.append(unit_id)
		if bool(presentation.get("presentation_motion_active", false)):
			presentation_motion_count += 1
			var role := String(presentation.get("presentation_motion_role", "")).strip_edges()
			if role != "":
				presentation_motion_roles[role] = int(presentation_motion_roles.get(role, 0)) + 1
		stack_entries.append({
			"battle_id": battle_id,
			"unit_id": unit_id,
			"battle_icon": path,
			"loaded": loaded,
			"battle_standee": standee_path,
			"battle_standee_loaded": standee_loaded,
			"battle_standee_facing": "right" if String(stack.get("side", "")) == "player" else "left",
			"battle_standee_rect": _stack_standee_rect(Vector2(float(presentation.get("presentation_x", 0.0)), float(presentation.get("presentation_y", 0.0))), float(hex_layout.get("radius", 1.0))),
			"animation_sheet": animation_path,
			"animation_loaded": animation_loaded,
			"token_art_source": token_art_source,
			"animation_state": _animation_state_for_stack(stack),
			"animation_frame_index": _animation_frame_index_for_stack(stack),
			"cell_q": cell.x,
			"cell_r": cell.y,
			"presentation_x": presentation.get("presentation_x", 0.0),
			"presentation_y": presentation.get("presentation_y", 0.0),
			"presentation_motion_active": bool(presentation.get("presentation_motion_active", false)),
			"presentation_motion_event_id": String(presentation.get("presentation_motion_event_id", "")),
			"presentation_motion_role": String(presentation.get("presentation_motion_role", "")),
			"presentation_motion_source_battle_id": String(presentation.get("presentation_motion_source_battle_id", "")),
			"presentation_motion_target_battle_id": String(presentation.get("presentation_motion_target_battle_id", "")),
			"presentation_motion_from_q": int(presentation.get("presentation_motion_from_q", -1)),
			"presentation_motion_from_r": int(presentation.get("presentation_motion_from_r", -1)),
			"presentation_motion_to_q": int(presentation.get("presentation_motion_to_q", -1)),
			"presentation_motion_to_r": int(presentation.get("presentation_motion_to_r", -1)),
			"presentation_motion_progress": presentation.get("presentation_motion_progress", 1.0),
			"alive_count": _stack_alive_count(stack),
			"event_playback_visible": _stack_alive_count(stack) <= 0 and not _animation_playback_record_for_stack(battle_id).is_empty(),
		})
	return {
		"visible_stack_count": stack_entries.size(),
		"battle_icon_loaded_count": loaded_count,
		"missing_battle_icon_units": missing,
		"battle_standee_loaded_count": standee_loaded_count,
		"missing_battle_standee_units": missing_standees,
		"animation_sheet_loaded_count": stack_entries.filter(func(entry): return bool(entry.get("animation_loaded", false))).size(),
		"missing_animation_units": stack_entries.filter(func(entry): return not bool(entry.get("animation_loaded", false))).map(func(entry): return String(entry.get("unit_id", ""))),
		"animation_playback": validation_animation_playback_summary(),
		"cue_playback": validation_cue_playback_summary(),
		"vfx_playback": validation_vfx_playback_summary(),
		"audio_playback": validation_audio_playback_summary(),
		"camera_playback": validation_camera_playback_summary(),
		"presentation_motion_count": presentation_motion_count,
		"presentation_motion_roles": presentation_motion_roles,
		"token_art_source_counts": token_art_source_counts,
		"token_visual_contract": _stack_token_visual_contract(hex_layout),
		"stacks": stack_entries,
	}

func _stack_token_visual_contract(hex_layout: Dictionary) -> Dictionary:
	var hex_radius := float(hex_layout.get("radius", 1.0))
	var token_radius := _stack_token_radius(hex_radius)
	return {
		"presentation_model": STACK_TOKEN_PRESENTATION_MODEL,
		"resting_art_source": "battle_standee",
		"event_art_source": "animation_sheet",
		"battle_icon_fallback_after_missing_standee": true,
		"event_animation_requires_live_playback_record": true,
		"playback_expiry_restores_resting_standee": true,
		"token_radius": token_radius,
		"hit_radius": _stack_hit_shape_radius(hex_radius),
		"hex_radius": hex_radius,
		"token_radius_factor": STACK_TOKEN_RADIUS_FACTOR,
		"token_radius_min": STACK_TOKEN_RADIUS_MIN,
		"token_radius_max": STACK_TOKEN_RADIUS_MAX,
		"hit_radius_factor": STACK_HIT_RADIUS_FACTOR,
		"hit_radius_min": STACK_HIT_RADIUS_MIN,
		"hit_radius_max": STACK_HIT_RADIUS_MAX,
		"hit_radius_padding": STACK_HIT_RADIUS_PADDING,
		"painted_token_larger_than_legacy_scale": token_radius > clampf(hex_radius * STACK_HIT_RADIUS_FACTOR, STACK_HIT_RADIUS_MIN, STACK_HIT_RADIUS_MAX),
		"token_diameter_within_neighbor_spacing": token_radius * 2.0 < SQRT_3 * hex_radius,
		"token_shadow_within_hex_radius": token_radius + 4.0 < hex_radius,
		"inner_fill": STACK_TOKEN_INNER_FILL,
		"side_rim_alpha": STACK_TOKEN_SIDE_RIM_ALPHA,
		"side_rim_width": maxf(2.4, token_radius * STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR),
		"animation_art_extent_factor": STACK_ANIMATION_ART_EXTENT_FACTOR,
		"icon_art_extent_factor": STACK_ICON_ART_EXTENT_FACTOR,
		"standee_art_height_factor": STACK_STANDEE_ART_HEIGHT_FACTOR,
		"standee_art_height_min": STACK_STANDEE_ART_HEIGHT_MIN,
		"standee_art_height_max": STACK_STANDEE_ART_HEIGHT_MAX,
		"standee_aspect": STACK_STANDEE_ASPECT,
		"standee_ground_offset_factor": STACK_STANDEE_GROUND_OFFSET_FACTOR,
		"standee_size": _stack_standee_size(hex_radius),
		"animation_art_diameter_fraction": STACK_ANIMATION_ART_EXTENT_FACTOR * 0.5,
		"icon_art_diameter_fraction": STACK_ICON_ART_EXTENT_FACTOR * 0.5,
		"art_contained_within_token": STACK_ANIMATION_ART_EXTENT_FACTOR <= 2.0 and STACK_ICON_ART_EXTENT_FACTOR <= 2.0,
	}

func validation_animation_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var records := {}
	var delayed_record_count := 0
	var max_sequence_delay_msec := 0
	for battle_id in _stack_animation_playback_records.keys():
		var record: Dictionary = _stack_animation_playback_records.get(battle_id, {}) if _stack_animation_playback_records.get(battle_id, {}) is Dictionary else {}
		var sequence_delay := int(record.get("sequence_delay_msec", 0))
		if sequence_delay > 0:
			delayed_record_count += 1
			max_sequence_delay_msec = maxi(max_sequence_delay_msec, sequence_delay)
		records[String(battle_id)] = record.duplicate(true)
	return {
		"playback_duration_msec": STACK_ANIMATION_EVENT_PLAYBACK_MSEC,
		"presentation_speed": _presentation_speed,
		"effective_playback_duration_msec": _presentation_duration_msec(STACK_ANIMATION_EVENT_PLAYBACK_MSEC),
		"reaction_delay_msec": STACK_ANIMATION_REACTION_DELAY_MSEC,
		"active_playback_count": records.size(),
		"delayed_record_count": delayed_record_count,
		"max_sequence_delay_msec": max_sequence_delay_msec,
		"active_records": records,
		"latest_serial_by_stack": _latest_animation_serial_by_stack.duplicate(true),
		"queue_count": BattleRulesScript.animation_event_queue(_battle).size() if not _battle.is_empty() else 0,
	}

func validation_cue_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	_activate_due_audio_cue_playback()
	var records := {}
	var vfx_record_count := 0
	var audio_record_count := 0
	var vfx_cue_count := 0
	var audio_cue_count := 0
	var delayed_record_count := 0
	var max_sequence_delay_msec := 0
	for battle_id in _stack_animation_cue_playback_records.keys():
		var record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		var vfx_ids: Array = record.get("selected_vfx_cue_ids", []) if record.get("selected_vfx_cue_ids", []) is Array else []
		var audio_ids: Array = record.get("selected_audio_cue_ids", []) if record.get("selected_audio_cue_ids", []) is Array else []
		var sequence_delay := int(record.get("sequence_delay_msec", 0))
		if sequence_delay > 0:
			delayed_record_count += 1
			max_sequence_delay_msec = maxi(max_sequence_delay_msec, sequence_delay)
		if not vfx_ids.is_empty():
			vfx_record_count += 1
			vfx_cue_count += vfx_ids.size()
		if not audio_ids.is_empty():
			audio_record_count += 1
			audio_cue_count += audio_ids.size()
		records[String(battle_id)] = record.duplicate(true)
	return {
		"active_cue_record_count": records.size(),
		"vfx_record_count": vfx_record_count,
		"audio_record_count": audio_record_count,
		"vfx_cue_count": vfx_cue_count,
		"audio_cue_count": audio_cue_count,
		"delayed_record_count": delayed_record_count,
		"max_sequence_delay_msec": max_sequence_delay_msec,
		"reaction_delay_msec": STACK_ANIMATION_REACTION_DELAY_MSEC,
		"active_records": records,
	}

func validation_vfx_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var stack_cells := _stack_cells()
	var entries := _vfx_draw_entries(_current_hex_layout(), stack_cells)
	var projectile_count := 0
	var status_count := 0
	var impact_count := 0
	var cast_count := 0
	var imported_asset_draw_count := 0
	var procedural_fallback_draw_count := 0
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if bool(entry.get("asset_loaded", false)):
			imported_asset_draw_count += 1
		else:
			procedural_fallback_draw_count += 1
		match String(entry.get("kind", "")):
			"projectile_path":
				projectile_count += 1
			"status_residue", "status_clear":
				status_count += 1
			"damage_tick", "melee_arc", "retaliation_arc", "stack_fade":
				impact_count += 1
			"cast_anchor":
				cast_count += 1
	return {
		"active_vfx_draw_count": entries.size(),
		"projectile_draw_count": projectile_count,
		"status_draw_count": status_count,
		"impact_draw_count": impact_count,
		"cast_draw_count": cast_count,
		"imported_asset_draw_count": imported_asset_draw_count,
		"procedural_fallback_draw_count": procedural_fallback_draw_count,
		"vfx_manifest_path": BATTLE_VFX_MANIFEST_PATH,
		"vfx_manifest_loaded": _battle_vfx_manifest_loaded,
		"active_draw_entries": entries,
	}

func validation_vfx_asset_summary() -> Dictionary:
	_load_battle_vfx_manifest()
	var cues: Dictionary = _battle_vfx_manifest.get("cues", {}) if _battle_vfx_manifest.get("cues", {}) is Dictionary else {}
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
		if _battle_vfx_texture_for_path(texture_path) != null:
			loaded_texture_paths.append(texture_path)
		else:
			missing_texture_paths.append(texture_path)
	return {
		"manifest_path": BATTLE_VFX_MANIFEST_PATH,
		"manifest_loaded": _battle_vfx_manifest_loaded,
		"schema_id": String(_battle_vfx_manifest.get("schema_id", "")),
		"mapped_cue_count": cue_ids.size(),
		"mapped_cue_ids": cue_ids,
		"unique_texture_count": texture_paths.size(),
		"texture_paths": texture_paths,
		"loaded_texture_count": loaded_texture_paths.size(),
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
	}

func validation_field_objective_art_summary() -> Dictionary:
	_load_field_objective_art_manifest()
	var objectives: Dictionary = _field_objective_art_manifest.get("objectives", {}) if _field_objective_art_manifest.get("objectives", {}) is Dictionary else {}
	var objective_types: Array = objectives.keys()
	objective_types.sort()
	var profiles := []
	var loaded_texture_paths := []
	var missing_texture_paths := []
	var silhouettes := []
	for objective_type_value in objective_types:
		var objective_type := String(objective_type_value)
		var profile := _field_objective_art_profile(objective_type)
		profiles.append(profile)
		var texture_path := String(profile.get("art_path", ""))
		if bool(profile.get("art_loaded", false)):
			loaded_texture_paths.append(texture_path)
		elif texture_path != "":
			missing_texture_paths.append(texture_path)
		var silhouette := String(profile.get("silhouette", ""))
		if silhouette != "" and not silhouettes.has(silhouette):
			silhouettes.append(silhouette)
	return {
		"manifest_path": BATTLE_FIELD_OBJECTIVE_ART_MANIFEST_PATH,
		"manifest_loaded": _field_objective_art_manifest_loaded,
		"schema_id": String(_field_objective_art_manifest.get("schema_id", "")),
		"presentation_model": BATTLE_FIELD_OBJECTIVE_ART_PRESENTATION_MODEL,
		"mapped_objective_type_count": objective_types.size(),
		"mapped_objective_types": objective_types,
		"loaded_texture_count": loaded_texture_paths.size(),
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
		"unique_silhouette_count": silhouettes.size(),
		"control_shapes": {
			"player": _field_objective_control_shape("player"),
			"enemy": _field_objective_control_shape("enemy"),
			"neutral": _field_objective_control_shape("neutral"),
		},
		"profiles": profiles,
		"texture_cache_count": _field_objective_art_textures.size(),
		"missing_cache_count": _field_objective_art_texture_missing.size(),
	}

func validation_field_objective_art_profile(objective_type: String, override_path: String = "") -> Dictionary:
	return _field_objective_art_profile(objective_type, override_path)

func validation_battle_status_effect_art_summary() -> Dictionary:
	_load_battle_status_effect_art_manifest()
	var statuses: Dictionary = _battle_status_effect_art_manifest.get("statuses", {}) if _battle_status_effect_art_manifest.get("statuses", {}) is Dictionary else {}
	var status_ids: Array = statuses.keys()
	status_ids.sort()
	var profiles := []
	var loaded_texture_paths := []
	var missing_texture_paths := []
	var silhouettes := []
	var polarities := {}
	for status_id_value in status_ids:
		var status_id := String(status_id_value)
		var profile := _battle_status_effect_art_profile(status_id)
		profiles.append(profile)
		var texture_path := String(profile.get("art_path", ""))
		if bool(profile.get("art_loaded", false)):
			loaded_texture_paths.append(texture_path)
		elif texture_path != "":
			missing_texture_paths.append(texture_path)
		var silhouette := String(profile.get("silhouette", ""))
		if silhouette != "" and not silhouettes.has(silhouette):
			silhouettes.append(silhouette)
		var polarity := String(profile.get("polarity", ""))
		polarities[polarity] = int(polarities.get(polarity, 0)) + 1
	var render_spec: Dictionary = _battle_status_effect_art_manifest.get("render", {}) if _battle_status_effect_art_manifest.get("render", {}) is Dictionary else {}
	return {
		"manifest_path": BATTLE_STATUS_EFFECT_ART_MANIFEST_PATH,
		"manifest_loaded": _battle_status_effect_art_manifest_loaded,
		"schema_id": String(_battle_status_effect_art_manifest.get("schema_id", "")),
		"presentation_model": BATTLE_STATUS_EFFECT_ART_PRESENTATION_MODEL,
		"mapped_status_count": status_ids.size(),
		"mapped_status_ids": status_ids,
		"loaded_texture_count": loaded_texture_paths.size(),
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
		"unique_silhouette_count": silhouettes.size(),
		"polarity_counts": polarities,
		"polarity_foundations": _battle_status_effect_art_manifest.get("polarity_foundations", {}).duplicate(true),
		"max_visible_badges": int(render_spec.get("max_visible_badges", 2)),
		"profiles": profiles,
		"texture_cache_count": _battle_status_effect_art_textures.size(),
		"missing_cache_count": _battle_status_effect_art_texture_missing.size(),
	}

func validation_battle_status_effect_art_profile(status_id: String, override_path: String = "") -> Dictionary:
	return _battle_status_effect_art_profile(status_id, override_path)

func validation_stack_status_effect_badges(stack: Dictionary) -> Dictionary:
	return _stack_status_effect_badge_summary(stack)

func validation_audio_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	_activate_due_audio_cue_playback()
	_cleanup_audio_players()
	var records := {}
	var audio_cue_count := 0
	var generated_waveform_count := 0
	var imported_asset_count := 0
	var generated_fallback_count := 0
	var scheduled_record_count := 0
	var played_audio_cue_count := 0
	var suppressed_audio_cue_count := 0
	for battle_id in _stack_animation_audio_playback_records.keys():
		var record: Dictionary = _stack_animation_audio_playback_records.get(battle_id, {}) if _stack_animation_audio_playback_records.get(battle_id, {}) is Dictionary else {}
		var audio_ids: Array = record.get("selected_audio_cue_ids", []) if record.get("selected_audio_cue_ids", []) is Array else []
		audio_cue_count += audio_ids.size()
		generated_waveform_count += int(record.get("generated_waveform_count", 0))
		imported_asset_count += int(record.get("imported_asset_count", 0))
		generated_fallback_count += int(record.get("generated_fallback_count", 0))
		played_audio_cue_count += int(record.get("played_audio_cue_count", 0))
		suppressed_audio_cue_count += int(record.get("suppressed_audio_cue_count", 0))
		if bool(record.get("scheduled", false)):
			scheduled_record_count += 1
		records[String(battle_id)] = record.duplicate(true)
	return {
		"active_audio_record_count": records.size(),
		"audio_cue_count": audio_cue_count,
		"generated_waveform_count": generated_waveform_count,
		"imported_asset_count": imported_asset_count,
		"generated_fallback_count": generated_fallback_count,
		"played_audio_cue_count": played_audio_cue_count,
		"suppressed_audio_cue_count": suppressed_audio_cue_count,
		"scheduled_record_count": scheduled_record_count,
		"active_player_count": _active_audio_player_count(),
		"active_voice_mix": _active_audio_voice_mix(),
		"mix_counters": _audio_mix_counters.duplicate(true),
		"audio_bus": BATTLE_AUDIO_BUS,
		"sfx_manifest_path": BATTLE_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _battle_sfx_manifest_loaded,
		"muted": SettingsService.effects_audio_muted(),
		"reduced_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"effective_voice_budget": _effective_battle_audio_voice_budget(),
		"active_records": records,
	}

func validation_reset_audio_mix() -> void:
	for entry in _active_audio_players:
		if entry is Dictionary:
			var player = entry.get("player", null)
			if player is AudioStreamPlayer and is_instance_valid(player):
				player.queue_free()
	_active_audio_players.clear()
	_audio_last_started_msec_by_cue.clear()
	_audio_mix_counters = {
		"played": 0,
		"suppressed": 0,
		"evicted": 0,
		"suppressed_by_reason": {},
	}

func validation_play_audio_cue(audio_id: String, battle_id: String = "validation", serial: int = 1) -> Dictionary:
	return _play_audio_cue(audio_id, battle_id, serial)

func validation_camera_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var stack_cells := _stack_cells()
	var hex_layout := _current_hex_layout()
	var records := _camera_playback_records(hex_layout, stack_cells)
	var focus_kind_counts := {}
	var shake_record_count := 0
	var strongest_record := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var focus_kind := String(record.get("focus_kind", "")).strip_edges()
		if focus_kind != "":
			focus_kind_counts[focus_kind] = int(focus_kind_counts.get(focus_kind, 0)) + 1
		if float(record.get("shake_strength", 0.0)) > 0.0:
			shake_record_count += 1
		if strongest_record.is_empty() or float(record.get("shake_strength", 0.0)) > float(strongest_record.get("shake_strength", 0.0)):
			strongest_record = record
	var offset := _battle_camera_offset_for_records(records)
	return {
		"active_camera_record_count": records.size(),
		"focus_kind_counts": focus_kind_counts,
		"shake_record_count": shake_record_count,
		"strongest_event_id": String(strongest_record.get("event_id", "")),
		"strongest_focus_kind": String(strongest_record.get("focus_kind", "")),
		"strongest_shake_strength": snappedf(float(strongest_record.get("shake_strength", 0.0)), 0.001),
		"configured_shake_mode": SettingsService.battle_camera_shake_mode_id(),
		"configured_shake_scale": SettingsService.battle_camera_shake_scale(),
		"offset_x": snappedf(offset.x, 0.01),
		"offset_y": snappedf(offset.y, 0.01),
		"max_offset_px": BATTLE_CAMERA_MAX_OFFSET_PX,
		"records": records,
	}

func validation_preview_hex_destination(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if _is_legal_destination_cell(cell):
		_hover_destination_cell = cell
	else:
		_hover_destination_cell = Vector2i(-1, -1)
	queue_redraw()
	return BattleRulesScript.movement_intent_for_destination(_battle, q, r)

func validation_perform_hex_cell_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_click_position_for_cell(cell)
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not resolve a point inside the requested cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_shape_miss_position"] = bool(probe.get("found_shape_miss_position", false))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_outer_hex_ring_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_outer_ring_click_position_for_cell(cell)
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"found_outer_ring_position": false,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find a token-miss point in the visible outer hex ring.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_outer_ring_position"] = bool(probe.get("found_outer_ring_position", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell)
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find a friendly-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_friendly_shape_overlap"] = bool(probe.get("found_shape_overlap", probe.get("found_friendly_shape_overlap", false)))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_enemy_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find an enemy-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_enemy_overlapped_occupied_hex_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var cell_target_before := _stack_id_at_cell(cell)
	if cell_target_before == "":
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is not occupied by a stack.",
		}
	var probe := _validation_overlapped_occupied_hex_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find an enemy-shape overlap inside the occupied hex.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	cell_target_before = _stack_id_at_cell(resolved_cell)
	var cell_target_intent_before := BattleRulesScript.board_click_attack_intent_for_target(_battle, cell_target_before)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["cell_target_before"] = cell_target_before
	dispatch["cell_target_side_before"] = String(_stack_by_id(cell_target_before).get("side", ""))
	dispatch["cell_target_click_action_before"] = String(cell_target_intent_before.get("action", ""))
	dispatch["cell_target_tooltip_before"] = String(cell_target_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_board_fallback_tooltip() -> Dictionary:
	var position := _validation_fallback_tooltip_position()
	if position.x < 0.0:
		return {
			"ok": false,
			"message": "Validation could not find an empty board fallback tooltip position.",
		}
	var resolved_cell := _hex_cell_at_position(position)
	var shape_target := _stack_id_at_position(position)
	return {
		"ok": true,
		"tooltip": _get_tooltip(position),
		"position_x": position.x,
		"position_y": position.y,
		"resolved_q": resolved_cell.x,
		"resolved_r": resolved_cell.y,
		"shape_target": shape_target,
	}

## The turn ribbon's chips as the screen draws them, for reports.
func validation_turn_strip_identity_surface() -> Dictionary:
	var layout := _turn_ribbon_layout()
	var chips := _turn_ribbon_chips()
	var rows: Array = []
	for entry in chips:
		var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
		var rect: Rect2 = entry.get("rect", Rect2())
		rows.append({
			"slot": int(entry.get("slot", 0)),
			"phase": String(entry.get("phase", "")),
			"battle_id": String(stack.get("battle_id", "")),
			"full_name": _stack_full_name(stack),
			"alive_count": _stack_alive_count(stack),
			"side": String(stack.get("side", "")),
			"unit_id": String(stack.get("unit_id", "")),
			"current": String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", "")),
			"portrait_loaded": _unit_battle_icon_for_stack(stack) != null,
			"tooltip": _get_tooltip(rect.get_center()),
			"rect": rect,
			"center": rect.get_center(),
		})
	return {
		"rows": rows,
		"visible_count": rows.size(),
		"ribbon_rect": Rect2(layout.get("rect", Rect2())),
		"overflow": bool(layout.get("overflow", false)),
		"active_stack_id": String(_battle.get("active_stack_id", "")),
		"turn_forecast": _turn_forecast.duplicate(true),
	}

func _draw() -> void:
	_stack_hit_shapes = []
	_stack_plate_records = {}
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _battle.is_empty():
		return
	_board_queries()
	_board_query_in_draw = true
	_draw_board()
	_board_query_in_draw = false

func _draw_board() -> void:
	var field_rect := _current_field_rect()
	var hex_field_rect := _hex_field_rect(field_rect)
	var hex_layout := _hex_layout(hex_field_rect)
	hex_layout = _camera_adjusted_hex_layout(hex_layout)
	_draw_terrain(hex_layout)
	_draw_terrain_ambient(field_rect)
	_draw_hero_figures(hex_layout)
	_draw_hex_grid(hex_layout)
	_draw_field_objectives(hex_layout)
	var stack_cells := _stack_cells()
	_draw_tactical_affordances(hex_layout, stack_cells)
	_draw_controller_cursor(hex_layout)
	_draw_order_path(hex_layout)
	_draw_vfx_cues(hex_layout, stack_cells)
	_draw_stack_tokens(hex_layout, stack_cells)
	if not _battle.has("playback_event"):
		for id in _spell_target_candidates:
			if not stack_cells.has(id): continue
			var selected := String(id) == _pointed_stack_id()
			for body_cell in BattleRulesScript.Footprint.cells(_stack_by_id(String(id))):
				var center := _hex_center(Vector2i(int(body_cell.q), int(body_cell.r)), hex_layout)
				_draw_hex_outline(center, float(hex_layout.get("radius", 20.0)) * 0.96, ACTIVE_COLOR if selected else Color(0.42, 0.80, 1.0, 0.85), 4.0 if selected else 1.5)
	if not _hover_ribbon_battle_id.is_empty() and stack_cells.has(_hover_ribbon_battle_id):
		_draw_body_outline(_hover_ribbon_battle_id, hex_layout, float(hex_layout.get("radius", 20.0)) * 0.98, Color(1.0, 1.0, 1.0, 0.85), 2.4)
	_draw_turn_ribbon()
	_draw_hover_forecast()
	_draw_field_cursor()

## The painted battlefield fills the window behind the field, darkened
## towards the edges. Without a painting the hexes get their terrain colours.
func _draw_terrain(hex_layout: Dictionary) -> void:
	var terrain := _battle_terrain_id()
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_rect(board_rect, _terrain_color_for(terrain), true)
	var battlefield := _battlefield_texture()
	if battlefield != null:
		draw_texture_rect_region(battlefield, board_rect, _cover_region(battlefield.get_size(), board_rect.size))
	else:
		_draw_hex_snapped_procedural_terrain(hex_layout, terrain)
	draw_texture_rect(_vignette(), board_rect, false, BATTLEFIELD_VIGNETTE_COLOR)

## The part of a texture that covers target_size without stretching it.
func _cover_region(texture_size: Vector2, target_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture_size)
	var scale := maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	var source_size := target_size / scale
	return Rect2((texture_size - source_size) * 0.5, source_size)

func _vignette() -> Texture2D:
	if _vignette_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 1.0)])
		_vignette_texture = GradientTexture2D.new()
		_vignette_texture.gradient = gradient
		_vignette_texture.fill = GradientTexture2D.FILL_RADIAL
		_vignette_texture.fill_from = Vector2(0.5, 0.54)
		_vignette_texture.fill_to = Vector2(1.25, 0.54)
		_vignette_texture.width = 256
		_vignette_texture.height = 256
	return _vignette_texture

func _soft_glow() -> Texture2D:
	if _soft_glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
		_soft_glow_texture = GradientTexture2D.new()
		_soft_glow_texture.gradient = gradient
		_soft_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_soft_glow_texture.fill_from = Vector2(0.5, 0.5)
		_soft_glow_texture.fill_to = Vector2(1.0, 0.5)
		_soft_glow_texture.width = 128
		_soft_glow_texture.height = 128
	return _soft_glow_texture

func _terrain_ambient_profile() -> Dictionary:
	var profile_value: Variant = TERRAIN_AMBIENT_PROFILES.get(battlefield_family(_battle_terrain_id()), {})
	return profile_value if profile_value is Dictionary else {}

func _terrain_ambient_available() -> bool:
	return not _battle.is_empty() \
		and not _terrain_ambient_profile().is_empty() \
		and not FrontierVisualKitScript.high_contrast_enabled()

func _terrain_ambient_should_animate() -> bool:
	return _terrain_ambient_available() and not SettingsService.reduced_motion_enabled()

func _terrain_ambient_entries(field_rect: Rect2, phase: float) -> Array:
	var profile := _terrain_ambient_profile()
	if profile.is_empty() or field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return []
	var radius := clampf(minf(field_rect.size.x, field_rect.size.y) * float(profile.get("radius_factor", 0.0024)), 1.15, 2.55)
	var outer_radius := radius * 3.2
	var safe_inset := maxf(10.0, outer_radius + 2.0)
	var safe_rect := field_rect.grow(-safe_inset)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return []
	var drift: Vector2 = profile.get("drift", Vector2.ZERO)
	var entries: Array = []
	for index in range(int(profile.get("count", 0))):
		var base_normalized := Vector2(
			0.08 + fmod(0.173 + float(index) * 0.347, 1.0) * 0.84,
			0.08 + fmod(0.291 + float(index) * 0.613, 1.0) * 0.84
		)
		var local_phase := phase + float(index) * 1.731
		var motion_normalized := Vector2(
			sin(local_phase) * drift.x,
			cos(local_phase * 0.73 + float(index) * 0.41) * drift.y
		)
		var center := safe_rect.position + (base_normalized + motion_normalized) * safe_rect.size
		var pulse := 0.78 + 0.22 * sin(local_phase * 1.19 + 0.7)
		var bounds := Rect2(center - Vector2(outer_radius, outer_radius), Vector2(outer_radius * 2.0, outer_radius * 2.0))
		entries.append({
			"index": index,
			"profile_id": String(profile.get("id", "")),
			"kind": String(profile.get("kind", "")),
			"base_normalized": base_normalized,
			"center": center,
			"radius": radius,
			"outer_radius": outer_radius,
			"alpha": float(profile.get("alpha", 0.0)) * pulse,
			"color": profile.get("color", Color.TRANSPARENT),
			"bounds": bounds,
			"contained": field_rect.encloses(bounds),
		})
	return entries

func _draw_terrain_ambient(field_rect: Rect2) -> void:
	if not _terrain_ambient_available():
		return
	var phase := TERRAIN_AMBIENT_STATIC_PHASE if SettingsService.reduced_motion_enabled() else _terrain_ambient_phase
	for entry_value in _terrain_ambient_entries(field_rect, phase):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var radius := float(entry.get("radius", 0.0))
		var alpha := float(entry.get("alpha", 0.0))
		var color: Color = entry.get("color", Color.TRANSPARENT)
		var halo_color := Color(color.r, color.g, color.b, alpha * 0.18)
		var soft_color := Color(color.r, color.g, color.b, alpha * 0.38)
		var core_color := Color(color.r, color.g, color.b, alpha)
		if String(entry.get("kind", "")) == "dust":
			var tangent := Vector2(1.0, -0.24).normalized()
			draw_line(center - tangent * radius * 1.8, center + tangent * radius * 1.8, soft_color, maxf(0.7, radius * 0.72), true)
			draw_circle(center, radius * 0.48, core_color)
		else:
			draw_circle(center, radius * 3.2, halo_color)
			draw_circle(center, radius * 1.55, soft_color)
			draw_circle(center, radius * 0.52, core_color)

func _draw_hex_snapped_procedural_terrain(hex_layout: Dictionary, terrain: String) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var base_color := _terrain_color_for(terrain)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var shade := 0.88 + _hex_variation(cell, 11.0) * 0.18
			var fill := Color(
				clampf(base_color.r * shade, 0.0, 1.0),
				clampf(base_color.g * shade, 0.0, 1.0),
				clampf(base_color.b * shade, 0.0, 1.0),
				0.92
			)
			_draw_hex(center, radius * TERRAIN_HEX_FALLBACK_INSET, fill, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			_draw_hex_procedural_detail(center, radius, terrain, cell)

func _draw_hex_procedural_detail(center: Vector2, radius: float, terrain: String, cell: Vector2i) -> void:
	var detail_roll := _hex_variation(cell, 29.0)
	match terrain:
		"forest":
			if detail_roll > 0.34:
				_draw_tree(center + Vector2(radius * 0.12, -radius * 0.08), radius * (0.26 + detail_roll * 0.08))
		"swamp", "mire":
			if detail_roll > 0.24:
				draw_circle(center + Vector2(radius * 0.12, radius * 0.04), radius * 0.24, Color(0.10, 0.17, 0.16, 0.28))
				draw_circle(center + Vector2(radius * 0.02, -radius * 0.04), radius * 0.12, Color(0.36, 0.42, 0.31, 0.15))
		"rough":
			if detail_roll > 0.30:
				_draw_hill(center + Vector2(0.0, radius * 0.06), radius * 0.88, radius * 0.38)
		"road":
			var road_row := int(HEX_ROWS / 2)
			if cell.y == road_row or (cell.y == road_row - 1 and cell.x < 4) or (cell.y == road_row + 1 and cell.x > 6):
				draw_line(center + Vector2(-radius * 0.46, radius * 0.18), center + Vector2(radius * 0.46, -radius * 0.12), Color(0.50, 0.39, 0.24, 0.36), radius * 0.20, true)
		_:
			if detail_roll > 0.48:
				draw_line(center + Vector2(-radius * 0.26, radius * 0.22), center + Vector2(radius * 0.18, radius * 0.02), Color(0.16, 0.23, 0.12, 0.24), 1.6, true)

## This battle's painting, loaded once; null when it is missing.
func _battlefield_texture() -> Texture2D:
	var path := battlefield_art_path(_battle_terrain_id())
	if _battlefield_textures.has(path):
		return _battlefield_textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	elif FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	_battlefield_textures[path] = texture
	return texture

## The painted battlefield (and prop set) a battle terrain is fought on.
static func battlefield_family(terrain_id: String) -> String:
	var normalized := terrain_id.strip_edges().to_lower()
	return String(BATTLEFIELD_FAMILIES.get(normalized if normalized != "" else "plains", "grass"))

static func battlefield_art_path(terrain_id: String) -> String:
	return "%s/%s.png" % [BATTLEFIELD_ART_ROOT, battlefield_family(terrain_id)]

## Every texture the board loads for this battle's terrain and stacks, so the
## entry can load them in the background before the first board draw.
static func art_texture_paths_for_battle(battle: Dictionary) -> PackedStringArray:
	var paths := PackedStringArray()
	if battle.is_empty():
		return paths
	var terrain_id := String(battle.get("terrain", "plains"))
	paths.append(battlefield_art_path(terrain_id))
	for obstacle in BattleRulesScript.battle_obstacles(battle):
		var obstacle_path := obstacle_art_path(terrain_id, obstacle)
		if obstacle_path != "" and not paths.has(obstacle_path):
			paths.append(obstacle_path)
	var stacks: Variant = battle.get("stacks", [])
	for stack in (stacks if stacks is Array else []):
		var unit_id := String(stack.get("unit_id", "")) if stack is Dictionary else ""
		if unit_id == "":
			continue
		var animation := ContentService.get_unit_animation(unit_id)
		var art := ContentService.get_unit_art(unit_id)
		for path in [String(animation.get("pose_sheet", animation.get("sprite_sheet", ""))), String(art.get("battle_standee", "")), String(art.get("battle_icon", ""))]:
			if path != "" and not paths.has(path):
				paths.append(path)
	for side in ["player", "enemy"]:
		var hero := BattleRulesScript.hero_presentation(battle, side)
		if bool(hero.get("has_figure", false)):
			var figure_path := BattleHeroFigureScript.figure_path(String(hero.get("hero_id", "")), String(hero.get("faction_id", "")))
			if figure_path != "" and not paths.has(figure_path):
				paths.append(figure_path)
	return paths

func _unit_battle_icon_for_stack(stack: Dictionary) -> Texture2D:
	var unit_id := String(stack.get("unit_id", ""))
	if unit_id == "":
		return null
	var art := ContentService.get_unit_art(unit_id)
	var path := String(art.get("battle_icon", ""))
	if path == "":
		return null
	return _unit_battle_icon_texture(path)

func _unit_battle_standee_for_stack(stack: Dictionary) -> Texture2D:
	var unit_id := String(stack.get("unit_id", ""))
	if unit_id == "":
		return null
	var art := ContentService.get_unit_art(unit_id)
	var path := String(art.get("battle_standee", ""))
	if path == "":
		return null
	return _unit_battle_standee_texture(path)

func _unit_battle_standee_texture(path: String) -> Texture2D:
	if _unit_battle_standee_textures.has(path):
		return _unit_battle_standee_textures[path]
	if _unit_battle_standee_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_unit_battle_standee_textures[path] = texture
		return texture
	_unit_battle_standee_missing[path] = true
	return null

func _unit_battle_icon_texture(path: String) -> Texture2D:
	if _unit_battle_icon_textures.has(path):
		return _unit_battle_icon_textures[path]
	if _unit_battle_icon_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_unit_battle_icon_textures[path] = texture
		return texture
	_unit_battle_icon_missing[path] = true
	return null

func _unit_animation_sheet_for_stack(stack: Dictionary) -> Texture2D:
	var unit_id := String(stack.get("unit_id", ""))
	if unit_id == "":
		return null
	var animation := ContentService.get_unit_animation(unit_id)
	var path := String(animation.get("pose_sheet", animation.get("sprite_sheet", "")))
	if path == "":
		return null
	return _unit_animation_sheet_texture(path)

func _unit_animation_sheet_texture(path: String) -> Texture2D:
	if _unit_animation_sheet_textures.has(path):
		return _unit_animation_sheet_textures[path]
	if _unit_animation_sheet_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_unit_animation_sheet_textures[path] = texture
		return texture
	_unit_animation_sheet_missing[path] = true
	return null

func _animation_frame_region_for_stack(stack: Dictionary) -> Rect2:
	var state_name := _animation_state_for_stack(stack)
	var animation := ContentService.get_unit_animation(String(stack.get("unit_id", "")))
	if BattleUnitPose.has_authored_poses(animation):
		var preferences := AnimationCueCatalogScript.normalize_animation_preferences(_animation_preferences())
		var reduced := bool(preferences.get("reduced_motion", false))
		var battle_id := String(stack.get("battle_id", ""))
		var now := Time.get_ticks_msec()
		var record := _animation_playback_record_for_stack(battle_id)
		var waiting := BattleUnitPose.waiting_for_start(record, now)
		# Keep idle breathing, or the settled defensive pose, during a queued
		# reaction. Freezing frame zero of the death/hit clip starts it too early.
		var elapsed := BattleUnitPose.elapsed_msec({} if waiting else record, now)
		if (record.is_empty() or waiting) and state_name in ["idle_hold", "ready_active"]:
			elapsed = BattleUnitPose.idle_elapsed_msec(animation, now, String(stack.get("unit_id", "")) + "/" + battle_id)
		var progress := 1.0 if waiting else _stack_presentation_progress(battle_id)
		return BattleUnitPose.region(animation, state_name, progress, elapsed, reduced)
	var row := _animation_state_row_for_unit(String(stack.get("unit_id", "")), state_name)
	var frame := _animation_frame_index_for_stack(stack)
	return Rect2(Vector2(64.0 * float(frame), 64.0 * float(row)), Vector2(64.0, 64.0))

func _animation_frame_index_for_stack(stack: Dictionary) -> int:
	var battle_id := String(stack.get("battle_id", ""))
	var playback_record := _animation_playback_record_for_stack(battle_id)
	if playback_record.is_empty() or BattleUnitPose.waiting_for_start(playback_record, Time.get_ticks_msec()):
		return int(Time.get_ticks_msec() / 180) % 4
	var progress := _stack_presentation_progress(battle_id)
	return clampi(int(floor(progress * 4.0)), 0, 3)

func _animation_state_for_stack(stack: Dictionary) -> String:
	var playback_record := _animation_playback_record_for_stack(String(stack.get("battle_id", "")))
	if not playback_record.is_empty() and not BattleUnitPose.waiting_for_start(playback_record, Time.get_ticks_msec()):
		return String(playback_record.get("state", ""))
	return _fallback_animation_state_for_stack(stack)

func _fallback_animation_state_for_stack(stack: Dictionary) -> String:
	var battle_id := String(stack.get("battle_id", ""))
	if battle_id != "" and battle_id == String(_battle.get("active_stack_id", "")):
		return "ready_active"
	if bool(stack.get("defending", false)):
		return "defend_brace"
	return "idle_hold"

func _animation_playback_record_for_stack(battle_id: String) -> Dictionary:
	if battle_id == "":
		return {}
	var expires_at := int(_stack_animation_playback_until_msec.get(battle_id, 0))
	if expires_at <= int(Time.get_ticks_msec()):
		_stack_animation_playback_records.erase(battle_id)
		_stack_animation_playback_until_msec.erase(battle_id)
		_stack_animation_cue_playback_records.erase(battle_id)
		_stack_animation_audio_playback_records.erase(battle_id)
		return {}
	var record: Dictionary = _stack_animation_playback_records.get(battle_id, {}) if _stack_animation_playback_records.get(battle_id, {}) is Dictionary else {}
	return record.duplicate(true)

func _sync_animation_playback_records() -> void:
	var now := int(Time.get_ticks_msec())
	var stack_ids := {}
	for stack in _battle.get("stacks", []):
		if stack is Dictionary:
			var battle_id := String(stack.get("battle_id", ""))
			if battle_id != "":
				stack_ids[battle_id] = true
	# A hero's cast plays its cues from beside its army (_hero_anchor_cell).
	for side in ["player", "enemy"]:
		stack_ids[BattleRulesScript.hero_actor_id(side)] = true
	for battle_id in _stack_animation_playback_records.keys():
		if not stack_ids.has(String(battle_id)):
			_stack_animation_playback_records.erase(battle_id)
			_stack_animation_playback_until_msec.erase(battle_id)
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)
	for event in BattleRulesScript.animation_event_queue(_battle):
		if not (event is Dictionary):
			continue
		var battle_id := String(event.get("battle_id", ""))
		if battle_id == "" or not stack_ids.has(battle_id):
			continue
		var serial := int(event.get("serial", 0))
		if serial <= int(_latest_animation_serial_by_stack.get(battle_id, 0)):
			continue
		_latest_animation_serial_by_stack[battle_id] = serial
		var cue_record := _animation_cue_playback_record_for_event(event)
		var sequence_delay_msec := _presentation_sequence_delay_msec(_sequence_delay_msec_for_event(event, cue_record))
		var base_duration_msec: int = int(cue_record.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)) if not cue_record.is_empty() else STACK_ANIMATION_EVENT_PLAYBACK_MSEC
		var actor := BattleRulesScript._get_stack_by_id(_battle, battle_id)
		var animation := ContentService.get_unit_animation(String(actor.get("unit_id", "")))
		var pose_name := BattleUnitPose.clip_name(String(event.get("state", "")))
		var pose_spec := BattleUnitPose.clip(animation, String(event.get("state", "")))
		# Ready/status events fall back to idle artwork, but are not idle cycles.
		# Likewise an unupgraded action alias must not acquire an idle duration.
		var authored_action: bool = pose_name != "idle" and animation.get("pose_clips", {}).has(pose_name) and bool(pose_spec.get("authored_timing", false))
		if authored_action:
			base_duration_msec = BattleUnitPose.clip_duration_msec(pose_spec)
			if String(event.get("event_id", "")) == "battle_unit_move":
				var walk_path: Array = _battle.get("playback_event", {}).get("walk_path", event.get("walk_path", []))
				base_duration_msec *= maxi(1, walk_path.size() - 1)
			if SettingsService.reduced_motion_enabled():
				base_duration_msec = mini(base_duration_msec, 260)
		var duration_msec: int = _presentation_duration_msec(base_duration_msec)
		var started_at_msec := now + sequence_delay_msec
		var expires_at_msec: int = started_at_msec + max(1, duration_msec)
		var playback_record: Dictionary = event.duplicate(true)
		playback_record["observed_at_msec"] = now
		playback_record["started_at_msec"] = started_at_msec
		playback_record["expires_at_msec"] = expires_at_msec
		playback_record["sequence_delay_msec"] = sequence_delay_msec
		playback_record["max_duration_ms"] = duration_msec
		playback_record["base_duration_ms"] = base_duration_msec
		if authored_action and pose_spec.has("contact_frame") and not SettingsService.reduced_motion_enabled():
			var release_at := started_at_msec + _presentation_duration_msec(BattleUnitPose.contact_msec(pose_spec))
			var flight := _presentation_duration_msec(int(pose_spec.get("projectile_travel_msec", 180))) if String(event.get("event_id", "")) == "battle_unit_ranged_attack" else 0
			playback_record["impact_at_msec"] = release_at + flight
			expires_at_msec = maxi(expires_at_msec, release_at + flight + 16)
			playback_record["expires_at_msec"] = expires_at_msec
			cue_record["audio_started_at_msec"] = release_at
			cue_record["vfx_started_at_msec"] = release_at
			cue_record["vfx_duration_msec"] = flight if flight > 0 else mini(_presentation_duration_msec(200), maxi(1, expires_at_msec-release_at))
		var previous_body: Dictionary = _stack_animation_playback_records.get(battle_id, {})
		var keep_action_body: bool = bool(_battle.get("_fluid_contact_reaction", false)) and String(event.get("event_id", "")) in ["battle_status_applied", "battle_status_expired"] and previous_body.has("impact_at_msec") and int(previous_body.get("expires_at_msec", 0)) > now
		# A self buff updates effects at contact without replacing the caster's
		# recovery poses. Real hit/death reactions still interrupt the body.
		if keep_action_body:
			var previous_audio: Dictionary = _stack_animation_audio_playback_records.get(battle_id, {})
			if bool(previous_audio.get("scheduled", false)) and int(previous_audio.get("started_at_msec", now + 1)) <= now:
				_register_audio_cue_playback(_stack_animation_cue_playback_records.get(battle_id, {}))
		else:
			_stack_animation_playback_records[battle_id] = playback_record
		if not cue_record.is_empty():
			cue_record["observed_at_msec"] = now
			cue_record["started_at_msec"] = started_at_msec
			cue_record["expires_at_msec"] = expires_at_msec
			cue_record["sequence_delay_msec"] = sequence_delay_msec
			cue_record["max_duration_ms"] = duration_msec
			_stack_animation_cue_playback_records[battle_id] = cue_record
			_register_audio_cue_playback(cue_record)
		else:
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)
		_stack_animation_playback_until_msec[battle_id] = maxi(expires_at_msec, int(previous_body.get("expires_at_msec", 0))) if keep_action_body else expires_at_msec

func _sequence_delay_msec_for_event(event: Dictionary, cue_record: Dictionary) -> int:
	if bool(_battle.get("_fluid_contact_reaction", false)):
		return 0
	var event_id := String(event.get("event_id", "")).strip_edges()
	var policy := String(cue_record.get("selected_playback_policy", "")).strip_edges()
	if policy.begins_with("queue_after_"):
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	if event_id in ["battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"] and String(event.get("source_battle_id", "")).strip_edges() != "":
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	if event_id == "battle_retaliation":
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	return 0

func _presentation_duration_msec(base_duration_msec: int) -> int:
	match _presentation_speed:
		BattleRulesScript.PRESENTATION_SPEED_FAST:
			return max(1, int(round(float(max(1, base_duration_msec)) * 0.42)))
		BattleRulesScript.PRESENTATION_SPEED_INSTANT:
			return 1
	return max(1, base_duration_msec)

func _presentation_sequence_delay_msec(base_delay_msec: int) -> int:
	match _presentation_speed:
		BattleRulesScript.PRESENTATION_SPEED_FAST:
			return max(0, int(round(float(max(0, base_delay_msec)) * 0.42)))
		BattleRulesScript.PRESENTATION_SPEED_INSTANT:
			return 0
	return max(0, base_delay_msec)

func _expire_animation_playback_records() -> void:
	var now := int(Time.get_ticks_msec())
	for battle_id in _stack_animation_playback_until_msec.keys():
		if int(_stack_animation_playback_until_msec.get(battle_id, 0)) <= now:
			_stack_animation_playback_until_msec.erase(battle_id)
			_stack_animation_playback_records.erase(battle_id)
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)

func _animation_cue_playback_record_for_event(event: Dictionary) -> Dictionary:
	var event_id := String(event.get("event_id", "")).strip_edges()
	var battle_id := String(event.get("battle_id", "")).strip_edges()
	if event_id == "" or battle_id == "":
		return {}
	var policy := AnimationCueCatalogScript.cue_playback_policy_for_event(event_id, _animation_preferences())
	if policy.is_empty():
		return {}
	var selected_vfx_cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var selected_audio_cue_ids: Array = policy.get("selected_audio_cue_ids", []) if policy.get("selected_audio_cue_ids", []) is Array else []
	var allows_strong_flash := bool(policy.get("allows_strong_flash", true))
	if allows_strong_flash:
		selected_vfx_cue_ids = _spell_specific_vfx_cue_ids_for_event(event, selected_vfx_cue_ids)
	selected_audio_cue_ids = _spell_specific_audio_cue_ids_for_event(event, selected_audio_cue_ids)
	selected_audio_cue_ids = AudioPaletteScript.battle_cues(event, _battle.get("stacks", []), selected_audio_cue_ids)
	return {
		"battle_id": battle_id,
		"event_id": event_id,
		"state": String(event.get("state", "")),
		"serial": int(event.get("serial", 0)),
		"target_battle_id": String(event.get("target_battle_id", "")),
		"source_battle_id": String(event.get("source_battle_id", "")),
		"from_q": int(event.get("from_q", -1)),
		"from_r": int(event.get("from_r", -1)),
		"to_q": int(event.get("to_q", -1)),
		"to_r": int(event.get("to_r", -1)),
		"spell_id": String(event.get("spell_id", "")),
		"resolution_type": String(event.get("resolution_type", "")),
		"cue_id": String(policy.get("cue_id", "")),
		"mode": String(policy.get("mode", AnimationCueCatalogScript.MODE_NORMAL)),
		"selected_animation_state": String(policy.get("selected_animation_state", "")),
		"selected_visual_policy": String(policy.get("selected_visual_policy", "")),
		"selected_playback_policy": String(policy.get("selected_playback_policy", "")),
		"selected_blocking_policy": String(policy.get("selected_blocking_policy", "")),
		"selected_vfx_cue_ids": selected_vfx_cue_ids,
		"selected_audio_cue_ids": selected_audio_cue_ids,
		"allows_strong_flash": allows_strong_flash,
		"max_duration_ms": int(policy.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
		"audio_policy": String(policy.get("audio_policy", "")),
	}

func _spell_specific_vfx_cue_ids_for_event(event: Dictionary, base_ids: Array) -> Array:
	var event_id := String(event.get("event_id", "")).strip_edges()
	if not ["battle_unit_cast", "battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"].has(event_id):
		return base_ids.duplicate(true)
	var cue_id := _spell_specific_vfx_cue_id(String(event.get("spell_id", "")), String(event.get("resolution_type", "")))
	if cue_id == "":
		return base_ids.duplicate(true)
	var family_spec := _battle_vfx_manifest_cue(cue_id)
	if String(family_spec.get("motion_profile", "")) in CombatVfxMotion.SPELL_PROFILES:
		# The authored effect already communicates cast/application. Do not
		# bury its silhouette beneath the old universal cast/status halos.
		var remaining := []
		for base_id in base_ids:
			if String(base_id) not in ["vfx_placeholder_cast_anchor", "vfx_placeholder_status_residue"]:
				remaining.append(base_id)
		return _prepend_unique_string(cue_id, remaining)
	return _prepend_unique_string(cue_id, base_ids)

func _spell_specific_audio_cue_ids_for_event(event: Dictionary, base_ids: Array) -> Array:
	var event_id := String(event.get("event_id", "")).strip_edges()
	if not ["battle_unit_cast", "battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"].has(event_id):
		return base_ids.duplicate(true)
	var cue_id := _spell_specific_audio_cue_id(String(event.get("spell_id", "")), String(event.get("resolution_type", "")))
	if cue_id == "":
		return base_ids.duplicate(true)
	return _prepend_unique_string(cue_id, base_ids)

func _prepend_unique_string(value: String, items: Array) -> Array:
	var result := []
	var normalized := value.strip_edges()
	if normalized != "":
		result.append(normalized)
	for item in items:
		var item_text := String(item).strip_edges()
		if item_text != "" and not result.has(item_text):
			result.append(item_text)
	return result

func _spell_specific_vfx_cue_id(spell_id: String, resolution_type: String) -> String:
	_load_battle_vfx_manifest()
	var normalized_spell_id := spell_id.strip_edges()
	var spell_cues: Dictionary = _battle_vfx_manifest.get("spell_cues", {}) if _battle_vfx_manifest.get("spell_cues", {}) is Dictionary else {}
	var cue_id := String(spell_cues.get(normalized_spell_id, "")).strip_edges()
	if cue_id != "":
		var cue := _battle_vfx_manifest_cue(cue_id)
		if String(cue.get("spell_id", "")).strip_edges() == normalized_spell_id:
			return cue_id
	var family := resolution_type.strip_edges()
	match family:
		"effect":
			return "vfx_spell_command_ward"
	return ""

func _spell_specific_audio_cue_id(spell_id: String, resolution_type: String) -> String:
	match spell_id.strip_edges():
		"spell_cinder_burst":
			return "audio_spell_cinder_burst"
		"spell_coal_rain":
			return "audio_spell_coal_rain"
		"spell_sunlance_arc":
			return "audio_spell_sunlance_arc"
		"spell_briar_bind":
			return "audio_spell_briar_bind"
		"spell_graft_mend":
			return "audio_spell_graft_mend"
		"spell_prism_bastion":
			return "audio_spell_prism_bastion"
		"spell_resonant_chorus":
			return "audio_spell_resonant_chorus"
	var family := resolution_type.strip_edges()
	match family:
		"effect":
			return "audio_spell_command_ward"
	return ""

func _animation_preferences() -> Dictionary:
	return SettingsService.animation_preferences()

func _animation_state_row_for_unit(unit_id: String, state_name: String) -> int:
	var animation := ContentService.get_unit_animation(unit_id)
	var states: Array = animation.get("states", []) if animation.get("states", []) is Array else []
	for index in range(states.size()):
		if String(states[index]) == state_name:
			return index
	return 0

func _battle_terrain_id() -> String:
	var terrain_id := String(_battle.get("terrain", "plains")).strip_edges().to_lower()
	return terrain_id if terrain_id != "" else "plains"

func _terrain_color_for(terrain_id: String) -> Color:
	return TERRAIN_COLORS.get(battlefield_family(terrain_id), TERRAIN_COLORS["grass"])

## Thin lines over the painted field, with a faint shadow under them, around
## the hexes the Options' hex grid asks for.
func _draw_hex_grid(hex_layout: Dictionary) -> void:
	var cells := _hex_grid_cells()
	if cells.is_empty():
		return
	var k := float(hex_layout.get("radius", 1.0)) / REFERENCE_HEX_RADIUS
	var line := Color(0.98, 0.89, 0.62, 0.5) if FrontierVisualKitScript.high_contrast_enabled() else BATTLEFIELD_GRID_LINE
	draw_set_transform(Vector2(0.0, 1.3 * k), 0.0, Vector2.ONE)
	_draw_unique_hex_grid_lines(hex_layout, cells, BATTLEFIELD_GRID_SHADOW, maxf(1.0, 2.2 * k), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_unique_hex_grid_lines(hex_layout, cells, line, maxf(1.0, 1.3 * k), 1.0)

## Full: every hex. Range only: the hexes the player's stack can move to, while
## it acts. Off: none.
func _hex_grid_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match SettingsService.battle_hex_grid_mode_id():
		SettingsService.BATTLE_HEX_GRID_FULL:
			for row in range(HEX_ROWS):
				for column in range(HEX_COLUMNS):
					cells.append(Vector2i(column, row))
		SettingsService.BATTLE_HEX_GRID_RANGE:
			if not _spell_target_mode and String(_active_stack.get("side", "")) == "player":
				cells.assign(_movement_range_region().get("cells", []))
	return cells

## The player's stack shows where it can move unless the hex grid is off.
func _movement_range_shown() -> bool:
	return SettingsService.battle_hex_grid_mode_id() != SettingsService.BATTLE_HEX_GRID_OFF

func _draw_field_objectives(hex_layout: Dictionary) -> void:
	var marker_count: int = mini(_field_objectives.size(), 5)
	for index in range(marker_count):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var objective_type := String(objective.get("type", ""))
		var cell := _objective_cell(index, objective_type)
		var center := _hex_center(cell, hex_layout)
		var color := _controller_color(String(objective.get("control_side", "neutral")))
		_draw_objective_marker(center, objective, color, float(hex_layout.get("radius", 1.0)))

func _draw_body_outline(battle_id: String, hex_layout: Dictionary, radius: float, color: Color, width: float) -> void:
	var stack := BattleRulesScript._get_stack_by_id(_battle, battle_id)
	for cell in BattleRulesScript.Footprint.cells(stack):
		var center := _hex_center(Vector2i(cell.q, cell.r), hex_layout)
		if FrontierVisualKitScript.high_contrast_enabled():
			_draw_hex_outline(center, radius, color, width)
		else:
			# Short corner brackets preserve the exact footprint without fencing
			# in the painted creature with a dominant full gold hexagon.
			for index in range(6):
				var angle := deg_to_rad(60.0 * index - 30.0)
				var corner := center + _hex_corner_offset(angle, radius)
				for direction in [-1.0, 1.0]:
					var neighbor := center + _hex_corner_offset(angle + direction * PI / 3.0, radius)
					draw_line(corner, corner.lerp(neighbor, 0.22), color, minf(width, 1.8), true)

func _draw_tactical_affordances(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	if _spell_target_mode: return
	if _active_stack.is_empty():
		return
	var active_id := String(_active_stack.get("battle_id", ""))
	if not stack_cells.has(active_id):
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var player_input_active := String(_active_stack.get("side", "")) == "player"

	if player_input_active and _movement_range_shown():
		var legal_destinations: Array = _legal_destinations()
		var movement_range_region := _movement_range_region()
		var legal_cell_keys: Dictionary = movement_range_region.get("cell_keys", {})
		for destination in legal_destinations:
			if not (destination is Dictionary):
				continue
			var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if not _cell_in_bounds(cell):
				continue
			_draw_movement_destination_cue(cell, _hex_center(cell, hex_layout), radius, legal_cell_keys)

	_draw_body_outline(active_id, hex_layout, radius * 1.02, ACTIVE_COLOR, 3.4)

	if player_input_active:
		var legal_melee_targets: Array = _legal_attack_targets(false)
		var legal_ranged_targets: Array = _legal_attack_targets(true)
		for battle_id_value in legal_ranged_targets:
			var ranged_id := String(battle_id_value)
			if not stack_cells.has(ranged_id):
				continue
			_draw_body_outline(ranged_id, hex_layout, radius * 0.90, LEGAL_RANGED_COLOR, 2.0)
		for battle_id_value in legal_melee_targets:
			var melee_id := String(battle_id_value)
			if not stack_cells.has(melee_id):
				continue
			_draw_body_outline(melee_id, hex_layout, radius * 0.96, LEGAL_MELEE_COLOR, 2.4)

	if player_input_active and not _target_stack.is_empty():
		var target_id := String(_target_stack.get("battle_id", ""))
		if stack_cells.has(target_id):
			var target_cell: Vector2i = stack_cells.get(target_id)
			var target_center := _hex_center(target_cell, hex_layout)
			var continuity_context := _selected_target_continuity_context()
			var preserved_setup_target := not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == target_id
			if _selected_target_is_blocked():
				_draw_body_outline(target_id, hex_layout, radius * 1.02, BLOCKED_TARGET_COLOR, 3.2)
				if preserved_setup_target:
					_draw_body_outline(target_id, hex_layout, radius * 1.11, BLOCKED_TARGET_COLOR.lightened(0.18), 2.0)
				_draw_blocked_target_marker(target_center, radius)
			else:
				if preserved_setup_target:
					var setup_color := LEGAL_RANGED_COLOR if String(continuity_context.get("board_click_action", "")) == "shoot" else LEGAL_MELEE_COLOR
					_draw_body_outline(target_id, hex_layout, radius * 1.12, setup_color, 2.4)
				_draw_body_outline(target_id, hex_layout, radius * 1.02, TARGET_COLOR, 3.2)

func _draw_movement_destination_cue(cell: Vector2i, center: Vector2, radius: float, legal_cell_keys: Dictionary) -> void:
	_draw_hex(
		center,
		radius * MOVE_RANGE_FILL_RADIUS_FACTOR,
		Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, MOVE_RANGE_FILL_ALPHA),
		Color(0.0, 0.0, 0.0, 0.0),
		0.0
	)
	var contour_points := _hex_points(center, radius * MOVE_RANGE_CONTOUR_RADIUS_FACTOR)
	var inset := (1.0 - MOVE_RANGE_CONTOUR_SEGMENT_FACTOR) * 0.5
	for edge_index in range(6):
		var neighbor := _movement_range_neighbor_for_edge(cell, edge_index)
		if legal_cell_keys.has(_movement_range_cell_key(neighbor)):
			continue
		var edge_start: Vector2 = contour_points[edge_index]
		var edge_end: Vector2 = contour_points[(edge_index + 1) % contour_points.size()]
		draw_line(
			edge_start.lerp(edge_end, inset),
			edge_start.lerp(edge_end, 1.0 - inset),
			Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, MOVE_RANGE_CONTOUR_ALPHA),
			MOVE_RANGE_CONTOUR_WIDTH,
			true
		)
	draw_circle(
		center,
		clampf(radius * MOVE_RANGE_PIP_RADIUS_FACTOR, 1.4, 2.6),
		Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, MOVE_RANGE_PIP_ALPHA),
		true
	)

func _movement_range_contour_summary(legal_destinations: Array) -> Dictionary:
	var cells: Array[Vector2i] = []
	var cell_keys := {}
	for destination in legal_destinations:
		if not (destination is Dictionary):
			continue
		var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
		if not _cell_in_bounds(cell):
			continue
		var key := _movement_range_cell_key(cell)
		if cell_keys.has(key):
			continue
		cell_keys[key] = true
		cells.append(cell)
	var boundary_segment_count := 0
	var internal_directed_edge_count := 0
	for cell in cells:
		for edge_index in range(6):
			var neighbor := _movement_range_neighbor_for_edge(cell, edge_index)
			if cell_keys.has(_movement_range_cell_key(neighbor)):
				internal_directed_edge_count += 1
			else:
				boundary_segment_count += 1
	var internal_shared_edge_count := int(internal_directed_edge_count / 2)
	return {
		"cells": cells,
		"cell_keys": cell_keys,
		"boundary_segment_count": boundary_segment_count,
		"internal_shared_edge_count": internal_shared_edge_count,
		"edge_balance_exact": boundary_segment_count + internal_shared_edge_count * 2 == cells.size() * 6,
	}

func _movement_range_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _movement_range_neighbor_for_edge(cell: Vector2i, edge_index: int) -> Vector2i:
	var even_row_offsets := [
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 0),
	]
	var odd_row_offsets := [
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, 0),
	]
	var offsets := even_row_offsets if cell.y % 2 == 0 else odd_row_offsets
	return cell + offsets[clampi(edge_index, 0, 5)]

func _draw_controller_cursor(hex_layout: Dictionary) -> void:
	if not _keyboard_cursor_shown() or not _cell_in_bounds(_controller_cursor_cell):
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var color := CONTROLLER_CURSOR_COLOR
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	if battle_id == "" and not _is_legal_destination_cell(_controller_cursor_cell):
		color = CONTROLLER_CURSOR_BLOCKED_COLOR
	var center := _hex_center(_controller_cursor_cell, hex_layout)
	_draw_hex_outline(center, radius * 1.13, color, 3.6)
	draw_circle(center, clampf(radius * 0.09, 2.5, 4.5), color)

## The battlefield's prop for an obstacle: its kind and size, and one of that
## set picked by its variant.
static func obstacle_art_path(terrain_id: String, obstacle: Dictionary) -> String:
	var kind := String(obstacle.get("kind", "rock"))
	if kind not in BattleRulesScript.OBSTACLE_KINDS:
		kind = BattleRulesScript.OBSTACLE_KINDS[0]
	var size := 2 if int(obstacle.get("size", 1)) >= 2 else 1
	var variant := clampi(int(obstacle.get("variant", 0)), 0, BattleRulesScript.OBSTACLE_VARIANT_COUNT - 1)
	return "%s/%s/%s_%d_%d.png" % [OBSTACLE_ART_ROOT, battlefield_family(terrain_id), kind, size, variant % int(OBSTACLE_ART_VARIANTS[size])]

func _obstacle_texture(path: String) -> Texture2D:
	if _obstacle_textures.has(path):
		return _obstacle_textures[path]
	if _obstacle_texture_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture != null:
		_obstacle_textures[path] = texture
		return texture
	_obstacle_texture_missing[path] = true
	return null

## The midpoint of an obstacle's cells: one hex, or the seam of two.
func _obstacle_center(obstacle: Dictionary, hex_layout: Dictionary) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for cell in obstacle.get("cells", []):
		if cell is Dictionary:
			total += _hex_center(Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0))), hex_layout)
			count += 1
	return total / float(count) if count > 0 else Vector2.ZERO

## The prop's canvas, scaled to the hexes, with its anchor on the obstacle's
## centre.
func _obstacle_art_rect(obstacle: Dictionary, hex_layout: Dictionary) -> Rect2:
	var hex_width := float(hex_layout.get("hex_width", SQRT_3 * float(hex_layout.get("radius", 1.0))))
	var scale := hex_width / OBSTACLE_ART_PIXELS_PER_HEX
	var canvas: Vector2 = OBSTACLE_ART_CANVAS[2 if obstacle.get("cells", []).size() >= 2 else 1] * scale
	var anchor := _obstacle_center(obstacle, hex_layout)
	return Rect2(anchor - Vector2(canvas.x * 0.5, OBSTACLE_ART_ANCHOR_Y * scale), canvas)

func _draw_battle_obstacle(obstacle: Dictionary, hex_layout: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var hex_width := float(hex_layout.get("hex_width", SQRT_3 * radius))
	# A soft shadow under the prop's ground, cast down and right from the light.
	var cell_count := maxi(1, obstacle.get("cells", []).size())
	var shadow_size := Vector2(hex_width * (float(cell_count) + 0.15), hex_width * 0.46)
	var shadow_center := _obstacle_center(obstacle, hex_layout) + Vector2(hex_width * 0.05, hex_width * 0.08)
	draw_texture_rect(_soft_glow(), Rect2(shadow_center - shadow_size * 0.5, shadow_size), false, OBSTACLE_SHADOW_COLOR)
	var texture := _obstacle_texture(obstacle_art_path(_battle_terrain_id(), obstacle))
	if texture != null:
		draw_texture_rect(texture, _obstacle_art_rect(obstacle, hex_layout), false)
		return
	# Missing art still shows a blocked cell: a plain stone mound per cell.
	for cell in obstacle.get("cells", []):
		if cell is Dictionary:
			var cell_center := _hex_center(Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0))), hex_layout)
			_draw_hill(cell_center + Vector2(0.0, radius * 0.18), radius * 0.92, radius * 0.62)

func _draw_stack_tokens(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	_draw_battle_corpses(hex_layout)
	var visual_rows: Array = []
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if not stack_cells.has(battle_id):
			continue
		var cell: Vector2i = stack_cells.get(battle_id)
		var center := _stack_presentation_center(stack, cell, hex_layout, stack_cells)
		visual_rows.append({"stack": stack, "battle_id": battle_id, "center": center})
	# "!" sorts an obstacle before the stacks of its own row, so they stand in front of it.
	for obstacle in BattleRulesScript.battle_obstacles(_battle):
		visual_rows.append({"obstacle": obstacle, "battle_id": "!" + String(obstacle.get("id", "")), "center": _obstacle_center(obstacle, hex_layout)})
	var ghost := _strike_ghost(hex_layout)
	if not ghost.is_empty():
		visual_rows.append({"ghost": true, "battle_id": "~ghost", "center": ghost.get("center", Vector2.ZERO)})
	visual_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_center: Vector2 = left.get("center", Vector2.ZERO)
		var right_center: Vector2 = right.get("center", Vector2.ZERO)
		if not is_equal_approx(left_center.y, right_center.y):
			return left_center.y < right_center.y
		return String(left.get("battle_id", "")) < String(right.get("battle_id", ""))
	)
	for row_value in visual_rows:
		var row: Dictionary = row_value if row_value is Dictionary else {}
		if row.has("obstacle"):
			_draw_battle_obstacle(row.get("obstacle", {}), hex_layout)
			continue
		# The ghost is the active stack, faded, where it will stand to strike.
		var is_ghost := row.has("ghost")
		var stack: Dictionary = _active_stack if is_ghost else (row.get("stack", {}) if row.get("stack", {}) is Dictionary else {})
		var battle_id := String(row.get("battle_id", ""))
		var center: Vector2 = row.get("center", Vector2.ZERO)
		var token_radius: float = _stack_token_radius(radius)
		var side := String(stack.get("side", ""))
		var art_alpha := APPROACH_GHOST_ALPHA if is_ghost else 1.0
		var is_active := battle_id == String(_battle.get("active_stack_id", ""))
		var is_target := battle_id == String(_battle.get("selected_target_id", ""))
		if _spell_target_mode: is_target = battle_id == _pointed_stack_id()
		var is_blocked_target := is_target and _selected_target_is_blocked()
		var fill := _side_color(side)
		if bool(stack.get("defending", false)):
			fill = fill.lightened(0.16)
		var ground_center := center + Vector2(0.0, radius * STACK_STANDEE_GROUND_OFFSET_FACTOR)
		var ground_half_width := token_radius * 0.92
		draw_set_transform(ground_center, 0.0, Vector2(1.0, 0.34))
		if not is_ghost:
			draw_circle(Vector2(2.0, 5.0), ground_half_width + 4.0, SHADOW_COLOR)
			draw_circle(Vector2(1.0, 2.0), ground_half_width + 1.0, SHADOW_COLOR)
			if is_active or is_target:
				draw_circle(Vector2.ZERO, ground_half_width + 2.0, ACTIVE_COLOR if is_active else (BLOCKED_TARGET_COLOR if is_blocked_target else TARGET_COLOR), false, 1.8, true)
			draw_circle(Vector2.ZERO, ground_half_width, STACK_TOKEN_INNER_FILL)
			var side_rim := Color(fill.r, fill.g, fill.b, STACK_TOKEN_SIDE_RIM_ALPHA)
			draw_circle(Vector2.ZERO, ground_half_width - 1.0, side_rim, false, maxf(2.4, token_radius * STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var art_source := _stack_token_art_source(stack)
		var animation_sheet: Texture2D = _unit_animation_sheet_for_stack(stack)
		var battle_standee: Texture2D = _unit_battle_standee_for_stack(stack)
		var battle_icon: Texture2D = _unit_battle_icon_for_stack(stack)
		if art_source == "event_animation_sheet":
			var frame_size := _stack_standee_size(radius, stack).y
			var frame_region := _animation_frame_region_for_stack(stack)
			var animation := ContentService.get_unit_animation(String(stack.get("unit_id", "")))
			var flip := BattleUnitPose.facing_flip(animation, side)
			var frame_rect := BattleUnitPose.grounded_rect(ground_center, frame_size, frame_region, animation, flip)
			_draw_stack_art_region(animation_sheet, frame_rect, frame_region, flip, Color(1.0, 1.0, 1.0, 0.96 * art_alpha))
		elif art_source == "resting_battle_standee":
			_draw_stack_art(battle_standee, _stack_standee_rect(center, radius, stack), side == "enemy", Color(1.0, 1.0, 1.0, 0.99 * art_alpha))
		elif art_source == "resting_battle_icon":
			var icon_size := token_radius * STACK_ICON_ART_EXTENT_FACTOR
			var icon_rect := Rect2(center - Vector2(icon_size * 0.5, icon_size * 0.5), Vector2(icon_size, icon_size))
			draw_texture_rect(battle_icon, icon_rect, false, Color(1.0, 1.0, 1.0, 0.98 * art_alpha))
		elif art_source == "animation_sheet_fallback":
			var fallback_frame_size := token_radius * STACK_ANIMATION_ART_EXTENT_FACTOR
			var fallback_frame_rect := Rect2(center - Vector2(fallback_frame_size * 0.5, fallback_frame_size * 0.55), Vector2(fallback_frame_size, fallback_frame_size))
			draw_texture_rect_region(animation_sheet, fallback_frame_rect, _animation_frame_region_for_stack(stack), Color(1.0, 1.0, 1.0, 0.96 * art_alpha))
		else:
			_draw_unit_glyph(center, token_radius, stack)
	# Foreground combat art belongs above the bodies but below every readout.
	_draw_combat_vfx_foreground(hex_layout, stack_cells)
	for row_value in visual_rows:
		var row: Dictionary = row_value
		if row.has("obstacle") or row.has("ghost"):
			continue
		var stack: Dictionary = row.stack
		var battle_id := String(row.battle_id)
		var center: Vector2 = row.center
		var token_radius: float = _stack_token_radius(radius)
		var side := String(stack.get("side", ""))
		_draw_stack_side_cue(center, token_radius, side)
		_draw_count_badge(center, radius, stack)
		_stack_hit_shapes.append(
			{
				"battle_id": battle_id,
				"side": side,
				"center": center,
				"radius": _stack_hit_shape_radius(radius),
				"body_rect": _stack_body_rect(center, radius, stack),
			}
		)

func _draw_battle_corpses(hex_layout: Dictionary) -> void:
	for corpse in _battle_corpse_entries(hex_layout):
		_draw_stack_art_region(corpse.texture, corpse.rect, corpse.region, corpse.flip, Color.WHITE)

func _battle_corpse_entries(hex_layout: Dictionary) -> Array:
	# Corpses derive from the saved dead stack, not an expiring visual event.
	# They never enter living stack lists, hit shapes, readouts or occupancy.
	var entries := []
	var radius := float(hex_layout.get("radius", 1.0))
	for stack in _battle.get("stacks", []):
		if not stack is Dictionary or _stack_alive_count(stack) > 0: continue
		if not _animation_playback_record_for_stack(String(stack.get("battle_id", ""))).is_empty(): continue
		var cell := _stack_hex_cell(stack)
		if not _cell_in_bounds(cell): continue
		var animation := ContentService.get_unit_animation(String(stack.get("unit_id", "")))
		# Rotated standing cutouts are not corpses. Content migration must supply
		# an approved dedicated dead pose before enabling this presentation.
		if not BattleUnitPose.has_authored_poses(animation): continue
		var region := BattleUnitPose.region(animation, "death_rout_remove", 1.0, 0, false, true)
		if not region.has_area(): continue
		var texture := _unit_animation_sheet_for_stack(stack)
		if texture == null: continue
		var extent := _stack_standee_size(radius, stack).y
		var center := _hex_center(cell, hex_layout) + _body_center_offset(stack, cell, hex_layout)
		var ground_y := center.y + radius * STACK_STANDEE_GROUND_OFFSET_FACTOR
		var flip := BattleUnitPose.facing_flip(animation, String(stack.get("side", "")))
		var rect := BattleUnitPose.grounded_rect(Vector2(center.x, ground_y), extent, region, animation, flip)
		entries.append({"battle_id":String(stack.get("battle_id", "")), "texture":texture, "rect":rect, "region":region, "flip":flip})
	return entries

func _active_mapped_status_effects(stack: Dictionary) -> Array:
	_load_battle_status_effect_art_manifest()
	var statuses: Dictionary = _battle_status_effect_art_manifest.get("statuses", {}) if _battle_status_effect_art_manifest.get("statuses", {}) is Dictionary else {}
	var current_round := int(_battle.get("round", 1))
	var by_status_id := {}
	var effects: Array = stack.get("effects", []) if stack.get("effects", []) is Array else []
	for effect_value in effects:
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		var status_id := String(effect.get("effect_id", "")).strip_edges()
		if status_id == "" or not statuses.has(status_id):
			continue
		var expires_after_round := int(effect.get("expires_after_round", 0))
		if expires_after_round < current_round:
			continue
		var prior: Dictionary = by_status_id.get(status_id, {}) if by_status_id.get(status_id, {}) is Dictionary else {}
		if prior.is_empty() or expires_after_round < int(prior.get("expires_after_round", expires_after_round)):
			by_status_id[status_id] = effect.duplicate(true)
	var mapped: Array = by_status_id.values()
	mapped.sort_custom(func(left_value, right_value) -> bool:
		var left: Dictionary = left_value if left_value is Dictionary else {}
		var right: Dictionary = right_value if right_value is Dictionary else {}
		var left_expiry := int(left.get("expires_after_round", 0))
		var right_expiry := int(right.get("expires_after_round", 0))
		if left_expiry != right_expiry:
			return left_expiry < right_expiry
		return String(left.get("effect_id", "")) < String(right.get("effect_id", ""))
	)
	return mapped

func _stack_status_effect_badge_summary(stack: Dictionary) -> Dictionary:
	var mapped := _active_mapped_status_effects(stack)
	var render_spec: Dictionary = _battle_status_effect_art_manifest.get("render", {}) if _battle_status_effect_art_manifest.get("render", {}) is Dictionary else {}
	var max_visible := clampi(int(render_spec.get("max_visible_badges", 2)), 1, 2)
	var ordered_status_ids := []
	var visible_status_ids := []
	var profiles := []
	for index in range(mapped.size()):
		var effect: Dictionary = mapped[index] if mapped[index] is Dictionary else {}
		var status_id := String(effect.get("effect_id", ""))
		ordered_status_ids.append(status_id)
		if index < max_visible:
			visible_status_ids.append(status_id)
			profiles.append(_battle_status_effect_art_profile(status_id))
	return {
		"presentation_model": BATTLE_STATUS_EFFECT_ART_PRESENTATION_MODEL,
		"active_status_count": mapped.size(),
		"ordered_status_ids": ordered_status_ids,
		"visible_status_ids": visible_status_ids,
		"visible_badge_count": visible_status_ids.size(),
		"max_visible_badges": max_visible,
		"overflow_count": maxi(0, mapped.size() - max_visible),
		"ordering": "expires_after_round_then_status_id",
		"expiry_filter": "expires_after_round_gte_current_round",
		"deduplication": "one_badge_per_status_id_earliest_expiry",
		"non_color_polarity_cues": true,
		"focus_authority": "BattleRules_stack_focus_summary_effects",
		"profiles": profiles,
	}

## The effects a plate shows: each mapped status with its badge art (soonest
## to end first), then each spell's effect with the spell's icon, on the
## foundation of its polarity ({"id", "texture", "foundation", "mark"}).
func _plate_effect_icons(stack: Dictionary) -> Array:
	var icons: Array = []
	for effect in _active_mapped_status_effects(stack):
		var status_id := String(effect.get("effect_id", ""))
		var profile := _battle_status_effect_art_profile(status_id)
		icons.append({
			"id": status_id,
			"texture": _battle_status_effect_art_texture_for_path(String(profile.get("art_path", ""))),
			"foundation": String(profile.get("polarity_foundation", "broken_diamond")),
			"mark": String(profile.get("fallback_mark", "?")),
		})
	for effect in SpellRules.active_effects_for_round(stack, int(_battle.get("round", 1))):
		var effect_id := String(effect.get("effect_id", ""))
		var spell_id := String(effect.get("spell_id", ""))
		if spell_id == "" or not _battle_status_effect_art_spec(effect_id).is_empty():
			continue
		var path := effect_icon_path(effect_id, spell_id)
		if path != "" and not _plate_icon_textures.has(path):
			_plate_icon_textures[path] = load(path) as Texture2D
		icons.append({
			"id": effect_id,
			"texture": _plate_icon_textures.get(path) if path != "" else null,
			"foundation": _battle_status_effect_polarity_foundation(BattleRulesScript.effect_polarity(effect)),
			"mark": String(effect.get("label", "?")).left(1),
		})
	return icons

## How many effects fit on a plate before "+N" counts the rest.
func _plate_effect_max_visible() -> int:
	_load_battle_status_effect_art_manifest()
	var render_spec: Dictionary = _battle_status_effect_art_manifest.get("render", {}) if _battle_status_effect_art_manifest.get("render", {}) is Dictionary else {}
	return clampi(int(render_spec.get("max_visible_badges", 2)), 1, 2)

## The effects on a stack inside its plate, from the slot's left edge: each
## on the foundation of its polarity (a pentagon for help, a broken diamond
## for harm, so colour is not the only cue) under its art, or its mark when
## it has none, then "+N" for the effects that do not fit.
func _draw_stack_status_effect_badges(slot: Rect2, icons: Array, overflow_count: int) -> void:
	var render_spec: Dictionary = _battle_status_effect_art_manifest.get("render", {}) if _battle_status_effect_art_manifest.get("render", {}) is Dictionary else {}
	var icon_size := slot.size.y
	var step := icon_size * PLATE_EFFECT_STEP
	for index in range(icons.size()):
		var icon: Dictionary = icons[index] if icons[index] is Dictionary else {}
		var badge_center := Vector2(slot.position.x + step * (float(index) + 0.5), slot.get_center().y)
		_draw_status_effect_polarity_foundation(badge_center, icon_size, String(icon.get("foundation", "broken_diamond")))
		var texture := icon.get("texture") as Texture2D
		if texture != null:
			var texture_rect := Rect2(badge_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
			draw_texture_rect(texture, texture_rect, false, Color(1.0, 1.0, 1.0, float(render_spec.get("texture_alpha", 0.98))))
		else:
			_draw_centered_label(String(icon.get("mark", "?")), badge_center, TEXT_COLOR, maxi(6, int(round(icon_size * 0.62))))
	if overflow_count > 0:
		var font := get_theme_default_font()
		if font != null:
			var font_size := maxi(6, int(round(icon_size * 0.72)))
			var baseline := slot.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			draw_string(font, Vector2(slot.position.x + step * float(icons.size()) + icon_size * 0.08, baseline), "+%d" % overflow_count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, PLATE_FLAG)

func _draw_status_effect_polarity_foundation(center: Vector2, icon_size: float, foundation: String) -> void:
	var extent := icon_size * 0.67
	var fill := Color(0.018, 0.024, 0.030, 0.96)
	var outline := Color(0.98, 0.88, 0.64, 0.94)
	if foundation == "upward_pentagon":
		var pentagon := PackedVector2Array()
		for index in range(5):
			var angle := -PI * 0.5 + TAU * float(index) / 5.0
			pentagon.append(center + Vector2(cos(angle), sin(angle)) * extent)
		draw_colored_polygon(pentagon, fill)
		draw_polyline(_closed_points(pentagon), outline, 1.3, true)
		return
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -extent),
		center + Vector2(extent, 0.0),
		center + Vector2(0.0, extent),
		center + Vector2(-extent, 0.0),
	])
	draw_colored_polygon(diamond, fill)
	for index in range(4):
		var start: Vector2 = diamond[index]
		var finish: Vector2 = diamond[(index + 1) % 4]
		draw_line(start.lerp(finish, 0.08), start.lerp(finish, 0.42), outline, 1.3, true)
		draw_line(start.lerp(finish, 0.58), start.lerp(finish, 0.92), outline, 1.3, true)

func _stack_token_art_source(stack: Dictionary) -> String:
	var battle_id := String(stack.get("battle_id", ""))
	var animation_sheet: Texture2D = _unit_animation_sheet_for_stack(stack)
	if animation_sheet != null and BattleUnitPose.has_authored_poses(ContentService.get_unit_animation(String(stack.get("unit_id", "")))):
		return "event_animation_sheet"
	var battle_standee: Texture2D = _unit_battle_standee_for_stack(stack)
	var battle_icon: Texture2D = _unit_battle_icon_for_stack(stack)
	return _stack_token_art_source_for_availability(
		animation_sheet != null,
		battle_standee != null,
		battle_icon != null,
		not _animation_playback_record_for_stack(battle_id).is_empty()
	)

func _stack_token_art_source_for_availability(animation_available: bool, standee_available: bool, icon_available: bool, playback_active: bool) -> String:
	if animation_available and playback_active:
		return "event_animation_sheet"
	if standee_available:
		return "resting_battle_standee"
	if icon_available:
		return "resting_battle_icon"
	if animation_available:
		return "animation_sheet_fallback"
	return "procedural_glyph_fallback"

func _stack_standee_size(hex_radius: float, stack: Dictionary = {}) -> Vector2:
	var height := clampf(hex_radius * STACK_STANDEE_ART_HEIGHT_FACTOR, STACK_STANDEE_ART_HEIGHT_MIN, STACK_STANDEE_ART_HEIGHT_MAX)
	height *= clampf(float(stack.get("battle_visual_scale", 1.0)), 0.65, 1.6)
	return Vector2(height * STACK_STANDEE_ASPECT, height)

func _stack_standee_rect(center: Vector2, hex_radius: float, stack: Dictionary = {}) -> Rect2:
	var size := _stack_standee_size(hex_radius, stack)
	var ground_y := center.y + hex_radius * STACK_STANDEE_GROUND_OFFSET_FACTOR
	return Rect2(Vector2(center.x - size.x * 0.5, ground_y - size.y), size)

func _draw_stack_art(texture: Texture2D, rect: Rect2, flip_horizontally: bool, modulate: Color) -> void:
	if not flip_horizontally:
		draw_texture_rect(texture, rect, false, modulate)
		return
	draw_set_transform(Vector2(rect.end.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(texture, Rect2(Vector2(0.0, rect.position.y), rect.size), false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stack_art_region(texture: Texture2D, rect: Rect2, region: Rect2, flip_horizontally: bool, modulate: Color) -> void:
	if not flip_horizontally:
		draw_texture_rect_region(texture, rect, region, modulate)
		return
	draw_set_transform(Vector2(rect.end.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(texture, Rect2(Vector2(0.0, rect.position.y), rect.size), region, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _stack_presentation_center(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Vector2:
	var motion := _stack_presentation_motion(stack, cell, hex_layout, stack_cells)
	var offset := _body_center_offset(stack, cell, hex_layout)
	if motion.is_empty():
		return _hex_center(cell, hex_layout) + offset
	return Vector2(float(motion.get("center_x", 0.0)), float(motion.get("center_y", 0.0))) + offset

func _body_center_offset(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary) -> Vector2:
	if BattleRulesScript.Footprint.width(stack) != 2: return Vector2.ZERO
	var rear := cell + Vector2i(1 if String(stack.get("side", "")) == "enemy" else -1, 0)
	return (_hex_center(rear, hex_layout) - _hex_center(cell, hex_layout)) * 0.5

func _stack_presentation_summary(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var center := _hex_center(cell, hex_layout)
	var summary := {
		"presentation_x": snappedf(center.x, 0.01),
		"presentation_y": snappedf(center.y, 0.01),
		"presentation_motion_active": false,
		"presentation_motion_event_id": "",
		"presentation_motion_role": "",
		"presentation_motion_source_battle_id": "",
		"presentation_motion_target_battle_id": "",
		"presentation_motion_from_q": -1,
		"presentation_motion_from_r": -1,
		"presentation_motion_to_q": -1,
		"presentation_motion_to_r": -1,
		"presentation_motion_progress": 1.0,
	}
	var motion := _stack_presentation_motion(stack, cell, hex_layout, stack_cells)
	if motion.is_empty():
		return summary
	summary["presentation_x"] = motion.get("center_x", summary.get("presentation_x"))
	summary["presentation_y"] = motion.get("center_y", summary.get("presentation_y"))
	summary["presentation_motion_active"] = true
	summary["presentation_motion_event_id"] = String(motion.get("event_id", ""))
	summary["presentation_motion_role"] = String(motion.get("role", ""))
	summary["presentation_motion_source_battle_id"] = String(motion.get("source_battle_id", ""))
	summary["presentation_motion_target_battle_id"] = String(motion.get("target_battle_id", ""))
	summary["presentation_motion_from_q"] = int(motion.get("from_q", -1))
	summary["presentation_motion_from_r"] = int(motion.get("from_r", -1))
	summary["presentation_motion_to_q"] = int(motion.get("to_q", -1))
	summary["presentation_motion_to_r"] = int(motion.get("to_r", -1))
	summary["presentation_motion_progress"] = motion.get("progress", 0.0)
	return summary

func _stack_presentation_motion(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var battle_id := String(stack.get("battle_id", ""))
	var record := _animation_playback_record_for_stack(battle_id)
	if record.is_empty():
		return {}
	var event_id := String(record.get("event_id", ""))
	if BattleUnitPose.waiting_for_start(record, Time.get_ticks_msec()):
		# Reactions must not knock a body aside before contact. A delayed move
		# still waits at its source cell, never at the committed destination.
		if event_id == "battle_unit_move":
			return _movement_presentation_motion(record, cell, hex_layout, 0.0)
		return {}
	var progress := _stack_presentation_progress(battle_id)
	match event_id:
		"battle_unit_move":
			return _movement_presentation_motion(record, cell, hex_layout, progress)
		"battle_unit_melee_attack", "battle_retaliation":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "melee_lunge")
		"battle_unit_ranged_attack":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "ranged_recoil")
		"battle_unit_cast":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "cast_anchor")
		"battle_unit_hit", "battle_status_applied", "battle_unit_death":
			return _impact_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress)
		"battle_status_expired":
			return _status_clear_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress)
		"battle_unit_retreat":
			return _exit_presentation_motion(record, battle_id, cell, hex_layout, progress, "retreat_withdraw")
		"battle_unit_surrender":
			return _exit_presentation_motion(record, battle_id, cell, hex_layout, progress, "surrender_stand_down")
	return {}

func _stack_presentation_progress(battle_id: String) -> float:
	var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
	var progress := 1.0
	if not cue_record.is_empty():
		progress = _cue_playback_progress(cue_record)
		var mode := String(cue_record.get("mode", AnimationCueCatalogScript.MODE_NORMAL))
		if mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION_FAST:
			progress = 1.0
	return clampf(progress, 0.0, 1.0)

func _movement_presentation_motion(record: Dictionary, cell: Vector2i, hex_layout: Dictionary, progress: float) -> Dictionary:
	var from_cell := Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))
	var to_cell := Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1)))
	if not _cell_in_bounds(from_cell) or not _cell_in_bounds(to_cell):
		return {}
	if to_cell != cell:
		return {}
	var from_center := _hex_center(from_cell, hex_layout)
	var to_center := _hex_center(to_cell, hex_layout)
	var center := from_center.lerp(to_center, clampf(progress, 0.0, 1.0))
	var path: Array = _battle.get("playback_event", {}).get("walk_path", [])
	if path.size() >= 2:
		var along := clampf(progress,0.0,1.0) * float(path.size()-1)
		var index := mini(int(along),path.size()-2)
		var a: Dictionary=path[index]
		var b: Dictionary=path[index+1]
		center=_hex_center(Vector2i(int(a.q),int(a.r)),hex_layout).lerp(_hex_center(Vector2i(int(b.q),int(b.r)),hex_layout),along-float(index))
	return {
		"event_id": String(record.get("event_id", "")),
		"role": "move_path",
		"source_battle_id": String(record.get("source_battle_id", "")),
		"target_battle_id": String(record.get("target_battle_id", "")),
		"from_q": from_cell.x,
		"from_r": from_cell.y,
		"to_q": to_cell.x,
		"to_r": to_cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _attack_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float, role: String) -> Dictionary:
	var target_id := String(record.get("target_battle_id", "")).strip_edges()
	if target_id == "" or not stack_cells.has(target_id):
		return {}
	var target_cell: Vector2i = stack_cells.get(target_id)
	if not _cell_in_bounds(cell) or not _cell_in_bounds(target_cell):
		return {}
	var origin := _hex_center(cell, hex_layout)
	var target := _hex_center(target_cell, hex_layout)
	var direction := (target - origin).normalized()
	if direction.length() <= 0.0:
		return {}
	var radius := float(hex_layout.get("radius", 1.0))
	var travel := 0.0
	match role:
		"melee_lunge":
			travel = sin(progress * PI) * radius * 0.34
		"ranged_recoil":
			travel = -sin(progress * PI) * radius * 0.12
		"cast_anchor":
			travel = -sin(progress * PI) * radius * 0.07
	var center := origin + direction * travel
	return {
		"event_id": String(record.get("event_id", "")),
		"role": role,
		"source_battle_id": battle_id,
		"target_battle_id": target_id,
		"from_q": cell.x,
		"from_r": cell.y,
		"to_q": target_cell.x,
		"to_r": target_cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _impact_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float) -> Dictionary:
	var source_id := String(record.get("source_battle_id", "")).strip_edges()
	var source_cells := _actor_cells(stack_cells)
	if source_id == "" or not source_cells.has(source_id):
		return {}
	var source_cell: Vector2i = source_cells.get(source_id)
	if not _cell_in_bounds(cell) or not _actor_cell_drawable(source_cell):
		return {}
	var source := _hex_center(source_cell, hex_layout)
	var origin := _hex_center(cell, hex_layout)
	var direction := (origin - source).normalized()
	if direction.length() <= 0.0:
		return {}
	var radius := float(hex_layout.get("radius", 1.0))
	var event_id := String(record.get("event_id", ""))
	var role := "hit_stagger"
	var travel := (1.0 - progress) * radius * 0.18
	if event_id == "battle_status_applied":
		role = "status_pulse"
		travel = sin(progress * TAU) * radius * 0.06
	elif event_id == "battle_unit_death":
		role = "death_fall_back"
		travel = (1.0 - progress) * radius * 0.26
	var center := origin + direction * travel
	return {
		"event_id": event_id,
		"role": role,
		"source_battle_id": source_id,
		"target_battle_id": battle_id,
		"from_q": source_cell.x,
		"from_r": source_cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _status_clear_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float) -> Dictionary:
	if not _cell_in_bounds(cell):
		return {}
	var source_id := String(record.get("source_battle_id", "")).strip_edges()
	var source_cell := cell
	var source_cells := _actor_cells(stack_cells)
	if source_id != "" and source_cells.has(source_id):
		source_cell = source_cells.get(source_id)
	var origin := _hex_center(cell, hex_layout)
	var radius := float(hex_layout.get("radius", 1.0))
	var lift := sin(progress * PI) * radius * 0.08
	var center := origin + Vector2(0.0, -lift)
	return {
		"event_id": String(record.get("event_id", "")),
		"role": "status_clear",
		"source_battle_id": source_id,
		"target_battle_id": battle_id,
		"from_q": source_cell.x,
		"from_r": source_cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _exit_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, progress: float, role: String) -> Dictionary:
	if not _cell_in_bounds(cell):
		return {}
	var origin := _hex_center(cell, hex_layout)
	var radius := float(hex_layout.get("radius", 1.0))
	var direction := -1.0 if String(record.get("event_id", "")) == "battle_unit_retreat" else 1.0
	var retreat_dx := direction * sin(progress * PI) * radius * 0.18
	var surrender_lift := sin(progress * PI) * radius * 0.06 if role == "surrender_stand_down" else 0.0
	var center := origin + Vector2(retreat_dx, surrender_lift)
	return {
		"event_id": String(record.get("event_id", "")),
		"role": role,
		"source_battle_id": battle_id,
		"target_battle_id": String(record.get("target_battle_id", "")),
		"from_q": cell.x,
		"from_r": cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _draw_vfx_cues(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	for entry in _vfx_draw_entries(hex_layout, stack_cells):
		if not (entry is Dictionary):
			continue
		var start := Vector2(float(entry.get("start_x", 0.0)), float(entry.get("start_y", 0.0)))
		var end := Vector2(float(entry.get("end_x", 0.0)), float(entry.get("end_y", 0.0)))
		var center := Vector2(float(entry.get("center_x", end.x)), float(entry.get("center_y", end.y)))
		var radius := float(entry.get("hex_radius", 12.0))
		var progress := float(entry.get("progress", 0.0))
		if _draw_imported_vfx_asset(entry, start, end, center, radius, progress):
			continue
		match String(entry.get("kind", "")):
			"idle_shadow":
				_draw_idle_shadow_vfx(center, radius, progress)
			"active_ring":
				_draw_active_ring_vfx(center, radius, progress)
			"projectile_path":
				_draw_projectile_vfx(start, end, radius, progress)
			"status_residue":
				_draw_status_residue_vfx(center, radius, progress)
			"status_clear":
				_draw_status_clear_vfx(center, radius, progress)
			"damage_tick":
				_draw_damage_tick_vfx(center, radius, progress)
			"melee_arc":
				_draw_melee_arc_vfx(start, end, radius, progress)
			"retaliation_arc":
				_draw_retaliation_arc_vfx(start, end, radius, progress)
			"stack_fade":
				_draw_stack_fade_vfx(center, radius, progress)
			"cast_anchor":
				_draw_cast_anchor_vfx(center, radius, progress)
			"brace_outline":
				_draw_brace_outline_vfx(center, radius, progress)
			"surrender_marker":
				_draw_surrender_marker_vfx(center, radius, progress)
			"path_ghost":
				_draw_path_ghost_vfx(center, radius, progress)
			"spell_cinder_burst":
				_draw_spell_cinder_burst_vfx(center, radius, progress)
			"spell_coal_rain":
				_draw_spell_coal_rain_vfx(center, radius, progress)
			"spell_sunlance_arc":
				_draw_spell_sunlance_arc_vfx(start, end, radius, progress)
			"spell_briar_bind":
				_draw_spell_briar_bind_vfx(center, radius, progress)
			"spell_graft_mend":
				_draw_spell_graft_mend_vfx(center, radius, progress)
			"spell_prism_bastion":
				_draw_spell_prism_bastion_vfx(center, radius, progress)
			"spell_resonant_chorus":
				_draw_spell_resonant_chorus_vfx(center, radius, progress)
			"spell_command_ward":
				_draw_spell_command_ward_vfx(center, radius, progress)

func _draw_imported_vfx_asset(entry: Dictionary, start: Vector2, end: Vector2, center: Vector2, radius: float, progress: float) -> bool:
	var cue_id := String(entry.get("cue_id", ""))
	var spec := _battle_vfx_manifest_cue(cue_id)
	if spec.is_empty():
		return false
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture: Texture2D = _battle_vfx_texture_for_path(texture_path) as Texture2D
	if texture == null:
		return false
	if CombatVfxMotion.owns(spec, entry):
		return true # Composited after unit bodies, before health/count captions.
	var render_mode := String(spec.get("render_mode", ""))
	var draw_center := center
	var rotation := deg_to_rad(float(spec.get("base_rotation_degrees", 0.0)))
	match render_mode:
		"projectile":
			if start.distance_to(end) > 1.0:
				var direction := (end - start).normalized()
				var head := start.lerp(end, clampf(progress, 0.08, 0.96))
				draw_center = head - direction * radius * 0.16
				rotation += direction.angle()
		"spell_projectile":
			if start.distance_to(end) > 1.0:
				var direction := (end - start).normalized()
				draw_center = start.lerp(end, clampf(progress, 0.12, 0.94))
				rotation += direction.angle()
		"slash":
			if start.distance_to(end) > 1.0:
				draw_center = start.lerp(end, 0.52)
				rotation += (end - start).angle()
		"impact":
			rotation += progress * TAU * 0.10
		"ward":
			rotation += progress * TAU * 0.08
		"spell_target":
			draw_center = end
			rotation += progress * TAU * 0.04
		"state_center":
			draw_center = center
			rotation += progress * TAU * 0.025
		"state_marker":
			draw_center = center + Vector2(radius * 0.38, -radius * 0.42)
		"path_follow":
			draw_center = center
			if start.distance_to(end) > 1.0:
				rotation += (end - start).angle()
		_:
			return false
	var draw_size := radius * float(spec.get("scale", 1.0))
	var alpha := clampf(0.82 - progress * 0.30, 0.42, 0.82)
	draw_set_transform(draw_center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-draw_size, -draw_size) * 0.5, Vector2(draw_size, draw_size)), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _combat_vfx_layers(hex_layout: Dictionary, stack_cells: Dictionary) -> Array:
	var result := []
	var preferences := AnimationCueCatalogScript.normalize_animation_preferences(_animation_preferences())
	for entry in _vfx_draw_entries(hex_layout, stack_cells):
		if not bool(entry.get("asset_loaded", false)): continue
		var spec := _battle_vfx_manifest_cue(String(entry.get("cue_id", "")))
		for layer in CombatVfxMotion.layers(spec, entry, preferences):
			if result.size() >= CombatVfxMotion.MAX_LAYERS_PER_FRAME: return result
			layer["asset_path"] = String(entry.get("asset_path", ""))
			layer["cue_id"] = String(entry.get("cue_id", ""))
			layer["event_id"] = String(entry.get("event_id", ""))
			result.append(layer)
	return result

func _draw_combat_vfx_foreground(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	for layer in _combat_vfx_layers(hex_layout, stack_cells):
		var texture: Texture2D = _battle_vfx_texture_for_path(String(layer.asset_path))
		if texture == null: continue
		var extent := float(layer.extent)
		draw_set_transform(layer.center, float(layer.rotation), Vector2.ONE)
		draw_texture_rect(texture, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), false, Color(1, 1, 1, float(layer.alpha)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _vfx_draw_entries(hex_layout: Dictionary, stack_cells: Dictionary) -> Array:
	var entries: Array = []
	var radius := float(hex_layout.get("radius", 1.0))
	var actor_cells := _actor_cells(stack_cells)
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		if BattleUnitPose.waiting_for_start(record, Time.get_ticks_msec()):
			continue
		var cue_ids: Array = record.get("selected_vfx_cue_ids", []) if record.get("selected_vfx_cue_ids", []) is Array else []
		if cue_ids.is_empty() or not actor_cells.has(battle_id):
			continue
		var subject_cell: Vector2i = actor_cells.get(battle_id)
		if not _actor_cell_drawable(subject_cell):
			continue
		var source_id := String(record.get("source_battle_id", "")).strip_edges()
		if source_id == "":
			source_id = battle_id
		var target_id := String(record.get("target_battle_id", "")).strip_edges()
		if target_id == "":
			target_id = battle_id
		var source_cell: Vector2i = actor_cells.get(source_id, subject_cell)
		var target_cell: Vector2i = actor_cells.get(target_id, subject_cell)
		var has_event_path := _cell_in_bounds(Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))) and _cell_in_bounds(Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1))))
		if has_event_path:
			source_cell = Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))
			target_cell = Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1)))
		var source_center := _hex_center(source_cell, hex_layout)
		var target_center := _hex_center(target_cell, hex_layout)
		var subject_center := _hex_center(subject_cell, hex_layout)
		var progress := _cue_playback_progress(record)
		if record.has("vfx_started_at_msec"):
			var vfx_elapsed := int(Time.get_ticks_msec()) - int(record.vfx_started_at_msec)
			var vfx_duration := maxi(1, int(record.get("vfx_duration_msec", 1)))
			if vfx_elapsed < 0 or vfx_elapsed >= vfx_duration: continue
			progress = float(vfx_elapsed) / float(vfx_duration)
		for cue_id_value in cue_ids:
			var cue_id := String(cue_id_value)
			var kind := _vfx_kind_for_cue_id(cue_id)
			if kind == "":
				continue
			var start := source_center
			var end := target_center
			var center := subject_center
			if kind == "projectile_path" or kind == "melee_arc" or kind == "retaliation_arc":
				start = subject_center
				end = target_center
				center = target_center
			elif kind == "path_ghost" and has_event_path:
				start = source_center
				end = target_center
				center = source_center.lerp(target_center, progress)
			elif source_id != "" and actor_cells.has(source_id):
				start = source_center
			var asset_spec := _battle_vfx_manifest_cue(cue_id)
			var asset_path := String(asset_spec.get("texture_path", "")).strip_edges()
			var asset_loaded := asset_path != "" and _battle_vfx_texture_for_path(asset_path) != null
			entries.append({
				"cue_id": cue_id,
				"kind": kind,
				"battle_id": battle_id,
				"event_id": String(record.get("event_id", "")),
				"serial": int(record.get("serial", 0)),
				"source_battle_id": source_id,
				"target_battle_id": target_id,
				"start_q": source_cell.x,
				"start_r": source_cell.y,
				"target_q": target_cell.x,
				"target_r": target_cell.y,
				"subject_q": subject_cell.x,
				"subject_r": subject_cell.y,
				"start_x": snappedf(start.x, 0.01),
				"start_y": snappedf(start.y, 0.01),
				"end_x": snappedf(end.x, 0.01),
				"end_y": snappedf(end.y, 0.01),
				"center_x": snappedf(center.x, 0.01),
				"center_y": snappedf(center.y, 0.01),
				"hex_radius": snappedf(radius, 0.01),
				"progress": snappedf(progress, 0.001),
				"asset_path": asset_path,
				"asset_render_mode": String(asset_spec.get("render_mode", "")),
				"asset_loaded": asset_loaded,
			})
	return entries

func _vfx_kind_for_cue_id(cue_id: String) -> String:
	var spell_cue := _battle_vfx_manifest_cue(cue_id)
	var spell_id := String(spell_cue.get("spell_id", "")).strip_edges()
	if spell_id != "":
		return spell_id
	if cue_id in [
		"vfx_spell_cinder_burst",
		"vfx_spell_coal_rain",
		"vfx_spell_sunlance_arc",
		"vfx_spell_briar_bind",
		"vfx_spell_graft_mend",
		"vfx_spell_prism_bastion",
		"vfx_spell_resonant_chorus",
	]:
		return cue_id.trim_prefix("vfx_")
	match cue_id:
		"vfx_placeholder_idle_shadow":
			return "idle_shadow"
		"vfx_placeholder_active_ring":
			return "active_ring"
		"vfx_placeholder_projectile_path":
			return "projectile_path"
		"vfx_placeholder_status_residue":
			return "status_residue"
		"vfx_placeholder_status_clear":
			return "status_clear"
		"vfx_placeholder_damage_tick":
			return "damage_tick"
		"vfx_placeholder_melee_arc":
			return "melee_arc"
		"vfx_placeholder_retaliation_arc":
			return "retaliation_arc"
		"vfx_placeholder_stack_fade":
			return "stack_fade"
		"vfx_placeholder_cast_anchor":
			return "cast_anchor"
		"vfx_placeholder_brace_outline":
			return "brace_outline"
		"vfx_placeholder_surrender_marker":
			return "surrender_marker"
		"vfx_placeholder_battle_path_ghost", "vfx_placeholder_withdraw_path":
			return "path_ghost"
		"vfx_spell_command_ward":
			return "spell_command_ward"
	return ""

func _cue_playback_progress(record: Dictionary) -> float:
	var started := int(record.get("started_at_msec", Time.get_ticks_msec()))
	var duration := maxi(1, int(record.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)))
	return clampf(float(Time.get_ticks_msec() - started) / float(duration), 0.0, 1.0)

func _draw_idle_shadow_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.12, 0.28 - progress * 0.08)
	draw_circle(center + Vector2(0.0, radius * 0.24), radius * 0.32, Color(0.02, 0.025, 0.03, alpha))

func _draw_active_ring_vfx(center: Vector2, radius: float, progress: float) -> void:
	var pulse := 0.88 + sin(progress * TAU) * 0.05
	draw_circle(center, radius * pulse, Color(ACTIVE_COLOR.r, ACTIVE_COLOR.g, ACTIVE_COLOR.b, 0.42), false, maxf(2.0, radius * 0.05), true)

func _draw_projectile_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	if start.distance_to(end) <= 1.0:
		return
	var alpha := maxf(0.20, 1.0 - progress * 0.42)
	var color := Color(BATTLE_VFX_PROJECTILE_COLOR.r, BATTLE_VFX_PROJECTILE_COLOR.g, BATTLE_VFX_PROJECTILE_COLOR.b, BATTLE_VFX_PROJECTILE_COLOR.a * alpha)
	var head := start.lerp(end, clampf(progress, 0.08, 0.96))
	var tail := start.lerp(end, clampf(progress - 0.16, 0.0, 0.84))
	draw_line(start, end, Color(color.r, color.g, color.b, 0.22), maxf(1.6, radius * 0.045), true)
	draw_line(tail, head, color, maxf(2.4, radius * 0.075), true)
	draw_circle(head, maxf(3.0, radius * 0.105), Color(color.r, color.g, color.b, 0.94))

func _draw_status_residue_vfx(center: Vector2, radius: float, progress: float) -> void:
	var pulse := 1.0 + sin(progress * TAU) * 0.10
	var alpha := maxf(0.18, 1.0 - progress * 0.35)
	var color := Color(BATTLE_VFX_STATUS_COLOR.r, BATTLE_VFX_STATUS_COLOR.g, BATTLE_VFX_STATUS_COLOR.b, BATTLE_VFX_STATUS_COLOR.a * alpha)
	draw_circle(center, radius * 0.58 * pulse, Color(color.r, color.g, color.b, 0.08), true)
	draw_circle(center, radius * 0.70 * pulse, color, false, maxf(1.8, radius * 0.045), true)
	for index in range(3):
		var angle := progress * TAU + float(index) * TAU / 3.0
		var pip := center + Vector2(cos(angle), sin(angle)) * radius * 0.46
		draw_circle(pip, maxf(2.4, radius * 0.055), Color(color.r, color.g, color.b, 0.86))

func _draw_status_clear_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.12, 1.0 - progress)
	var color := Color(0.72, 0.88, 1.0, 0.72 * alpha)
	var inner := radius * (0.24 + progress * 0.14)
	var outer := radius * (0.64 + progress * 0.24)
	draw_circle(center, outer, Color(color.r, color.g, color.b, 0.06), true)
	draw_circle(center, outer, color, false, maxf(1.6, radius * 0.04), true)
	draw_line(center + Vector2(-inner, 0.0), center + Vector2(inner, 0.0), color, maxf(1.6, radius * 0.045), true)
	draw_line(center + Vector2(0.0, -inner), center + Vector2(0.0, inner), color, maxf(1.6, radius * 0.045), true)

func _draw_damage_tick_vfx(center: Vector2, radius: float, progress: float) -> void:
	var span := radius * (0.26 + progress * 0.18)
	var alpha := maxf(0.18, 1.0 - progress * 0.45)
	var color := Color(BATTLE_VFX_DAMAGE_COLOR.r, BATTLE_VFX_DAMAGE_COLOR.g, BATTLE_VFX_DAMAGE_COLOR.b, BATTLE_VFX_DAMAGE_COLOR.a * alpha)
	draw_line(center + Vector2(-span, -span * 0.40), center + Vector2(span, span * 0.40), color, maxf(2.0, radius * 0.06), true)
	draw_line(center + Vector2(span * 0.32, -span), center + Vector2(-span * 0.32, span), color, maxf(1.8, radius * 0.05), true)

func _draw_melee_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var direction := (end - start).normalized() if start.distance_to(end) > 1.0 else Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var center := start.lerp(end, 0.55) + normal * radius * 0.18
	var alpha := maxf(0.20, 1.0 - progress * 0.55)
	var color := Color(BATTLE_VFX_DAMAGE_COLOR.r, BATTLE_VFX_DAMAGE_COLOR.g, BATTLE_VFX_DAMAGE_COLOR.b, 0.72 * alpha)
	draw_line(start.lerp(center, 0.35), center, color, maxf(2.4, radius * 0.07), true)
	draw_line(center, end.lerp(center, 0.35), color, maxf(2.4, radius * 0.07), true)

func _draw_retaliation_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var direction := (end - start).normalized() if start.distance_to(end) > 1.0 else Vector2.LEFT
	var normal := Vector2(direction.y, -direction.x)
	var center := start.lerp(end, 0.48) + normal * radius * 0.24
	var alpha := maxf(0.18, 1.0 - progress * 0.60)
	var color := Color(1.0, 0.76, 0.42, 0.74 * alpha)
	draw_line(start.lerp(center, 0.30), center, color, maxf(2.2, radius * 0.065), true)
	draw_line(center, end.lerp(center, 0.30), color, maxf(2.2, radius * 0.065), true)

func _draw_stack_fade_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.10, 1.0 - progress)
	draw_circle(center, radius * (0.44 + progress * 0.38), Color(0.86, 0.88, 0.92, 0.34 * alpha), false, maxf(2.0, radius * 0.055), true)
	draw_circle(center, radius * 0.22, Color(0.08, 0.09, 0.10, 0.18 * alpha), true)

func _draw_cast_anchor_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.35)
	var color := Color(BATTLE_VFX_CAST_COLOR.r, BATTLE_VFX_CAST_COLOR.g, BATTLE_VFX_CAST_COLOR.b, BATTLE_VFX_CAST_COLOR.a * alpha)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(radius * 0.54, 0.0),
		center + Vector2(0.0, radius * 0.74),
		center + Vector2(-radius * 0.54, 0.0),
		center + Vector2(0.0, -radius * 0.74),
	])
	draw_polyline(points, color, maxf(1.8, radius * 0.045), true)
	draw_circle(center, radius * 0.18, Color(color.r, color.g, color.b, 0.38), true)

func _draw_brace_outline_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.50)
	var color := Color(0.76, 0.88, 1.0, 0.58 * alpha)
	draw_circle(center, radius * 0.68, color, false, maxf(2.0, radius * 0.055), true)
	draw_arc(center, radius * 0.48, PI * 0.12, PI * 0.88, 12, color, maxf(2.0, radius * 0.055), true)

func _draw_surrender_marker_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.55)
	var color := Color(0.92, 0.92, 0.86, 0.70 * alpha)
	var pole_top := center + Vector2(0.0, -radius * 0.44)
	var pole_bottom := center + Vector2(0.0, radius * 0.30)
	draw_line(pole_top, pole_bottom, color, maxf(1.8, radius * 0.04), true)
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(radius * 0.34, radius * 0.10),
		pole_top + Vector2(0.0, radius * 0.22),
	])
	draw_colored_polygon(flag, Color(color.r, color.g, color.b, 0.42 * alpha))

func _draw_path_ghost_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.60)
	_draw_hex(center, radius * (0.50 + progress * 0.16), Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.08 * alpha), Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.48 * alpha), maxf(1.6, radius * 0.04))

func _draw_spell_cinder_burst_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.14, 1.0 - progress * 0.72)
	var flare := Color(1.0, 0.42, 0.16, 0.72 * alpha)
	draw_circle(center, radius * (0.26 + progress * 0.34), Color(flare.r, flare.g, flare.b, 0.14 * alpha), true)
	for index in range(6):
		var angle := progress * TAU * 0.35 + float(index) * TAU / 6.0
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.18
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * (0.52 + progress * 0.20)
		draw_line(inner, outer, flare, maxf(1.8, radius * 0.045), true)

func _draw_spell_coal_rain_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.62)
	for index in range(5):
		var lane := (float(index) - 2.0) * radius * 0.16
		var head := center + Vector2(lane, -radius * 0.56 + radius * progress * 0.82)
		var tail := head + Vector2(-radius * 0.14, -radius * 0.22)
		draw_line(tail, head, Color(0.92, 0.32, 0.18, 0.76 * alpha), maxf(1.8, radius * 0.045), true)
		draw_circle(head, maxf(2.2, radius * 0.05), Color(0.12, 0.10, 0.08, 0.72 * alpha))

func _draw_spell_sunlance_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var source := start if start.distance_to(end) > 1.0 else end + Vector2(-radius, 0.0)
	var alpha := maxf(0.18, 1.0 - progress * 0.46)
	var head := source.lerp(end, clampf(progress, 0.12, 1.0))
	draw_line(source, end, Color(1.0, 0.90, 0.46, 0.24 * alpha), maxf(2.0, radius * 0.05), true)
	draw_line(source.lerp(head, 0.38), head, Color(1.0, 0.78, 0.24, 0.86 * alpha), maxf(2.8, radius * 0.08), true)
	draw_circle(head, maxf(3.0, radius * 0.08), Color(1.0, 0.96, 0.58, 0.82 * alpha))

func _draw_spell_briar_bind_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.58)
	var color := Color(0.36, 0.74, 0.40, 0.78 * alpha)
	draw_arc(center, radius * (0.34 + progress * 0.16), PI * 0.10, PI * 1.78, 18, color, maxf(2.0, radius * 0.052), true)
	draw_arc(center, radius * (0.50 + progress * 0.10), PI * 1.08, PI * 2.78, 18, color, maxf(1.8, radius * 0.046), true)
	for index in range(3):
		var angle := float(index) * TAU / 3.0 + progress * 0.8
		draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.24, center + Vector2(cos(angle), sin(angle)) * radius * 0.62, color, maxf(1.6, radius * 0.04), true)

func _draw_spell_graft_mend_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.54)
	var color := Color(0.58, 1.0, 0.70, 0.74 * alpha)
	var span := radius * (0.22 + progress * 0.10)
	draw_circle(center, radius * (0.46 + progress * 0.12), Color(color.r, color.g, color.b, 0.08 * alpha), true)
	draw_line(center + Vector2(-span, 0.0), center + Vector2(span, 0.0), color, maxf(2.2, radius * 0.06), true)
	draw_line(center + Vector2(0.0, -span), center + Vector2(0.0, span), color, maxf(2.2, radius * 0.06), true)

func _draw_spell_prism_bastion_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.50)
	var color := Color(0.66, 0.90, 1.0, 0.72 * alpha)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.62),
		center + Vector2(radius * 0.48, -radius * 0.10),
		center + Vector2(radius * 0.32, radius * 0.54),
		center + Vector2(-radius * 0.32, radius * 0.54),
		center + Vector2(-radius * 0.48, -radius * 0.10),
		center + Vector2(0.0, -radius * 0.62),
	])
	draw_polyline(points, color, maxf(1.9, radius * 0.05), true)
	draw_circle(center, radius * (0.18 + progress * 0.10), Color(color.r, color.g, color.b, 0.18 * alpha), true)

func _draw_spell_resonant_chorus_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.48)
	var gold := Color(1.0, 0.82, 0.34, 0.76 * alpha)
	var glass := Color(0.70, 0.94, 1.0, 0.68 * alpha)
	var pulse := 0.32 + progress * 0.16
	for ring_index in range(3):
		var ring_radius := radius * (pulse + float(ring_index) * 0.14)
		var color := gold if ring_index % 2 == 0 else glass
		draw_arc(center, ring_radius, -PI * 0.94, PI * 0.94, 28, color, maxf(1.8, radius * 0.045), true)
	for shard_index in range(6):
		var angle := float(shard_index) * TAU / 6.0 - PI * 0.5 + progress * 0.20
		var shard_start := center + Vector2(cos(angle), sin(angle)) * radius * 0.42
		var shard_end := center + Vector2(cos(angle), sin(angle)) * radius * 0.64
		draw_line(shard_start, shard_end, glass, maxf(1.7, radius * 0.04), true)
	draw_circle(center, radius * (0.13 + progress * 0.06), Color(gold.r, gold.g, gold.b, 0.22 * alpha), true)

func _draw_spell_command_ward_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.44)
	var color := Color(1.0, 0.84, 0.42, 0.72 * alpha)
	draw_circle(center, radius * (0.58 + progress * 0.10), Color(color.r, color.g, color.b, 0.06 * alpha), true)
	draw_arc(center, radius * 0.60, PI * 0.08, PI * 0.92, 14, color, maxf(2.0, radius * 0.05), true)
	draw_arc(center, radius * 0.60, PI * 1.08, PI * 1.92, 14, color, maxf(2.0, radius * 0.05), true)

func _register_audio_cue_playback(cue_record: Dictionary) -> void:
	var battle_id := String(cue_record.get("battle_id", "")).strip_edges()
	if battle_id == "":
		return
	var audio_ids: Array = cue_record.get("selected_audio_cue_ids", []) if cue_record.get("selected_audio_cue_ids", []) is Array else []
	if audio_ids.is_empty():
		_stack_animation_audio_playback_records.erase(battle_id)
		return
	var now := int(Time.get_ticks_msec())
	var started_at := int(cue_record.get("audio_started_at_msec", cue_record.get("started_at_msec", now)))
	if started_at > now:
		_stack_animation_audio_playback_records[battle_id] = {
			"battle_id": battle_id,
			"event_id": String(cue_record.get("event_id", "")),
			"serial": int(cue_record.get("serial", 0)),
			"cue_id": String(cue_record.get("cue_id", "")),
			"selected_audio_cue_ids": audio_ids.duplicate(true),
			"generated_waveform_count": 0,
			"imported_asset_count": 0,
			"generated_fallback_count": 0,
			"generated_waveforms": [],
			"imported_assets": [],
			"asset_playbacks": [],
			"started_at_msec": started_at,
			"expires_at_msec": int(cue_record.get("expires_at_msec", started_at + STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
			"sequence_delay_msec": int(cue_record.get("sequence_delay_msec", 0)),
			"audio_bus": BATTLE_AUDIO_BUS,
			"muted": SettingsService.effects_audio_muted(),
			"scheduled": true,
		}
		return
	var generated_records := []
	var imported_records := []
	var suppressed_records := []
	var asset_records := []
	for audio_id_value in audio_ids:
		var audio_id := String(audio_id_value).strip_edges()
		if audio_id == "":
			continue
		var playback := _play_audio_cue(audio_id, battle_id, int(cue_record.get("serial", 0)))
		if playback.is_empty():
			continue
		asset_records.append(playback)
		match String(playback.get("source", "")):
			"imported_wav":
				imported_records.append(playback)
			"generated_waveform":
				generated_records.append(playback)
			"suppressed":
				suppressed_records.append(playback)
	_stack_animation_audio_playback_records[battle_id] = {
		"battle_id": battle_id,
		"event_id": String(cue_record.get("event_id", "")),
		"serial": int(cue_record.get("serial", 0)),
		"cue_id": String(cue_record.get("cue_id", "")),
		"selected_audio_cue_ids": audio_ids.duplicate(true),
		"generated_waveform_count": generated_records.size(),
		"imported_asset_count": imported_records.size(),
		"generated_fallback_count": generated_records.size(),
		"played_audio_cue_count": imported_records.size() + generated_records.size(),
		"suppressed_audio_cue_count": suppressed_records.size(),
		"generated_waveforms": generated_records,
		"imported_assets": imported_records,
		"suppressed_cues": suppressed_records,
		"asset_playbacks": asset_records,
		"started_at_msec": started_at,
		"expires_at_msec": int(cue_record.get("expires_at_msec", Time.get_ticks_msec() + STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
		"sequence_delay_msec": int(cue_record.get("sequence_delay_msec", 0)),
		"audio_bus": BATTLE_AUDIO_BUS,
		"muted": SettingsService.effects_audio_muted(),
		"scheduled": false,
	}

func _play_audio_cue(audio_id: String, battle_id: String, serial: int) -> Dictionary:
	var admission := _audio_mix_admission(audio_id)
	if not bool(admission.get("allowed", false)):
		return {
			"audio_id": audio_id,
			"source": "suppressed",
			"played": false,
			"priority_class": String(admission.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
			"priority": int(admission.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
			"repeat_cooldown_msec": int(admission.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC)),
			"effective_voice_budget": int(admission.get("effective_voice_budget", BATTLE_AUDIO_MAX_ACTIVE_PLAYERS)),
			"reduced_repetitive_sounds": bool(admission.get("reduced_repetitive_sounds", false)),
			"suppressed_reason": String(admission.get("reason", "mix_policy")),
		}
	var imported := _play_imported_audio_cue(audio_id, battle_id, serial, admission)
	if not imported.is_empty():
		_record_audio_cue_started(audio_id, imported, admission)
		return imported
	var generated := _play_generated_audio_cue(audio_id, battle_id, serial, admission)
	if not generated.is_empty():
		generated["source"] = "generated_waveform"
		_record_audio_cue_started(audio_id, generated, admission)
	return generated

func _play_imported_audio_cue(audio_id: String, battle_id: String, serial: int, mix_policy: Dictionary) -> Dictionary:
	var cue := _battle_sfx_manifest_cue(audio_id)
	if cue.is_empty():
		return {}
	var path := String(cue.get("path", "")).strip_edges()
	if path == "":
		return {}
	var stream := RuntimeAudioLoaderScript.load_stream(path)
	if stream == null:
		return {}
	var duration_msec := int(cue.get("duration_msec", 120))
	var stream_length := stream.get_length()
	if stream_length > 0.0:
		duration_msec = maxi(1, int(ceil(stream_length * 1000.0)))
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsService.effects_audio_bus_name()
	player.volume_db = float(cue.get("volume_db", -12.0))
	add_child(player)
	_active_audio_players.append({
		"player": player,
		"battle_id": battle_id,
		"audio_id": audio_id,
		"source": "imported_wav",
		"asset_path": path,
		"serial": serial,
		"priority_class": String(mix_policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
		"priority": int(mix_policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
		"started_at_msec": int(Time.get_ticks_msec()),
		"expires_at_msec": int(Time.get_ticks_msec()) + duration_msec + 180,
	})
	_trim_audio_players()
	player.play()
	return {
		"audio_id": audio_id,
		"source": "imported_wav",
		"asset_path": path,
		"role": String(cue.get("role", "")),
		"duration_msec": duration_msec,
		"volume_db": float(cue.get("volume_db", -12.0)),
		"played": true,
		"player_created": true,
	}

func _play_generated_audio_cue(audio_id: String, battle_id: String, serial: int, mix_policy: Dictionary) -> Dictionary:
	var spec := _audio_cue_wave_spec(audio_id)
	if spec.is_empty():
		return {}
	var duration_msec := int(spec.get("duration_msec", 120))
	var frame_count := maxi(1, int(BATTLE_AUDIO_SAMPLE_RATE * float(duration_msec) / 1000.0))
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = BATTLE_AUDIO_SAMPLE_RATE
	stream.buffer_length = maxf(0.05, float(duration_msec) / 1000.0 + 0.04)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsService.effects_audio_bus_name()
	player.volume_db = float(spec.get("volume_db", -12.0))
	add_child(player)
	_active_audio_players.append({
		"player": player,
		"battle_id": battle_id,
		"audio_id": audio_id,
		"serial": serial,
		"priority_class": String(mix_policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
		"priority": int(mix_policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
		"started_at_msec": int(Time.get_ticks_msec()),
		"expires_at_msec": int(Time.get_ticks_msec()) + duration_msec + 180,
	})
	_trim_audio_players()
	player.play()
	var playback = player.get_stream_playback()
	if playback is AudioStreamGeneratorPlayback:
		_push_generated_audio_frames(playback, spec, frame_count)
	return {
		"audio_id": audio_id,
		"waveform": String(spec.get("waveform", "sine")),
		"frequency_hz": float(spec.get("frequency_hz", 440.0)),
		"secondary_frequency_hz": float(spec.get("secondary_frequency_hz", 0.0)),
		"duration_msec": duration_msec,
		"frame_count": frame_count,
		"played": true,
		"player_created": true,
	}

func _audio_mix_admission(audio_id: String) -> Dictionary:
	var policy := _audio_mix_policy(audio_id)
	var priority := int(policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS]))
	var priority_class := String(policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS))
	var cooldown_msec := int(policy.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC))
	var voice_budget := _effective_battle_audio_voice_budget()
	var reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	if SettingsService.effects_audio_muted():
		_record_audio_cue_suppressed("effects_muted")
		return {"allowed": false, "reason": "effects_muted", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
	_cleanup_audio_players()
	while _active_audio_players.size() > voice_budget:
		_evict_audio_voice(_audio_eviction_candidate_index())
	var now := int(Time.get_ticks_msec())
	var cooldown_key := String(_battle_sfx_manifest_cue(audio_id).get("cooldown_key", audio_id))
	var last_started := int(_audio_last_started_msec_by_cue.get(cooldown_key, -1000000000))
	if cooldown_msec > 0 and now - last_started < cooldown_msec:
		_record_audio_cue_suppressed("repeat_cooldown")
		return {"allowed": false, "reason": "repeat_cooldown", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
	var evicted := {}
	if _active_audio_players.size() >= voice_budget:
		var candidate_index := _audio_eviction_candidate_index()
		var candidate: Dictionary = _active_audio_players[candidate_index] if candidate_index >= 0 and _active_audio_players[candidate_index] is Dictionary else {}
		if candidate.is_empty() or priority <= int(candidate.get("priority", 0)):
			_record_audio_cue_suppressed("voice_budget")
			return {"allowed": false, "reason": "voice_budget", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
		evicted = _evict_audio_voice(candidate_index)
	return {
		"allowed": true,
		"priority": priority,
		"priority_class": priority_class,
		"repeat_cooldown_msec": cooldown_msec,
		"effective_voice_budget": voice_budget,
		"reduced_repetitive_sounds": reduced_repetition,
		"evicted_audio_id": String(evicted.get("audio_id", "")),
		"evicted_priority_class": String(evicted.get("priority_class", "")),
	}

func _audio_mix_policy(audio_id: String) -> Dictionary:
	var cue := _battle_sfx_manifest_cue(audio_id)
	var priority_class := String(cue.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)).strip_edges()
	if not BATTLE_AUDIO_PRIORITY_VALUES.has(priority_class):
		priority_class = BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS
	var repeat_cooldown_msec := maxi(0, int(cue.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC)))
	if SettingsService.reduced_repetitive_sounds_enabled():
		repeat_cooldown_msec *= BATTLE_AUDIO_REDUCED_REPETITION_COOLDOWN_MULTIPLIER
	return {
		"priority_class": priority_class,
		"priority": int(BATTLE_AUDIO_PRIORITY_VALUES[priority_class]),
		"repeat_cooldown_msec": repeat_cooldown_msec,
	}

func _effective_battle_audio_voice_budget() -> int:
	return BATTLE_AUDIO_REDUCED_REPETITION_MAX_ACTIVE_PLAYERS if SettingsService.reduced_repetitive_sounds_enabled() else BATTLE_AUDIO_MAX_ACTIVE_PLAYERS

func _audio_eviction_candidate_index() -> int:
	var candidate_index := -1
	var candidate_priority := 1000000
	var candidate_started_at := 1000000000000
	for index in range(_active_audio_players.size()):
		var entry: Dictionary = _active_audio_players[index] if _active_audio_players[index] is Dictionary else {}
		if entry.is_empty():
			continue
		var priority := int(entry.get("priority", 0))
		var started_at := int(entry.get("started_at_msec", 0))
		if priority < candidate_priority or (priority == candidate_priority and started_at < candidate_started_at):
			candidate_index = index
			candidate_priority = priority
			candidate_started_at = started_at
	return candidate_index

func _evict_audio_voice(index: int) -> Dictionary:
	if index < 0 or index >= _active_audio_players.size():
		return {}
	var entry = _active_audio_players.pop_at(index)
	if entry is Dictionary:
		var player = entry.get("player", null)
		if player is AudioStreamPlayer and is_instance_valid(player):
			player.queue_free()
		_audio_mix_counters["evicted"] = int(_audio_mix_counters.get("evicted", 0)) + 1
		return entry.duplicate(true)
	return {}

func _record_audio_cue_started(audio_id: String, playback: Dictionary, admission: Dictionary) -> void:
	var cooldown_key := String(_battle_sfx_manifest_cue(audio_id).get("cooldown_key", audio_id))
	_audio_last_started_msec_by_cue[cooldown_key] = int(Time.get_ticks_msec())
	_audio_mix_counters["played"] = int(_audio_mix_counters.get("played", 0)) + 1
	playback["priority_class"] = String(admission.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS))
	playback["priority"] = int(admission.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS]))
	playback["repeat_cooldown_msec"] = int(admission.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC))
	playback["effective_voice_budget"] = int(admission.get("effective_voice_budget", BATTLE_AUDIO_MAX_ACTIVE_PLAYERS))
	playback["reduced_repetitive_sounds"] = bool(admission.get("reduced_repetitive_sounds", false))
	playback["evicted_audio_id"] = String(admission.get("evicted_audio_id", ""))
	playback["evicted_priority_class"] = String(admission.get("evicted_priority_class", ""))

func _record_audio_cue_suppressed(reason: String) -> void:
	_audio_mix_counters["suppressed"] = int(_audio_mix_counters.get("suppressed", 0)) + 1
	var reasons: Dictionary = _audio_mix_counters.get("suppressed_by_reason", {}) if _audio_mix_counters.get("suppressed_by_reason", {}) is Dictionary else {}
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	_audio_mix_counters["suppressed_by_reason"] = reasons

func _active_audio_voice_mix() -> Array:
	_cleanup_audio_players()
	var result := []
	for entry in _active_audio_players:
		if entry is Dictionary:
			result.append({
				"audio_id": String(entry.get("audio_id", "")),
				"battle_id": String(entry.get("battle_id", "")),
				"priority_class": String(entry.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
				"priority": int(entry.get("priority", 0)),
				"source": String(entry.get("source", "generated_waveform")),
			})
	return result

func _battle_sfx_manifest_cue(audio_id: String) -> Dictionary:
	if audio_id.begins_with("production_"):
		return AudioPaletteScript.cue(audio_id)
	_load_battle_sfx_manifest()
	var cues: Dictionary = _battle_sfx_manifest.get("cues", {}) if _battle_sfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(audio_id, {}) if cues.get(audio_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _battle_vfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_battle_vfx_manifest()
	var cues: Dictionary = _battle_vfx_manifest.get("cues", {}) if _battle_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_battle_vfx_manifest() -> void:
	if _battle_vfx_manifest_loaded:
		return
	_battle_vfx_manifest_loaded = true
	_battle_vfx_manifest = {}
	_battle_vfx_textures.clear()
	_battle_vfx_texture_missing.clear()
	if not FileAccess.file_exists(BATTLE_VFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_VFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_battle_vfx_manifest = parsed

func _battle_vfx_texture_for_path(texture_path: String):
	if texture_path == "" or _battle_vfx_texture_missing.has(texture_path):
		return null
	if _battle_vfx_textures.has(texture_path):
		return _battle_vfx_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path):
		_battle_vfx_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_battle_vfx_textures[texture_path] = loaded
		return loaded
	_battle_vfx_texture_missing[texture_path] = true
	return null

func _load_field_objective_art_manifest() -> void:
	if _field_objective_art_manifest_loaded:
		return
	_field_objective_art_manifest_loaded = true
	_field_objective_art_manifest = {}
	_field_objective_art_textures.clear()
	_field_objective_art_texture_missing.clear()
	if not FileAccess.file_exists(BATTLE_FIELD_OBJECTIVE_ART_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_FIELD_OBJECTIVE_ART_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_field_objective_art_manifest = parsed

func _field_objective_art_spec(objective_type: String) -> Dictionary:
	_load_field_objective_art_manifest()
	var objectives: Dictionary = _field_objective_art_manifest.get("objectives", {}) if _field_objective_art_manifest.get("objectives", {}) is Dictionary else {}
	var spec: Dictionary = objectives.get(objective_type, {}) if objectives.get(objective_type, {}) is Dictionary else {}
	var art_path := String(spec.get("path", "")).strip_edges()
	if String(spec.get("id", "")).strip_edges() == "" \
		or String(spec.get("alt_text", "")).strip_edges() == "" \
		or String(spec.get("silhouette", "")).strip_edges() == "" \
		or not art_path.begins_with("res://art/battle/runtime/field_objectives/") \
		or not art_path.ends_with(".png"):
		return {}
	return spec.duplicate(true)

func _field_objective_art_profile(objective_type: String, override_path: String = "") -> Dictionary:
	var spec := _field_objective_art_spec(objective_type)
	var art_path := override_path.strip_edges() if override_path.strip_edges() != "" else String(spec.get("path", "")).strip_edges()
	var texture = _field_objective_art_texture_for_path(art_path)
	return {
		"objective_type": objective_type,
		"art_id": String(spec.get("id", "")),
		"art_path": art_path,
		"source_path": String(spec.get("source_path", "")),
		"alt_text": String(spec.get("alt_text", "")),
		"silhouette": String(spec.get("silhouette", "")),
		"art_loaded": texture is Texture2D,
		"uses_legacy_geometry_fallback": not (texture is Texture2D),
	}

func _field_objective_art_texture_for_path(texture_path: String):
	if not texture_path.begins_with("res://art/battle/runtime/field_objectives/") \
		or not texture_path.ends_with(".png") \
		or _field_objective_art_texture_missing.has(texture_path):
		return null
	if _field_objective_art_textures.has(texture_path):
		return _field_objective_art_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path, "Texture2D"):
		_field_objective_art_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_field_objective_art_textures[texture_path] = loaded
		return loaded
	_field_objective_art_texture_missing[texture_path] = true
	return null

func _field_objective_control_shape(control_side: String) -> String:
	_load_field_objective_art_manifest()
	var normalized_side := control_side if control_side in ["player", "enemy"] else "neutral"
	var control_shapes: Dictionary = _field_objective_art_manifest.get("control_shapes", {}) if _field_objective_art_manifest.get("control_shapes", {}) is Dictionary else {}
	var shape := String(control_shapes.get(normalized_side, ""))
	if shape in ["diamond", "downward_triangle", "hollow_square"]:
		return shape
	return {"player": "diamond", "enemy": "downward_triangle", "neutral": "hollow_square"}.get(normalized_side, "hollow_square")

func _load_battle_status_effect_art_manifest() -> void:
	if _battle_status_effect_art_manifest_loaded:
		return
	_battle_status_effect_art_manifest_loaded = true
	_battle_status_effect_art_manifest = {}
	_battle_status_effect_art_textures.clear()
	_battle_status_effect_art_texture_missing.clear()
	if not FileAccess.file_exists(BATTLE_STATUS_EFFECT_ART_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_STATUS_EFFECT_ART_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_battle_status_effect_art_manifest = parsed

func _battle_status_effect_art_spec(status_id: String) -> Dictionary:
	_load_battle_status_effect_art_manifest()
	var statuses: Dictionary = _battle_status_effect_art_manifest.get("statuses", {}) if _battle_status_effect_art_manifest.get("statuses", {}) is Dictionary else {}
	var spec: Dictionary = statuses.get(status_id, {}) if statuses.get(status_id, {}) is Dictionary else {}
	var art_path := String(spec.get("path", "")).strip_edges()
	var polarity := String(spec.get("polarity", "")).strip_edges()
	var fallback_mark := String(spec.get("fallback_mark", "")).strip_edges()
	if String(spec.get("id", "")).strip_edges() == "" \
		or String(spec.get("alt_text", "")).strip_edges() == "" \
		or String(spec.get("silhouette", "")).strip_edges() == "" \
		or not polarity in ["harmful", "beneficial"] \
		or fallback_mark.length() != 1 \
		or not art_path.begins_with("res://art/battle/runtime/status_effects/") \
		or not art_path.ends_with(".png"):
		return {}
	return spec.duplicate(true)

func _battle_status_effect_art_profile(status_id: String, override_path: String = "") -> Dictionary:
	var spec := _battle_status_effect_art_spec(status_id)
	var art_path := override_path.strip_edges() if override_path.strip_edges() != "" else String(spec.get("path", "")).strip_edges()
	var texture = _battle_status_effect_art_texture_for_path(art_path)
	var polarity := String(spec.get("polarity", ""))
	return {
		"status_id": status_id,
		"art_id": String(spec.get("id", "")),
		"art_path": art_path,
		"source_path": String(spec.get("source_path", "")),
		"alt_text": String(spec.get("alt_text", "")),
		"silhouette": String(spec.get("silhouette", "")),
		"polarity": polarity,
		"polarity_foundation": _battle_status_effect_polarity_foundation(polarity),
		"fallback_mark": String(spec.get("fallback_mark", "?")),
		"art_loaded": texture is Texture2D,
		"uses_procedural_mark_fallback": not (texture is Texture2D),
	}

func _battle_status_effect_art_texture_for_path(texture_path: String):
	if not texture_path.begins_with("res://art/battle/runtime/status_effects/") \
		or not texture_path.ends_with(".png") \
		or _battle_status_effect_art_texture_missing.has(texture_path):
		return null
	if _battle_status_effect_art_textures.has(texture_path):
		return _battle_status_effect_art_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path, "Texture2D"):
		_battle_status_effect_art_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_battle_status_effect_art_textures[texture_path] = loaded
		return loaded
	_battle_status_effect_art_texture_missing[texture_path] = true
	return null

func _battle_status_effect_polarity_foundation(polarity: String) -> String:
	_load_battle_status_effect_art_manifest()
	var foundations: Dictionary = _battle_status_effect_art_manifest.get("polarity_foundations", {}) if _battle_status_effect_art_manifest.get("polarity_foundations", {}) is Dictionary else {}
	var normalized := polarity if polarity in ["harmful", "beneficial"] else "harmful"
	var shape := String(foundations.get(normalized, ""))
	if normalized == "beneficial" and shape == "upward_pentagon":
		return shape
	if normalized == "harmful" and shape == "broken_diamond":
		return shape
	return "upward_pentagon" if normalized == "beneficial" else "broken_diamond"

func _load_battle_sfx_manifest() -> void:
	if _battle_sfx_manifest_loaded:
		return
	_battle_sfx_manifest_loaded = true
	_battle_sfx_manifest = {}
	if not FileAccess.file_exists(BATTLE_SFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_SFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_battle_sfx_manifest = parsed

func _push_generated_audio_frames(playback: AudioStreamGeneratorPlayback, spec: Dictionary, frame_count: int) -> void:
	var frequency := float(spec.get("frequency_hz", 440.0))
	var secondary_frequency := float(spec.get("secondary_frequency_hz", 0.0))
	var amplitude := float(spec.get("amplitude", 0.18))
	var noise_amount := float(spec.get("noise", 0.0))
	var waveform := String(spec.get("waveform", "sine"))
	for index in range(frame_count):
		var t := float(index) / BATTLE_AUDIO_SAMPLE_RATE
		var progress := float(index) / float(maxi(1, frame_count - 1))
		var envelope := _audio_envelope(progress)
		var sample := 0.0
		match waveform:
			"triangle":
				sample = _triangle_wave(frequency * t)
			"square":
				sample = 1.0 if sin(TAU * frequency * t) >= 0.0 else -1.0
			_:
				sample = sin(TAU * frequency * t)
		if secondary_frequency > 0.0:
			sample = sample * 0.72 + sin(TAU * secondary_frequency * t) * 0.28
		if noise_amount > 0.0:
			sample = sample * (1.0 - noise_amount) + _deterministic_audio_noise(index) * noise_amount
		sample = clampf(sample * amplitude * envelope, -0.90, 0.90)
		playback.push_frame(Vector2(sample, sample))

func _audio_envelope(progress: float) -> float:
	var attack := smoothstep(0.0, 0.12, progress)
	var release := 1.0 - smoothstep(0.68, 1.0, progress)
	return clampf(attack * release, 0.0, 1.0)

func _triangle_wave(phase: float) -> float:
	var wrapped: float = phase - floor(phase)
	return 4.0 * abs(wrapped - 0.5) - 1.0

func _deterministic_audio_noise(index: int) -> float:
	var value := sin(float(index) * 12.9898 + 78.233) * 43758.5453
	return (value - floor(value)) * 2.0 - 1.0

func _audio_cue_wave_spec(audio_id: String) -> Dictionary:
	match audio_id:
		"audio_placeholder_ranged_release":
			return {"waveform": "sine", "frequency_hz": 760.0, "secondary_frequency_hz": 1140.0, "duration_msec": 150, "amplitude": 0.16, "volume_db": -13.0}
		"audio_placeholder_status_apply":
			return {"waveform": "triangle", "frequency_hz": 420.0, "secondary_frequency_hz": 630.0, "duration_msec": 190, "amplitude": 0.14, "volume_db": -14.0}
		"audio_placeholder_melee_release":
			return {"waveform": "triangle", "frequency_hz": 260.0, "secondary_frequency_hz": 520.0, "duration_msec": 120, "amplitude": 0.18, "noise": 0.18, "volume_db": -12.0}
		"audio_placeholder_hit":
			return {"waveform": "square", "frequency_hz": 150.0, "duration_msec": 100, "amplitude": 0.13, "noise": 0.34, "volume_db": -13.0}
		"audio_placeholder_unit_rout":
			return {"waveform": "triangle", "frequency_hz": 180.0, "secondary_frequency_hz": 120.0, "duration_msec": 260, "amplitude": 0.13, "noise": 0.12, "volume_db": -14.0}
		"audio_placeholder_cast":
			return {"waveform": "sine", "frequency_hz": 520.0, "secondary_frequency_hz": 780.0, "duration_msec": 220, "amplitude": 0.14, "volume_db": -14.0}
		"audio_placeholder_unit_step":
			return {"waveform": "triangle", "frequency_hz": 220.0, "duration_msec": 80, "amplitude": 0.09, "noise": 0.18, "volume_db": -17.0}
		"audio_placeholder_defend":
			return {"waveform": "triangle", "frequency_hz": 300.0, "duration_msec": 100, "amplitude": 0.10, "volume_db": -16.0}
		"audio_placeholder_retaliation":
			return {"waveform": "triangle", "frequency_hz": 340.0, "secondary_frequency_hz": 170.0, "duration_msec": 130, "amplitude": 0.16, "noise": 0.12, "volume_db": -13.0}
		"audio_placeholder_retreat_order", "audio_placeholder_surrender_order":
			return {"waveform": "sine", "frequency_hz": 330.0, "secondary_frequency_hz": 250.0, "duration_msec": 210, "amplitude": 0.12, "volume_db": -15.0}
		"audio_placeholder_turn_ready":
			return {"waveform": "sine", "frequency_hz": 640.0, "duration_msec": 110, "amplitude": 0.09, "volume_db": -18.0}
		"audio_placeholder_status_clear":
			return {"waveform": "sine", "frequency_hz": 360.0, "secondary_frequency_hz": 540.0, "duration_msec": 150, "amplitude": 0.10, "volume_db": -17.0}
		"audio_placeholder_idle_soft":
			return {"waveform": "sine", "frequency_hz": 180.0, "duration_msec": 70, "amplitude": 0.04, "volume_db": -24.0}
		"audio_spell_cinder_burst":
			return {"waveform": "triangle", "frequency_hz": 220.0, "secondary_frequency_hz": 760.0, "duration_msec": 260, "amplitude": 0.18, "noise": 0.18, "volume_db": -12.0}
		"audio_spell_coal_rain":
			return {"waveform": "triangle", "frequency_hz": 185.0, "secondary_frequency_hz": 520.0, "duration_msec": 300, "amplitude": 0.16, "noise": 0.24, "volume_db": -12.5}
		"audio_spell_sunlance_arc":
			return {"waveform": "sine", "frequency_hz": 690.0, "secondary_frequency_hz": 1380.0, "duration_msec": 240, "amplitude": 0.16, "volume_db": -12.0}
		"audio_spell_briar_bind":
			return {"waveform": "triangle", "frequency_hz": 260.0, "secondary_frequency_hz": 390.0, "duration_msec": 270, "amplitude": 0.14, "noise": 0.12, "volume_db": -13.0}
		"audio_spell_graft_mend":
			return {"waveform": "sine", "frequency_hz": 380.0, "secondary_frequency_hz": 570.0, "duration_msec": 280, "amplitude": 0.13, "volume_db": -13.5}
		"audio_spell_prism_bastion":
			return {"waveform": "sine", "frequency_hz": 510.0, "secondary_frequency_hz": 1020.0, "duration_msec": 270, "amplitude": 0.13, "volume_db": -13.5}
		"audio_spell_resonant_chorus":
			return {"waveform": "sine", "frequency_hz": 294.0, "secondary_frequency_hz": 882.0, "duration_msec": 290, "amplitude": 0.14, "volume_db": -13.0}
		"audio_spell_command_ward":
			return {"waveform": "sine", "frequency_hz": 330.0, "secondary_frequency_hz": 495.0, "duration_msec": 240, "amplitude": 0.12, "volume_db": -14.0}
	return {}

func _cleanup_audio_players() -> void:
	var now := int(Time.get_ticks_msec())
	var retained := []
	for entry in _active_audio_players:
		if not (entry is Dictionary):
			continue
		var player = entry.get("player", null)
		var expired := int(entry.get("expires_at_msec", 0)) <= now
		if player is AudioStreamPlayer and is_instance_valid(player) and not expired:
			retained.append(entry)
		elif player is AudioStreamPlayer and is_instance_valid(player):
			player.queue_free()
	_active_audio_players = retained

func _activate_due_audio_cue_playback() -> void:
	var now := int(Time.get_ticks_msec())
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		if cue_record.is_empty() or int(cue_record.get("started_at_msec", now)) > now:
			continue
		var audio_record: Dictionary = _stack_animation_audio_playback_records.get(battle_id, {}) if _stack_animation_audio_playback_records.get(battle_id, {}) is Dictionary else {}
		if audio_record.is_empty() or bool(audio_record.get("scheduled", false)):
			_register_audio_cue_playback(cue_record)

func _trim_audio_players() -> void:
	_cleanup_audio_players()
	while _active_audio_players.size() > BATTLE_AUDIO_MAX_ACTIVE_PLAYERS:
		var entry = _active_audio_players.pop_front()
		if entry is Dictionary:
			var player = entry.get("player", null)
			if player is AudioStreamPlayer and is_instance_valid(player):
				player.queue_free()

func _active_audio_player_count() -> int:
	_cleanup_audio_players()
	return _active_audio_players.size()

func _turn_ribbon_chip_at_position(position: Vector2) -> Dictionary:
	if _battle.is_empty():
		return {}
	for entry in _turn_ribbon_chips():
		if Rect2(entry.get("rect", Rect2())).has_point(position):
			return entry
	return {}

func _turn_ribbon_chip_tooltip(entry: Dictionary, visible_count: int) -> String:
	var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
	if stack.is_empty():
		return tooltip_text
	var current := String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", ""))
	var state := "current stack" if current else "queued stack"
	match String(entry.get("phase", "current")):
		"waiting":
			state = "waiting stack, acts after the others"
		"next_round":
			state = "next round (round %d), predicted" % (int(_turn_forecast.get("round", 1)) + 1)
	return "Turn order\n- Visible slot: %d of %d\n- Stack: %s x%d\n- Side: %s\n- State: %s\n- Inspection: hovering this chip does not advance initiative or spend an action." % [
		int(entry.get("slot", 0)),
		visible_count,
		_stack_full_name(stack),
		_stack_alive_count(stack),
		String(stack.get("side", "neutral")).capitalize(),
		state,
	]

func _controller_cursor_cell_role() -> String:
	if not _cell_in_bounds(_controller_cursor_cell):
		return ""
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	if battle_id != "":
		var stack := _stack_by_id(battle_id)
		return "%s_stack" % String(stack.get("side", "unknown"))
	return "legal_destination" if _is_legal_destination_cell(_controller_cursor_cell) else "blocked_hex"

func _draw_objective_marker(center: Vector2, objective: Dictionary, color: Color, radius: float) -> void:
	var objective_type := String(objective.get("type", ""))
	var art_spec := _field_objective_art_spec(objective_type)
	var art_path := String(art_spec.get("path", ""))
	var art_texture: Texture2D = _field_objective_art_texture_for_path(art_path) as Texture2D
	var render_spec: Dictionary = _field_objective_art_manifest.get("render", {}) if _field_objective_art_manifest.get("render", {}) is Dictionary else {}
	var extent := clampf(
		radius * float(render_spec.get("extent_factor", 0.82)),
		float(render_spec.get("extent_min", 19.0)),
		float(render_spec.get("extent_max", 28.0))
	)
	var control_side := String(objective.get("control_side", "neutral"))
	_draw_field_objective_control_foundation(center, color, extent)
	if art_texture != null:
		var texture_rect := Rect2(center - Vector2(extent, extent), Vector2(extent * 2.0, extent * 2.0))
		draw_texture_rect(
			art_texture,
			texture_rect,
			false,
			Color(1.0, 1.0, 1.0, float(render_spec.get("texture_alpha", 0.98)))
		)
	else:
		_draw_legacy_objective_marker(center, objective_type, color, radius)
	_draw_field_objective_control_badge(
		center + Vector2(extent * 0.60, -extent * 0.58),
		_field_objective_control_shape(control_side),
		color,
		extent
	)
	var progress_side := String(objective.get("progress_side", ""))
	var progress_value := int(objective.get("progress_value", 0))
	var threshold: int = maxi(1, int(objective.get("capture_threshold", 2)))
	if progress_side != "" and progress_value > 0:
		for pip in range(threshold):
			var pip_center := center + Vector2((float(pip) - float(threshold - 1) * 0.5) * 6.0, extent * 0.86 + 5.0)
			draw_circle(pip_center, 2.0, _controller_color(progress_side) if pip < progress_value else Color(0.08, 0.10, 0.12, 0.55))

func _draw_field_objective_control_foundation(center: Vector2, color: Color, extent: float) -> void:
	draw_circle(center, extent * 0.78, Color(0.018, 0.024, 0.028, 0.62))
	draw_circle(center, extent * 0.79, color.darkened(0.10), false, 2.2)
	draw_circle(center, extent * 0.69, Color(0.96, 0.88, 0.66, 0.20), false, 1.0)

func _draw_field_objective_control_badge(center: Vector2, shape: String, color: Color, extent: float) -> void:
	var badge_size := clampf(extent * 0.22, 4.5, 6.5)
	match shape:
		"diamond":
			var points := PackedVector2Array([
				center + Vector2(0.0, -badge_size),
				center + Vector2(badge_size, 0.0),
				center + Vector2(0.0, badge_size),
				center + Vector2(-badge_size, 0.0),
			])
			draw_colored_polygon(points, color)
			draw_polyline(_closed_points(points), Color(0.02, 0.025, 0.03, 0.94), 1.5, true)
		"downward_triangle":
			var points := PackedVector2Array([
				center + Vector2(-badge_size, -badge_size * 0.66),
				center + Vector2(badge_size, -badge_size * 0.66),
				center + Vector2(0.0, badge_size),
			])
			draw_colored_polygon(points, color)
			draw_polyline(_closed_points(points), Color(0.02, 0.025, 0.03, 0.94), 1.5, true)
		_:
			var badge_rect := Rect2(center - Vector2(badge_size, badge_size), Vector2(badge_size * 2.0, badge_size * 2.0))
			draw_rect(badge_rect, Color(0.02, 0.025, 0.03, 0.86), true)
			draw_rect(badge_rect, color, false, 1.8)

func _draw_legacy_objective_marker(center: Vector2, objective_type: String, color: Color, radius: float) -> void:
	var size: float = clampf(radius * 0.46, 10.0, 20.0)
	match objective_type:
		"cover_line":
			var cover_rect := Rect2(center - Vector2(size * 1.15, size * 0.38), Vector2(size * 2.3, size * 0.76))
			draw_rect(cover_rect, color.darkened(0.08), true)
			draw_rect(cover_rect, Color(0.08, 0.10, 0.12, 0.80), false, 1.6)
			draw_line(cover_rect.position + Vector2(3.0, 0.0), cover_rect.end - Vector2(3.0, 0.0), Color(0.98, 0.90, 0.66, 0.36), 1.2)
		"obstruction_line":
			draw_line(center + Vector2(-size, -size * 0.68), center + Vector2(size, size * 0.68), color, 4.0)
			draw_line(center + Vector2(size, -size * 0.68), center + Vector2(-size, size * 0.68), color, 4.0)
			draw_circle(center, size * 0.24, TEXT_COLOR)
		"lane_battery":
			draw_circle(center, size * 0.74, color)
			draw_rect(Rect2(center - Vector2(size * 0.20, size * 0.92), Vector2(size * 0.40, size * 1.12)), Color(0.08, 0.10, 0.12, 0.78), true)
			draw_line(center + Vector2(-size * 0.82, size * 0.38), center + Vector2(size * 0.82, size * 0.38), Color(0.08, 0.10, 0.12, 0.78), 3.0)
		"hazard_zone":
			var points := PackedVector2Array([
				center + Vector2(0.0, -size),
				center + Vector2(size * 0.90, size * 0.60),
				center + Vector2(-size * 0.90, size * 0.60),
			])
			draw_colored_polygon(points, color)
			draw_polyline(_closed_points(points), Color(0.08, 0.10, 0.12, 0.86), 1.8, true)
		_:
			draw_circle(center, size * 0.76, color)
			draw_circle(center, size * 0.76, Color(0.08, 0.10, 0.12, 0.82), false, 1.8)

func _draw_unit_glyph(center: Vector2, radius: float, stack: Dictionary) -> void:
	var glyph_color := Color(0.08, 0.10, 0.12, 0.88)
	if bool(stack.get("ranged", false)):
		draw_line(center + Vector2(-radius * 0.52, radius * 0.25), center + Vector2(radius * 0.50, -radius * 0.28), glyph_color, 2.6)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.22, -radius * 0.32), glyph_color, 2.2)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.38, -radius * 0.02), glyph_color, 2.2)
	else:
		draw_line(center + Vector2(-radius * 0.42, radius * 0.34), center + Vector2(radius * 0.38, -radius * 0.38), glyph_color, 3.0)
		draw_line(center + Vector2(-radius * 0.20, radius * 0.10), center + Vector2(radius * 0.10, radius * 0.38), glyph_color, 2.2)
	if bool(stack.get("defending", false)):
		var shield := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.58),
			center + Vector2(radius * 0.34, -radius * 0.22),
			center + Vector2(radius * 0.23, radius * 0.36),
			center + Vector2(0.0, radius * 0.58),
			center + Vector2(-radius * 0.23, radius * 0.36),
			center + Vector2(-radius * 0.34, -radius * 0.22),
		])
		draw_polyline(_closed_points(shield), Color(0.98, 0.93, 0.74, 0.80), 1.6, true)

func _draw_stack_side_cue(center: Vector2, token_radius: float, side: String) -> void:
	if not FrontierVisualKitScript.color_cue_assist_enabled():
		return
	var marker_center := center + Vector2(-token_radius * 0.72, -token_radius * 0.70)
	var marker_radius := maxf(7.0, token_radius * 0.34)
	var outline := Color(0.98, 0.98, 0.94, 0.96)
	var fill := _side_color(side).darkened(0.18)
	if side == "player":
		draw_circle(marker_center, marker_radius, fill)
		draw_circle(marker_center, marker_radius, outline, false, 1.6)
		_draw_centered_text("P", marker_center + Vector2(0.0, 3.4), outline, 9)
		return
	var triangle := PackedVector2Array([
		marker_center + Vector2(0.0, -marker_radius),
		marker_center + Vector2(marker_radius * 0.92, marker_radius * 0.78),
		marker_center + Vector2(-marker_radius * 0.92, marker_radius * 0.78),
	])
	draw_colored_polygon(triangle, fill)
	draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), outline, 1.6, true)
	_draw_centered_text("E", marker_center + Vector2(0.0, 3.8), outline, 9)

## The stack's count in a pill of its side's colour under its feet, with a
## sword or a bow for how it fights.
## A stack's plate at its feet, in its side's colour: a bow or sword, the
## count, a ranged stack's shots left, a pip per strike-back (lit while the
## stack still has it this round), an hourglass while it waits, a shield
## while it defends, and the effects on it. The acting stack's plate glows
## gold; the one the pointer, its ribbon chip or the details card points at
## is ringed white.
func _draw_count_badge(center: Vector2, radius: float, stack: Dictionary) -> void:
	var font := _plate_font()
	if font == null:
		return
	var plate := _stack_plate_layout(center, radius, stack, font)
	var rect: Rect2 = plate.get("rect", Rect2())
	var k := float(plate.get("k", 1.0))
	var model: Dictionary = plate.get("model", {})
	_stack_plate_records[String(model.get("battle_id", ""))] = {"rect": rect, "model": model}
	var player := String(model.get("side", "")) == "player"
	var active := bool(model.get("active", false))
	var highlighted := bool(model.get("highlighted", false))
	draw_texture_rect(_soft_glow(), Rect2(rect.position + Vector2(-8.0, 1.0) * k, rect.size + Vector2(16.0, 8.0) * k), false, Color(0.0, 0.0, 0.0, 0.5))
	if active:
		draw_texture_rect(_soft_glow(), rect.grow(13.0 * k), false, Color(UI_ACTIVE, 0.55))
	elif highlighted:
		draw_texture_rect(_soft_glow(), rect.grow(11.0 * k), false, Color(1.0, 1.0, 1.0, 0.3))
	_draw_rounded_box(rect, PLATE_PLAYER_FILL if player else PLATE_ENEMY_FILL, UI_PLAYER if player else UI_ENEMY, 7.0 * k, maxf(1.0, k))
	draw_line(rect.position + Vector2(6.0, 1.5) * k, Vector2(rect.end.x - 6.0 * k, rect.position.y + 1.5 * k), Color(1.0, 1.0, 1.0, 0.18), maxf(1.0, k))
	if active or highlighted:
		_draw_rounded_box(rect.grow(2.0 * k), Color(0.0, 0.0, 0.0, 0.0), UI_ACTIVE if active else Color.WHITE, 9.0 * k, 2.0 * k)
	var middle := rect.get_center().y
	var shots_color := Color(PLATE_SHOTS, 1.0 if int(model.get("shots", 0)) > 0 else 0.45)
	for part_value in plate.get("parts", []):
		var part: Dictionary = part_value
		var left := rect.position.x + float(part.get("x", 0.0))
		var width := float(part.get("width", 0.0))
		var part_center := Vector2(left + width * 0.5, middle)
		match String(part.get("part", "")):
			"role":
				_draw_role_glyph(part_center, width, bool(model.get("ranged", false)), PLATE_GLYPH)
			"count":
				_draw_plate_text(font, String(part.get("text", "")), left, middle, int(part.get("font_size", 12)), PLATE_INK, k)
			"divider":
				draw_line(Vector2(left, rect.position.y + 5.0 * k), Vector2(left, rect.end.y - 5.0 * k), Color(1.0, 1.0, 1.0, 0.3), maxf(1.0, k))
			"arrow":
				_draw_shot_glyph(part_center, width, shots_color)
			"shots":
				_draw_plate_text(font, String(part.get("text", "")), left, middle, int(part.get("font_size", 12)), shots_color, k)
			"pip":
				_draw_strike_back_pip(part_center, width * 0.5, bool(part.get("lit", false)), k)
			"waiting":
				_draw_hourglass_glyph(part_center, width, PLATE_FLAG)
			"defending":
				_draw_shield_glyph(part_center, width, PLATE_FLAG)
			"effects":
				var icon := float(part.get("icon", 14.0 * k))
				_draw_stack_status_effect_badges(Rect2(Vector2(left, middle - icon * 0.5), Vector2(width, icon)), model.get("effects", []), int(model.get("overflow", 0)))

## What a stack's plate shows: its side and role, the count, a ranged
## stack's shots left, its strike-backs a round and how many it still has
## (none while Staggered), whether it waits or defends, the effects on it,
## and whether it acts now or is pointed at.
func _stack_plate_model(stack: Dictionary) -> Dictionary:
	var battle_id := String(stack.get("battle_id", ""))
	var ranged := bool(stack.get("ranged", false))
	var strike_backs := BattleRulesScript.stack_strike_backs(_battle, stack)
	var icons := _plate_effect_icons(stack)
	var visible := icons.slice(0, _plate_effect_max_visible())
	var active := battle_id == String(_battle.get("active_stack_id", "")) and not _field_final
	return {
		"battle_id": battle_id,
		"side": String(stack.get("side", "")),
		"ranged": ranged,
		"count": _stack_alive_count(stack),
		"shots": maxi(0, int(stack.get("shots_remaining", 0))) if ranged else -1,
		"strike_backs": int(strike_backs.get("max", 0)),
		"strike_backs_left": int(strike_backs.get("left", 0)),
		"waiting": BattleRulesScript.stack_is_waiting(_battle, battle_id),
		"defending": bool(stack.get("defending", false)),
		"effects": visible,
		"effect_ids": visible.map(func(icon: Dictionary) -> String: return String(icon.get("id", ""))),
		"overflow": icons.size() - visible.size(),
		"active": active,
		"highlighted": not active and battle_id != "" and battle_id == _plate_highlight_id(),
	}

## The stack whose plate is ringed: the one the details card shows, else the
## one the pointer, its ribbon chip or the keyboard cursor points at.
func _plate_highlight_id() -> String:
	if String(_details_subject.get("kind", "")) == "stack":
		return String(_details_subject.get("id", ""))
	if _hover_ribbon_battle_id != "":
		return _hover_ribbon_battle_id
	return _pointed_stack_id()

## The plate's box at a stack's feet, sized by what it shows, and where each
## part goes from its left edge ({"rect", "k", "model", "parts"}).
func _stack_plate_layout(center: Vector2, radius: float, stack: Dictionary, font: Font) -> Dictionary:
	var model := _stack_plate_model(stack)
	var k := clampf(radius / REFERENCE_HEX_RADIUS, 0.55, 1.6)
	var parts: Array = []
	var x := 4.0 * k
	parts.append({"part": "role", "x": x, "width": 15.0 * k})
	x += 18.0 * k
	var count_size := int(round(15.0 * k))
	var count_text := str(int(model.get("count", 0)))
	var count_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_size).x
	parts.append({"part": "count", "x": x, "width": count_width, "text": count_text, "font_size": count_size})
	x += count_width
	if int(model.get("shots", -1)) >= 0:
		x += 5.0 * k
		parts.append({"part": "divider", "x": x, "width": 0.0})
		x += 4.0 * k
		parts.append({"part": "arrow", "x": x, "width": 11.0 * k})
		x += 12.0 * k
		var shots_size := int(round(12.5 * k))
		var shots_text := str(int(model.get("shots", 0)))
		var shots_width := font.get_string_size(shots_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, shots_size).x
		parts.append({"part": "shots", "x": x, "width": shots_width, "text": shots_text, "font_size": shots_size})
		x += shots_width
	var pips := int(model.get("strike_backs", 0))
	if pips > 0:
		x += 5.0 * k
		for index in range(pips):
			parts.append({"part": "pip", "x": x, "width": 8.5 * k, "lit": index < int(model.get("strike_backs_left", 0))})
			x += 8.5 * k + (2.5 * k if index < pips - 1 else 0.0)
	for flag in ["waiting", "defending"]:
		if bool(model.get(flag, false)):
			x += 4.0 * k
			parts.append({"part": flag, "x": x, "width": 13.0 * k})
			x += 13.0 * k
	var effects: Array = model.get("effects", [])
	if not effects.is_empty():
		x += 4.0 * k
		var icon := 14.0 * k
		var width := icon * PLATE_EFFECT_STEP * float(effects.size())
		var overflow := int(model.get("overflow", 0))
		if overflow > 0:
			width += icon * 0.08 + font.get_string_size("+%d" % overflow, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(6, int(round(icon * 0.72)))).x
		parts.append({"part": "effects", "x": x, "width": width, "icon": icon})
		x += width
	x += 6.0 * k
	var ground_y := center.y + radius * STACK_STANDEE_GROUND_OFFSET_FACTOR
	var rect := Rect2(Vector2(center.x - x * 0.5, ground_y + radius * 0.1 * HEX_VERTICAL_SCALE), Vector2(x, 24.0 * k))
	return {"rect": rect, "k": k, "model": model, "parts": parts}

## The plates' bold face: the theme's font, thickened.
func _plate_font() -> Font:
	var base := get_theme_default_font()
	if base == null:
		return null
	if _plate_font_variation == null or _plate_font_variation.base_font != base:
		_plate_font_variation = FontVariation.new()
		_plate_font_variation.base_font = base
		_plate_font_variation.variation_embolden = 0.6
	return _plate_font_variation

## Text on a plate from its left edge, centred on the plate's middle, over a
## dark shadow.
func _draw_plate_text(font: Font, text: String, left: float, middle: float, font_size: int, color: Color, k: float) -> void:
	var baseline := middle + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(left, baseline + maxf(1.0, k)), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

## A small arrow flying up and to the right, for the shots left.
func _draw_shot_glyph(center: Vector2, extent: float, color: Color) -> void:
	BattleGlyphsScript.draw_shot(self, center, extent, color)

## One strike-back: a gold diamond while the stack still has it this round,
## an empty one once it is spent.
func _draw_strike_back_pip(center: Vector2, half: float, lit: bool, k: float) -> void:
	var diamond := PackedVector2Array([center + Vector2(0.0, -half), center + Vector2(half, 0.0), center + Vector2(0.0, half), center + Vector2(-half, 0.0)])
	if lit:
		draw_texture_rect(_soft_glow(), Rect2(center - Vector2(half, half) * 2.2, Vector2(half, half) * 4.4), false, Color(PLATE_PIP, 0.55))
	draw_colored_polygon(diamond, PLATE_PIP if lit else Color(0.0, 0.0, 0.0, 0.3))
	draw_polyline(_closed_points(diamond), PLATE_PIP_EDGE if lit else PLATE_PIP_SPENT, maxf(1.0, k), true)

## A heater shield, for a stack that defends.
func _draw_shield_glyph(center: Vector2, extent: float, color: Color) -> void:
	BattleGlyphsScript.draw_shield(self, center, extent, color)

## The plate a stack showed when last drawn: what it holds and its box ({}
## for a stack without one).
func validation_stack_plate(battle_id: String) -> Dictionary:
	var record: Dictionary = _stack_plate_records.get(battle_id, {})
	if record.is_empty():
		return {}
	var plate: Dictionary = (record.get("model", {}) as Dictionary).duplicate()
	plate.erase("effects")
	plate["rect"] = record.get("rect", Rect2())
	return plate

## The details hint: what the pointer hovers that it names, how many such
## hovers there have been, and whether it shows now.
func validation_details_hint() -> Dictionary:
	return {"subject": _details_hint_subject, "hovers": _details_hint_hovers, "shown": _details_hint_shown()}

func _draw_blocked_target_marker(center: Vector2, radius: float) -> void:
	var marker_radius: float = clampf(radius * 0.34, 7.0, 14.0)
	var marker_center := center + Vector2(radius * 0.36, -radius * 0.36)
	draw_circle(marker_center, marker_radius, Color(0.08, 0.09, 0.10, 0.86))
	draw_line(marker_center + Vector2(-marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)
	draw_line(marker_center + Vector2(marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(-marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)

func _draw_tree(center: Vector2, scale: float) -> void:
	var crown := PackedVector2Array([
		center + Vector2(0.0, -scale),
		center + Vector2(scale * 0.78, scale * 0.48),
		center + Vector2(-scale * 0.78, scale * 0.48),
	])
	draw_colored_polygon(crown, Color(0.10, 0.21, 0.13, 0.34))
	draw_rect(Rect2(center + Vector2(-2.0, scale * 0.28), Vector2(4.0, scale * 0.46)), Color(0.16, 0.11, 0.07, 0.26), true)

func _draw_hill(center: Vector2, width: float, height: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-width * 0.50, height * 0.35),
		center + Vector2(-width * 0.22, -height * 0.34),
		center + Vector2(width * 0.04, -height * 0.08),
		center + Vector2(width * 0.34, -height * 0.42),
		center + Vector2(width * 0.50, height * 0.35),
	])
	draw_colored_polygon(points, Color(0.18, 0.14, 0.09, 0.20))

func _draw_hex(center: Vector2, radius: float, fill: Color, stroke: Color, width: float) -> void:
	var points := _hex_points(center, radius)
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	if stroke.a > 0.0 and width > 0.0:
		draw_polyline(_closed_points(points), stroke, width, true)

func _draw_hex_outline(center: Vector2, radius: float, stroke: Color, width: float) -> void:
	draw_polyline(_closed_points(_hex_points(center, radius)), stroke, width, true)

## Each edge of the cells once, so shared edges are not drawn twice as dark.
func _draw_unique_hex_grid_lines(hex_layout: Dictionary, cells: Array[Vector2i], stroke: Color, width: float, radius_scale: float) -> void:
	var radius := float(hex_layout.get("radius", 1.0)) * radius_scale
	var drawn_edges := {}
	for cell in cells:
		var points := _hex_points(_hex_center(cell, hex_layout), radius)
		for index in range(points.size()):
			var start := points[index]
			var end := points[(index + 1) % points.size()]
			var edge_key := _edge_key(start, end)
			if drawn_edges.has(edge_key):
				continue
			drawn_edges[edge_key] = true
			draw_line(start, end, stroke, width, true)

func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(30.0 + 60.0 * float(index))
		points.append(center + _hex_corner_offset(angle, radius))
	return points

## A hex corner's offset from its centre on the squashed field.
func _hex_corner_offset(angle: float, radius: float) -> Vector2:
	return Vector2(cos(angle) * radius, sin(angle) * radius * HEX_VERTICAL_SCALE)

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed

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

func _edge_key(start: Vector2, end: Vector2) -> String:
	var start_key := _point_grid_key(start)
	var end_key := _point_grid_key(end)
	if start_key.x > end_key.x or (start_key.x == end_key.x and start_key.y > end_key.y):
		var swap_key := start_key
		start_key = end_key
		end_key = swap_key
	return "%d:%d|%d:%d" % [start_key.x, start_key.y, end_key.x, end_key.y]

func _point_grid_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))

func _hex_variation(cell: Vector2i, salt: float) -> float:
	var value := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233 + salt) * 43758.5453
	return value - floor(value)

func _hex_field_rect(field_rect: Rect2) -> Rect2:
	return field_rect

func _hex_layout(hex_field_rect: Rect2) -> Dictionary:
	var radius_x := hex_field_rect.size.x / (SQRT_3 * (float(HEX_COLUMNS) + 0.5))
	var radius_y := hex_field_rect.size.y / ((1.5 * float(HEX_ROWS - 1) + 2.0) * HEX_VERTICAL_SCALE)
	var radius: float = maxf(8.0, minf(radius_x, radius_y))
	var grid_size := Vector2(
		SQRT_3 * radius * (float(HEX_COLUMNS) + 0.5),
		radius * HEX_VERTICAL_SCALE * (1.5 * float(HEX_ROWS - 1) + 2.0)
	)
	var origin := hex_field_rect.position + (hex_field_rect.size - grid_size) * 0.5
	return {
		"origin": origin,
		"radius": radius,
		"hex_width": SQRT_3 * radius,
		"vertical_scale": HEX_VERTICAL_SCALE,
		"grid_size": grid_size,
		"rect": Rect2(origin, grid_size),
	}

func _hex_center(cell: Vector2i, layout: Dictionary) -> Vector2:
	var origin: Vector2 = layout.get("origin", Vector2.ZERO)
	var radius := float(layout.get("radius", 1.0))
	if not _cell_in_bounds(cell):
		# A hero's casts start from its figure (_hero_anchor_cell).
		for side in ["player", "enemy"]:
			if cell == _hero_anchor_cell(side) and _hero_has_figure(side):
				return _hero_foot(side, layout) - Vector2(0.0, HERO_CAST_POINT_RADII * radius)
	var hex_width := float(layout.get("hex_width", SQRT_3 * radius))
	return origin + Vector2(
		hex_width * (float(cell.x) + 0.5 * float(cell.y % 2)) + hex_width * 0.5,
		radius * HEX_VERTICAL_SCALE * (1.5 * float(cell.y) + 1.0)
	)

func _stack_cells() -> Dictionary:
	var cells := {}
	_assign_stack_cells(cells, _visible_stack_list(_player_stacks), "player")
	_assign_stack_cells(cells, _visible_stack_list(_enemy_stacks), "enemy")
	return cells

func _assign_stack_cells(cells: Dictionary, stacks: Array, side: String) -> void:
	for index in range(stacks.size()):
		var stack_value = stacks[index]
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var hex := _stack_hex_cell(stack)
		if hex.x < 0:
			var deployment := BattleRulesScript.default_deployment_hex(side, index, stacks.size(), stack)
			hex = Vector2i(int(deployment.get("q", 0)), int(deployment.get("r", 0)))
		cells[String(stack.get("battle_id", ""))] = hex

func _objective_cell(index: int, objective_type: String) -> Vector2i:
	var cell := _objective_anchor_cell(index, objective_type)
	var blocked := BattleRulesScript.battle_obstacle_cells(_battle)
	if not blocked.has("%d,%d" % [cell.x, cell.y]):
		return cell
	for neighbor in BattleRulesScript._hex_neighbors({"q": cell.x, "r": cell.y}):
		if not blocked.has("%d,%d" % [int(neighbor.q), int(neighbor.r)]):
			return Vector2i(int(neighbor.q), int(neighbor.r))
	return cell

func _objective_anchor_cell(index: int, objective_type: String) -> Vector2i:
	var mid := int(HEX_ROWS / 2)
	var centre := int(HEX_COLUMNS / 2)
	match objective_type:
		"lane_battery":
			return Vector2i(centre, mid - 2 if index % 2 == 0 else mid + 2)
		"cover_line":
			return Vector2i(centre - 1, mid - 1 + (index % 3))
		"obstruction_line":
			return Vector2i(centre, mid)
		"hazard_zone":
			return Vector2i(centre + 1, mid - 1 + (index % 3))
		"signal_beacon":
			return Vector2i(centre, 0 if index % 2 == 0 else HEX_ROWS - 1)
		"breach_point":
			return Vector2i(centre, mid)
		_:
			var defaults := [Vector2i(centre, mid), Vector2i(centre, mid - 1), Vector2i(centre, mid + 1), Vector2i(centre - 1, mid), Vector2i(centre + 1, mid)]
			return defaults[index % defaults.size()]

func _stack_hex_cell(stack: Dictionary) -> Vector2i:
	var hex = stack.get("hex", {})
	if not (hex is Dictionary):
		return Vector2i(-1, -1)
	var cell := Vector2i(int(hex.get("q", -1)), int(hex.get("r", -1)))
	return cell if _cell_in_bounds(cell) else Vector2i(-1, -1)

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

## A hero casts from beside its army: its cast plays half a hex past the
## board's edge on its side, level with the middle row.
func _hero_anchor_cell(side: String) -> Vector2i:
	return Vector2i(-1 if side == "player" else HEX_COLUMNS, int(HEX_ROWS / 2))

## The stacks' cells plus both heroes' anchors, for effects that start at a
## hero or point away from it.
func _actor_cells(stack_cells: Dictionary) -> Dictionary:
	var cells := stack_cells.duplicate()
	for side in ["player", "enemy"]:
		cells[BattleRulesScript.hero_actor_id(side)] = _hero_anchor_cell(side)
	return cells

func _actor_cell_drawable(cell: Vector2i) -> bool:
	return _cell_in_bounds(cell) or cell == _hero_anchor_cell("player") or cell == _hero_anchor_cell("enemy")

func _hex_cell_at_position(position: Vector2) -> Vector2i:
	if _battle.is_empty():
		return Vector2i(-1, -1)
	var hex_layout := _current_hex_layout()
	var radius := float(hex_layout.get("radius", 1.0))
	var best_cell := Vector2i(-1, -1)
	var best_distance := 999999.0
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			if not Geometry2D.is_point_in_polygon(position, _hex_points(center, radius)):
				continue
			var distance := position.distance_to(center)
			if distance < best_distance:
				best_distance = distance
				best_cell = cell
	if best_cell.x >= 0:
		return best_cell

	best_distance = radius * 0.92
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var distance := position.distance_to(_hex_center(cell, hex_layout))
			if distance <= best_distance:
				best_distance = distance
				best_cell = cell
	return best_cell

func _current_hex_layout() -> Dictionary:
	return _hex_layout(_hex_field_rect(_current_field_rect()))

## The middle of the window the hexes fill (FIELD_MARGIN_*).
func _current_field_rect() -> Rect2:
	var k := ui_scale()
	var side := FIELD_MARGIN_SIDE * k
	var top := FIELD_MARGIN_TOP * k
	return Rect2(
		Vector2(side, top),
		Vector2(maxf(1.0, size.x - side * 2.0), maxf(1.0, size.y - top - FIELD_MARGIN_BOTTOM * k))
	)

## The window's size against 1920x1080, for sizes laid out for that window.
## The player's UI scale (Settings) already enlarges the canvas, which makes
## size smaller by that factor; multiplying it back keeps the HUD and ribbon
## as much larger as the setting asks while the field takes the rest.
func ui_scale() -> float:
	var factor := 1.0
	var window := get_window() if is_inside_tree() else null
	if window != null:
		factor = clampf(window.content_scale_factor, 0.5, 3.0)
	return clampf(minf(size.x / FIELD_REFERENCE_SIZE.x, size.y / FIELD_REFERENCE_SIZE.y) * factor, 0.3, 4.0)

func _camera_adjusted_hex_layout(hex_layout: Dictionary) -> Dictionary:
	var adjusted := hex_layout.duplicate(true)
	var offset := _battle_camera_offset_for_records(_camera_playback_records(hex_layout, _stack_cells()))
	if offset.length() <= 0.01:
		return adjusted
	var origin: Vector2 = adjusted.get("origin", Vector2.ZERO)
	adjusted["origin"] = origin + offset
	var rect: Rect2 = adjusted.get("rect", Rect2())
	adjusted["rect"] = Rect2(rect.position + offset, rect.size)
	return adjusted

func _camera_playback_records(hex_layout: Dictionary, stack_cells: Dictionary) -> Array:
	var records: Array = []
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		if cue_record.is_empty() or not stack_cells.has(battle_id):
			continue
		var camera_record := _camera_playback_record_for_cue(cue_record, hex_layout, stack_cells)
		if not camera_record.is_empty():
			records.append(camera_record)
	return records

func _camera_playback_record_for_cue(cue_record: Dictionary, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var battle_id := String(cue_record.get("battle_id", "")).strip_edges()
	if battle_id == "" or not stack_cells.has(battle_id):
		return {}
	var subject_cell: Vector2i = stack_cells.get(battle_id)
	var source_id := String(cue_record.get("source_battle_id", "")).strip_edges()
	if source_id == "":
		source_id = battle_id
	var target_id := String(cue_record.get("target_battle_id", "")).strip_edges()
	if target_id == "":
		target_id = battle_id
	var source_cell: Vector2i = stack_cells.get(source_id, subject_cell)
	var target_cell: Vector2i = stack_cells.get(target_id, subject_cell)
	var from_cell := Vector2i(int(cue_record.get("from_q", -1)), int(cue_record.get("from_r", -1)))
	var to_cell := Vector2i(int(cue_record.get("to_q", -1)), int(cue_record.get("to_r", -1)))
	if _cell_in_bounds(from_cell) and _cell_in_bounds(to_cell):
		source_cell = from_cell
		target_cell = to_cell
	var subject_center := _hex_center(subject_cell, hex_layout)
	var source_center := _hex_center(source_cell, hex_layout)
	var target_center := _hex_center(target_cell, hex_layout)
	var event_id := String(cue_record.get("event_id", ""))
	var focus_kind := _camera_focus_kind_for_event(event_id)
	if focus_kind == "":
		return {}
	var focus := subject_center
	match focus_kind:
		"travel":
			focus = source_center.lerp(target_center, _cue_playback_progress(cue_record))
		"source_target", "spell":
			focus = source_center.lerp(target_center, 0.5)
		"impact", "status", "exit":
			focus = target_center
	var shake_strength := _camera_shake_strength_for_event(event_id)
	var mode := String(cue_record.get("mode", AnimationCueCatalogScript.MODE_NORMAL))
	if mode == AnimationCueCatalogScript.MODE_FAST or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION_FAST:
		shake_strength = 0.0
	else:
		shake_strength *= SettingsService.battle_camera_shake_scale()
	return {
		"battle_id": battle_id,
		"event_id": event_id,
		"serial": int(cue_record.get("serial", 0)),
		"focus_kind": focus_kind,
		"source_battle_id": source_id,
		"target_battle_id": target_id,
		"subject_q": subject_cell.x,
		"subject_r": subject_cell.y,
		"source_q": source_cell.x,
		"source_r": source_cell.y,
		"target_q": target_cell.x,
		"target_r": target_cell.y,
		"focus_x": snappedf(focus.x, 0.01),
		"focus_y": snappedf(focus.y, 0.01),
		"progress": snappedf(_cue_playback_progress(cue_record), 0.001),
		"shake_strength": snappedf(shake_strength, 0.001),
		"mode": mode,
	}

func _camera_focus_kind_for_event(event_id: String) -> String:
	match event_id:
		"battle_unit_move":
			return "travel"
		"battle_unit_ranged_attack", "battle_unit_melee_attack", "battle_retaliation":
			return "source_target"
		"battle_unit_cast":
			return "spell"
		"battle_unit_hit", "battle_unit_death":
			return "impact"
		"battle_status_applied", "battle_status_expired":
			return "status"
		"battle_unit_retreat", "battle_unit_surrender":
			return "exit"
	return ""

func _camera_shake_strength_for_event(event_id: String) -> float:
	match event_id:
		"battle_unit_death":
			return 0.62
		"battle_unit_hit":
			return 0.38
		"battle_unit_melee_attack", "battle_retaliation":
			return 0.24
		"battle_unit_ranged_attack":
			return 0.16
		"battle_unit_cast":
			return 0.12
		"battle_status_applied", "battle_status_expired":
			return 0.10
		"battle_unit_retreat", "battle_unit_surrender":
			return 0.08
	return 0.0

func _battle_camera_offset_for_records(records: Array) -> Vector2:
	if records.is_empty():
		return Vector2.ZERO
	var strongest := {}
	for record in records:
		if not (record is Dictionary):
			continue
		if strongest.is_empty() or float(record.get("shake_strength", 0.0)) > float(strongest.get("shake_strength", 0.0)):
			strongest = record
	if strongest.is_empty():
		return Vector2.ZERO
	var progress := clampf(float(strongest.get("progress", 0.0)), 0.0, 1.0)
	var shake_strength := clampf(float(strongest.get("shake_strength", 0.0)), 0.0, 1.0)
	if shake_strength <= 0.0:
		return Vector2.ZERO
	var decay := 1.0 - progress
	var serial := float(int(strongest.get("serial", 0)))
	var pulse := Vector2(sin(progress * TAU * 2.0 + serial), cos(progress * TAU * 1.5 + serial * 0.61))
	if pulse.length() > 0.0:
		pulse = pulse.normalized()
	var offset := pulse * BATTLE_CAMERA_MAX_OFFSET_PX * shake_strength * decay
	if offset.length() > BATTLE_CAMERA_MAX_OFFSET_PX:
		offset = offset.normalized() * BATTLE_CAMERA_MAX_OFFSET_PX
	return offset

## The board's cached rules queries for the current battle state. A new state
## from set_battle_state() clears them; the hash also catches in-place edits to
## the shared session battle. A draw pass checks it once, other callers
## (input, tooltips, validation) on every call.
func _board_queries() -> Dictionary:
	if not _board_query_in_draw:
		var signature := _battle.hash()
		if signature != _board_query_signature:
			_board_query_signature = signature
			_board_query_cache = {}
	return _board_query_cache

## Read-only: callers share the cached result.
func _board_query(key: String, compute: Callable) -> Variant:
	var cache := _board_queries()
	if not cache.has(key):
		cache[key] = compute.call()
	return cache[key]

func _legal_destinations() -> Array:
	return _board_query("legal_destinations", func(): return BattleRulesScript.legal_destinations_for_active_stack(_battle))

func _movement_range_region() -> Dictionary:
	return _board_query("movement_range_region", func(): return _movement_range_contour_summary(_legal_destinations()))

func _legal_attack_targets(ranged: bool) -> Array:
	return _board_query("legal_ranged_targets" if ranged else "legal_melee_targets", func(): return BattleRulesScript.legal_attack_targets_for_active_stack(_battle, ranged))

func _selected_target_continuity_context() -> Dictionary:
	return _board_query("continuity_context", func(): return BattleRulesScript.selected_target_continuity_context(_battle))

func _is_legal_destination_cell(cell: Vector2i) -> bool:
	if not _cell_in_bounds(cell):
		return false
	var legal_cell_keys: Dictionary = _movement_range_region().get("cell_keys", {})
	return legal_cell_keys.has(_movement_range_cell_key(cell))

func _selected_target_is_blocked() -> bool:
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	if selected_target_id == "" or _battle.is_empty():
		return false
	return bool(_board_query("selected_target_blocked", func(): return bool(BattleRulesScript.selected_target_legality(_battle).get("blocked", false))))

func _target_state_label() -> String:
	return String(_board_query("target_state_label", _resolve_target_state_label))

func _resolve_target_state_label() -> String:
	if _target_stack.is_empty():
		return ""
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		return "Input locked"
	var continuity_context := _selected_target_continuity_context()
	if not continuity_context.is_empty():
		return String(continuity_context.get("footer_label", "Setup target"))
	var closing_context := BattleRulesScript.selected_target_closing_context(_battle, false)
	if not closing_context.is_empty():
		return String(closing_context.get("footer_label", "Closing target"))
	var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, String(_target_stack.get("battle_id", "")))
	var action_label := String(click_intent.get("label", ""))
	if action_label != "":
		return "Click: %s" % action_label
	var legality := BattleRulesScript.selected_target_legality(_battle)
	if bool(legality.get("melee", false)) and bool(legality.get("ranged", false)):
		return "Target: melee/ranged"
	if bool(legality.get("melee", false)):
		return "Target: melee"
	if bool(legality.get("ranged", false)):
		return "Target: ranged"
	if bool(legality.get("blocked", false)):
		return "Target: blocked"
	return ""

func _hover_destination_preview() -> Dictionary:
	if _is_legal_destination_cell(_hover_destination_cell):
		var cell := _hover_destination_cell
		return _board_query("movement_intent:%d,%d" % [cell.x, cell.y], func(): return BattleRulesScript.movement_intent_for_destination(_battle, cell.x, cell.y))
	return {}

func _stack_board_tooltip(battle_id: String) -> String:
	if _spell_target_mode:
		return String(_spell_target_previews.get(battle_id, {}).get("message", "Not a legal target for this spell.")) + "\nSelect to preview; Confirm order casts. Esc cancels."
	var stack := _stack_by_id(battle_id)
	if stack.is_empty():
		return tooltip_text
	var side := String(stack.get("side", ""))
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		if battle_id == String(_battle.get("active_stack_id", "")):
			return "Active: %s. It is not the player's turn." % String(stack.get("name", "Stack"))
		return "%s is %s stack. It is not the player's turn." % [
			String(stack.get("name", "Stack")),
			"a friendly" if side == "player" else "an enemy",
		]
	if String(_active_stack.get("side", "")) == "player" and side == "enemy":
		var continuity_context := _selected_target_continuity_context()
		if not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == battle_id:
			return String(continuity_context.get("message", tooltip_text))
		var closing_context := BattleRulesScript.selected_target_closing_context(_battle, false)
		if not closing_context.is_empty() and String(closing_context.get("battle_id", "")) == battle_id:
			return String(closing_context.get("message", tooltip_text))
		var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, battle_id)
		var message := String(click_intent.get("message", ""))
		if message != "":
			return message
	if battle_id == String(_battle.get("active_stack_id", "")):
		return "Active: %s. Click outlined move hexes to reposition; highlighted enemies show attacks." % String(stack.get("name", "Stack"))
	if side == "player":
		return "%s is a friendly stack." % String(stack.get("name", "Stack"))
	return "%s is an enemy stack." % String(stack.get("name", "Stack"))

func _movement_board_tooltip(cell: Vector2i) -> String:
	var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, cell.x, cell.y)
	var message := String(movement_intent.get("message", ""))
	return message if message != "" else tooltip_text

func _fallback_board_tooltip() -> String:
	if String(_active_stack.get("side", "")) != "" and String(_active_stack.get("side", "")) != "player":
		return "Input locked: it is not the player's turn."
	return tooltip_text

func _unique_target_count(primary: Array, secondary: Array) -> int:
	var seen := {}
	for value in primary:
		seen[String(value)] = true
	for value in secondary:
		seen[String(value)] = true
	return seen.size()

func _stack_id_at_position(position: Vector2) -> String:
	for index in range(_stack_hit_shapes.size() - 1, -1, -1):
		var shape_value = _stack_hit_shapes[index]
		if not (shape_value is Dictionary):
			continue
		var shape: Dictionary = shape_value
		var center: Vector2 = shape.get("center", Vector2.ZERO)
		var radius := float(shape.get("radius", 0.0))
		if position.distance_to(center) <= radius:
			return String(shape.get("battle_id", ""))
	return ""

## The stack whose drawn figure covers position, front-most first.
func _stack_body_at_position(position: Vector2) -> String:
	for index in range(_stack_hit_shapes.size() - 1, -1, -1):
		var shape_value = _stack_hit_shapes[index]
		if shape_value is Dictionary and Rect2(shape_value.get("body_rect", Rect2())).has_point(position):
			return String(shape_value.get("battle_id", ""))
	return ""

## The stack a pointer at position points at: the one standing on the hex
## under it, else one whose figure covers it. Off the hexes the old round
## token shapes still count.
func _stack_id_at_board_position(position: Vector2, cell: Vector2i) -> String:
	var battle_id := _stack_id_at_cell(cell)
	if battle_id == "":
		battle_id = _stack_body_at_position(position)
	if battle_id == "" and not _cell_in_bounds(cell):
		battle_id = _stack_id_at_position(position)
	return battle_id

## The box over a stack's drawn figure that a click on it hits: up from its
## feet, as wide as its body.
func _stack_body_rect(center: Vector2, radius: float, stack: Dictionary) -> Rect2:
	var hex_width := SQRT_3 * radius
	var half_width := hex_width * (0.7 if BattleRulesScript.Footprint.width(stack) == 2 else 0.28)
	var ground_y := center.y + radius * STACK_STANDEE_GROUND_OFFSET_FACTOR
	var height := _stack_standee_size(radius, stack).y * 0.72
	return Rect2(Vector2(center.x - half_width, ground_y - height), Vector2(half_width * 2.0, height))

func _stack_token_radius(hex_radius: float) -> float:
	return clampf(hex_radius * STACK_TOKEN_RADIUS_FACTOR, STACK_TOKEN_RADIUS_MIN, STACK_TOKEN_RADIUS_MAX)

func _stack_hit_shape_radius(hex_radius: float) -> float:
	return clampf(hex_radius * STACK_HIT_RADIUS_FACTOR, STACK_HIT_RADIUS_MIN, STACK_HIT_RADIUS_MAX) + STACK_HIT_RADIUS_PADDING

func _neighboring_stack_hit_shape_overlap_possible(hex_radius: float) -> bool:
	return _stack_hit_shape_radius(hex_radius) >= cos(deg_to_rad(30.0)) * hex_radius

func _stack_id_at_cell(cell: Vector2i) -> String:
	if not _cell_in_bounds(cell):
		return ""
	var occupied := BattleRulesScript.battle_occupancy_map(_battle)
	var body_id := String(occupied.get("%d,%d" % [cell.x, cell.y], ""))
	if body_id != "": return body_id
	var stack_cells := _stack_cells()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "":
			continue
		var stack_cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		if stack_cell == cell:
			return battle_id
	return ""

func _stack_cell_for_battle_id(battle_id: String) -> Vector2i:
	if battle_id == "":
		return Vector2i(-1, -1)
	var stack_cells := _stack_cells()
	return stack_cells.get(battle_id, Vector2i(-1, -1))

func _validation_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var fallback_position := center
	var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 30.0, 90.0, 150.0, 210.0, 270.0, 330.0]
	for factor in [0.91, 0.86, 0.80, 0.72, 0.64, 0.56, 0.48]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			fallback_position = position
			if _stack_id_at_position(position) == "":
				return {
					"position": position,
					"found_shape_miss_position": true,
					"hex_radius": radius,
				}
	return {
		"position": fallback_position,
		"found_shape_miss_position": false,
		"hex_radius": radius,
	}

func _validation_outer_ring_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var angles := []
	for angle_index in range(24):
		angles.append(float(angle_index) * 15.0)
	for factor in [0.995, 0.99, 0.985, 0.98, 0.975, 0.97, 0.965, 0.96, 0.955, 0.95, 0.945, 0.94, 0.935, 0.93]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if position.distance_to(center) <= radius * 0.92:
				continue
			if _hex_cell_at_position(position) != cell:
				continue
			if _stack_id_at_position(position) != "":
				continue
			return {
				"position": position,
				"found_outer_ring_position": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
	return {}

func _validation_overlapped_destination_click_position_for_cell(cell: Vector2i, overlap_side: String = "player") -> Dictionary:
	if not _is_legal_destination_cell(cell):
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	var active_id := String(_battle.get("active_stack_id", ""))
	if active_id != "" and overlap_side == "player":
		candidate_ids.append(active_id)
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id in candidate_ids:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "":
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_overlapped_occupied_hex_click_position_for_cell(cell: Vector2i, overlap_side: String = "enemy") -> Dictionary:
	var cell_battle_id := _stack_id_at_cell(cell)
	if cell_battle_id == "":
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id == cell_battle_id:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "" or overlap_id == cell_battle_id:
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_fallback_tooltip_position() -> Vector2:
	var candidates := [
		Vector2(4.0, 4.0),
		Vector2(maxf(4.0, size.x - 4.0), 4.0),
		Vector2(4.0, maxf(4.0, size.y - 4.0)),
		Vector2(maxf(4.0, size.x - 4.0), maxf(4.0, size.y - 4.0)),
		Vector2(size.x * 0.5, 20.0),
		Vector2(size.x * 0.5, maxf(20.0, size.y - 20.0)),
	]
	for position in candidates:
		if position.x < 0.0 or position.y < 0.0 or position.x > size.x or position.y > size.y:
			continue
		if _hex_cell_at_position(position).x >= 0:
			continue
		if _stack_id_at_position(position) != "":
			continue
		return position
	return Vector2(-1.0, -1.0)

func _all_visible_stacks() -> Array:
	var stacks := []
	stacks.append_array(_visible_stack_list(_player_stacks))
	stacks.append_array(_visible_stack_list(_enemy_stacks))
	return stacks

func _visible_stack_list(source_stacks: Array) -> Array:
	var stacks := []
	for stack in source_stacks:
		if stack is Dictionary and _stack_visible_for_presentation(stack):
			stacks.append(stack)
	return stacks

func _stack_visible_for_presentation(stack: Dictionary) -> bool:
	if _stack_alive_count(stack) > 0:
		return true
	return not _animation_playback_record_for_stack(String(stack.get("battle_id", ""))).is_empty()

func _stack_has_cell(battle_id: String, stack_cells: Dictionary) -> bool:
	if battle_id == "" or not stack_cells.has(battle_id):
		return false
	var cell: Vector2i = stack_cells.get(battle_id)
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

func _stack_by_id(battle_id: String) -> Dictionary:
	for stack in _battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _stack_alive_count(stack: Dictionary) -> int:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var total_health: int = maxi(0, int(stack.get("total_health", 0)))
	if total_health <= 0:
		return 0
	return int(ceil(float(total_health) / float(unit_hp)))

func _stack_full_name(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack"))).strip_edges()
	return name if name != "" else "Stack"

func _side_color(side: String) -> Color:
	var fallback := PLAYER_COLOR if side == "player" else ENEMY_COLOR
	return FrontierVisualKitScript.semantic_color(side, fallback)

func _controller_color(controller: String) -> Color:
	match controller:
		"player":
			return FrontierVisualKitScript.semantic_color("player", PLAYER_COLOR)
		"enemy":
			return FrontierVisualKitScript.semantic_color("enemy", ENEMY_COLOR)
		_:
			return FrontierVisualKitScript.semantic_color("neutral", NEUTRAL_COLOR)

func _distance_label(distance: int) -> String:
	match clampi(distance, 0, 2):
		0:
			return "Engaged"
		1:
			return "Closing"
		_:
			return "Long lane"

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, position - Vector2(text_size.x * 0.5, text_size.y * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


# --- Pointer hover -----------------------------------------------------------

## What the pointer is over outside the order preview: a hero, a ribbon chip
## or a stack. The forecast beside the pointer and the highlights follow it.
func _update_pointer_hover(position: Vector2) -> void:
	var hero_side := _hero_side_at_position(position)
	var chip := _turn_ribbon_chip_at_position(position)
	var chip_stack: Dictionary = chip.get("stack", {}) if chip.get("stack", {}) is Dictionary else {}
	var ribbon_id := String(chip_stack.get("battle_id", ""))
	var stack_id := ""
	if hero_side == "" and not _ribbon_rect().has_point(position):
		stack_id = _stack_id_at_board_position(position, _hex_cell_at_position(position))
	_hover_hero_side = hero_side
	_hover_ribbon_battle_id = ribbon_id
	_hover_stack_id = stack_id
	# The forecast follows the pointer.
	queue_redraw()

func _on_pointer_left() -> void:
	_pointer_position = Vector2(-1.0, -1.0)
	_hover_hero_side = ""
	_hover_ribbon_battle_id = ""
	_hover_stack_id = ""
	_details_hint_subject = ""
	if not _keyboard_cursor_shown():
		_hover_destination_cell = Vector2i(-1, -1)
		_hover_order = {}
		set_consequence_preview({})
	_apply_field_cursor_shape()
	queue_redraw()

## The board draws its own forecast beside the pointer, so the delayed hover
## card stays away from the field; F1 still inspects the same text.
func _make_custom_tooltip(_for_text: String) -> Object:
	var hidden := Control.new()
	hidden.hide()
	return hidden

# --- Details under the right button -------------------------------------------

## What the right button shows at a point: a hero, a ribbon chip's stack or a
## stack on the field, with the rect its card stands beside ({} for none).
func _details_subject_at_position(position: Vector2) -> Dictionary:
	if _battle.is_empty():
		return {}
	var hero_side := _hero_side_at_position(position)
	if hero_side != "":
		return {"kind": "hero", "id": hero_side, "anchor": Rect2(hero_figure_layout(hero_side).get("hit_rect", Rect2()))}
	var chip := _turn_ribbon_chip_at_position(position)
	var chip_stack: Dictionary = chip.get("stack", {}) if chip.get("stack", {}) is Dictionary else {}
	if not chip_stack.is_empty():
		return {"kind": "chip", "id": String(chip_stack.get("battle_id", "")), "anchor": Rect2(chip.get("rect", Rect2()))}
	if _ribbon_rect().has_point(position):
		return {}
	var stack_id := _stack_id_at_board_position(position, _hex_cell_at_position(position))
	if stack_id == "":
		return {}
	return {"kind": "stack", "id": stack_id, "anchor": _stack_anchor_rect(stack_id)}

## The box over a stack's figure, from the plates last drawn, with its plate.
func _stack_anchor_rect(battle_id: String) -> Rect2:
	for shape in _stack_hit_shapes:
		if shape is Dictionary and String(shape.get("battle_id", "")) == battle_id:
			var body: Rect2 = shape.get("body_rect", Rect2())
			var record: Dictionary = _stack_plate_records.get(battle_id, {})
			return body.merge(Rect2(record.get("rect", body))) if not record.is_empty() else body
	var cell := _stack_hex_cell(_stack_by_id(battle_id))
	if not _cell_in_bounds(cell):
		return Rect2()
	var layout := _current_hex_layout()
	var radius := float(layout.get("radius", 1.0))
	return Rect2(_hex_center(cell, layout) - Vector2(radius, radius), Vector2(radius, radius) * 2.0)

## The screen shows the details card for a stack or a hero while the right
## button is held ({"kind": "stack" or "hero", "id"}; "" closes it): the
## drawn cursor and the forecast step aside and the stack's plate is ringed.
func set_details_subject(kind: String, id: String) -> void:
	var subject := {} if kind == "" else {"kind": kind, "id": id}
	if subject == _details_subject:
		return
	_details_subject = subject
	_apply_field_cursor_shape()
	queue_redraw()

func details_subject() -> Dictionary:
	return _details_subject.duplicate()

## The turn ribbon's box along the top edge, which the details card keeps below.
func turn_ribbon_rect() -> Rect2:
	return _ribbon_rect()

## The icon an effect shows on plates and cards: a status's badge art, else
## its spell's icon. "" when it has neither.
func effect_icon_path(effect_id: String, spell_id: String = "") -> String:
	var spec := _battle_status_effect_art_spec(effect_id)
	if not spec.is_empty():
		return String(spec.get("path", ""))
	var spell_icon := SpellRules.spell_icon_path(spell_id) if spell_id != "" else ""
	return spell_icon if spell_icon != "" and ResourceLoader.exists(spell_icon) else ""

## Counts the hovers the details hint names: a ribbon chip, a hero, or a
## stack the cursor gives no order for.
func _note_details_hint_subject() -> void:
	var subject := ""
	if _hover_ribbon_battle_id != "":
		subject = "chip:" + _hover_ribbon_battle_id
	elif _hover_hero_side != "":
		subject = "hero:" + _hover_hero_side
	elif String(_hover_order.get("kind", "")) == "info":
		subject = "stack:" + String(_hover_order.get("target_id", ""))
	if subject == _details_hint_subject:
		return
	_details_hint_subject = subject
	if subject != "":
		_details_hint_hovers += 1
	queue_redraw()

func _details_hint_shown() -> bool:
	if _details_hint_subject == "":
		return false
	return _details_hint_subject == "hero:enemy" or _details_hint_hovers <= DETAILS_HINT_HOVERS

# --- Heroes beside their armies ---------------------------------------------

func _hero_presentation_for(side: String) -> Dictionary:
	var value: Variant = _hero_presentations.get(side, {})
	return value if value is Dictionary else {}

func _hero_has_figure(side: String) -> bool:
	return bool(_hero_presentation_for(side).get("has_figure", false))

## Where a hero stands: beside its army's edge, a quarter of the way down the
## field, clear of the hexes.
func _hero_foot(side: String, layout: Dictionary) -> Vector2:
	var grid: Rect2 = layout.get("rect", Rect2())
	var radius := float(layout.get("radius", 1.0))
	var x := grid.position.x - HERO_FOOT_OUTSET_RADII * radius
	if side != "player":
		x = grid.end.x + HERO_FOOT_OUTSET_RADII * radius
	return Vector2(x, grid.position.y + grid.size.y * HERO_FOOT_GRID_FRACTION)

func _hero_hit_rect(foot: Vector2, radius: float) -> Rect2:
	var half_width := HERO_HIT_HALF_WIDTH_RADII * radius
	return Rect2(
		foot - Vector2(half_width, HERO_HIT_TOP_RADII * radius),
		Vector2(half_width * 2.0, (HERO_HIT_TOP_RADII + HERO_HIT_BOTTOM_RADII) * radius)
	)

func _hero_side_at_position(position: Vector2) -> String:
	if _battle.is_empty():
		return ""
	var layout := _current_hex_layout()
	var radius := float(layout.get("radius", 1.0))
	for side in ["player", "enemy"]:
		if _hero_has_figure(side) and _hero_hit_rect(_hero_foot(side, layout), radius).has_point(position):
			return side
	return ""

func _hero_figure_texture(side: String) -> Texture2D:
	var path := String(_hero_presentation_for(side).get("figure_path", ""))
	if path == "":
		return null
	if not _hero_figure_textures.has(path):
		var loaded: Variant = load(path) if ResourceLoader.exists(path) else null
		_hero_figure_textures[path] = loaded if loaded is Texture2D else null
	return _hero_figure_textures.get(path) as Texture2D

## How strongly a hero's cast still shows: 1 as it starts, 0 once it ends.
func _hero_cast_intensity(side: String) -> float:
	var record := _animation_playback_record_for_stack(BattleRulesScript.hero_actor_id(side))
	if record.is_empty():
		return 0.0
	var started := int(record.get("started_at_msec", 0))
	var expires := int(record.get("expires_at_msec", started))
	var now := int(Time.get_ticks_msec())
	if now < started:
		return 0.0
	if expires <= started:
		return 1.0
	return clampf(1.0 - float(now - started) / float(expires - started), 0.0, 1.0)

## Both commanders stand beside their armies; the right-hand one is mirrored
## to face the field. The player's glows while its spell is ready, and a
## casting hero rises a little and flares.
func _draw_hero_figures(hex_layout: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var k := radius / REFERENCE_HEX_RADIUS
	var motion := not SettingsService.reduced_motion_enabled()
	var msec := float(Time.get_ticks_msec())
	for side: String in ["player", "enemy"]:
		if not _hero_has_figure(side):
			continue
		var texture := _hero_figure_texture(side)
		if texture == null:
			continue
		var foot := _hero_foot(side, hex_layout)
		var cast := _hero_cast_intensity(side)
		var hovered := _hover_hero_side == side
		draw_texture_rect(_soft_glow(), Rect2(foot - Vector2(84.0, 17.0) * k, Vector2(168.0, 34.0) * k), false, Color(0.0, 0.0, 0.0, 0.55))
		var glow := 0.0
		if cast > 0.0:
			glow = 0.55 * cast + 0.2
		elif side == "player" and _hero_cast_ready:
			glow = 0.16 + (0.1 * sin(msec / 420.0) if motion else 0.0) + (0.14 if hovered else 0.0)
		elif hovered:
			glow = 0.14
		if glow > 0.0:
			var tint := HERO_READY_GLOW if side == "player" else UI_ENEMY.lightened(0.35)
			draw_texture_rect(_soft_glow(), Rect2(foot - Vector2(100.0, 34.0) * k, Vector2(200.0, 60.0) * k), false, Color(tint.r, tint.g, tint.b, glow))
		var scale := HERO_FIGURE_CANVAS_RADII * radius / maxf(1.0, texture.get_size().y)
		var bob := sin(msec / 900.0 + (1.7 if side == "enemy" else 0.0)) * 0.006 if motion else 0.0
		var anchor := BattleHeroFigureScript.foot_anchor(texture)
		draw_set_transform(foot - Vector2(0.0, cast * 7.0 * k), 0.0, Vector2(_hero_facing(side) * scale, scale * (1.0 + bob)))
		draw_texture(texture, -anchor)
		if cast > 0.0 or hovered:
			draw_texture(texture, -anchor, Color(1.6, 1.5, 1.3, 0.35 * cast if cast > 0.0 else 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A hero's place on the board, for the screen's plates: its feet, its
## clickable box and whether it is drawn.
func hero_figure_layout(side: String) -> Dictionary:
	if _battle.is_empty():
		return {}
	var layout := _current_hex_layout()
	var radius := float(layout.get("radius", 1.0))
	var foot := _hero_foot(side, layout)
	return {
		"side": side,
		"has_figure": _hero_has_figure(side),
		"figure_path": String(_hero_presentation_for(side).get("figure_path", "")),
		"foot": foot,
		"hit_rect": _hero_hit_rect(foot, radius),
		"hex_radius": radius,
		"grid_rect": Rect2(layout.get("rect", Rect2())),
		"facing": _hero_facing(side),
	}

## The figures are painted facing right; the enemy's hero is mirrored to face
## the field from the right.
func _hero_facing(side: String) -> float:
	return -1.0 if side == "enemy" else 1.0

## The player's hero glows while it can cast this turn.
func set_hero_cast_ready(ready: bool) -> void:
	if ready != _hero_cast_ready:
		_hero_cast_ready = ready
		queue_redraw()

func hero_presentation(side: String) -> Dictionary:
	return _hero_presentation_for(side).duplicate(true)

func _hero_status_line(hero: Dictionary) -> String:
	if bool(hero.get("cast_this_round", false)):
		return "Spell cast this round"
	if int(hero.get("battle_spell_count", 0)) <= 0:
		return "Knows no battle spells"
	return "Can cast one spell this round"

func _hero_tooltip(side: String) -> String:
	var hero := _hero_presentation_for(side)
	if hero.is_empty():
		return ""
	var lines := PackedStringArray([String(hero.get("name", "Commander"))])
	var role := String(hero.get("role", "")).strip_edges()
	if role != "":
		lines.append(role)
	lines.append("Mana %d/%d" % [int(hero.get("mana_current", 0)), int(hero.get("mana_max", 0))])
	lines.append(_hero_status_line(hero))
	if side == "player":
		lines.append("Click: spellbook. One spell per round; the stack keeps its turn.")
	return "\n".join(lines)

# --- Turn ribbon ---------------------------------------------------------------

func _ribbon_rect() -> Rect2:
	return Rect2(_turn_ribbon_layout().get("rect", Rect2()))

## The living stacks of one phase of the turn-order forecast.
func _forecast_stacks(phase: String) -> Array:
	var stacks: Array = []
	var ids: Variant = _turn_forecast.get(phase, [])
	if ids is Array:
		for battle_id in ids:
			var stack := _stack_by_id(String(battle_id))
			if not stack.is_empty() and _stack_alive_count(stack) > 0:
				stacks.append(stack)
	return stacks

## The ribbon along the top edge: the round, the active stack's large chip,
## the rest of this round, the waiting stacks after an hourglass, then the
## next round's predicted order. What does not fit is left off, and the
## ribbon fades out on the right.
func _turn_ribbon_layout() -> Dictionary:
	if _battle.is_empty() or _field_final:
		return {}
	var cache_key := str(size)
	if _ribbon_cache_key == cache_key:
		return _ribbon_cache
	var k := ui_scale()
	var round_number := maxi(1, int(_turn_forecast.get("round", _battle.get("round", 1))))
	var items: Array = [{"kind": "round", "width": 46.0 * k, "value": round_number}]
	var active_id := ""
	if not _active_stack.is_empty() and _stack_alive_count(_active_stack) > 0:
		active_id = String(_active_stack.get("battle_id", ""))
		items.append({"kind": "chip", "phase": "active", "stack": _active_stack, "width": RIBBON_ACTIVE_CHIP * k, "margin": 6.0 * k})
	for stack in _forecast_stacks("current"):
		if String(stack.get("battle_id", "")) != active_id:
			items.append({"kind": "chip", "phase": "current", "stack": stack, "width": RIBBON_CHIP * k})
	var waiting: Array = []
	for stack in _forecast_stacks("waiting"):
		if String(stack.get("battle_id", "")) != active_id:
			waiting.append(stack)
	if not waiting.is_empty():
		items.append({"kind": "wait_mark", "width": 29.0 * k, "height": 44.0 * k})
		for stack in waiting:
			items.append({"kind": "chip", "phase": "waiting", "stack": stack, "width": RIBBON_CHIP * k})
	if active_id != "":
		items.append({"kind": "round_mark", "width": 58.0 * k, "height": 50.0 * k, "value": round_number + 1})
		for stack in _forecast_stacks("next_round"):
			items.append({"kind": "chip", "phase": "next_round", "stack": stack, "width": RIBBON_NEXT_CHIP * k})
	var padding := RIBBON_PADDING_SIDE * k
	var gap := RIBBON_GAP * k
	var max_width := minf(RIBBON_MAX_WIDTH * k, size.x - 24.0 * k)
	var content_width := 0.0
	var fitted: Array = []
	var overflow := false
	for item in items:
		var needed := float(item.get("width", 0.0)) + float(item.get("margin", 0.0)) + (gap if not fitted.is_empty() else 0.0)
		if padding * 2.0 + content_width + needed > max_width:
			overflow = true
			break
		content_width += needed
		fitted.append(item)
	var tallest := (RIBBON_ACTIVE_CHIP if active_id != "" else RIBBON_CHIP) * k
	var rect := Rect2(
		Vector2((size.x - content_width - padding * 2.0) * 0.5, 0.0),
		Vector2(content_width + padding * 2.0, (RIBBON_PADDING_TOP + RIBBON_PADDING_BOTTOM) * k + tallest)
	)
	var center_y := RIBBON_PADDING_TOP * k + tallest * 0.5
	var x := rect.position.x + padding
	var entries: Array = []
	var slot := 0
	var previous_phase := ""
	for item in fitted:
		if not entries.is_empty():
			x += gap
		var entry: Dictionary = item.duplicate()
		var item_width := float(item.get("width", 0.0))
		var chip := String(item.get("kind", "")) == "chip"
		var item_height := item_width if chip else float(item.get("height", tallest))
		entry["rect"] = Rect2(Vector2(x, center_y - item_height * 0.5), Vector2(item_width, item_height))
		if chip:
			slot += 1
			entry["slot"] = slot
			var phase := String(item.get("phase", ""))
			entry["first_of_phase"] = phase != previous_phase
			previous_phase = phase
		entries.append(entry)
		x += item_width + float(item.get("margin", 0.0))
	_ribbon_cache = {"rect": rect, "entries": entries, "overflow": overflow, "scale": k}
	_ribbon_cache_key = cache_key
	return _ribbon_cache

func _turn_ribbon_chips() -> Array:
	var chips: Array = []
	for entry in _turn_ribbon_layout().get("entries", []):
		if String(entry.get("kind", "")) == "chip":
			chips.append(entry)
	return chips

func _draw_turn_ribbon() -> void:
	var layout := _turn_ribbon_layout()
	if layout.is_empty():
		return
	var k := float(layout.get("scale", ui_scale()))
	var rect: Rect2 = layout.get("rect", Rect2())
	if _ribbon_style == null:
		_ribbon_style = StyleBoxFlat.new()
		_ribbon_style.anti_aliasing = true
		_ribbon_style.bg_color = RIBBON_FILL
		_ribbon_style.border_color = UI_GOLD_DIM
		_ribbon_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		_ribbon_style.border_width_top = 0
	var line := maxi(1, int(round(k)))
	_ribbon_style.border_width_left = line
	_ribbon_style.border_width_right = line
	_ribbon_style.border_width_bottom = line
	_ribbon_style.corner_radius_bottom_left = int(round(16.0 * k))
	_ribbon_style.corner_radius_bottom_right = int(round(16.0 * k))
	_ribbon_style.shadow_size = int(round(9.0 * k))
	_ribbon_style.shadow_offset = Vector2(0.0, 6.0 * k)
	draw_style_box(_ribbon_style, rect)
	var overflow := bool(layout.get("overflow", false))
	var fade_width := maxf(1.0, rect.size.x * 0.07)
	var highlight_id := _hover_ribbon_battle_id if _hover_ribbon_battle_id != "" else _hover_stack_id
	for entry in layout.get("entries", []):
		var entry_rect: Rect2 = entry.get("rect", Rect2())
		var alpha := 1.0
		if overflow:
			alpha = clampf((rect.end.x - entry_rect.get_center().x) / fade_width, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		match String(entry.get("kind", "")):
			"round", "round_mark":
				_draw_ribbon_round_mark(entry, k, alpha)
			"wait_mark":
				_draw_ribbon_wait_mark(entry, k, alpha)
			"chip":
				var stack: Dictionary = entry.get("stack", {})
				_draw_ribbon_chip(entry, k, alpha, highlight_id != "" and String(stack.get("battle_id", "")) == highlight_id)

func _draw_ribbon_round_mark(entry: Dictionary, k: float, alpha: float) -> void:
	var rect: Rect2 = entry.get("rect", Rect2())
	var separator := String(entry.get("kind", "")) == "round_mark"
	if separator:
		var faint := Color(UI_GOLD_FAINT, UI_GOLD_FAINT.a * alpha)
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), faint, maxf(1.0, k))
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, faint, maxf(1.0, k))
	var center := rect.get_center()
	_draw_centered_label("ROUND", center - Vector2(0.0, 9.0 * k), Color(UI_MUTED if separator else UI_GOLD, alpha), int(round(10.0 * k)))
	_draw_centered_label(str(int(entry.get("value", 1))), center + Vector2(0.0, 8.0 * k), Color(Color(0.863, 0.784, 0.604) if separator else UI_GOLD_HI, alpha), int(round(21.0 * k)))

func _draw_ribbon_wait_mark(entry: Dictionary, k: float, alpha: float) -> void:
	var rect: Rect2 = entry.get("rect", Rect2())
	draw_dashed_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(UI_GOLD_DIM, UI_GOLD_DIM.a * alpha), maxf(1.0, k), 3.0 * k)
	_draw_hourglass_glyph(Vector2(rect.position.x + 17.5 * k, rect.get_center().y), 17.0 * k, Color(0.914, 0.843, 0.678, alpha))

## One stack on the ribbon: its unit in a ring of its side's colour (gold for
## the active stack), its count below, a bow or sword badge, and an hourglass
## badge while it waits. The next round's chips are smaller and dimmer.
func _draw_ribbon_chip(entry: Dictionary, k: float, alpha: float, highlighted: bool) -> void:
	var rect: Rect2 = entry.get("rect", Rect2())
	var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
	var phase := String(entry.get("phase", "current"))
	var active := phase == "active"
	var next_round := phase == "next_round"
	if next_round:
		alpha *= 0.78
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	var player := String(stack.get("side", "")) == "player"
	var ring_width := (3.0 if active else 2.0) * k
	draw_texture_rect(_soft_glow(), Rect2(center - Vector2(radius, radius) * 1.25 + Vector2(0.0, 2.0 * k), Vector2(radius, radius) * 2.5), false, Color(0.0, 0.0, 0.0, 0.5 * alpha))
	if active:
		draw_texture_rect(_soft_glow(), Rect2(center - Vector2(radius, radius) * 1.5, Vector2(radius, radius) * 3.0), false, Color(UI_ACTIVE, 0.45 * alpha))
	draw_circle(center, radius, Color(0.086, 0.071, 0.047, alpha))
	var texture := _unit_battle_icon_for_stack(stack)
	if texture != null:
		_draw_circle_texture(texture, center, radius - ring_width * 0.5, Color(1.0, 1.0, 1.0, alpha))
	else:
		_draw_role_glyph(center, radius, bool(stack.get("ranged", false)), Color(UI_CREAM, alpha))
	var ring := UI_ACTIVE if active else (UI_PLAYER if player else UI_ENEMY)
	draw_arc(center, radius - ring_width * 0.5, 0.0, TAU, 48, Color(ring, alpha), ring_width, true)
	if highlighted:
		draw_arc(center, radius + 1.5 * k, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.95 * alpha), 3.0 * k, true)
	var font := get_theme_default_font()
	if font != null:
		var font_size := int(round((13.0 if active else (11.0 if next_round else 12.0)) * k))
		var count_text := str(_stack_alive_count(stack))
		var text_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var pill_height := float(font_size) * 1.15 + 4.0 * k
		var pill_width := maxf((18.0 if next_round else 22.0) * k, text_width + (10.0 if next_round else 12.0) * k)
		var pill_bottom := rect.end.y + (6.0 if next_round else 7.0) * k
		var pill := Rect2(Vector2(center.x - pill_width * 0.5, pill_bottom - pill_height), Vector2(pill_width, pill_height))
		_draw_rounded_box(pill, Color(UI_PLAYER_DEEP if player else UI_ENEMY_DEEP, alpha), Color(UI_PLAYER if player else UI_ENEMY, alpha), 8.0 * k, maxf(1.0, k))
		_draw_centered_label(count_text, pill.get_center(), Color(1.0, 1.0, 1.0, alpha), font_size)
	var badge := (16.0 if next_round else 19.0) * k
	var badge_center := Vector2(rect.end.x + (5.0 if next_round else 4.0) * k - badge * 0.5, rect.position.y - (4.0 if next_round else 3.0) * k + badge * 0.5)
	_draw_ribbon_badge(badge_center, badge, k, alpha)
	_draw_role_glyph(badge_center, (10.0 if next_round else 12.0) * k, bool(stack.get("ranged", false)), Color(0.965, 0.886, 0.706, alpha))
	if not next_round and BattleRulesScript.stack_has_waited(_battle, String(stack.get("battle_id", ""))):
		var wait_center := Vector2(rect.position.x - 4.0 * k + badge * 0.5, rect.position.y - 3.0 * k + badge * 0.5)
		_draw_ribbon_badge(wait_center, badge, k, alpha)
		_draw_hourglass_glyph(wait_center, 12.0 * k, Color(0.965, 0.886, 0.706, alpha))

func _draw_ribbon_badge(center: Vector2, extent: float, k: float, alpha: float) -> void:
	draw_circle(center, extent * 0.5, Color(0.086, 0.071, 0.047, alpha))
	draw_arc(center, extent * 0.5, 0.0, TAU, 24, Color(UI_GOLD_DIM, UI_GOLD_DIM.a * alpha), maxf(1.0, k), true)

## A texture cut to a circle.
func _draw_circle_texture(texture: Texture2D, center: Vector2, radius: float, modulate: Color) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in range(36):
		var direction := Vector2.from_angle(TAU * float(index) / 36.0)
		points.append(center + direction * radius)
		uvs.append(Vector2(0.5, 0.5) + direction * 0.5)
	draw_colored_polygon(points, modulate, uvs, texture)

# --- Glyphs and boxes -------------------------------------------------------

## A sword for melee stacks, a bow with an arrow for ranged ones.
func _draw_role_glyph(center: Vector2, extent: float, ranged: bool, color: Color) -> void:
	BattleGlyphsScript.draw_role(self, center, extent, ranged, color)

func _draw_hourglass_glyph(center: Vector2, extent: float, color: Color) -> void:
	BattleGlyphsScript.draw_hourglass(self, center, extent, color)

func _draw_rounded_box(rect: Rect2, fill: Color, border: Color, radius: float, border_width: float) -> void:
	if _box_style == null:
		_box_style = StyleBoxFlat.new()
		_box_style.anti_aliasing = true
	_box_style.bg_color = fill
	_box_style.draw_center = fill.a > 0.0
	_box_style.border_color = border
	_box_style.set_border_width_all(maxi(0, int(round(border_width))))
	_box_style.set_corner_radius_all(maxi(0, int(round(radius))))
	draw_style_box(_box_style, rect)

## Text centred on a point, both ways.
func _draw_centered_label(text: String, center: Vector2, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	if font == null or text == "":
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

# --- Forecast beside the pointer --------------------------------------------

## Where the forecast hangs: beside the pointer, or beside the keyboard
## cursor's hex while keys steer the board. (-1, -1) for nowhere.
func _forecast_anchor() -> Vector2:
	if _keyboard_cursor_shown() and _cell_in_bounds(_controller_cursor_cell):
		return _hex_center(_controller_cursor_cell, _current_hex_layout())
	return _pointer_position

## What the forecast says, one line each ({"text", "detail", "tone", "role",
## "icon"}; see _draw_hover_forecast): a hovered chip's or hero's summary, a
## stack's identity when no order applies to it, else what the order under
## the cursor does (the attack's kills, damage, strike-back and walk or
## shots; the spell's effect), else why it is refused. A move says nothing:
## its path shows on the field.
func _hover_forecast() -> Array:
	var lines: Array = []
	if _battle.is_empty() or _battle.has("playback_event"):
		return lines
	var focused := _keyboard_cursor_shown() and _cell_in_bounds(_controller_cursor_cell)
	if not focused and _pointer_position.x < 0.0:
		return lines
	if not focused and _hover_ribbon_battle_id != "":
		var chip_stack := _stack_by_id(_hover_ribbon_battle_id)
		if not chip_stack.is_empty():
			lines.append({"text": "%s ×%d" % [_stack_full_name(chip_stack), _stack_alive_count(chip_stack)]})
			lines.append({"text": _ribbon_phase_text(_hover_ribbon_battle_id), "role": "note"})
			_append_details_hint(lines)
		return lines
	if not focused and _hover_hero_side != "":
		var hero := _hero_presentation_for(_hover_hero_side)
		lines.append({"text": String(hero.get("name", "Commander")), "icon": "book" if _hover_hero_side == "player" and not bool(hero.get("cast_this_round", false)) else ""})
		if _hover_hero_side == "player":
			lines.append({"text": "Already cast a spell this round" if bool(hero.get("cast_this_round", false)) else "Click: spellbook · one spell per round, the stack keeps its turn", "role": "note"})
		else:
			lines.append({"text": "Mana %d/%d · %s" % [int(hero.get("mana_current", 0)), int(hero.get("mana_max", 0)), _hero_status_line(hero)], "role": "note"})
		_append_details_hint(lines)
		return lines
	var preview: Dictionary = _hover_order.get("preview", {})
	var kind := String(_hover_order.get("kind", ""))
	match kind:
		"info":
			var stack := _stack_by_id(String(_hover_order.get("target_id", "")))
			if not stack.is_empty():
				lines.append({"text": "%s ×%d" % [_stack_full_name(stack), _stack_alive_count(stack)]})
				lines.append({"text": "%s · %s" % ["Your stack" if String(stack.get("side", "")) == "player" else "Enemy stack", "Ranged" if bool(stack.get("ranged", false)) else "Melee"], "role": "note"})
				if not focused:
					_append_details_hint(lines)
		"strike", "shoot", "spell":
			if not bool(preview.get("ok", false)):
				var refusal := String(preview.get("message", "")).strip_edges().get_slice("\n", 0)
				if refusal != "":
					lines.append({"text": refusal, "role": "note"})
				return lines
			for value in preview.get("forecast_lines", []):
				if value is Dictionary:
					lines.append((value as Dictionary).duplicate())
			if lines.is_empty():
				return lines
			lines[0]["icon"] = "sword" if kind == "strike" else ("arrow" if kind == "shoot" else "spark")
			var last: Dictionary = lines.back()
			if kind == "strike" and (_hover_order.get("approaches", []) as Array).size() > 1:
				last["detail"] = "· point at another side, or turn it with Q and E"
			elif kind == "shoot" and bool(preview.get("penalised", false)) and bool(_hover_order.get("can_strike", false)):
				last["detail"] = "· hold Ctrl to strike in melee"
		"blocked":
			var reason := String(_hover_order.get("reason", "")).strip_edges()
			if reason != "":
				lines.append({"text": reason, "role": "note"})
	return lines

## The first hovers say how to see the details (DETAILS_HINT_HOVERS).
func _append_details_hint(lines: Array) -> void:
	if _details_hint_shown():
		lines.append({"text": DETAILS_HINT_TEXT, "role": "note"})

## The forecast as plain lines, for checks and the screen reader.
func _hover_forecast_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _hover_forecast():
		lines.append(BattleRulesScript.forecast_text([line]))
	return lines

func _ribbon_phase_text(battle_id: String) -> String:
	if battle_id == String(_battle.get("active_stack_id", "")):
		return "Acting now"
	for phase in ["current", "waiting", "next_round"]:
		var ids: Variant = _turn_forecast.get(phase, [])
		if ids is Array and (ids as Array).has(battle_id):
			match phase:
				"current":
					return "Acts later this round"
				"waiting":
					return "Waiting: acts at the end of the round, slowest first"
				_:
					return "Next round (predicted)"
	return ""

## The forecast's role per line when it names none: the headline, the main
## consequence, then notes.
func _forecast_line_role(line: Dictionary, index: int) -> String:
	var role := String(line.get("role", ""))
	if role != "":
		return role
	return "head" if index == 0 else ("main" if index == 1 else "note")

## The badge beside the cursor: a headline (with the order's icon and its
## detail in small type), the main consequence coloured by its tone (red for
## losses, green for none, amber for a warning), then muted notes.
func _draw_hover_forecast() -> void:
	if not _details_subject.is_empty():
		return
	var lines := _hover_forecast()
	if lines.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var anchor := _forecast_anchor()
	if anchor.x < 0.0:
		return
	var k := ui_scale()
	var rows: Array = []
	var width := 0.0
	var height := 0.0
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		var role := _forecast_line_role(line, index)
		var text_size := (19.0 if role == "head" else (14.0 if role == "main" else 12.5)) * k
		var font_size := int(round(text_size))
		var detail_size := int(round(13.5 * k)) if role == "head" else font_size
		var text := String(line.get("text", ""))
		var detail := String(line.get("detail", ""))
		var icon := String(line.get("icon", ""))
		var icon_width := 24.0 * k if icon != "" else 0.0
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var detail_width := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, detail_size).x if detail != "" else 0.0
		var row_width := icon_width + text_width + (7.0 * k + detail_width if detail != "" else 0.0)
		var row_height := float(font_size) * 1.2 + ((3.0 if role == "main" else 2.0) * k if index > 0 else 0.0)
		rows.append({"line": line, "role": role, "font_size": font_size, "detail_size": detail_size, "icon_width": icon_width, "text_width": text_width, "height": row_height})
		width = maxf(width, row_width)
		height += row_height
	var box_size := Vector2(width + 21.0 * k, height + 15.0 * k)
	var position := anchor + Vector2(30.0, 26.0) * k
	if position.x + box_size.x > size.x - 12.0 * k:
		position.x = anchor.x - box_size.x - 30.0 * k
	var bottom_limit := size.y - 92.0 * k
	if position.y + box_size.y > bottom_limit:
		position.y = anchor.y - box_size.y - 22.0 * k
	var top_limit := _ribbon_rect().end.y + 6.0 * k
	position.x = clampf(position.x, 12.0 * k, maxf(12.0 * k, size.x - box_size.x - 12.0 * k))
	position.y = clampf(position.y, top_limit, maxf(top_limit, bottom_limit - box_size.y))
	var box := Rect2(position, box_size)
	if _forecast_style == null:
		_forecast_style = StyleBoxFlat.new()
		_forecast_style.anti_aliasing = true
		_forecast_style.bg_color = UI_PANEL
		_forecast_style.border_color = UI_GOLD_DIM
		_forecast_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_forecast_style.set_border_width_all(maxi(1, int(round(k))))
	_forecast_style.set_corner_radius_all(int(round(9.0 * k)))
	_forecast_style.shadow_size = int(round(8.0 * k))
	_forecast_style.shadow_offset = Vector2(0.0, 6.0 * k)
	draw_style_box(_forecast_style, box)
	var y := position.y + 7.0 * k
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var line: Dictionary = row.get("line", {})
		var role := String(row.get("role", "note"))
		var font_size := int(row.get("font_size", 12))
		if index > 0:
			y += (3.0 if role == "main" else 2.0) * k
		var baseline := y + font.get_ascent(font_size)
		var x := position.x + 10.0 * k
		var icon := String(line.get("icon", ""))
		if icon != "":
			_draw_forecast_icon(icon, Vector2(x + 8.5 * k, y + float(font_size) * 0.6), 17.0 * k)
			x += float(row.get("icon_width", 0.0))
		var color := _forecast_tone_color(String(line.get("tone", "")), role)
		draw_string(font, Vector2(x, baseline), String(line.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
		var detail := String(line.get("detail", ""))
		if detail != "":
			draw_string(font, Vector2(x + float(row.get("text_width", 0.0)) + 7.0 * k, baseline), detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(row.get("detail_size", font_size)), UI_MUTED)
		y += float(font_size) * 1.2

## A forecast line's colour: the headline gold, the main line by its tone
## (red unless it says otherwise), notes muted unless amber.
func _forecast_tone_color(tone: String, role: String) -> Color:
	match tone:
		"green":
			return FORECAST_GOOD
		"amber":
			return FORECAST_WARN
		"red":
			return FORECAST_LOSS
		"muted":
			return UI_MUTED
	if role == "head":
		return FORECAST_HEAD
	return FORECAST_LOSS if role == "main" else UI_MUTED

func _draw_forecast_icon(icon: String, center: Vector2, extent: float) -> void:
	var tint := Color(0.965, 0.886, 0.706)
	match icon:
		"sword":
			_draw_role_glyph(center, extent, false, tint)
		"arrow":
			_draw_role_glyph(center, extent, true, tint)
		"spark":
			draw_colored_polygon(_spark_points(center, extent * 0.5), tint)
		"book":
			var half := extent * 0.42
			var spine := Vector2(center.x, center.y - half * 0.7)
			draw_polyline(PackedVector2Array([spine, center + Vector2(-half, -half * 0.85), center + Vector2(-half, half * 0.75), center + Vector2(0.0, half * 0.95)]), tint, maxf(1.0, extent * 0.09), true)
			draw_polyline(PackedVector2Array([spine, center + Vector2(half, -half * 0.85), center + Vector2(half, half * 0.75), center + Vector2(0.0, half * 0.95)]), tint, maxf(1.0, extent * 0.09), true)
			draw_line(spine, center + Vector2(0.0, half * 0.95), tint, maxf(1.0, extent * 0.07), true)

func _spark_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(8):
		var reach := radius if index % 2 == 0 else radius * 0.3
		points.append(center + Vector2.from_angle(-PI * 0.5 + PI * 0.25 * float(index)) * reach)
	return points

# --- Orders and the field cursor -------------------------------------------------

## What a click at position, or Enter on the keyboard cursor (focused), orders
## now, and the cursor that shows it. kind is "strike", "shoot", "move",
## "spell", "blocked" (refused; reason says why), "info" (a stack no order
## applies to), "hero", or "" for none: the scenery, the ribbon, a playback,
## empty ground on the enemy's turn. cursor names the glyph drawn at the
## pointer (FIELD_CURSOR_GLYPHS, or "info" beside the system pointer). A
## strike carries the hex it is made from (approach), every hex it could be
## made from in clockwise order (approaches) and the sector the pointer chose
## it in; force_strike (Ctrl) makes a shooter strike instead when it can.
func _resolve_order(position: Vector2, focused: bool, force_strike: bool = false) -> Dictionary:
	var order := {"kind": "", "cursor": "", "target_id": "", "cell": Vector2i(-1, -1), "preview": {}, "approach": {}, "approaches": [], "sector": "", "angle": 0.0, "reason": "", "can_strike": false}
	if _battle.is_empty() or _battle.has("playback_event") or _field_final:
		return order
	if not focused:
		if position.x < 0.0 or _ribbon_rect().has_point(position):
			return order
		if _hero_side_at_position(position) != "":
			order["kind"] = "hero"
			return order
	var cell := _controller_cursor_cell if focused else _hex_cell_at_position(position)
	var target_id := _stack_id_at_cell(cell) if focused else _stack_id_at_board_position(position, cell)
	order["cell"] = cell
	order["target_id"] = target_id
	if target_id == "" and not _cell_in_bounds(cell):
		return order
	if String(_active_stack.get("side", "")) != "player":
		if target_id != "":
			_set_order_kind(order, "info", "info")
		return order
	if _spell_target_mode:
		var spell_preview: Dictionary = _spell_target_previews.get(target_id, {}) if target_id != "" else {}
		if target_id != "" and _spell_target_candidates.has(target_id) and bool(spell_preview.get("ok", false)):
			_set_order_kind(order, "spell", "spark")
			order["preview"] = spell_preview
		else:
			_set_order_kind(order, "blocked", "blocked")
			order["reason"] = "Not a target for this spell" if target_id != "" else "Choose a highlighted stack"
		return order
	if target_id == "":
		if _is_legal_destination_cell(cell):
			_set_order_kind(order, "move", "boot")
			order["preview"] = _move_preview(cell)
		else:
			_set_order_kind(order, "blocked", "blocked")
			order["reason"] = _blocked_hex_reason(cell)
		return order
	var stack := _stack_by_id(target_id)
	if String(stack.get("side", "")) != "enemy":
		_set_order_kind(order, "info", "info")
		return order
	var intent: Dictionary = _board_query("click_intent:" + target_id, func(): return BattleRulesScript.board_click_attack_intent_for_target(_battle, target_id))
	var approaches: Array = _board_query("approaches:" + target_id, func(): return BattleRulesScript.melee_approach_cells(_battle, _active_stack, stack))
	var action := String(intent.get("action", ""))
	order["can_strike"] = not approaches.is_empty()
	if force_strike and action == "shoot" and not approaches.is_empty():
		action = "strike"
	if action == "":
		_set_order_kind(order, "blocked", "blocked")
		order["reason"] = _blocked_target_reason()
		return order
	var layout := _current_hex_layout()
	var line_of_attack := _stack_rest_center(stack, layout) - _stack_rest_center(_active_stack, layout)
	if action == "shoot":
		var shot := BattleRulesScript.attack_consequence_preview(_battle, "shoot", target_id)
		_set_order_kind(order, "shoot", "broken_arrow" if bool(shot.get("penalised", false)) else "arrow")
		order["preview"] = shot
		order["angle"] = line_of_attack.angle()
		return order
	var clockwise := _approaches_clockwise(approaches, stack, layout)
	var choice := _choose_approach(clockwise, approaches, stack, layout, position, focused)
	var entry: Dictionary = choice.get("entry", {})
	_set_order_kind(order, "strike", "sword")
	order["approaches"] = clockwise
	order["approach"] = entry
	order["sector"] = String(choice.get("sector", ""))
	order["preview"] = BattleRulesScript.attack_consequence_preview(_battle, "strike", target_id, {"q": int(entry.get("q", -1)), "r": int(entry.get("r", -1))} if not entry.is_empty() else {})
	order["angle"] = float(entry.get("strike_angle", line_of_attack.angle()))
	return order

func _set_order_kind(order: Dictionary, kind: String, cursor: String) -> void:
	order["kind"] = kind
	order["cursor"] = cursor

## What makes one order differ from another for the forecast.
func _order_key(order: Dictionary) -> String:
	var approach: Dictionary = order.get("approach", {})
	return "%s|%s|%s|%s" % [String(order.get("kind", "")), String(order.get("target_id", "")), str(order.get("cell", Vector2i(-1, -1))), "" if approach.is_empty() else BattleRulesScript._hex_key(approach)]

## A move to an empty hex: where it ends and the hexes it walks through.
func _move_preview(cell: Vector2i) -> Dictionary:
	return _board_query("move_preview:%d,%d" % [cell.x, cell.y], func():
		var destination := {"q": cell.x, "r": cell.y}
		var path: Array = []
		for step in BattleRulesScript._presentation_walk_path(_battle, BattleRulesScript._stack_hex(_active_stack), destination):
			path.append({"q": int(step.get("q", -1)), "r": int(step.get("r", -1))})
		return {"ok": true, "action": "move", "destination": destination, "steps": maxi(0, path.size() - 1), "path": path,
			"message": "Move → %s\nMovement only — no attack. Enemy choices are not predicted." % BattleRulesScript._hex_label(destination)})

## Why the active stack cannot go to an empty hex, in a few words.
func _blocked_hex_reason(cell: Vector2i) -> String:
	if BattleRulesScript.battle_obstacle_cells(_battle).has("%d,%d" % [cell.x, cell.y]):
		return "Blocked by an obstacle"
	if BattleRulesScript._stack_is_rooted(_active_stack, _battle):
		return "Rooted: cannot move"
	if _legal_destinations().is_empty():
		return "%s cannot move this turn" % _stack_full_name(_active_stack)
	return "Out of reach this turn"

## Why the active stack cannot attack the enemy under the cursor.
func _blocked_target_reason() -> String:
	if BattleRulesScript._stack_is_rooted(_active_stack, _battle):
		return "Rooted: cannot move"
	if bool(_active_stack.get("ranged", false)) and int(_active_stack.get("shots_remaining", 0)) <= 0:
		return "No shots left, and out of reach this turn"
	return "Out of reach this turn"

## Where a stack's body stands while it is still: its hex, or the middle of
## its two hexes.
func _stack_rest_center(stack: Dictionary, layout: Dictionary) -> Vector2:
	var cell := _stack_hex_cell(stack)
	return _hex_center(cell, layout) + _body_center_offset(stack, cell, layout)

## A screen direction with the field's vertical squash taken out, so the six
## sides of a hex lie sixty degrees apart.
func _unsquashed(direction: Vector2) -> Vector2:
	return Vector2(direction.x, direction.y / HEX_VERTICAL_SCALE)

func _nearest_cell_center(cells: Array, point: Vector2, layout: Dictionary) -> Vector2:
	var nearest := point
	var best := INF
	for cell in cells:
		var center := _hex_center(Vector2i(int(cell.get("q", -1)), int(cell.get("r", -1))), layout)
		if center.distance_squared_to(point) < best:
			best = center.distance_squared_to(point)
			nearest = center
	return nearest

## The hexes a strike on target can be made from (melee_approach_cells), each
## with the direction it comes from around the target (angle, unsquashed) and
## the direction its blow lands in on screen (strike_angle), clockwise.
func _approaches_clockwise(approaches: Array, target: Dictionary, layout: Dictionary) -> Array:
	var middle := _stack_rest_center(target, layout)
	var body: Array = BattleRulesScript.Footprint.cells(target)
	var entries: Array = []
	for index in range(approaches.size()):
		var entry: Dictionary = (approaches[index] as Dictionary).duplicate()
		var strike := _hex_center(Vector2i(int(entry.get("strike_q", -1)), int(entry.get("strike_r", -1))), layout)
		entry["angle"] = _unsquashed(strike - middle).angle()
		entry["strike_angle"] = (_nearest_cell_center(body, strike, layout) - strike).angle()
		entry["rank"] = index
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.get("angle", 0.0)), float(b.get("angle", 0.0))):
			return float(a.get("angle", 0.0)) < float(b.get("angle", 0.0))
		return int(a.get("rank", 0)) < int(b.get("rank", 0)))
	return entries

func _approach_with_key(entries: Array, key: String) -> Dictionary:
	for entry in entries:
		if BattleRulesScript._hex_key(entry) == key:
			return entry
	return {}

## The side a strike on target comes from: the hex on the side the pointer
## points to, seen from the target's hex under it (or nearest it), or the
## nearest hex (where the stack stands, else the fewest steps) while the
## pointer is on that hex's middle or keys steer. A turn made with Q or E
## holds while the pointer stays in the sector it was made in.
func _choose_approach(clockwise: Array, approaches: Array, target: Dictionary, layout: Dictionary, position: Vector2, focused: bool) -> Dictionary:
	if clockwise.is_empty():
		return {"entry": {}, "sector": ""}
	var nearest_key := ""
	var fewest := 1 << 30
	for entry in approaches:
		if int(entry.get("steps", 0)) < fewest:
			fewest = int(entry.get("steps", 0))
			nearest_key = BattleRulesScript._hex_key(entry)
	var chosen := _approach_with_key(clockwise, nearest_key)
	var sector := "keys" if focused else "middle"
	if not focused:
		var hovered := _hovered_body_cell_center(target, position, layout)
		var pointer := _unsquashed(position - hovered)
		if pointer.length() > APPROACH_NEUTRAL_SHARE * float(layout.get("radius", 1.0)):
			var best_gap := INF
			for entry in clockwise:
				var strike := _hex_center(Vector2i(int(entry.get("strike_q", -1)), int(entry.get("strike_r", -1))), layout)
				var gap := absf(angle_difference(pointer.angle(), _unsquashed(strike - hovered).angle()))
				if gap < best_gap - 0.0001:
					best_gap = gap
					chosen = entry
			sector = BattleRulesScript._hex_key(chosen)
	var held := _approach_choice
	if String(held.get("target_id", "")) == String(target.get("battle_id", "")) and String(held.get("active_id", "")) == String(_active_stack.get("battle_id", "")) and String(held.get("sector", "")) == sector:
		var turned := _approach_with_key(clockwise, "%d,%d" % [int(held.get("q", -1)), int(held.get("r", -1))])
		if not turned.is_empty():
			chosen = turned
	return {"entry": chosen, "sector": sector}

## The centre of the target's hex under the pointer, or of the one nearest it
## while the pointer is on the target's figure above another hex.
func _hovered_body_cell_center(target: Dictionary, position: Vector2, layout: Dictionary) -> Vector2:
	var pointer_cell := _hex_cell_at_position(position)
	var body: Array = BattleRulesScript.Footprint.cells(target)
	for body_cell in body:
		if Vector2i(int(body_cell.get("q", -1)), int(body_cell.get("r", -1))) == pointer_cell:
			return _hex_center(pointer_cell, layout)
	return _nearest_cell_center(body, position, layout)

## Turns the side the enemy under the cursor is struck from: E (1) clockwise,
## Q (-1) the other way, around the hexes the strike can be made from. False
## when no strike with a choice of sides is under the cursor.
func cycle_approach(direction: int) -> bool:
	if String(_hover_order.get("kind", "")) != "strike":
		return false
	var approaches: Array = _hover_order.get("approaches", [])
	if approaches.size() < 2:
		return false
	var current := BattleRulesScript._hex_key(_hover_order.get("approach", {}))
	var index := 0
	for slot in range(approaches.size()):
		if BattleRulesScript._hex_key(approaches[slot]) == current:
			index = slot
			break
	var turned: Dictionary = approaches[posmod(index + direction, approaches.size())]
	_approach_choice = {
		"active_id": String(_active_stack.get("battle_id", "")),
		"target_id": String(_hover_order.get("target_id", "")),
		"sector": String(_hover_order.get("sector", "")),
		"q": int(turned.get("q", -1)),
		"r": int(turned.get("r", -1)),
	}
	_refresh_hover_order()
	return true

## The order under the cursor, for checks: its kind, cursor, target, the hex
## a strike is made from and the ones it could turn to, and the forecast.
func validation_pointer_order() -> Dictionary:
	var approaches: Array = []
	for entry in _hover_order.get("approaches", []):
		approaches.append({"q": int(entry.get("q", -1)), "r": int(entry.get("r", -1)), "steps": int(entry.get("steps", 0)), "angle": float(entry.get("angle", 0.0))})
	var approach: Dictionary = _hover_order.get("approach", {})
	return {
		"kind": String(_hover_order.get("kind", "")),
		"cursor": String(_hover_order.get("cursor", "")),
		"target_id": String(_hover_order.get("target_id", "")),
		"approach": {} if approach.is_empty() else {"q": int(approach.get("q", -1)), "r": int(approach.get("r", -1)), "steps": int(approach.get("steps", 0))},
		"approaches": approaches,
		"sector": String(_hover_order.get("sector", "")),
		"angle": float(_hover_order.get("angle", 0.0)),
		"reason": String(_hover_order.get("reason", "")),
		"preview": (_hover_order.get("preview", {}) as Dictionary).duplicate(true),
		"forecast": _hover_forecast_lines(),
		"cursor_shape": mouse_default_cursor_shape,
		"strike_forced": _strike_forced,
	}

## The system cursor hides where the board draws its own glyph, points at the
## player's hero, and is the plain arrow elsewhere.
func _apply_field_cursor_shape() -> void:
	var shape := Control.CURSOR_ARROW
	# The plain pointer while keys steer the board or a details card is open.
	var pointer_led := not _keyboard_cursor_shown() and _details_subject.is_empty()
	if pointer_led and String(_hover_order.get("cursor", "")) in FIELD_CURSOR_GLYPHS:
		shape = FIELD_CURSOR_SHAPE
	elif pointer_led and _hover_hero_side == "player":
		shape = Control.CURSOR_POINTING_HAND
	if mouse_default_cursor_shape != shape:
		mouse_default_cursor_shape = shape

## The walk an order makes, on the ground under the stacks: dots on the hexes
## it passes, and a ring where it ends.
func _draw_order_path(hex_layout: Dictionary) -> void:
	var kind := String(_hover_order.get("kind", ""))
	if kind not in ["strike", "move"] or _battle.has("playback_event"):
		return
	var preview: Dictionary = _hover_order.get("preview", {})
	if not bool(preview.get("ok", false)):
		return
	var radius := float(hex_layout.get("radius", 20.0))
	var path: Array = preview.get("path", [])
	for index in range(1, path.size() - 1):
		var step: Dictionary = path[index]
		var center := _hex_center(Vector2i(int(step.get("q", -1)), int(step.get("r", -1))), hex_layout)
		draw_circle(center + Vector2(0.0, radius * 0.03), radius * 0.1, Color(0.0, 0.0, 0.0, 0.45))
		draw_circle(center, radius * 0.08, APPROACH_PATH_DOT)
	var end := _order_end_cell()
	if not _cell_in_bounds(end):
		return
	for body_cell in BattleRulesScript.Footprint.cells(_active_stack, {"q": end.x, "r": end.y}):
		draw_arc(_hex_center(Vector2i(int(body_cell.q), int(body_cell.r)), hex_layout), radius * 0.88, 0.0, TAU, 32, Color(ACTIVE_COLOR, 0.85), maxf(2.0, radius * 0.035), true)

## Where the order under the cursor leaves the active stack when it walks:
## the hex a move ends on, or the one a strike is made from. (-1, -1) when
## the stack stays where it is.
func _order_end_cell() -> Vector2i:
	var preview: Dictionary = _hover_order.get("preview", {})
	match String(_hover_order.get("kind", "")):
		"move":
			var destination: Dictionary = preview.get("destination", {})
			return Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
		"strike":
			if int(preview.get("steps", 0)) > 0:
				var approach: Dictionary = preview.get("approach", {})
				return Vector2i(int(approach.get("q", -1)), int(approach.get("r", -1)))
	return Vector2i(-1, -1)

## Where the stack will stand to strike, for _draw_stack_tokens to draw its
## faded ghost among the stacks: {"center"} or {} when it strikes in place.
func _strike_ghost(hex_layout: Dictionary) -> Dictionary:
	if String(_hover_order.get("kind", "")) != "strike" or _battle.has("playback_event"):
		return {}
	var end := _order_end_cell()
	if not _cell_in_bounds(end):
		return {}
	return {"center": _hex_center(end, hex_layout) + _body_center_offset(_active_stack, end, hex_layout)}

## The board's own cursor, over everything: a sword turned the way the blow
## lands, an arrow (broken for a point-blank shot) toward the target, a boot
## for a move, a spark for a spell, a barred circle for a refused order, and
## a small info badge beside the system pointer over a stack.
func _draw_field_cursor() -> void:
	var glyph := String(_hover_order.get("cursor", ""))
	if glyph == "" or _battle.has("playback_event") or not _details_subject.is_empty():
		return
	var anchor := _forecast_anchor()
	if anchor.x < 0.0:
		return
	var k := maxf(0.7, ui_scale())
	if glyph == "info":
		if _keyboard_cursor_shown():
			return
		var badge := anchor + Vector2(23.0, 26.0) * k
		draw_circle(badge, 7.65 * k, Color(0.114, 0.239, 0.431))
		draw_arc(badge, 7.65 * k, 0.0, TAU, 24, Color(0.906, 0.949, 1.0), maxf(1.0, 1.4 * k), true)
		draw_circle(badge - Vector2(0.0, 3.4 * k), 1.3 * k, Color.WHITE)
		draw_line(badge - Vector2(0.0, 0.9 * k), badge + Vector2(0.0, 4.1 * k), Color.WHITE, maxf(1.0, 2.0 * k), true)
		return
	if glyph not in FIELD_CURSOR_GLYPHS:
		return
	var turn := 0.0
	match glyph:
		"sword":
			turn = float(_hover_order.get("angle", 0.0)) + PI * 0.5
		"arrow", "broken_arrow":
			turn = float(_hover_order.get("angle", 0.0))
	# The glyphs are drawn on a 48-unit square centred on the pointer.
	draw_set_transform(anchor + Vector2(0.0, 2.0 * k), turn, Vector2(k, k))
	_draw_cursor_glyph(glyph, true)
	draw_set_transform(anchor, turn, Vector2(k, k))
	_draw_cursor_glyph(glyph, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One cursor glyph in its 48-unit square around the origin: shadow draws the
## dark silhouette under it.
func _draw_cursor_glyph(glyph: String, shadow: bool) -> void:
	var ink := Color(0.0, 0.0, 0.0, 0.45) if shadow else FIELD_CURSOR_OUTLINE
	match glyph:
		"sword":
			var blade := PackedVector2Array([Vector2(0.0, -21.5), Vector2(4.6, -15.0), Vector2(4.6, 6.0), Vector2(-4.6, 6.0), Vector2(-4.6, -15.0)])
			_draw_glyph_shape(blade, FIELD_CURSOR_BLADE, ink, 2.2, shadow)
			if not shadow:
				draw_line(Vector2(0.0, -17.0), Vector2(0.0, 5.0), Color(0.663, 0.639, 0.592), 1.3, true)
			_draw_glyph_shape(_rounded_bar(Vector2(-11.5, 6.0), Vector2(11.5, 10.4)), UI_GOLD, ink, 2.0, shadow)
			_draw_glyph_shape(PackedVector2Array([Vector2(-2.4, 10.4), Vector2(2.4, 10.4), Vector2(2.4, 17.8), Vector2(-2.4, 17.8)]), Color(0.482, 0.29, 0.141), ink, 2.0, shadow)
			_draw_glyph_disc(Vector2(0.0, 20.0), 3.0, UI_GOLD, ink, 2.0, shadow)
		"arrow", "broken_arrow":
			var broken := glyph == "broken_arrow"
			var shaft: Array = [[Vector2(-18.0, 0.0), Vector2(-8.0, 0.0)], [Vector2(-1.0, 0.0), Vector2(10.0, 0.0)]] if broken else [[Vector2(-18.0, 0.0), Vector2(10.0, 0.0)]]
			for part in shaft:
				draw_line(part[0], part[1], ink, 6.5, true)
				if not shadow:
					draw_line(part[0], part[1], Color(0.937, 0.863, 0.682), 3.0, true)
			if broken:
				var crack := PackedVector2Array([Vector2(-6.5, -6.5), Vector2(-4.0, -1.5), Vector2(-6.0, 1.5), Vector2(-3.0, 7.0)])
				draw_polyline(crack, ink, 4.5, true)
				if not shadow:
					draw_polyline(crack, Color(1.0, 0.541, 0.361), 2.0, true)
			_draw_glyph_shape(PackedVector2Array([Vector2(7.0, -9.5), Vector2(21.0, 0.0), Vector2(7.0, 9.5), Vector2(10.0, 0.0)]), Color(0.965, 0.949, 0.918), ink, 2.0, shadow)
			var fletches: Array = [[Vector2(-21.0, -7.0), Vector2(-16.0, 0.0), Vector2(-21.0, 7.0)]] if broken else [[Vector2(-21.0, -7.0), Vector2(-13.5, 0.0), Vector2(-21.0, 7.0)], [Vector2(-15.0, -7.0), Vector2(-7.5, 0.0), Vector2(-15.0, 7.0)]]
			for fletch in fletches:
				var points := PackedVector2Array(fletch)
				draw_polyline(points, ink, 5.0, true)
				if not shadow:
					draw_polyline(points, Color(0.894, 0.416, 0.333), 2.4, true)
		"boot":
			var boot := PackedVector2Array([Vector2(-9.0, -18.0), Vector2(2.0, -18.0), Vector2(2.0, 1.5), Vector2(12.8, 5.9), Vector2(15.2, 6.9), Vector2(16.5, 9.0), Vector2(16.5, 15.0), Vector2(-11.5, 15.0), Vector2(-11.5, 1.5)])
			_draw_glyph_shape(boot, Color(0.918, 0.843, 0.659), ink, 2.4, shadow)
			_draw_glyph_shape(PackedVector2Array([Vector2(-11.5, 15.0), Vector2(16.5, 15.0), Vector2(16.5, 19.5), Vector2(-11.5, 19.5)]), Color(0.482, 0.29, 0.141), ink, 2.2, shadow)
			if not shadow:
				var crease := Color(FIELD_CURSOR_OUTLINE, 0.5)
				draw_line(Vector2(-9.0, -12.0), Vector2(2.0, -12.0), crease, 1.6, true)
				draw_line(Vector2(2.0, 1.5), Vector2(-1.5, 5.5), crease, 1.6, true)
		"spark":
			var star := PackedVector2Array([Vector2(0.0, -21.0), Vector2(4.2, -6.4), Vector2(19.0, 0.0), Vector2(4.2, 6.4), Vector2(0.0, 21.0), Vector2(-4.2, 6.4), Vector2(-19.0, 0.0), Vector2(-4.2, -6.4)])
			_draw_glyph_shape(star, Color(0.898, 0.604, 0.227), ink, 2.2, shadow)
			if not shadow:
				var inner := PackedVector2Array()
				for point in star:
					inner.append(point * 0.62)
				draw_colored_polygon(inner, Color(1.0, 0.878, 0.541))
				var core := PackedVector2Array()
				for point in star:
					core.append(point * 0.3)
				draw_colored_polygon(core, Color.WHITE)
			_draw_glyph_disc(Vector2(14.0, -15.0), 3.2, Color(0.749, 0.878, 1.0), ink, 1.6, shadow)
		"blocked":
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 40, ink, 8.0, true)
			draw_line(Vector2(-9.5, 9.5), Vector2(9.5, -9.5), ink, 8.0, true)
			if not shadow:
				draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 40, FIELD_CURSOR_BLOCKED, 4.4, true)
				draw_line(Vector2(-9.5, 9.5), Vector2(9.5, -9.5), FIELD_CURSOR_BLOCKED, 4.4, true)

## A filled glyph part with a dark outline; as shadow, its silhouette only.
func _draw_glyph_shape(points: PackedVector2Array, fill: Color, ink: Color, outline: float, shadow: bool) -> void:
	if shadow:
		draw_colored_polygon(points, ink)
		draw_polyline(_closed_points(points), ink, outline, true)
		return
	draw_colored_polygon(points, fill)
	draw_polyline(_closed_points(points), ink, outline, true)

func _draw_glyph_disc(center: Vector2, radius: float, fill: Color, ink: Color, outline: float, shadow: bool) -> void:
	draw_circle(center, radius, ink if shadow else fill)
	draw_arc(center, radius, 0.0, TAU, 20, ink, outline, true)

## A bar from top_left to bottom_right with round ends.
func _rounded_bar(top_left: Vector2, bottom_right: Vector2) -> PackedVector2Array:
	var radius := (bottom_right.y - top_left.y) * 0.5
	var middle_y := (top_left.y + bottom_right.y) * 0.5
	var points := PackedVector2Array()
	for index in range(7):
		points.append(Vector2(bottom_right.x - radius, middle_y) + Vector2.from_angle(-PI * 0.5 + PI * float(index) / 6.0) * radius)
	for index in range(7):
		points.append(Vector2(top_left.x + radius, middle_y) + Vector2.from_angle(PI * 0.5 + PI * float(index) / 6.0) * radius)
	return points
