class_name MapEditorShell
extends Control

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const TerrainPlacementRulesScript = preload("res://scripts/core/TerrainPlacementRules.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const DEFAULT_TERRAIN_ID := "grass"
const EDITOR_ROAD_LAYER_ID := "editor_working_road"
const EDITOR_ROAD_OVERLAY_ID := "road_dirt"
const TERRAIN_LINE_RULE_ID := "manhattan_l_horizontal_then_vertical"
const TERRAIN_LINE_RULE_LABEL := "Manhattan L line, horizontal first, then vertical"
const TERRAIN_RECTANGLE_RULE_ID := "inclusive_axis_aligned_corners"
const TERRAIN_RECTANGLE_RULE_LABEL := "Inclusive axis-aligned rectangle between corner tiles"
const TERRAIN_RECTANGLE_TILE_ORDER := "row_major_top_left_to_bottom_right"
const TERRAIN_OPTION_CONTRACT := "homm3_base_family_picker"
const TERRAIN_OPTION_SOURCE := "editor_base_terrain_options"
const TERRAIN_PLACEMENT_MODEL := "homm3_owner_queue_rewrite_final_normalization.v1"
const ROAD_PATH_RULE_ID := "manhattan_l_horizontal_then_vertical"
const ROAD_PATH_RULE_LABEL := "Manhattan L path, horizontal first, then vertical"
const TOOL_INSPECT := "inspect"
const TOOL_TERRAIN := "terrain"
const TOOL_TERRAIN_LINE := "terrain_line"
const TOOL_TERRAIN_RECTANGLE := "terrain_rectangle"
const TOOL_ROAD := "road"
const TOOL_ROAD_PATH := "road_path"
const TOOL_HERO_START := "hero_start"
const TOOL_PLACE_OBJECT := "place_object"
const TOOL_REMOVE_OBJECT := "remove_object"
const TOOL_MOVE_OBJECT := "move_object"
const TOOL_DUPLICATE_OBJECT := "duplicate_object"
const TOOL_RETHEME_OBJECT := "retheme_object"
const OBJECT_FAMILY_TOWN := "town"
const OBJECT_FAMILY_RESOURCE := "resource"
const OBJECT_FAMILY_ARTIFACT := "artifact"
const OBJECT_FAMILY_ENCOUNTER := "encounter"
const DEFAULT_OBJECT_FAMILY := OBJECT_FAMILY_RESOURCE
const EDITOR_DENSITY_REGION_SIZE := 16
const PROPERTY_TOWN_OWNER := "owner"
const PROPERTY_ENCOUNTER_DIFFICULTY := "difficulty"
const PROPERTY_COLLECTED := "collected"
const TOWN_OWNER_OPTIONS := ["neutral", "player", "enemy"]
const ENCOUNTER_DIFFICULTY_OPTIONS := ["low", "medium", "high", "pressure", "scripted"]
const PLACEMENT_DEBUG_OVERLAY_TOGGLE_KEY := KEY_F4
const DIRTY_TRANSITION_MENU := "menu"
const DIRTY_TRANSITION_PACKAGE := "package"
const DIRTY_TRANSITION_QUIT := "quit"
const DIRTY_TRANSITION_CANCEL_TEXT := "Keep Editing"
const DIRTY_TRANSITION_QUIT_SOURCE := "map_editor_confirmed"
const DIRTY_TRANSITION_PENDING_MESSAGE := "Finish the current unsaved-work confirmation first."
const EDITOR_MAP_JOYPAD_REPEAT_INITIAL_DELAY_SECONDS := 0.36
const EDITOR_MAP_JOYPAD_REPEAT_INTERVAL_SECONDS := 0.09
const EDITOR_MAP_CURSOR_SEMANTIC_DEBOUNCE_SECONDS := 0.42
const EDITOR_MAP_CURSOR_RESULT_VISIBLE_SECONDS := 1.20
const EDITOR_MAP_CURSOR_SEMANTIC_MAX_CHARS := 320
const EDITOR_WORKBENCH_SKIN_MODEL := "shared_cartographic_frame_and_control_art"
const EDITOR_SHELL_FRAME_PATH := "res://art/ui/runtime/main_menu/stage_dock_cartography.png"
const EDITOR_TOP_FRAME_PATH := "res://art/ui/runtime/battle/battle_footer_panel.png"
const EDITOR_MAP_FRAME_PATH := "res://art/ui/runtime/battle/combat_log_panel.png"
const EDITOR_TOOL_RAIL_FRAME_PATH := "res://art/ui/runtime/overworld/sidebar_frame.png"

@onready var _header_label: Label = %Header
@onready var _map_package_picker: OptionButton = %MapPackagePicker
@onready var _load_map_button: Button = %LoadMap
@onready var _save_copy_button: Button = %SaveCopy
@onready var _editor_top_pad: MarginContainer = $RootMargin/Shell/ShellPad/ShellBox/TopPanel/TopPad
@onready var _editor_top_bar: HBoxContainer = $RootMargin/Shell/ShellPad/ShellBox/TopPanel/TopPad/TopBar
@onready var _editor_shell_panel: PanelContainer = $RootMargin/Shell
@onready var _editor_top_panel: PanelContainer = $RootMargin/Shell/ShellPad/ShellBox/TopPanel
@onready var _editor_map_panel: PanelContainer = $RootMargin/Shell/ShellPad/ShellBox/BodyRow/MapPanel
@onready var _editor_tool_rail: PanelContainer = $RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail
@onready var _terrain_picker: OptionButton = %TerrainPicker
@onready var _inspect_tool_button: Button = %InspectTool
@onready var _terrain_tool_button: Button = %TerrainTool
@onready var _terrain_line_tool_button: Button = %TerrainLineTool
@onready var _terrain_rectangle_tool_button: Button = %TerrainRectangleTool
@onready var _road_tool_button: Button = %RoadTool
@onready var _road_path_tool_button: Button = %RoadPathTool
@onready var _hero_start_tool_button: Button = %HeroStartTool
@onready var _place_object_tool_button: Button = %PlaceObjectTool
@onready var _remove_object_tool_button: Button = %RemoveObjectTool
@onready var _move_object_tool_button: Button = %MoveObjectTool
@onready var _duplicate_object_tool_button: Button = %DuplicateObjectTool
@onready var _retheme_object_tool_button: Button = %RethemeObjectTool
@onready var _fill_terrain_button: Button = %FillTerrain
@onready var _restore_tile_button: Button = %RestoreSelectedTile
@onready var _tile_info_label: Label = %TileInfo
@onready var _status_label: Label = %WorkingCopyStatus
@onready var _map_view = %Map
@onready var _editor_map_cursor_live_label: Label = %EditorMapCursorLive
@onready var _play_button: Button = %PlayWorkingCopy
@onready var _menu_button: Button = %Menu
@onready var _dirty_transition_dialog: ConfirmationDialog = $DirtyTransitionConfirmationDialog
@onready var _object_family_picker: OptionButton = %ObjectFamilyPicker
@onready var _object_content_picker: OptionButton = %ObjectContentPicker
@onready var _object_taxonomy_summary_label: Label = %ObjectTaxonomySummary
@onready var _selected_object_picker: OptionButton = %SelectedObjectPicker
@onready var _property_summary_label: Label = %PropertySummary
@onready var _property_owner_picker: OptionButton = %PropertyOwnerPicker
@onready var _property_difficulty_picker: OptionButton = %PropertyDifficultyPicker
@onready var _property_collected_check: CheckBox = %PropertyCollectedFlag
@onready var _property_apply_button: Button = %ApplyObjectProperties
@onready var _tool_scroll: ScrollContainer = $RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll
@onready var _tool_buttons: GridContainer = $RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll/ToolBox/ToolButtons

# Assigning the working copy or the dirty flag bumps the edit revision, which
# drops the memoised validation below.
var _session = null:
	set(value):
		_session = value
		_editor_edit_revision += 1
var _map_package_entries: Array = []
var _map_package_index_status := {}
var _terrain_entries: Array = []
var _object_family_entries: Array = []
var _object_content_entries: Array = []
var _selected_map_package_id := ""
var _selected_terrain_id := DEFAULT_TERRAIN_ID
var _selected_object_family := DEFAULT_OBJECT_FAMILY
var _selected_object_content_id := ""
var _selected_property_object_key := ""
var _pending_move_object_key := ""
var _pending_duplicate_object_key := ""
var _pending_terrain_line_start := Vector2i(-1, -1)
var _pending_terrain_rectangle_corner := Vector2i(-1, -1)
var _pending_road_path_start := Vector2i(-1, -1)
var _selected_tile := Vector2i.ZERO
var _hovered_tile := Vector2i(-1, -1)
var _tool := TOOL_INSPECT
var _dirty := false:
	set(value):
		_dirty = value
		_editor_edit_revision += 1
# Whole-map validation is memoised per edit revision so one refresh (and every
# hover after it) runs it once instead of once per status surface.
var _editor_edit_revision := 0
var _editor_validation_memo_revision := -1
var _editor_validation_memo := {}
var _last_message := ""
var _last_object_authoring_recap := {}
var _restored_from_play_copy := false
var _terrain_paint_order := 0
var _last_terrain_placement_result := {}
var _authored_baseline_cache = null
var _authored_baseline_cache_id := ""
var _placement_debug_overlay_enabled := false
var _last_save_copy_result := {}
var _pending_dirty_transition := {}
var _dirty_transition_return_focus: Control = null
var _last_editor_command_focus: Control = null
var _editor_map_joypad_repeat_timer: Timer = null
var _held_editor_map_joypad_direction := Vector2i.ZERO
var _held_editor_map_joypad_action: StringName = &""
var _held_editor_map_joypad_button := -1
var _held_editor_map_joypad_device := -1
var _editor_map_cursor_semantic_timer: Timer = null
var _editor_map_cursor_semantic_generation := 0
var _editor_map_cursor_semantic_pending: Dictionary = {}
var _editor_top_bar_layout_sync_queued := false
var _editor_top_bar_header_preferred_width := 0.0
var _editor_top_bar_picker_preferred_width := 0.0
var _editor_tool_rail_layout_sync_queued := false
var _forwarding_dirty_transition_root_physical_input := false
var _safe_close_guard_authorized := false
var _safe_close_guard_authorized_source := ""
var _validation_dirty_transition_routing_enabled := true
var _validation_dirty_transition_request_count := 0
var _validation_dirty_transition_cancel_count := 0
var _validation_dirty_transition_confirm_count := 0
var _validation_dirty_transition_duplicate_request_count := 0
var _validation_dirty_transition_menu_route_count := 0
var _validation_dirty_transition_package_action_count := 0
var _validation_dirty_transition_quit_attempt_count := 0
var _last_dirty_transition_result := {}
var validation_skip_initial_package_index := false

func _ready() -> void:
	_apply_visual_theme()
	_configure_dirty_transition_confirmation()
	_configure_editor_map_keyboard_input()
	_configure_editor_map_cursor_semantic_timer()
	_connect_ui()
	_configure_editor_top_bar_layout()
	_configure_editor_tool_rail_layout()
	_connect_editor_focus_visibility()
	_rebuild_terrain_picker()
	_rebuild_object_family_picker()
	_rebuild_property_option_pickers()
	if not validation_skip_initial_package_index:
		_rebuild_map_package_picker()
	else:
		_map_package_entries = []
		_map_package_index_status = {"ok": true, "entries": [], "message": "Initial package index skipped for focused validation."}
		_map_package_picker.clear()
	_select_tool(TOOL_INSPECT)
	var returned_snapshot: Dictionary = SessionState.consume_editor_return_snapshot()
	var returned_session = returned_snapshot.get("working_copy_session", null)
	var returned_baseline = returned_snapshot.get("authored_baseline_session", null)
	var returned_package_identity: Dictionary = returned_snapshot.get("package_identity", {})
	if returned_session != null and _resume_working_copy_from_memory(returned_session, returned_baseline, returned_package_identity):
		call_deferred("_configure_editor_keyboard_focus")
		return
	_refresh_state()
	call_deferred("_configure_editor_keyboard_focus")

func _exit_tree() -> void:
	_stop_editor_map_joypad_repeat()
	_cancel_editor_map_cursor_semantic()

func _unhandled_input(event: InputEvent) -> void:
	if _dirty_transition_dialog != null and _dirty_transition_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == PLACEMENT_DEBUG_OVERLAY_TOGGLE_KEY:
			_set_placement_debug_overlay_enabled(not _placement_debug_overlay_enabled)
			get_viewport().set_input_as_handled()

func _connect_ui() -> void:
	_map_package_picker.item_selected.connect(_on_map_package_selected)
	_load_map_button.pressed.connect(_on_load_map_pressed)
	_save_copy_button.pressed.connect(_on_save_copy_pressed)
	_terrain_picker.item_selected.connect(_on_terrain_selected)
	_inspect_tool_button.pressed.connect(func(): _select_tool(TOOL_INSPECT))
	_terrain_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN))
	_terrain_line_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN_LINE))
	_terrain_rectangle_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN_RECTANGLE))
	_road_tool_button.pressed.connect(func(): _select_tool(TOOL_ROAD))
	_road_path_tool_button.pressed.connect(func(): _select_tool(TOOL_ROAD_PATH))
	_hero_start_tool_button.pressed.connect(func(): _select_tool(TOOL_HERO_START))
	_place_object_tool_button.pressed.connect(func(): _select_tool(TOOL_PLACE_OBJECT))
	_remove_object_tool_button.pressed.connect(func(): _select_tool(TOOL_REMOVE_OBJECT))
	_move_object_tool_button.pressed.connect(func(): _select_tool(TOOL_MOVE_OBJECT))
	_duplicate_object_tool_button.pressed.connect(func(): _select_tool(TOOL_DUPLICATE_OBJECT))
	_retheme_object_tool_button.pressed.connect(func(): _select_tool(TOOL_RETHEME_OBJECT))
	_fill_terrain_button.pressed.connect(_on_fill_terrain_pressed)
	_restore_tile_button.pressed.connect(_on_restore_selected_tile_pressed)
	_object_family_picker.item_selected.connect(_on_object_family_selected)
	_object_content_picker.item_selected.connect(_on_object_content_selected)
	_selected_object_picker.item_selected.connect(_on_selected_property_object_selected)
	_property_apply_button.pressed.connect(_on_apply_object_properties_pressed)
	_play_button.pressed.connect(_on_play_working_copy_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	if _map_view != null:
		_map_view.tile_pressed.connect(_on_map_tile_pressed)
		_map_view.tile_hovered.connect(_on_map_tile_hovered)

func _configure_editor_top_bar_layout() -> void:
	if (
		_editor_top_pad == null
		or _editor_top_bar == null
		or _header_label == null
		or _map_package_picker == null
	):
		return
	_editor_top_bar_header_preferred_width = _header_label.custom_minimum_size.x
	_editor_top_bar_picker_preferred_width = _map_package_picker.custom_minimum_size.x
	if not _editor_top_pad.resized.is_connected(_queue_editor_top_bar_layout_sync):
		_editor_top_pad.resized.connect(_queue_editor_top_bar_layout_sync)
	if not theme_changed.is_connected(_queue_editor_top_bar_layout_sync):
		theme_changed.connect(_queue_editor_top_bar_layout_sync)
	_queue_editor_top_bar_layout_sync()

func _queue_editor_top_bar_layout_sync() -> void:
	if _editor_top_bar_layout_sync_queued or not is_inside_tree():
		return
	_editor_top_bar_layout_sync_queued = true
	call_deferred("_sync_editor_top_bar_layout")

func _sync_editor_top_bar_layout() -> void:
	_editor_top_bar_layout_sync_queued = false
	if (
		not is_inside_tree()
		or _editor_top_pad == null
		or not is_instance_valid(_editor_top_pad)
		or _editor_top_bar == null
		or not is_instance_valid(_editor_top_bar)
		or _header_label == null
		or not is_instance_valid(_header_label)
		or _map_package_picker == null
		or not is_instance_valid(_map_package_picker)
	):
		return
	var available_width := (
		_editor_top_pad.size.x
		- float(_editor_top_pad.get_theme_constant("margin_left"))
		- float(_editor_top_pad.get_theme_constant("margin_right"))
	)
	var commands: Array[Control] = [
		_load_map_button,
		_save_copy_button,
		_play_button,
		_menu_button,
	]
	var command_width := 0.0
	for command in commands:
		if command != null and command.visible:
			command_width += command.get_combined_minimum_size().x
	var visible_surface_count := 2
	for command in commands:
		if command != null and command.visible:
			visible_surface_count += 1
	var separation_width := (
		float(_editor_top_bar.get_theme_constant("separation"))
		* float(maxi(0, visible_surface_count - 1))
	)
	var flexible_width := maxf(0.0, available_width - command_width - separation_width)
	if flexible_width <= 0.0:
		return
	var header_floor := _editor_top_bar_text_minimum_width(_header_label, "Map Editor")
	var picker_floor := _editor_top_bar_picker_text_minimum_width("Map Package")
	var header_preferred := maxf(
		_editor_top_bar_header_preferred_width,
		_editor_top_bar_text_minimum_width(_header_label, _header_label.text)
	)
	var picker_preferred := maxf(
		_editor_top_bar_picker_preferred_width,
		_editor_top_bar_picker_text_minimum_width(_selected_map_package_picker_text())
	)
	var header_width := header_floor
	var picker_width := picker_floor
	var floor_total := header_floor + picker_floor
	var preferred_total := header_preferred + picker_preferred
	if flexible_width >= preferred_total:
		header_width = header_preferred
		picker_width = picker_preferred
	elif flexible_width >= floor_total:
		var extra_width := flexible_width - floor_total
		var header_need := maxf(0.0, header_preferred - header_floor)
		var picker_need := maxf(0.0, picker_preferred - picker_floor)
		var need_total := header_need + picker_need
		var header_share := header_need / need_total if need_total > 0.0 else 0.5
		header_width += extra_width * header_share
		picker_width = flexible_width - header_width
	elif floor_total > 0.0:
		header_width = flexible_width * (header_floor / floor_total)
		picker_width = flexible_width - header_width
	var header_minimum := _header_label.custom_minimum_size
	header_minimum.x = floorf(header_width)
	_header_label.custom_minimum_size = header_minimum
	var picker_minimum := _map_package_picker.custom_minimum_size
	picker_minimum.x = floorf(picker_width)
	_map_package_picker.custom_minimum_size = picker_minimum

func _editor_top_bar_text_minimum_width(control: Control, text: String) -> float:
	if control == null:
		return 0.0
	var font := control.get_theme_font("font")
	var font_size := control.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var normal_style := control.get_theme_stylebox("normal")
	if normal_style != null:
		text_width += normal_style.get_minimum_size().x
	return ceilf(text_width)

func _editor_top_bar_picker_text_minimum_width(text: String) -> float:
	var width := _editor_top_bar_text_minimum_width(_map_package_picker, text)
	var arrow := _map_package_picker.get_theme_icon("arrow")
	if arrow != null:
		width += arrow.get_width()
	width += float(_map_package_picker.get_theme_constant("arrow_margin"))
	return ceilf(width)

func _selected_map_package_picker_text() -> String:
	if _map_package_picker == null:
		return ""
	var selected_index := _map_package_picker.selected
	if selected_index < 0 or selected_index >= _map_package_picker.get_item_count():
		return ""
	return _map_package_picker.get_item_text(selected_index)

func _configure_editor_tool_rail_layout() -> void:
	if _tool_scroll == null or _tool_buttons == null:
		return
	if not _tool_scroll.resized.is_connected(_queue_editor_tool_rail_layout_sync):
		_tool_scroll.resized.connect(_queue_editor_tool_rail_layout_sync)
	if not _tool_buttons.minimum_size_changed.is_connected(_queue_editor_tool_rail_layout_sync):
		_tool_buttons.minimum_size_changed.connect(_queue_editor_tool_rail_layout_sync)
	_queue_editor_tool_rail_layout_sync()

func _queue_editor_tool_rail_layout_sync() -> void:
	if _editor_tool_rail_layout_sync_queued or not is_inside_tree():
		return
	_editor_tool_rail_layout_sync_queued = true
	call_deferred("_sync_editor_tool_rail_layout")

func _sync_editor_tool_rail_layout() -> void:
	_editor_tool_rail_layout_sync_queued = false
	if (
		not is_inside_tree()
		or _tool_scroll == null
		or not is_instance_valid(_tool_scroll)
		or _tool_buttons == null
		or not is_instance_valid(_tool_buttons)
	):
		return
	var inner_width := _tool_scroll.size.x
	var vertical_scroll_bar := _tool_scroll.get_v_scroll_bar()
	if vertical_scroll_bar != null and vertical_scroll_bar.visible:
		inner_width -= vertical_scroll_bar.size.x
	if inner_width <= 0.0:
		return
	var required_two_column_width := _editor_tool_buttons_two_column_minimum_width()
	var desired_columns := 2 if required_two_column_width <= inner_width else 1
	if _tool_buttons.columns == desired_columns:
		return
	_tool_buttons.columns = desired_columns
	_queue_editor_tool_rail_layout_sync()

func _editor_tool_buttons_two_column_minimum_width() -> float:
	var column_widths := [0.0, 0.0]
	var visible_control_index := 0
	for child in _tool_buttons.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var control := child as Control
		var column_index := visible_control_index % 2
		column_widths[column_index] = maxf(
			float(column_widths[column_index]),
			control.get_combined_minimum_size().x
		)
		visible_control_index += 1
	if visible_control_index < 2:
		return float(column_widths[0])
	return (
		float(column_widths[0])
		+ float(column_widths[1])
		+ float(_tool_buttons.get_theme_constant("h_separation"))
	)

func _configure_editor_map_keyboard_input() -> void:
	if _map_view == null:
		return
	_map_view.focus_mode = Control.FOCUS_ALL
	if not _map_view.gui_input.is_connected(_on_editor_map_gui_input):
		_map_view.gui_input.connect(_on_editor_map_gui_input)
	if not _map_view.focus_exited.is_connected(_on_editor_map_focus_exited):
		_map_view.focus_exited.connect(_on_editor_map_focus_exited)
	if _editor_map_joypad_repeat_timer == null or not is_instance_valid(_editor_map_joypad_repeat_timer):
		_editor_map_joypad_repeat_timer = Timer.new()
		_editor_map_joypad_repeat_timer.name = "EditorMapJoypadRepeatTimer"
		_editor_map_joypad_repeat_timer.one_shot = true
		add_child(_editor_map_joypad_repeat_timer)
	if not _editor_map_joypad_repeat_timer.timeout.is_connected(_on_editor_map_joypad_repeat_timeout):
		_editor_map_joypad_repeat_timer.timeout.connect(_on_editor_map_joypad_repeat_timeout)

func _on_editor_map_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if not _editor_map_keyboard_input_owned():
		_stop_editor_map_joypad_repeat()
		return
	if event is InputEventJoypadButton and not event.pressed:
		if _editor_map_joypad_release_matches(event as InputEventJoypadButton):
			_stop_editor_map_joypad_repeat()
			_map_view.accept_event()
		return
	var cardinal_action := _editor_map_cardinal_action(event)
	if cardinal_action != &"":
		var direction := _editor_map_direction_for_action(cardinal_action)
		if event is InputEventJoypadButton:
			var joypad_event := event as InputEventJoypadButton
			if _editor_map_joypad_hold_matches(joypad_event, cardinal_action, direction):
				_map_view.accept_event()
				return
			_move_editor_map_cursor(direction)
			_start_editor_map_joypad_repeat(joypad_event, cardinal_action, direction)
		else:
			_move_editor_map_cursor(direction)
		_map_view.accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		var source_session = _session
		_on_map_tile_pressed(_selected_tile)
		_publish_editor_map_cursor_semantic_result(
			_editor_map_action_result_semantic_text(),
			source_session,
			_map_view
		)
		_map_view.accept_event()
		return
	if _editor_map_cancel_pressed(event):
		_handle_editor_map_cancel()
		_map_view.accept_event()

func _handle_editor_map_cancel() -> void:
	var source_session = _session
	var canceled_tile := _selected_tile
	_restore_editor_command_focus()
	var focus_owner := get_viewport().gui_get_focus_owner() as Control
	_publish_editor_map_cursor_semantic_result(
		"Canvas navigation ended at %d,%d. Focus returned to the %s command." % [
			canceled_tile.x,
			canceled_tile.y,
			_tool_label(_tool),
		],
		source_session,
		focus_owner
	)

func _editor_map_cancel_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE)
	)

func _editor_map_keyboard_input_owned() -> bool:
	if (
		not is_inside_tree()
		or _map_view == null
		or not is_instance_valid(_map_view)
		or (_dirty_transition_dialog != null and _dirty_transition_dialog.visible)
		or not _pending_dirty_transition.is_empty()
	):
		return false
	var viewport := get_viewport()
	return viewport != null and viewport.gui_get_focus_owner() == _map_view

func _editor_map_cardinal_action(event: InputEvent) -> StringName:
	if event.is_action_pressed("ui_left", true):
		return &"ui_left"
	if event.is_action_pressed("ui_right", true):
		return &"ui_right"
	if event.is_action_pressed("ui_up", true):
		return &"ui_up"
	if event.is_action_pressed("ui_down", true):
		return &"ui_down"
	return &""

func _editor_map_direction_for_action(action: StringName) -> Vector2i:
	return HumanEngine.native_writing(&"MapEditorShell._editor_map_direction_for_action", [self, action])

func _start_editor_map_joypad_repeat(
	event: InputEventJoypadButton,
	action: StringName,
	direction: Vector2i
) -> void:
	if _editor_map_joypad_repeat_timer == null or direction == Vector2i.ZERO:
		return
	_held_editor_map_joypad_direction = direction
	_held_editor_map_joypad_action = action
	_held_editor_map_joypad_button = event.button_index
	_held_editor_map_joypad_device = event.device
	_editor_map_joypad_repeat_timer.start(EDITOR_MAP_JOYPAD_REPEAT_INITIAL_DELAY_SECONDS)

func _editor_map_joypad_hold_matches(
	event: InputEventJoypadButton,
	action: StringName,
	direction: Vector2i
) -> bool:
	return (
		_held_editor_map_joypad_direction == direction
		and _held_editor_map_joypad_action == action
		and _held_editor_map_joypad_button == event.button_index
		and _held_editor_map_joypad_device == event.device
	)

func _editor_map_joypad_release_matches(event: InputEventJoypadButton) -> bool:
	return (
		_held_editor_map_joypad_direction != Vector2i.ZERO
		and _held_editor_map_joypad_action != &""
		and _held_editor_map_joypad_button == event.button_index
		and _held_editor_map_joypad_device == event.device
	)

func _on_editor_map_joypad_repeat_timeout() -> void:
	if (
		not _editor_map_keyboard_input_owned()
		or _held_editor_map_joypad_direction == Vector2i.ZERO
		or _held_editor_map_joypad_action == &""
		or _held_editor_map_joypad_button < 0
	):
		_stop_editor_map_joypad_repeat()
		return
	_move_editor_map_cursor(_held_editor_map_joypad_direction)
	if not _editor_map_keyboard_input_owned():
		_stop_editor_map_joypad_repeat()
		return
	_editor_map_joypad_repeat_timer.start(EDITOR_MAP_JOYPAD_REPEAT_INTERVAL_SECONDS)

func _stop_editor_map_joypad_repeat() -> void:
	if _editor_map_joypad_repeat_timer != null and is_instance_valid(_editor_map_joypad_repeat_timer):
		_editor_map_joypad_repeat_timer.stop()
	_held_editor_map_joypad_direction = Vector2i.ZERO
	_held_editor_map_joypad_action = &""
	_held_editor_map_joypad_button = -1
	_held_editor_map_joypad_device = -1

func _move_editor_map_cursor(direction: Vector2i) -> void:
	if _session == null:
		return
	var map_size := OverworldRules.derive_map_size(_session)
	if map_size.x <= 0 or map_size.y <= 0:
		return
	var next_tile := Vector2i(
		clampi(_selected_tile.x + direction.x, 0, map_size.x - 1),
		clampi(_selected_tile.y + direction.y, 0, map_size.y - 1)
	)
	if next_tile == _selected_tile:
		return
	_selected_tile = next_tile
	_hovered_tile = next_tile
	if _map_view.has_method("pan_tiles"):
		_map_view.call("pan_tiles", direction)
	_refresh_state()
	_schedule_editor_map_cursor_semantic()

func _configure_editor_map_cursor_semantic_timer() -> void:
	if _editor_map_cursor_semantic_timer != null and is_instance_valid(_editor_map_cursor_semantic_timer):
		return
	_editor_map_cursor_semantic_timer = Timer.new()
	_editor_map_cursor_semantic_timer.name = "EditorMapCursorSemanticTimer"
	_editor_map_cursor_semantic_timer.one_shot = true
	_editor_map_cursor_semantic_timer.timeout.connect(_on_editor_map_cursor_semantic_timeout)
	add_child(_editor_map_cursor_semantic_timer)

func _on_editor_map_focus_exited() -> void:
	_stop_editor_map_joypad_repeat()
	_cancel_editor_map_cursor_semantic()

func _schedule_editor_map_cursor_semantic() -> void:
	_cancel_editor_map_cursor_semantic()
	if not _editor_map_keyboard_input_owned() or _session == null or not _tile_in_bounds(_selected_tile):
		return
	_editor_map_cursor_semantic_pending = {
		"kind": "context",
		"generation": _editor_map_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": String(_session.session_id),
		"selected_tile": _editor_tile_payload(_selected_tile),
		"tool": _tool,
		"label_ref": _editor_map_cursor_live_label,
	}
	_editor_map_cursor_semantic_timer.start(EDITOR_MAP_CURSOR_SEMANTIC_DEBOUNCE_SECONDS)

func _editor_map_cursor_semantic_context() -> String:
	return HumanEngine.native_writing(&"MapEditorShell._editor_map_cursor_semantic_context", [self])

func _editor_map_action_result_semantic_text() -> String:
	return HumanEngine.native_writing(&"MapEditorShell._editor_map_action_result_semantic_text", [self])

func _publish_editor_map_cursor_semantic_result(
	text: String,
	source_session,
	expected_focus: Control
) -> void:
	var bounded_text := _bounded_editor_map_semantic_text(text, EDITOR_MAP_CURSOR_SEMANTIC_MAX_CHARS)
	if (
		bounded_text == ""
		or not is_inside_tree()
		or _session == null
		or not is_same(source_session, _session)
		or String(source_session.session_id) != String(_session.session_id)
		or not is_instance_valid(expected_focus)
		or get_viewport().gui_get_focus_owner() != expected_focus
		or (_dirty_transition_dialog != null and _dirty_transition_dialog.visible)
		or not _pending_dirty_transition.is_empty()
	):
		return
	_cancel_editor_map_cursor_semantic()
	_editor_map_cursor_live_label.text = bounded_text
	_editor_map_cursor_semantic_pending = {
		"kind": "result_clear",
		"generation": _editor_map_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": String(_session.session_id),
		"focus_ref": expected_focus,
		"label_ref": _editor_map_cursor_live_label,
		"label_text": bounded_text,
	}
	_editor_map_cursor_semantic_timer.start(EDITOR_MAP_CURSOR_RESULT_VISIBLE_SECONDS)

func _on_editor_map_cursor_semantic_timeout() -> void:
	var pending := _editor_map_cursor_semantic_pending
	if pending.is_empty() or int(pending.get("generation", -1)) != _editor_map_cursor_semantic_generation:
		return
	_editor_map_cursor_semantic_pending = {}
	match String(pending.get("kind", "")):
		"context":
			_publish_pending_editor_map_cursor_context(pending)
		"result_clear":
			_clear_editor_map_cursor_semantic_result(pending)
		_:
			_cancel_editor_map_cursor_semantic()

func _publish_pending_editor_map_cursor_context(pending: Dictionary) -> void:
	var selected_value: Variant = pending.get("selected_tile", {})
	var selected_payload: Dictionary = selected_value if selected_value is Dictionary else {}
	var pending_tile := Vector2i(int(selected_payload.get("x", -1)), int(selected_payload.get("y", -1)))
	if (
		not is_inside_tree()
		or not _editor_map_keyboard_input_owned()
		or _session == null
		or not is_same(pending.get("session_ref"), _session)
		or String(pending.get("session_id", "")) != String(_session.session_id)
		or pending_tile != _selected_tile
		or String(pending.get("tool", "")) != _tool
		or not is_same(pending.get("label_ref"), _editor_map_cursor_live_label)
	):
		_cancel_editor_map_cursor_semantic()
		return
	var context := _editor_map_cursor_semantic_context()
	if context == "":
		_cancel_editor_map_cursor_semantic()
		return
	_editor_map_cursor_live_label.text = context.left(EDITOR_MAP_CURSOR_SEMANTIC_MAX_CHARS)

func _clear_editor_map_cursor_semantic_result(pending: Dictionary) -> void:
	if int(pending.get("generation", -1)) != _editor_map_cursor_semantic_generation:
		return
	var expected_focus: Variant = pending.get("focus_ref")
	if (
		not is_inside_tree()
		or _session == null
		or not is_same(pending.get("session_ref"), _session)
		or String(pending.get("session_id", "")) != String(_session.session_id)
		or not is_instance_valid(expected_focus)
		or get_viewport().gui_get_focus_owner() != expected_focus
		or (_dirty_transition_dialog != null and _dirty_transition_dialog.visible)
		or not _pending_dirty_transition.is_empty()
		or not is_same(pending.get("label_ref"), _editor_map_cursor_live_label)
	):
		_cancel_editor_map_cursor_semantic()
		return
	_editor_map_cursor_semantic_generation += 1
	if _editor_map_cursor_live_label.text == String(pending.get("label_text", "")):
		_editor_map_cursor_live_label.text = ""

func _cancel_editor_map_cursor_semantic() -> void:
	_editor_map_cursor_semantic_generation += 1
	_editor_map_cursor_semantic_pending.clear()
	if _editor_map_cursor_semantic_timer != null and is_instance_valid(_editor_map_cursor_semantic_timer):
		_editor_map_cursor_semantic_timer.stop()
	if _editor_map_cursor_live_label != null and is_instance_valid(_editor_map_cursor_live_label):
		_editor_map_cursor_live_label.text = ""

func _bounded_editor_map_semantic_text(value: String, maximum_characters: int) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._bounded_editor_map_semantic_text", [self, value, maximum_characters])

func _editor_tile_payload(tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_tile_payload", [self, tile])

func _restore_editor_command_focus() -> void:
	var target := _active_tool_focus_control()
	if not FrontierVisualKit.is_keyboard_focusable(target):
		target = _last_editor_command_focus
	if not FrontierVisualKit.is_keyboard_focusable(target):
		target = _map_package_picker
	if FrontierVisualKit.is_keyboard_focusable(target):
		target.grab_focus()
		_reveal_editor_focus(target)

func _active_tool_focus_control() -> Control:
	match _tool:
		TOOL_TERRAIN:
			return _terrain_tool_button
		TOOL_TERRAIN_LINE:
			return _terrain_line_tool_button
		TOOL_TERRAIN_RECTANGLE:
			return _terrain_rectangle_tool_button
		TOOL_ROAD:
			return _road_tool_button
		TOOL_ROAD_PATH:
			return _road_path_tool_button
		TOOL_HERO_START:
			return _hero_start_tool_button
		TOOL_PLACE_OBJECT:
			return _place_object_tool_button
		TOOL_REMOVE_OBJECT:
			return _remove_object_tool_button
		TOOL_MOVE_OBJECT:
			return _move_object_tool_button
		TOOL_DUPLICATE_OBJECT:
			return _duplicate_object_tool_button
		TOOL_RETHEME_OBJECT:
			return _retheme_object_tool_button
		_:
			return _inspect_tool_button

func _editor_focus_surfaces() -> Array:
	return [
		_map_package_picker,
		_load_map_button,
		_save_copy_button,
		_play_button,
		_menu_button,
		_map_view,
		_inspect_tool_button,
		_terrain_tool_button,
		_terrain_line_tool_button,
		_terrain_rectangle_tool_button,
		_road_tool_button,
		_road_path_tool_button,
		_hero_start_tool_button,
		_place_object_tool_button,
		_remove_object_tool_button,
		_move_object_tool_button,
		_duplicate_object_tool_button,
		_retheme_object_tool_button,
		_fill_terrain_button,
		_restore_tile_button,
		_terrain_picker,
		_object_family_picker,
		_object_content_picker,
		_selected_object_picker,
		_property_owner_picker,
		_property_difficulty_picker,
		_property_collected_check,
		_property_apply_button,
	]

func _connect_editor_focus_visibility() -> void:
	for control_value in _editor_focus_surfaces():
		var control := control_value as Control
		if control == null:
			continue
		var callback := _on_editor_focus_entered.bind(control)
		if not control.focus_entered.is_connected(callback):
			control.focus_entered.connect(callback)

func _configure_editor_keyboard_focus() -> void:
	if (
		not is_inside_tree()
		or (_dirty_transition_dialog != null and _dirty_transition_dialog.visible)
		or not _pending_dirty_transition.is_empty()
	):
		return
	var controls := FrontierVisualKit.configure_focus_cycle(_editor_focus_surfaces())
	var current := get_viewport().gui_get_focus_owner() as Control
	if current != null and controls.has(current) and FrontierVisualKit.is_keyboard_focusable(current):
		_reveal_editor_focus(current)
		return
	var focused := FrontierVisualKit.grab_keyboard_focus(
		self,
		_map_package_picker,
		controls,
		true
	)
	_reveal_editor_focus(focused)

func _on_editor_focus_entered(control: Control) -> void:
	_cancel_editor_map_cursor_semantic()
	if (
		_dirty_transition_dialog != null
		and (_dirty_transition_dialog.visible or not _pending_dirty_transition.is_empty())
	):
		return
	if control != _map_view and FrontierVisualKit.is_keyboard_focusable(control):
		_last_editor_command_focus = control
	call_deferred("_reveal_editor_focus", control)

func _reveal_editor_focus(control: Control) -> void:
	if (
		(_dirty_transition_dialog != null and _dirty_transition_dialog.visible)
		or not _pending_dirty_transition.is_empty()
	):
		return
	if (
		control != null
		and is_instance_valid(control)
		and _tool_scroll != null
		and _tool_scroll.is_ancestor_of(control)
	):
		_tool_scroll.ensure_control_visible(control)

func _configure_dirty_transition_confirmation() -> void:
	_dirty_transition_dialog.exclusive = true
	_dirty_transition_dialog.unresizable = true
	_dirty_transition_dialog.get_cancel_button().text = DIRTY_TRANSITION_CANCEL_TEXT
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	_dirty_transition_dialog.get_cancel_button().shortcut = cancel_shortcut
	var dialog_label := _dirty_transition_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(560.0, 0.0)
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)

func _on_root_window_input(event: InputEvent) -> void:
	if (
		_forwarding_dirty_transition_root_physical_input
		or not (event is InputEventKey or event is InputEventJoypadButton)
	):
		return
	var root_window := get_tree().root
	if _editor_map_keyboard_input_owned() and _editor_map_cancel_pressed(event):
		root_window.set_input_as_handled()
		_handle_editor_map_cancel()
		return
	if not _dirty_transition_dialog.visible or _pending_dirty_transition.is_empty():
		return
	root_window.set_input_as_handled()
	var dialog := _dirty_transition_dialog
	var pending := _pending_dirty_transition
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred(
		"_forward_root_physical_input_to_dirty_transition",
		dialog,
		pending,
		detached_event
	)

func _forward_root_physical_input_to_dirty_transition(
	dialog: ConfirmationDialog,
	pending: Dictionary,
	event: InputEvent
) -> void:
	if (
		_forwarding_dirty_transition_root_physical_input
		or not is_instance_valid(dialog)
		or dialog != _dirty_transition_dialog
		or not dialog.visible
		or _pending_dirty_transition.is_empty()
		or not is_same(pending, _pending_dirty_transition)
	):
		return
	_forwarding_dirty_transition_root_physical_input = true
	dialog.push_input(event)
	_forwarding_dirty_transition_root_physical_input = false

func _rebuild_map_package_picker() -> void:
	_map_package_index_status = ScenarioSelectRulesScript.maps_folder_package_index({
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	_map_package_entries = _map_package_index_status.get("entries", []) if _map_package_index_status.get("entries", []) is Array else []
	_map_package_picker.clear()
	var selected_index := -1
	for index in range(_map_package_entries.size()):
		var entry: Dictionary = _map_package_entries[index]
		var package_id := String(entry.get("package_id", ""))
		var map_size: Dictionary = entry.get("map_size", {}) if entry.get("map_size", {}) is Dictionary else {}
		var label := "Map Package | %s | %dx%d" % [
			String(entry.get("display_name", entry.get("package_stem", package_id))),
			int(map_size.get("width", 0)),
			int(map_size.get("height", 0)),
		]
		if bool(entry.get("editor_inspection_only", false)):
			label = "%s | Inspect Only" % label
		_map_package_picker.add_item(label, index)
		_map_package_picker.set_item_metadata(index, package_id)
		if package_id == _selected_map_package_id:
			selected_index = index
	if selected_index < 0 and not _map_package_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_map_package_picker.select(selected_index)
		_selected_map_package_id = String(_map_package_picker.get_item_metadata(selected_index))
	else:
		_selected_map_package_id = ""
		var empty_label := "No map packages found"
		if not bool(_map_package_index_status.get("ok", true)):
			empty_label = "Map packages unavailable"
		_map_package_picker.add_item(empty_label, 0)
		_map_package_picker.set_item_metadata(0, "")
	_map_package_picker.disabled = _map_package_entries.is_empty()
	_queue_editor_top_bar_layout_sync()

func _rebuild_terrain_picker() -> void:
	_terrain_entries = _terrain_items()
	_terrain_picker.clear()
	var selected_index := -1
	for index in range(_terrain_entries.size()):
		var terrain: Dictionary = _terrain_entries[index]
		var terrain_id := String(terrain.get("id", ""))
		_terrain_picker.add_item(String(terrain.get("label", terrain_id.capitalize())), index)
		_terrain_picker.set_item_metadata(index, terrain_id)
		if terrain_id == DEFAULT_TERRAIN_ID:
			selected_index = index
	if selected_index < 0 and not _terrain_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_terrain_picker.select(selected_index)
		_selected_terrain_id = String(_terrain_picker.get_item_metadata(selected_index))

func _rebuild_object_family_picker() -> void:
	_object_family_entries = [
		{"id": OBJECT_FAMILY_TOWN, "label": "Towns"},
		{"id": OBJECT_FAMILY_RESOURCE, "label": "Resource Sites"},
		{"id": OBJECT_FAMILY_ARTIFACT, "label": "Artifacts"},
		{"id": OBJECT_FAMILY_ENCOUNTER, "label": "Encounters"},
	]
	_object_family_picker.clear()
	var selected_index := -1
	for index in range(_object_family_entries.size()):
		var entry: Dictionary = _object_family_entries[index]
		var family_id := String(entry.get("id", ""))
		_object_family_picker.add_item(String(entry.get("label", family_id.capitalize())), index)
		_object_family_picker.set_item_metadata(index, family_id)
		if family_id == _selected_object_family:
			selected_index = index
	if selected_index < 0:
		selected_index = 0
	if selected_index >= 0:
		_object_family_picker.select(selected_index)
		_selected_object_family = String(_object_family_picker.get_item_metadata(selected_index))
	_rebuild_object_content_picker()

func _rebuild_object_content_picker() -> void:
	_object_content_entries = _object_content_items(_selected_object_family)
	_object_content_picker.clear()
	var selected_index := -1
	for index in range(_object_content_entries.size()):
		var entry: Dictionary = _object_content_entries[index]
		var content_id := String(entry.get("id", ""))
		_object_content_picker.add_item(_object_content_label(entry), index)
		_object_content_picker.set_item_metadata(index, content_id)
		if content_id == _selected_object_content_id:
			selected_index = index
	if selected_index < 0 and not _object_content_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_object_content_picker.select(selected_index)
		_selected_object_content_id = String(_object_content_picker.get_item_metadata(selected_index))
	else:
		_selected_object_content_id = ""

func _rebuild_property_option_pickers() -> void:
	_property_owner_picker.clear()
	for index in range(TOWN_OWNER_OPTIONS.size()):
		var owner_id := String(TOWN_OWNER_OPTIONS[index])
		_property_owner_picker.add_item(owner_id.capitalize(), index)
		_property_owner_picker.set_item_metadata(index, owner_id)
	_property_difficulty_picker.clear()
	for index in range(ENCOUNTER_DIFFICULTY_OPTIONS.size()):
		var difficulty_id := String(ENCOUNTER_DIFFICULTY_OPTIONS[index])
		_property_difficulty_picker.add_item(difficulty_id.capitalize(), index)
		_property_difficulty_picker.set_item_metadata(index, difficulty_id)

func _sync_property_controls() -> void:
	_rebuild_selected_object_picker()
	_sync_property_value_controls(_selected_property_object_detail())

func _rebuild_selected_object_picker() -> void:
	if _selected_object_picker == null:
		return
	var options := _property_object_options_at(_selected_tile)
	_selected_object_picker.clear()
	var selected_index := -1
	for index in range(options.size()):
		var detail: Dictionary = options[index]
		var property_key := String(detail.get("property_key", ""))
		_selected_object_picker.add_item(_property_object_label(detail), index)
		_selected_object_picker.set_item_metadata(index, property_key)
		if property_key == _selected_property_object_key:
			selected_index = index
	if selected_index < 0 and not options.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_selected_object_picker.select(selected_index)
		_selected_property_object_key = String(_selected_object_picker.get_item_metadata(selected_index))
		_selected_object_picker.disabled = false
	else:
		_selected_property_object_key = ""
		_selected_object_picker.disabled = true

func _sync_property_value_controls(detail: Dictionary) -> void:
	var has_detail := not detail.is_empty()
	var kind := String(detail.get("kind", ""))
	var handoff := _selected_property_handoff_payload(detail)
	var handoff_text := String(handoff.get("visible_text", _property_summary_text(detail)))
	var handoff_tooltip := String(handoff.get("tooltip_text", handoff_text))
	_set_compact_label(_property_summary_label, handoff_text, 3)
	_selected_object_picker.tooltip_text = handoff_tooltip
	_property_apply_button.tooltip_text = String(handoff.get("apply_tooltip", "Apply editable object properties to the in-memory working copy."))
	_property_owner_picker.disabled = kind != OBJECT_FAMILY_TOWN
	_property_difficulty_picker.disabled = kind != OBJECT_FAMILY_ENCOUNTER
	_property_collected_check.disabled = kind != OBJECT_FAMILY_RESOURCE and kind != OBJECT_FAMILY_ARTIFACT
	_property_apply_button.disabled = not has_detail
	if kind == OBJECT_FAMILY_TOWN:
		_select_picker_metadata(_property_owner_picker, String(detail.get("owner", "neutral")))
	elif kind == OBJECT_FAMILY_ENCOUNTER:
		_ensure_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
		_select_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
	elif kind == OBJECT_FAMILY_RESOURCE or kind == OBJECT_FAMILY_ARTIFACT:
		_property_collected_check.button_pressed = bool(detail.get("collected", false))
	else:
		_select_picker_metadata(_property_owner_picker, "neutral")
		_select_picker_metadata(_property_difficulty_picker, "medium")
		_property_collected_check.button_pressed = false
	_property_owner_picker.tooltip_text = handoff_tooltip
	_property_difficulty_picker.tooltip_text = handoff_tooltip
	_property_collected_check.tooltip_text = handoff_tooltip

func _property_summary_text(detail: Dictionary) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._property_summary_text", [self, detail])

func _selected_property_handoff_payload(detail: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._selected_property_handoff_payload", [self, detail])

func _property_object_options_at(tile: Vector2i) -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._property_object_options_at", [self, tile])

func _selected_property_object_detail() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._selected_property_object_detail", [self])

func _object_detail_by_key(property_key: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._object_detail_by_key", [self, property_key])

func _selected_property_object_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._selected_property_object_payload", [self])

func _pending_move_object_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._pending_move_object_payload", [self])

func _pending_duplicate_object_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._pending_duplicate_object_payload", [self])

func _select_property_object_at_tile(family: String) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._select_property_object_at_tile", [self, family])

func _apply_object_property_value(property_name: String, value: Variant) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._apply_object_property_value", [self, property_name, value])

func _property_object_label(detail: Dictionary) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._property_object_label", [self, detail])

func _ensure_picker_metadata(picker: OptionButton, value: String) -> void:
	if value == "":
		return
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == value:
			return
	var index := picker.get_item_count()
	picker.add_item(value.capitalize(), index)
	picker.set_item_metadata(index, value)

func _select_picker_metadata(picker: OptionButton, value: String) -> bool:
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == value:
			picker.select(index)
			return true
	return false

func _selected_picker_metadata(picker: OptionButton, fallback: String = "") -> String:
	var selected_index := picker.selected
	if selected_index < 0 or selected_index >= picker.get_item_count():
		return fallback
	return String(picker.get_item_metadata(selected_index))

func _terrain_items() -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_items", [self])

func _terrain_label_for_id(terrain_id: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_label_for_id", [self, terrain_id])

func _terrain_option_payload() -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_option_payload", [self])

func _terrain_option_ids() -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_option_ids", [self])

func _authored_terrain_ids() -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._authored_terrain_ids", [self])

func _hidden_terrain_ids() -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._hidden_terrain_ids", [self])

func _object_content_items(family: String) -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._object_content_items", [self, family])

func _object_content_label(entry: Dictionary) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._object_content_label", [self, entry])

func _object_content_taxonomy_payload(family: String, content_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._object_content_taxonomy_payload", [self, family, content_id])

func _object_palette_guidance_text(payload: Dictionary, guidance: Dictionary) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._object_palette_guidance_text", [self, payload, guidance])

func _placement_preview_tile() -> Vector2i:
	return HumanEngine.native_writing(&"MapEditorShell._placement_preview_tile", [self])

func _selected_object_placement_preview_payload(tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._selected_object_placement_preview_payload", [self, tile])

func _editor_object_preview_check_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_object_preview_check_payload", [self])

func _editor_acceptance_cue_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_acceptance_cue_payload", [self])

func _editor_placement_action_cue_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_placement_action_cue_payload", [self])

func _editor_terrain_paint_check_payload(tool: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_terrain_paint_check_payload", [self, tool])

func _editor_road_check_payload(tool: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_road_check_payload", [self, tool])

func _set_object_authoring_recap(action: String, changed: bool, before_detail: Dictionary, after_detail: Dictionary, from_tile: Vector2i, to_tile: Vector2i, preview: Dictionary = {}, property_name: String = "", previous_value: Variant = null, new_value: Variant = null) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._set_object_authoring_recap", [self, action, changed, before_detail, after_detail, from_tile, to_tile, preview, property_name, previous_value, new_value])

func _placement_availability_for_selected_object(tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._placement_availability_for_selected_object", [self, tile])

func _placement_guidance_payload(payload: Dictionary, tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._placement_guidance_payload", [self, payload, tile])

func _scenario_authoring_validation_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._scenario_authoring_validation_payload", [self])

func _humanize_editor_id(value: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._humanize_editor_id", [self, value])

func _load_maps_folder_package_working_copy(package_id: String) -> bool:
	var index_options := {
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	}
	var entry := ScenarioSelectRulesScript.maps_folder_package_entry(package_id, index_options)
	if entry.is_empty():
		_last_message = "Unable to find map package %s for the editor." % package_id
		_refresh_state()
		return false
	return _load_maps_folder_package_entry_working_copy(entry)

func _load_maps_folder_package_entry_working_copy(entry: Dictionary) -> bool:
	var opened := _open_maps_folder_package_entry(entry)
	if opened:
		_cancel_editor_map_cursor_semantic()
		_select_map_package_picker_by_id(_selected_map_package_id)
	_refresh_state()
	return opened

## The package's session becomes the working copy, its copy the baseline.
func _open_maps_folder_package_entry(entry: Dictionary) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._open_maps_folder_package_entry", [self, entry])

func _resume_working_copy_from_memory(session, baseline_session = null, package_identity: Dictionary = {}) -> bool:
	if not _resume_working_copy_session(session, baseline_session, package_identity):
		return false
	_cancel_editor_map_cursor_semantic()
	_select_map_package_picker_by_id(_selected_map_package_id)
	_restore_editor_ui_metadata()
	_restored_from_play_copy = true
	_last_message = "Returned from Play Copy with the editor launch snapshot still in memory."
	_refresh_state()
	return true

## The play copy's launch snapshot becomes the working copy again, when it
## and its baseline are the same package's.
func _resume_working_copy_session(session, baseline_session, package_identity: Dictionary) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._resume_working_copy_session", [self, session, baseline_session, package_identity])

func _restore_editor_ui_metadata() -> void:
	var selected_tile_value = _session.flags.get("editor_selected_tile", {})
	if selected_tile_value is Dictionary:
		_selected_tile = Vector2i(
			int(selected_tile_value.get("x", OverworldRules.hero_position(_session).x)),
			int(selected_tile_value.get("y", OverworldRules.hero_position(_session).y))
		)
	else:
		_selected_tile = OverworldRules.hero_position(_session)
	if not _tile_in_bounds(_selected_tile):
		_selected_tile = OverworldRules.hero_position(_session)
	var restored_terrain_id := String(_session.flags.get("editor_selected_terrain_id", _selected_terrain_id))
	if not _select_terrain_by_id(restored_terrain_id):
		_select_terrain_by_id(DEFAULT_TERRAIN_ID)
	var restored_family := String(_session.flags.get("editor_selected_object_family", _selected_object_family))
	if _select_object_family_by_id(restored_family):
		var restored_content_id := String(_session.flags.get("editor_selected_object_content_id", _selected_object_content_id))
		if restored_content_id != "":
			_select_object_content_by_id(restored_content_id)
	_selected_property_object_key = String(_session.flags.get("editor_selected_property_object_key", ""))
	_pending_move_object_key = String(_session.flags.get("editor_pending_move_object_key", ""))
	_pending_duplicate_object_key = String(_session.flags.get("editor_pending_duplicate_object_key", ""))
	var pending_terrain_line_value = _session.flags.get("editor_pending_terrain_line_start", {})
	if pending_terrain_line_value is Dictionary:
		_pending_terrain_line_start = Vector2i(
			int(pending_terrain_line_value.get("x", -1)),
			int(pending_terrain_line_value.get("y", -1))
		)
	else:
		_pending_terrain_line_start = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_terrain_line_start):
		_pending_terrain_line_start = Vector2i(-1, -1)
	var pending_terrain_rectangle_value = _session.flags.get("editor_pending_terrain_rectangle_corner", {})
	if pending_terrain_rectangle_value is Dictionary:
		_pending_terrain_rectangle_corner = Vector2i(
			int(pending_terrain_rectangle_value.get("x", -1)),
			int(pending_terrain_rectangle_value.get("y", -1))
		)
	else:
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_terrain_rectangle_corner):
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
	var pending_road_path_value = _session.flags.get("editor_pending_road_path_start", {})
	if pending_road_path_value is Dictionary:
		_pending_road_path_start = Vector2i(
			int(pending_road_path_value.get("x", -1)),
			int(pending_road_path_value.get("y", -1))
		)
	else:
		_pending_road_path_start = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_road_path_start):
		_pending_road_path_start = Vector2i(-1, -1)
	_dirty = bool(_session.flags.get("editor_dirty", true))
	_terrain_paint_order = 0

func _refresh_state() -> void:
	_editor_edit_revision += 1
	_sync_tool_buttons()
	_sync_property_controls()
	_sync_object_taxonomy_summary()
	_sync_map_package_load_surface()
	_sync_save_copy_surface()
	_sync_play_handoff_surface()
	_sync_menu_return_surface()
	_sync_restore_tile_surface()
	_sync_terrain_paint_surface()
	_sync_preview()
	_refresh_labels()
	_configure_editor_keyboard_focus()
	_queue_editor_top_bar_layout_sync()
	_queue_editor_tool_rail_layout_sync()

func _sync_play_handoff_surface() -> void:
	if _play_button == null:
		return
	var handoff := _editor_play_handoff_payload()
	var gate := _editor_play_readiness_gate_payload()
	_play_button.disabled = _session == null
	_play_button.text = String(gate.get("button_label", handoff.get("button_label", "Play Copy")))
	var tooltip_lines := []
	var gate_text := String(gate.get("text", "")).strip_edges()
	if gate_text != "":
		tooltip_lines.append(gate_text)
	var handoff_tooltip := String(handoff.get("tooltip", "")).strip_edges()
	if handoff_tooltip != "":
		tooltip_lines.append(handoff_tooltip)
	var return_context := _editor_play_return_context_payload()
	var return_tooltip := String(return_context.get("tooltip", "")).strip_edges()
	if return_tooltip != "":
		tooltip_lines.append(return_tooltip)
	_play_button.tooltip_text = "\n".join(tooltip_lines) if not tooltip_lines.is_empty() else "Load a map package working copy before play-testing it."

func _sync_save_copy_surface() -> void:
	if _save_copy_button == null:
		return
	var contract := _save_copy_readiness_payload()
	var package_backed := _session != null and String(_session.flags.get("editor_source_kind", "")) == "maps_folder_package"
	_save_copy_button.disabled = not package_backed or not bool(contract.get("ready", false))
	_save_copy_button.text = "Save Copy"
	if not package_backed:
		_save_copy_button.tooltip_text = "Load a map package working copy before saving a new package pair."
	elif not bool(contract.get("ready", false)):
		_save_copy_button.tooltip_text = "Resolve editor validation blockers before saving a copy."
	else:
		_save_copy_button.tooltip_text = "Write a new non-overwriting map and scenario package pair, then continue editing that copy."

func _sync_map_package_load_surface() -> void:
	if _map_package_picker == null:
		return
	var check := _editor_scenario_validation_check_payload()
	var tooltip_lines := [String(check.get("tooltip", "Load a map package working copy to review editor validation."))]
	var selected_package_text := _selected_map_package_picker_text().strip_edges()
	if selected_package_text != "":
		tooltip_lines.push_front("Selected package: %s" % selected_package_text)
	var load_handoff := String(_editor_map_load_handoff_payload().get("tooltip", "")).strip_edges()
	if load_handoff != "":
		tooltip_lines.append(load_handoff)
	var focus_tooltip := String(_editor_selected_validation_focus_payload().get("tooltip", "")).strip_edges()
	if focus_tooltip != "":
		tooltip_lines.append(focus_tooltip)
	_map_package_picker.tooltip_text = "\n".join(tooltip_lines)
	if _load_map_button != null:
		_load_map_button.disabled = _selected_map_package_id == ""
		_load_map_button.text = "Load Map"
		_load_map_button.tooltip_text = load_handoff if load_handoff != "" else "Choose a map package from maps/, then load it into the editor working copy."

func _sync_menu_return_surface() -> void:
	if _menu_button == null:
		return
	var menu_return := _editor_menu_return_payload()
	_menu_button.disabled = false
	_menu_button.text = String(menu_return.get("button_label", "Menu"))
	_menu_button.tooltip_text = String(menu_return.get("tooltip", "Return to the main menu."))

func _sync_restore_tile_surface() -> void:
	if _restore_tile_button == null:
		return
	var cue := _editor_restore_tile_cue_payload()
	_restore_tile_button.disabled = _session == null
	_restore_tile_button.text = String(cue.get("button_label", "Restore Tile"))
	_restore_tile_button.tooltip_text = String(cue.get("tooltip", "Restore the selected tile from the loaded map baseline."))

func _sync_terrain_paint_surface() -> void:
	if _terrain_picker == null:
		return
	var cue := _editor_terrain_paint_check_payload()
	_terrain_picker.tooltip_text = String(cue.get("tooltip", "Choose the active terrain brush for editor painting."))

func _sync_object_taxonomy_summary() -> void:
	if _object_taxonomy_summary_label == null:
		return
	var payload := _object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id)
	var guidance := _placement_guidance_payload(payload, _selected_tile)
	var text := _object_palette_guidance_text(payload, guidance)
	if text == "":
		text = "Choose an object to see taxonomy, placement role, density, and links."
	_set_compact_label(_object_taxonomy_summary_label, text, 4)
	_object_content_picker.tooltip_text = text

func _sync_preview() -> void:
	if _session == null or _map_view == null:
		return
	var map_size := OverworldRules.derive_map_size(_session)
	var map_data: Array = _session.overworld.get("map", [])
	_map_view.set_route_preview_enabled(false)
	_map_view.set_map_state(_session, map_data, map_size, _selected_tile)
	_map_view.set_placement_debug_overlay_enabled(_placement_debug_overlay_enabled)
	_sync_preview_tooltip()

func _sync_preview_tooltip() -> void:
	if _session == null or _map_view == null:
		return
	var tooltip_sections := [String(_editor_active_tool_cue_payload().get("tooltip", ""))]
	if _tool in [TOOL_TERRAIN, TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE]:
		var terrain_paint_tooltip := String(_editor_terrain_paint_check_payload().get("tooltip", "")).strip_edges()
		if terrain_paint_tooltip != "":
			tooltip_sections.append(terrain_paint_tooltip)
	if _tool in [TOOL_ROAD, TOOL_ROAD_PATH]:
		var road_check_tooltip := String(_editor_road_check_payload().get("tooltip", "")).strip_edges()
		if road_check_tooltip != "":
			tooltip_sections.append(road_check_tooltip)
	if _tool == TOOL_PLACE_OBJECT:
		var object_preview_check := String(_editor_object_preview_check_payload().get("tooltip", "")).strip_edges()
		if object_preview_check != "":
			tooltip_sections.append(object_preview_check)
		var placement_action := String(_editor_placement_action_cue_payload().get("tooltip_text", "")).strip_edges()
		if placement_action != "":
			tooltip_sections.append(placement_action)
	_map_view.tooltip_text = "\n".join(tooltip_sections)

func _refresh_labels() -> void:
	var texts := _editor_label_texts()
	_header_label.text = String(texts.header)
	_header_label.tooltip_text = _header_label.text
	if _session == null:
		_set_compact_label(_tile_info_label, String(texts.tile_info), int(texts.tile_info_lines))
		_set_compact_label(_status_label, String(texts.status), int(texts.status_lines))
		return
	_set_compact_label(_status_label, String(texts.status), int(texts.status_lines))
	_set_compact_label(_tile_info_label, String(texts.tile_info), int(texts.tile_info_lines))

## The header's, the status's and the tile inspection's texts, with the lines
## each label shows.
func _editor_label_texts() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_label_texts", [self])

func _set_placement_debug_overlay_enabled(enabled: bool) -> void:
	_placement_debug_overlay_enabled = enabled
	if _map_view != null and _map_view.has_method("set_placement_debug_overlay_enabled"):
		_map_view.call("set_placement_debug_overlay_enabled", enabled)
	_last_message = "F4 blockers view %s." % ("enabled" if enabled else "disabled")
	_refresh_labels()

func _selected_map_package_label() -> String:
	return HumanEngine.native_writing(&"MapEditorShell._selected_map_package_label", [self])

func _map_package_label_for_id(package_id: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._map_package_label_for_id", [self, package_id])

func _tool_label(tool: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._tool_label", [self, tool])

func _select_tool(tool: String) -> void:
	_cancel_editor_map_cursor_semantic()
	_set_tool(tool)
	_sync_tool_buttons()
	_sync_terrain_paint_surface()
	_sync_object_taxonomy_summary()
	_sync_preview()
	_refresh_labels()

## The tool, and the two-click starts the other tools leave.
func _set_tool(tool: String) -> void:
	HumanEngine.native_writing(&"MapEditorShell._set_tool", [self, tool])

func _sync_tool_buttons() -> void:
	var buttons := {
		TOOL_INSPECT: _inspect_tool_button,
		TOOL_TERRAIN: _terrain_tool_button,
		TOOL_TERRAIN_LINE: _terrain_line_tool_button,
		TOOL_TERRAIN_RECTANGLE: _terrain_rectangle_tool_button,
		TOOL_ROAD: _road_tool_button,
		TOOL_ROAD_PATH: _road_path_tool_button,
		TOOL_HERO_START: _hero_start_tool_button,
		TOOL_PLACE_OBJECT: _place_object_tool_button,
		TOOL_REMOVE_OBJECT: _remove_object_tool_button,
		TOOL_MOVE_OBJECT: _move_object_tool_button,
		TOOL_DUPLICATE_OBJECT: _duplicate_object_tool_button,
		TOOL_RETHEME_OBJECT: _retheme_object_tool_button,
	}
	for tool_id in buttons.keys():
		var button: Button = buttons[tool_id]
		if button == null:
			continue
		button.button_pressed = tool_id == _tool
		var tooltip := String(_editor_active_tool_cue_payload(String(tool_id)).get("tooltip", _tool_label(String(tool_id))))
		if tool_id in [TOOL_TERRAIN, TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE]:
			var terrain_check := String(_editor_terrain_paint_check_payload(String(tool_id)).get("tooltip", "")).strip_edges()
			if terrain_check != "":
				tooltip = "%s\n%s" % [tooltip, terrain_check]
		if tool_id in [TOOL_ROAD, TOOL_ROAD_PATH]:
			var road_check := String(_editor_road_check_payload(String(tool_id)).get("tooltip", "")).strip_edges()
			if road_check != "":
				tooltip = "%s\n%s" % [tooltip, road_check]
		if tool_id == TOOL_PLACE_OBJECT:
			var object_preview_check := String(_editor_object_preview_check_payload().get("tooltip", "")).strip_edges()
			if object_preview_check != "":
				tooltip = "%s\n%s" % [tooltip, object_preview_check]
			var placement_action := String(_editor_placement_action_cue_payload().get("tooltip_text", "")).strip_edges()
			if placement_action != "":
				tooltip = "%s\n%s" % [tooltip, placement_action]
		button.tooltip_text = tooltip

func _on_map_package_selected(index: int) -> void:
	if index < 0 or index >= _map_package_picker.get_item_count():
		return
	_selected_map_package_id = String(_map_package_picker.get_item_metadata(index))
	if _selected_map_package_id != "":
		_last_message = "Selected map package %s. Press Load Map to open it." % _selected_map_package_label()
	else:
		_last_message = "No map package selected."
	_refresh_state()

func _on_load_map_pressed() -> Dictionary:
	if _selected_map_package_id == "":
		_last_message = "No map package selected. Generate a map so maps/ contains a paired .amap and .ascenario package."
		_refresh_state()
		return {
			"ok": false,
			"handled": true,
			"pending": false,
			"reason": "package_not_selected",
			"message": _last_message,
		}
	if _dirty:
		return _request_dirty_transition(
			DIRTY_TRANSITION_PACKAGE,
			_selected_map_package_id,
			_map_package_label_for_id(_selected_map_package_id),
			"load_map",
			_load_map_button
		)
	var loaded := _load_maps_folder_package_working_copy(_selected_map_package_id)
	return {
		"ok": loaded,
		"handled": true,
		"pending": false,
		"direct": true,
		"action": DIRTY_TRANSITION_PACKAGE,
		"package_id": _selected_map_package_id,
		"reason": "loaded" if loaded else "load_failed",
		"message": _last_message,
		"load_attempt_delta": 1,
	}

func _on_save_copy_pressed() -> void:
	_save_package_working_copy()

func _save_package_working_copy(target_dir_override: String = "", target_stem_override: String = "") -> Dictionary:
	var written := _write_package_copy(target_dir_override, target_stem_override)
	if not bool(written.get("ok", false)):
		_refresh_state()
		return written
	var saved_entry: Dictionary = written.saved_entry
	if not _load_maps_folder_package_entry_working_copy(saved_entry):
		return _finish_save_copy_failure("saved_pair_adoption_failed", "The saved package pair could not be adopted as the editor baseline.", written.output_paths, {"index": written.index})
	var default_dir := String(ScenarioSelectRulesScript.generated_map_package_directory_policy().get("active_dir", ""))
	if String(written.target_dir) == default_dir:
		_rebuild_map_package_picker()
		_select_map_package_picker_by_id(String(saved_entry.get("package_id", "")))
	var result := _finish_package_copy(written)
	_refresh_state()
	return result

## Save Copy's package pair written, reloaded, checked and found in the
## index; a failure removes what it wrote.
func _write_package_copy(target_dir_override: String, target_stem_override: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._write_package_copy", [self, target_dir_override, target_stem_override])

## The adopted copy is the clean working copy and its own baseline.
func _finish_package_copy(written: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._finish_package_copy", [self, written])

func _finish_save_copy_failure(code: String, message: String, cleanup_paths: Array = [], details: Dictionary = {}) -> Dictionary:
	var result := _save_copy_failure(code, message, cleanup_paths, details)
	_refresh_state()
	return result

## A failed Save Copy: what it wrote removed, the failure kept and shown.
func _save_copy_failure(code: String, message: String, cleanup_paths: Array = [], details: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._save_copy_failure", [self, code, message, cleanup_paths, details])

func _on_terrain_selected(index: int) -> void:
	if index < 0 or index >= _terrain_picker.get_item_count():
		return
	_selected_terrain_id = String(_terrain_picker.get_item_metadata(index))
	var terrain_tool := _tool if _tool in [TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE] else TOOL_TERRAIN
	_select_tool(terrain_tool)
	_last_message = "Terrain brush set to %s." % _terrain_label_for_id(_selected_terrain_id)
	_refresh_state()

func _on_object_family_selected(index: int) -> void:
	if index < 0 or index >= _object_family_picker.get_item_count():
		return
	_selected_object_family = String(_object_family_picker.get_item_metadata(index))
	_selected_object_content_id = ""
	_rebuild_object_content_picker()
	_select_tool(TOOL_RETHEME_OBJECT if _tool == TOOL_RETHEME_OBJECT else TOOL_PLACE_OBJECT)
	_last_message = "Object family set to %s." % _object_family_label(_selected_object_family)
	_refresh_state()

func _on_object_content_selected(index: int) -> void:
	if index < 0 or index >= _object_content_picker.get_item_count():
		return
	_selected_object_content_id = String(_object_content_picker.get_item_metadata(index))
	_select_tool(TOOL_RETHEME_OBJECT if _tool == TOOL_RETHEME_OBJECT else TOOL_PLACE_OBJECT)
	_last_message = "Object palette set to %s." % _selected_object_content_id
	_refresh_state()

func _on_selected_property_object_selected(index: int) -> void:
	if index < 0 or index >= _selected_object_picker.get_item_count():
		return
	_selected_property_object_key = String(_selected_object_picker.get_item_metadata(index))
	_last_message = "Selected runtime properties for %s." % _selected_property_object_key
	_refresh_state()

func _on_apply_object_properties_pressed() -> void:
	var detail := _selected_property_object_detail()
	var owner := ""
	var difficulty := ""
	if not detail.is_empty():
		owner = _selected_picker_metadata(_property_owner_picker, String(detail.get("owner", "neutral")))
		difficulty = _selected_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
	_edit_selected_object_properties(owner, difficulty, _property_collected_check.button_pressed)
	_refresh_state()

## The property controls' values on the selected object, with the recap.
func _edit_selected_object_properties(owner: String, difficulty: String, collected: bool) -> void:
	HumanEngine.native_writing(&"MapEditorShell._edit_selected_object_properties", [self, owner, difficulty, collected])

func _on_fill_terrain_pressed() -> void:
	_fill_terrain_tool()
	_refresh_state()

## Fill Terrain: the selected tile's region in the brush's terrain.
func _fill_terrain_tool() -> void:
	HumanEngine.native_writing(&"MapEditorShell._fill_terrain_tool", [self])

func _on_restore_selected_tile_pressed() -> void:
	_restore_tile_tool()
	_refresh_state()

## Restore Tile: the selected tile as the baseline has it.
func _restore_tile_tool() -> void:
	HumanEngine.native_writing(&"MapEditorShell._restore_tile_tool", [self])

func _on_map_tile_hovered(tile: Vector2i) -> void:
	# Hover only moves the placement or paint preview. The map state, selection and
	# validation are unchanged, so refresh the hover-dependent text and tooltips
	# without re-pushing the map view; validation comes from the memo.
	_hovered_tile = tile
	if _tool == TOOL_PLACE_OBJECT:
		_sync_object_taxonomy_summary()
		_sync_tool_buttons()
		_sync_preview_tooltip()
		_refresh_labels()
	elif _tool in [TOOL_TERRAIN, TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE]:
		_sync_terrain_paint_surface()
		_sync_tool_buttons()
		_sync_preview_tooltip()
		_refresh_labels()

func _on_map_tile_pressed(tile: Vector2i) -> void:
	if _session == null or not _tile_in_bounds(tile):
		return
	_cancel_editor_map_cursor_semantic()
	var action_succeeded := _apply_map_tool(tile)
	_record_editor_map_action_result(action_succeeded, tile)
	_refresh_state()

## The active tool on a clicked tile; false when the click did nothing.
func _apply_map_tool(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._apply_map_tool", [self, tile])

func _record_editor_map_action_result(action_succeeded: bool, tile: Vector2i) -> void:
	var message := _last_message.strip_edges()
	if action_succeeded or message == "":
		return
	UiAudio.play_invalid("MapEditorShell._record_editor_map_action_result", {
		"lane": "canvas",
		"tool": _tool,
		"tile": _editor_tile_payload(tile),
		"message": message,
	})

func _paint_terrain(tile: Vector2i, terrain_id: String) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._paint_terrain", [self, tile, terrain_id])

func _materialize_last_terrain_final_normalization() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._materialize_last_terrain_final_normalization", [self])

func _apply_terrain_line(start_tile: Vector2i, end_tile: Vector2i, terrain_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._apply_terrain_line", [self, start_tile, end_tile, terrain_id])

func _apply_terrain_rectangle(corner_tile: Vector2i, opposite_tile: Vector2i, terrain_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._apply_terrain_rectangle", [self, corner_tile, opposite_tile, terrain_id])

func _terrain_rectangle_bounds(corner_tile: Vector2i, opposite_tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_rectangle_bounds", [self, corner_tile, opposite_tile])

func _fill_terrain_region(start_tile: Vector2i, terrain_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._fill_terrain_region", [self, start_tile, terrain_id])

func _toggle_road(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._toggle_road", [self, tile])

func _apply_road_path(start_tile: Vector2i, end_tile: Vector2i, requested_action: String = "toggle") -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._apply_road_path", [self, start_tile, end_tile, requested_action])

func _has_pending_terrain_line_start() -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._has_pending_terrain_line_start", [self])

func _pending_terrain_line_start_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._pending_terrain_line_start_payload", [self])

func _has_pending_terrain_rectangle_corner() -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._has_pending_terrain_rectangle_corner", [self])

func _pending_terrain_rectangle_corner_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._pending_terrain_rectangle_corner_payload", [self])

func _has_pending_road_path_start() -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._has_pending_road_path_start", [self])

func _pending_road_path_start_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._pending_road_path_start_payload", [self])

func _set_hero_start(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._set_hero_start", [self, tile])

func _place_object(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._place_object", [self, tile])

func _remove_object(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._remove_object", [self, tile])

func _preferred_move_detail_at(tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._preferred_move_detail_at", [self, tile])

func _move_object_by_key(property_key: String, destination_tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._move_object_by_key", [self, property_key, destination_tile])

func _duplicate_object_by_key(property_key: String, destination_tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._duplicate_object_by_key", [self, property_key, destination_tile])

func _object_detail_for_family_at(tile: Vector2i, family: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._object_detail_for_family_at", [self, tile, family])

func _retheme_object_by_key(property_key: String, replacement_content_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._retheme_object_by_key", [self, property_key, replacement_content_id])

func _apply_selected_object_properties(detail: Dictionary) -> Dictionary:
	var owner := _selected_picker_metadata(_property_owner_picker, String(detail.get("owner", "neutral")))
	var difficulty := _selected_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
	return _apply_object_properties(detail, owner, difficulty, _property_collected_check.button_pressed)

## The property controls' values on the selected object.
func _apply_object_properties(detail: Dictionary, owner: String, difficulty: String, collected: bool) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._apply_object_properties", [self, detail, owner, difficulty, collected])

func _restore_selected_tile_from_authored() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._restore_selected_tile_from_authored", [self])

func _set_tile_terrain(tile: Vector2i, terrain_id: String) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._set_tile_terrain", [self, tile, terrain_id])

func _on_play_working_copy_pressed() -> void:
	if _session == null:
		return
	if not _stage_working_copy_for_play():
		_refresh_state()
		return
	AppRouter.go_to_overworld()

## The working copy and its baseline staged for the return, and a copy of it
## the active session.
func _stage_working_copy_for_play() -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._stage_working_copy_for_play", [self])

func _editor_play_readiness_gate_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_play_readiness_gate_payload", [self])

func _editor_scenario_validation_check_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_scenario_validation_check_payload", [self])

## Save Copy's gate: the editor validation's warnings as blockers, memoised
## per edit revision. (Owner decision D-h, 2026-10-23: the authored-scenario
## export is deleted; its validation stays the gate of Save Copy.)
func _save_copy_readiness_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._save_copy_readiness_payload", [self])

func _editor_map_load_handoff_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_map_load_handoff_payload", [self])

func _editor_scenario_switch_handoff_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_scenario_switch_handoff_payload", [self])

func _editor_selected_validation_focus_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_selected_validation_focus_payload", [self])

func _editor_play_handoff_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_play_handoff_payload", [self])

func _editor_play_return_context_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_play_return_context_payload", [self])

func _editor_restore_tile_cue_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_restore_tile_cue_payload", [self])

func _editor_menu_return_payload() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_menu_return_payload", [self])

func _editor_active_tool_cue_payload(tool: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._editor_active_tool_cue_payload", [self, tool])

func _on_menu_pressed() -> Dictionary:
	if _dirty:
		return _request_dirty_transition(
			DIRTY_TRANSITION_MENU,
			"",
			"",
			"menu",
			_menu_button
		)
	return _perform_clean_menu_transition()

func request_safe_close_guard(source: String) -> Dictionary:
	if not _dirty:
		return {
			"handled": false,
			"pending": false,
			"reason": "clean",
			"action": DIRTY_TRANSITION_QUIT,
			"message": "",
		}
	return _request_dirty_transition(
		DIRTY_TRANSITION_QUIT,
		"",
		"",
		source.strip_edges().left(64),
		_capture_dirty_transition_origin(_menu_button)
	)

func consume_safe_close_guard_confirmation(source: String) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell.consume_safe_close_guard_confirmation", [self, source])

func _request_dirty_transition(
	action: String,
	package_id: String = "",
	package_label: String = "",
	source: String = "",
	origin: Control = null
) -> Dictionary:
	if not _pending_dirty_transition.is_empty():
		_validation_dirty_transition_duplicate_request_count += 1
		var duplicate_result := {
			"ok": false,
			"handled": true,
			"pending": true,
			"reason": "transition_pending",
			"action": String(_pending_dirty_transition.get("action", "")),
			"package_id": String(_pending_dirty_transition.get("package_id", "")),
			"package_label": String(_pending_dirty_transition.get("package_label", "")),
			"source": String(_pending_dirty_transition.get("source", "")),
			"message": DIRTY_TRANSITION_PENDING_MESSAGE,
			"route_attempt_delta": 0,
			"load_attempt_delta": 0,
		}
		_last_dirty_transition_result = duplicate_result.duplicate(true)
		return duplicate_result
	if not _dirty:
		return {
			"ok": true,
			"handled": false,
			"pending": false,
			"reason": "clean",
			"action": action,
			"message": "",
			"route_attempt_delta": 0,
			"load_attempt_delta": 0,
		}
	if not action in [DIRTY_TRANSITION_MENU, DIRTY_TRANSITION_PACKAGE, DIRTY_TRANSITION_QUIT]:
		return {
			"ok": false,
			"handled": false,
			"pending": false,
			"reason": "invalid_action",
			"action": action,
			"message": "Unknown editor transition.",
			"route_attempt_delta": 0,
			"load_attempt_delta": 0,
		}
	var normalized_package_id := package_id.strip_edges().left(160)
	if action == DIRTY_TRANSITION_PACKAGE and normalized_package_id == "":
		return {
			"ok": false,
			"handled": false,
			"pending": false,
			"reason": "package_not_selected",
			"action": action,
			"message": "Choose a map package before replacing this working copy.",
			"route_attempt_delta": 0,
			"load_attempt_delta": 0,
		}
	_stop_editor_map_joypad_repeat()
	_cancel_editor_map_cursor_semantic()
	_dirty_transition_return_focus = _capture_dirty_transition_origin(origin)
	_pending_dirty_transition = {
		"action": action,
		"package_id": normalized_package_id,
		"package_label": package_label.strip_edges().left(120),
		"source": source.strip_edges().left(64),
	}
	_validation_dirty_transition_request_count += 1
	_safe_close_guard_authorized = false
	_safe_close_guard_authorized_source = ""
	_apply_dirty_transition_copy(_pending_dirty_transition)
	_dirty_transition_dialog.popup_centered(Vector2i(680, 250))
	_focus_dirty_transition_cancel()
	var result := {
		"ok": true,
		"handled": true,
		"pending": true,
		"reason": "editor_dirty",
		"action": action,
		"package_id": normalized_package_id,
		"package_label": String(_pending_dirty_transition.get("package_label", "")),
		"source": String(_pending_dirty_transition.get("source", "")),
		"message": "Unsaved editor changes need confirmation.",
		"route_attempt_delta": 0,
		"load_attempt_delta": 0,
	}
	_last_dirty_transition_result = result.duplicate(true)
	return result

func _apply_dirty_transition_copy(pending: Dictionary) -> void:
	var action := String(pending.get("action", ""))
	_dirty_transition_dialog.get_cancel_button().text = DIRTY_TRANSITION_CANCEL_TEXT
	match action:
		DIRTY_TRANSITION_MENU:
			_dirty_transition_dialog.title = "Leave Unsaved Map?"
			_dirty_transition_dialog.dialog_text = "This working copy has unsaved changes. Leave for the Main Menu and discard them?"
			_dirty_transition_dialog.get_ok_button().text = "Leave for Menu"
		DIRTY_TRANSITION_PACKAGE:
			var label := String(pending.get("package_label", pending.get("package_id", "selected map")))
			_dirty_transition_dialog.title = "Replace Unsaved Map?"
			_dirty_transition_dialog.dialog_text = "This working copy has unsaved changes. Load %s and discard them?" % label
			_dirty_transition_dialog.get_ok_button().text = "Load Map"
		DIRTY_TRANSITION_QUIT:
			_dirty_transition_dialog.title = "Quit With Unsaved Changes?"
			_dirty_transition_dialog.dialog_text = "This working copy has unsaved changes. Quit the game and discard them?"
			_dirty_transition_dialog.get_ok_button().text = "Quit Game"

func _capture_dirty_transition_origin(fallback: Control) -> Control:
	var focus_owner := get_viewport().gui_get_focus_owner() as Control
	if (
		is_instance_valid(focus_owner)
		and focus_owner.is_inside_tree()
		and focus_owner.is_visible_in_tree()
		and focus_owner.focus_mode != Control.FOCUS_NONE
		and is_ancestor_of(focus_owner)
	):
		return focus_owner
	return fallback

func _focus_dirty_transition_cancel() -> void:
	if not _dirty_transition_dialog.visible or _pending_dirty_transition.is_empty():
		return
	_dirty_transition_dialog.get_cancel_button().grab_focus()
	await get_tree().process_frame
	if _dirty_transition_dialog.visible and not _pending_dirty_transition.is_empty():
		_dirty_transition_dialog.get_cancel_button().grab_focus()

func _restore_dirty_transition_origin(target: Control) -> void:
	await get_tree().process_frame
	if (
		is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	):
		target.grab_focus()

func _on_dirty_transition_canceled() -> Dictionary:
	if _pending_dirty_transition.is_empty():
		return {
			"ok": false,
			"canceled": false,
			"pending": false,
			"reason": "no_pending_transition",
		}
	var pending := _pending_dirty_transition.duplicate(true)
	var return_focus := _dirty_transition_return_focus
	_pending_dirty_transition = {}
	_dirty_transition_return_focus = null
	_safe_close_guard_authorized = false
	_safe_close_guard_authorized_source = ""
	_validation_dirty_transition_cancel_count += 1
	_dirty_transition_dialog.hide()
	var result := {
		"ok": true,
		"canceled": true,
		"pending": false,
		"action": String(pending.get("action", "")),
		"package_id": String(pending.get("package_id", "")),
		"reason": "canceled",
		"message": "Kept the current editor working copy.",
		"route_attempt_delta": 0,
		"load_attempt_delta": 0,
	}
	_last_dirty_transition_result = result.duplicate(true)
	_restore_dirty_transition_origin(return_focus)
	return result

func _on_dirty_transition_confirmed() -> Dictionary:
	if _pending_dirty_transition.is_empty():
		return {
			"ok": false,
			"pending": false,
			"confirmed": false,
			"reason": "no_pending_transition",
			"route_attempt_delta": 0,
			"load_attempt_delta": 0,
		}
	var pending := _pending_dirty_transition.duplicate(true)
	var return_focus := _dirty_transition_return_focus
	_pending_dirty_transition = {}
	_dirty_transition_return_focus = null
	_dirty_transition_dialog.hide()
	_validation_dirty_transition_confirm_count += 1
	var action := String(pending.get("action", ""))
	var result := {}
	match action:
		DIRTY_TRANSITION_MENU:
			result = _perform_clean_menu_transition()
			result["confirmed"] = true
		DIRTY_TRANSITION_PACKAGE:
			_validation_dirty_transition_package_action_count += 1
			var package_id := String(pending.get("package_id", ""))
			var loaded := _load_maps_folder_package_working_copy(package_id)
			result = {
				"ok": loaded,
				"handled": true,
				"pending": false,
				"confirmed": true,
				"action": action,
				"package_id": package_id,
				"package_label": String(pending.get("package_label", "")),
				"reason": "loaded" if loaded else "load_failed",
				"message": _last_message,
				"route_attempt_delta": 0,
				"load_attempt_delta": 1,
			}
			if not loaded:
				_restore_dirty_transition_origin(return_focus)
		DIRTY_TRANSITION_QUIT:
			_validation_dirty_transition_quit_attempt_count += 1
			_safe_close_guard_authorized = true
			_safe_close_guard_authorized_source = DIRTY_TRANSITION_QUIT_SOURCE
			var quit_value: Variant = AppRouter.request_safe_quit_after_close_guard(DIRTY_TRANSITION_QUIT_SOURCE)
			var quit_result: Dictionary = quit_value if quit_value is Dictionary else {}
			result = quit_result.duplicate(true)
			result["confirmed"] = true
			result["pending"] = false
			result["action"] = action
			result["route_attempt_delta"] = 0
			result["load_attempt_delta"] = 0
			if not bool(result.get("ok", false)):
				_last_message = String(result.get("message", "The editor remains open because the application could not close.")).strip_edges().left(240)
				_refresh_state()
				_restore_dirty_transition_origin(return_focus)
		_:
			result = {
				"ok": false,
				"confirmed": false,
				"pending": false,
				"action": action,
				"reason": "invalid_action",
				"message": "Unknown editor transition.",
				"route_attempt_delta": 0,
				"load_attempt_delta": 0,
			}
	_last_dirty_transition_result = result.duplicate(true)
	return result

func _perform_clean_menu_transition() -> Dictionary:
	_validation_dirty_transition_menu_route_count += 1
	if _validation_dirty_transition_routing_enabled:
		AppRouter.go_to_main_menu()
	return {
		"ok": true,
		"handled": true,
		"pending": false,
		"routed": true,
		"route_suppressed": not _validation_dirty_transition_routing_enabled,
		"action": DIRTY_TRANSITION_MENU,
		"reason": "main_menu",
		"message": "Returning to the Main Menu.",
		"route_attempt_delta": 1,
		"load_attempt_delta": 0,
	}

func _object_details_at(tile: Vector2i, include_hero: bool = true) -> Array:
	return HumanEngine.native_writing(&"MapEditorShell._object_details_at", [self, tile, include_hero])

func _object_property_key(kind: String, placement_id: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._object_property_key", [self, kind, placement_id])

func _object_family_label(family: String) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._object_family_label", [self, family])

func _has_road_at(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._has_road_at", [self, tile])

func _road_tile_count() -> int:
	return HumanEngine.native_writing(&"MapEditorShell._road_tile_count", [self])

func _placement_count() -> int:
	return HumanEngine.native_writing(&"MapEditorShell._placement_count", [self])

func _terrain_at(tile: Vector2i) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_at", [self, tile])

func _terrain_id_in_grammar(terrain_id: String) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._terrain_id_in_grammar", [self, terrain_id])

func _tile_in_bounds(tile: Vector2i) -> bool:
	return HumanEngine.native_writing(&"MapEditorShell._tile_in_bounds", [self, tile])

func _tile_key(tile: Vector2i) -> String:
	return HumanEngine.native_writing(&"MapEditorShell._tile_key", [self, tile])

func _set_compact_label(label: Label, text: String, max_lines: int) -> void:
	label.text = text
	label.tooltip_text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.max_lines_visible = max_lines

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_confirmation_dialog(_dirty_transition_dialog, "danger")
	FrontierVisualKit.apply_art_panel(_editor_shell_panel, EDITOR_SHELL_FRAME_PATH, "frame", 24, 8, Color(0.90, 0.92, 0.94, 0.96))
	FrontierVisualKit.apply_art_panel(_editor_top_panel, EDITOR_TOP_FRAME_PATH, "banner", 24, 8)
	FrontierVisualKit.apply_art_panel(_editor_map_panel, EDITOR_MAP_FRAME_PATH, "frame", 24, 8)
	FrontierVisualKit.apply_art_panel(_editor_tool_rail, EDITOR_TOOL_RAIL_FRAME_PATH, "earth", 24, 8)
	var primary_buttons := [_load_map_button, _save_copy_button, _play_button, _property_apply_button]
	var secondary_buttons := [
		_inspect_tool_button,
		_terrain_tool_button,
		_terrain_line_tool_button,
		_terrain_rectangle_tool_button,
		_road_tool_button,
		_road_path_tool_button,
		_hero_start_tool_button,
		_place_object_tool_button,
		_remove_object_tool_button,
		_move_object_tool_button,
		_duplicate_object_tool_button,
		_retheme_object_tool_button,
		_fill_terrain_button,
		_restore_tile_button,
		_menu_button,
	]
	for button in primary_buttons:
		_apply_editor_button_surface(button, "primary")
	for button in secondary_buttons:
		_apply_editor_button_surface(button, "secondary")
	for picker in [
		_map_package_picker,
		_terrain_picker,
		_object_family_picker,
		_object_content_picker,
		_selected_object_picker,
		_property_owner_picker,
		_property_difficulty_picker,
	]:
		_apply_editor_option_surface(picker)

func _apply_editor_button_surface(button: BaseButton, role: String) -> void:
	if button == null:
		return
	var minimum := button.custom_minimum_size
	var font_size := button.get_theme_font_size("font_size")
	button.focus_mode = Control.FOCUS_ALL
	FrontierVisualKit.apply_button(button, role, minimum.x, minimum.y, font_size)

func _apply_editor_option_surface(picker: OptionButton) -> void:
	if picker == null:
		return
	var minimum := picker.custom_minimum_size
	var font_size := picker.get_theme_font_size("font_size")
	FrontierVisualKit.apply_option_button(picker, "secondary", minimum.x, minimum.y, font_size)

func validation_request_dirty_transition(action: String, target_package_id: String = "") -> Dictionary:
	match action:
		DIRTY_TRANSITION_MENU:
			return _request_dirty_transition(action, "", "", "validation_menu", _menu_button)
		DIRTY_TRANSITION_PACKAGE:
			var package_id := target_package_id.strip_edges()
			if package_id == "":
				package_id = _selected_map_package_id
			return _request_dirty_transition(
				action,
				package_id,
				_map_package_label_for_id(package_id),
				"validation_package",
				_load_map_button
			)
		DIRTY_TRANSITION_QUIT:
			return request_safe_close_guard("window_close")
	return {
		"ok": false,
		"handled": false,
		"pending": false,
		"reason": "invalid_action",
		"action": action,
		"message": "Unknown editor transition.",
		"route_attempt_delta": 0,
		"load_attempt_delta": 0,
	}

func validation_cancel_dirty_transition() -> Dictionary:
	return _on_dirty_transition_canceled()

func validation_confirm_dirty_transition() -> Dictionary:
	return _on_dirty_transition_confirmed()

func validation_set_dirty_transition_routing_enabled(enabled: bool) -> void:
	_validation_dirty_transition_routing_enabled = enabled

func validation_select_map_package_id(package_id: String) -> Dictionary:
	if not _select_map_package_picker_by_id(package_id):
		return {
			"ok": false,
			"selected_map_package_id": _selected_map_package_id,
			"reason": "package_not_indexed",
			"message": "Map package is not available in the editor picker.",
		}
	_selected_map_package_id = package_id
	_last_message = "Selected map package %s. Press Load Map to open it." % _map_package_label_for_id(package_id)
	_refresh_state()
	return {
		"ok": true,
		"selected_map_package_id": _selected_map_package_id,
		"package_label": _map_package_label_for_id(package_id),
		"message": _last_message,
	}

func validation_reset_dirty_transition_state() -> void:
	_dirty_transition_dialog.hide()
	_pending_dirty_transition = {}
	_dirty_transition_return_focus = null
	_safe_close_guard_authorized = false
	_safe_close_guard_authorized_source = ""
	_validation_dirty_transition_request_count = 0
	_validation_dirty_transition_cancel_count = 0
	_validation_dirty_transition_confirm_count = 0
	_validation_dirty_transition_duplicate_request_count = 0
	_validation_dirty_transition_menu_route_count = 0
	_validation_dirty_transition_package_action_count = 0
	_validation_dirty_transition_quit_attempt_count = 0
	_last_dirty_transition_result = {}

func validation_dirty_transition_snapshot() -> Dictionary:
	var pending := _pending_dirty_transition.duplicate(true)
	var cancel_button := _dirty_transition_dialog.get_cancel_button()
	var dialog_focus_owner := cancel_button.get_viewport().gui_get_focus_owner()
	var origin_focus_owner := get_viewport().gui_get_focus_owner()
	var session_payload: Dictionary = _session.to_dict() if _session != null else {}
	return {
		"pending": not pending.is_empty(),
		"dialog_visible": _dirty_transition_dialog.visible,
		"action": String(pending.get("action", "")),
		"package_id": String(pending.get("package_id", "")),
		"package_label": String(pending.get("package_label", "")),
		"source": String(pending.get("source", "")),
		"title": _dirty_transition_dialog.title,
		"text": _dirty_transition_dialog.dialog_text,
		"confirm_text": _dirty_transition_dialog.get_ok_button().text,
		"cancel_text": cancel_button.text,
		"dialog_focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"return_focus_name": String(_dirty_transition_return_focus.name) if is_instance_valid(_dirty_transition_return_focus) else "",
		"origin_focus_owner": String(origin_focus_owner.name) if origin_focus_owner != null else "",
		"dialog_position": _dirty_transition_dialog.position,
		"dialog_size": _dirty_transition_dialog.size,
		"dirty": _dirty,
		"selected_map_package_id": _selected_map_package_id,
		"tool": _tool,
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"working_copy_signature": JSON.stringify(session_payload).sha256_text(),
		"request_count": _validation_dirty_transition_request_count,
		"cancel_count": _validation_dirty_transition_cancel_count,
		"confirm_count": _validation_dirty_transition_confirm_count,
		"duplicate_request_count": _validation_dirty_transition_duplicate_request_count,
		"menu_route_count": _validation_dirty_transition_menu_route_count,
		"package_action_count": _validation_dirty_transition_package_action_count,
		"quit_attempt_count": _validation_dirty_transition_quit_attempt_count,
		"safe_close_authorized": _safe_close_guard_authorized,
		"routing_enabled": _validation_dirty_transition_routing_enabled,
		"last_result": _last_dirty_transition_result.duplicate(true),
	}

func validation_snapshot() -> Dictionary:
	_editor_edit_revision += 1
	var map_size := OverworldRules.derive_map_size(_session) if _session != null else Vector2i.ZERO
	var hero_pos := OverworldRules.hero_position(_session) if _session != null else Vector2i.ZERO
	var terrain_placement := _materialize_last_terrain_final_normalization()
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id if _session != null else "",
		"selected_map_package_id": _selected_map_package_id,
		"selected_scenario_id": _selected_map_package_id,
		"editor_source_kind": String(_session.flags.get("editor_source_kind", "")) if _session != null else "",
		"editor_source_package_id": String(_session.flags.get("editor_source_package_id", "")) if _session != null else "",
		"editor_source_map_path": String(_session.flags.get("editor_source_map_path", "")) if _session != null else "",
		"editor_source_scenario_path": String(_session.flags.get("editor_source_scenario_path", "")) if _session != null else "",
		"map_package_ref": _session.flags.get("map_package_ref", {}) if _session != null else {},
		"scenario_package_ref": _session.flags.get("scenario_package_ref", {}) if _session != null else {},
		"maps_folder_package_browser": bool(_session.flags.get("maps_folder_package_browser", false)) if _session != null else false,
		"working_copy": _session != null,
		"restored_from_play_copy": _restored_from_play_copy,
		"return_model": String(_session.flags.get("editor_return_model", "")) if _session != null else "",
		"dirty": _dirty,
		"dirty_transition": validation_dirty_transition_snapshot(),
		"status_text": _last_message,
		"visible_status_text": _status_label.text if _status_label != null else "",
		"visible_status_full": _status_label.tooltip_text if _status_label != null else "",
		"scenario_validation_check": _editor_scenario_validation_check_payload(),
		"scenario_validation_check_text": String(_editor_scenario_validation_check_payload().get("text", "")),
		"scenario_switch_handoff": _editor_scenario_switch_handoff_payload(),
		"scenario_switch_handoff_text": String(_editor_scenario_switch_handoff_payload().get("text", "")),
		"scenario_switch_handoff_tooltip": String(_editor_scenario_switch_handoff_payload().get("tooltip", "")),
		"map_load_handoff": _editor_map_load_handoff_payload(),
		"map_load_handoff_text": String(_editor_map_load_handoff_payload().get("text", "")),
		"map_load_handoff_tooltip": String(_editor_map_load_handoff_payload().get("tooltip", "")),
		"selected_validation_focus": _editor_selected_validation_focus_payload(),
		"selected_validation_focus_text": String(_editor_selected_validation_focus_payload().get("text", "")),
		"selected_validation_focus_tooltip": String(_editor_selected_validation_focus_payload().get("tooltip", "")),
		"map_package_picker_tooltip": _map_package_picker.tooltip_text if _map_package_picker != null else "",
		"map_package_picker_item_count": _map_package_picker.get_item_count() if _map_package_picker != null else 0,
		"map_package_picker_labels": _map_package_picker_labels(),
		"map_package_picker_metadata": _map_package_picker_metadata(),
		"load_map_button_text": _load_map_button.text if _load_map_button != null else "",
		"load_map_button_disabled": _load_map_button.disabled if _load_map_button != null else true,
		"save_copy_button_text": _save_copy_button.text if _save_copy_button != null else "",
		"save_copy_button_disabled": _save_copy_button.disabled if _save_copy_button != null else true,
		"save_copy_button_tooltip": _save_copy_button.tooltip_text if _save_copy_button != null else "",
		"last_save_copy_result": _last_save_copy_result.duplicate(true),
		"load_map_flow_active": true,
		"legacy_scenario_dropdown_active": false,
		"authored_json_scenarios_used": false,
		"map_package_index_status": _public_map_package_index_status(),
		"scenario_picker_tooltip": _map_package_picker.tooltip_text if _map_package_picker != null else "",
		"play_readiness_gate": _editor_play_readiness_gate_payload(),
		"play_readiness_gate_text": String(_editor_play_readiness_gate_payload().get("text", "")),
		"play_handoff": _editor_play_handoff_payload(),
		"play_handoff_text": String(_editor_play_handoff_payload().get("text", "")),
		"play_return_context": _editor_play_return_context_payload(),
		"play_return_context_text": String(_editor_play_return_context_payload().get("text", "")),
		"play_button_text": _play_button.text if _play_button != null else "",
		"play_button_tooltip": _play_button.tooltip_text if _play_button != null else "",
		"menu_return": _editor_menu_return_payload(),
		"menu_return_text": String(_editor_menu_return_payload().get("text", "")),
		"menu_button_text": _menu_button.text if _menu_button != null else "",
		"menu_button_tooltip": _menu_button.tooltip_text if _menu_button != null else "",
		"restore_tile_cue": _editor_restore_tile_cue_payload(),
		"restore_tile_cue_text": String(_editor_restore_tile_cue_payload().get("text", "")),
		"restore_tile_button_text": _restore_tile_button.text if _restore_tile_button != null else "",
		"restore_tile_button_tooltip": _restore_tile_button.tooltip_text if _restore_tile_button != null else "",
		"terrain_paint_check": _editor_terrain_paint_check_payload(),
		"terrain_paint_check_text": String(_editor_terrain_paint_check_payload().get("text", "")),
		"terrain_paint_check_tooltip": String(_editor_terrain_paint_check_payload().get("tooltip", "")),
		"terrain_picker_tooltip": _terrain_picker.tooltip_text if _terrain_picker != null else "",
		"road_check": _editor_road_check_payload(),
		"road_check_text": String(_editor_road_check_payload().get("text", "")),
		"road_check_tooltip": String(_editor_road_check_payload().get("tooltip", "")),
		"active_tool_cue": _editor_active_tool_cue_payload(),
		"active_tool_cue_text": String(_editor_active_tool_cue_payload().get("text", "")),
		"active_tool_cue_tooltip": String(_editor_active_tool_cue_payload().get("tooltip", "")),
		"map_tooltip": _map_view.tooltip_text if _map_view != null else "",
		"placement_debug_overlay_enabled": _placement_debug_overlay_enabled,
		"object_preview_check": _editor_object_preview_check_payload(),
		"object_preview_check_text": String(_editor_object_preview_check_payload().get("text", "")),
		"object_preview_check_tooltip": String(_editor_object_preview_check_payload().get("tooltip", "")),
		"placement_action_cue": _editor_placement_action_cue_payload(),
		"placement_action_cue_text": String(_editor_placement_action_cue_payload().get("text", "")),
		"placement_action_cue_tooltip": String(_editor_placement_action_cue_payload().get("tooltip_text", "")),
		"place_object_tooltip": _place_object_tool_button.tooltip_text if _place_object_tool_button != null else "",
		"editor_acceptance_cue": _editor_acceptance_cue_payload(),
		"last_object_authoring_recap": _last_object_authoring_recap,
		"tool": _tool,
		"selected_terrain_id": _selected_terrain_id,
		"selected_terrain_label": _terrain_label_for_id(_selected_terrain_id),
		"terrain_option_contract": TERRAIN_OPTION_CONTRACT,
		"terrain_option_source": TERRAIN_OPTION_SOURCE,
		"terrain_options": _terrain_option_payload(),
		"terrain_option_ids": _terrain_option_ids(),
		"authored_terrain_ids": _authored_terrain_ids(),
		"hidden_terrain_ids": _hidden_terrain_ids(),
		"terrain_paint_order": _terrain_paint_order,
		"terrain_placement": terrain_placement,
		"editor_restamp": _editor_restamp_payload_for_tile(_selected_tile),
		"selected_object_family": _selected_object_family,
		"selected_object_content_id": _selected_object_content_id,
		"selected_object_taxonomy": _object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id),
		"selected_object_guidance": _placement_guidance_payload(_object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id), _selected_tile),
		"selected_object_placement_preview": _selected_object_placement_preview_payload(_placement_preview_tile()),
		"selected_object_palette_text": _object_taxonomy_summary_label.tooltip_text if _object_taxonomy_summary_label != null else "",
		"selected_property_object_key": _selected_property_object_key,
		"selected_property_object": _selected_property_object_payload(),
		"selected_property_handoff": _selected_property_handoff_payload(_selected_property_object_detail()),
		"property_summary_text": _property_summary_label.text if _property_summary_label != null else "",
		"property_summary_tooltip": _property_summary_label.tooltip_text if _property_summary_label != null else "",
		"selected_object_picker_tooltip": _selected_object_picker.tooltip_text if _selected_object_picker != null else "",
		"property_apply_tooltip": _property_apply_button.tooltip_text if _property_apply_button != null else "",
		"pending_move_object_key": _pending_move_object_key,
		"pending_move_object": _pending_move_object_payload(),
		"pending_duplicate_object_key": _pending_duplicate_object_key,
		"pending_duplicate_object": _pending_duplicate_object_payload(),
		"pending_terrain_line_start": _pending_terrain_line_start_payload(),
		"terrain_line_rule": TERRAIN_LINE_RULE_ID,
		"terrain_line_rule_label": TERRAIN_LINE_RULE_LABEL,
		"pending_terrain_rectangle_corner": _pending_terrain_rectangle_corner_payload(),
		"terrain_rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
		"terrain_rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
		"terrain_rectangle_tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		"pending_road_path_start": _pending_road_path_start_payload(),
		"road_path_rule": ROAD_PATH_RULE_ID,
		"road_path_rule_label": ROAD_PATH_RULE_LABEL,
		"hero_position": {"x": hero_pos.x, "y": hero_pos.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y},
		"map_size": {"x": map_size.x, "y": map_size.y},
		"road_tile_count": _road_tile_count(),
		"placement_count": _placement_count(),
		"scenario_authoring_validation": _scenario_authoring_validation_payload(),
		"tile_inspection": _tile_inspection_payload(_selected_tile),
		"map_viewport": _map_view.call("validation_view_metrics") if _map_view != null and _map_view.has_method("validation_view_metrics") else {},
	}

func validation_placement_debug_overlay_snapshot() -> Dictionary:
	var map_view := {}
	if _map_view != null and _map_view.has_method("validation_placement_debug_overlay_snapshot"):
		map_view = _map_view.call("validation_placement_debug_overlay_snapshot")
	return {
		"enabled": _placement_debug_overlay_enabled,
		"map_view": map_view,
	}

func _map_package_picker_labels() -> Array:
	var labels := []
	if _map_package_picker == null:
		return labels
	for index in range(_map_package_picker.get_item_count()):
		labels.append(_map_package_picker.get_item_text(index))
	return labels

func _map_package_picker_metadata() -> Array:
	var metadata := []
	if _map_package_picker == null:
		return metadata
	for index in range(_map_package_picker.get_item_count()):
		metadata.append(String(_map_package_picker.get_item_metadata(index)))
	return metadata

func _public_map_package_index_status() -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._public_map_package_index_status", [self])

func validation_load_maps_folder_package(package_id: String) -> Dictionary:
	var loaded := _load_maps_folder_package_working_copy(package_id)
	var snapshot := validation_snapshot()
	snapshot["ok"] = loaded
	return snapshot

func validation_load_package_from_directory(package_dir: String, package_stem: String) -> Dictionary:
	var index := ScenarioSelectRulesScript.maps_folder_package_index({
		"package_dir": package_dir,
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	var entry := {}
	for entry_value in index.get("entries", []):
		if entry_value is Dictionary and String(entry_value.get("package_stem", "")) == package_stem:
			entry = entry_value
			break
	var loaded := not entry.is_empty() and _load_maps_folder_package_entry_working_copy(entry)
	var snapshot := validation_snapshot()
	snapshot["ok"] = loaded
	snapshot["package_index"] = index
	return snapshot

func validation_load_selected_map_package() -> Dictionary:
	var loaded := false
	if _selected_map_package_id != "":
		loaded = _load_maps_folder_package_working_copy(_selected_map_package_id)
	else:
		_last_message = "No map package selected. Generate a map so maps/ contains a paired .amap and .ascenario package."
		_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = loaded
	return snapshot

func validation_select_tile(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	_selected_tile = tile
	_tool = TOOL_INSPECT
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_set_tool(tool: String) -> Dictionary:
	_select_tool(tool)
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_select_object_family(family: String) -> Dictionary:
	var selected := _select_object_family_by_id(family)
	var snapshot := validation_snapshot()
	snapshot["ok"] = selected
	return snapshot

func validation_select_object_content(content_id: String) -> Dictionary:
	var selected := _select_object_content_by_id(content_id)
	var snapshot := validation_snapshot()
	snapshot["ok"] = selected
	return snapshot

func validation_select_terrain(terrain_id: String) -> Dictionary:
	if _select_terrain_by_id(terrain_id):
		var terrain_tool := _tool if _tool in [TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE] else TOOL_TERRAIN
		_select_tool(terrain_tool)
		var snapshot := validation_snapshot()
		snapshot["ok"] = true
		return snapshot
	return {"ok": false, "message": "Terrain id is not in the editor base terrain options."}

func validation_paint_terrain(x: int, y: int, terrain_id: String) -> Dictionary:
	if not _terrain_id_in_grammar(terrain_id):
		var invalid_snapshot := validation_snapshot()
		invalid_snapshot["ok"] = false
		invalid_snapshot["message"] = "Terrain id %s is not in the authored terrain grammar." % terrain_id
		return invalid_snapshot
	_selected_tile = Vector2i(x, y)
	var previous_terrain := _terrain_at(_selected_tile)
	_select_terrain_by_id(terrain_id)
	_tool = TOOL_TERRAIN
	var changed := _paint_terrain(_selected_tile, terrain_id)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["painted_tile"] = {"x": _selected_tile.x, "y": _selected_tile.y}
	snapshot["paint_previous_terrain_id"] = previous_terrain
	snapshot["paint_new_terrain_id"] = terrain_id
	snapshot["paint_changed"] = previous_terrain != terrain_id and changed
	snapshot["terrain_paint_order"] = _terrain_paint_order
	snapshot["terrain_placement"] = _last_terrain_placement_result
	snapshot["owner_changed_count"] = int(_last_terrain_placement_result.get("owner_changed_count", 0))
	snapshot["changed_tiles"] = _last_terrain_placement_result.get("changed_tiles", [])
	snapshot["owner_changed_tiles"] = _last_terrain_placement_result.get("owner_changed_tiles", [])
	snapshot["final_normalization"] = _last_terrain_placement_result.get("final_normalization", {})
	snapshot["editor_restamp"] = _editor_restamp_payload_for_tile(_selected_tile)
	return snapshot

func validation_seed_terrain_direct(x: int, y: int, terrain_id: String) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	if not _terrain_id_in_grammar(terrain_id):
		return {"ok": false, "message": "Terrain id %s is not in the authored terrain grammar." % terrain_id}
	_selected_tile = tile
	var previous_terrain := _terrain_at(tile)
	var changed := previous_terrain != terrain_id and _set_tile_terrain(tile, terrain_id)
	if changed:
		_dirty = true
	var previous_terrain_by_tile := {}
	previous_terrain_by_tile[_tile_key(tile)] = previous_terrain
	_last_terrain_placement_result = {
		"ok": true,
		"changed": changed,
		"placement_model": "direct_validation_seed_no_homm3_queue",
		"brush_terrain_id": terrain_id,
		"requested_tiles": [{"x": tile.x, "y": tile.y}],
		"changed_tiles": [{"x": tile.x, "y": tile.y}] if changed else [],
		"owner_changed_tiles": [],
		"owner_changed_count": 0,
		"previous_terrain_by_tile": previous_terrain_by_tile,
	}
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	snapshot["changed"] = changed
	snapshot["seed_previous_terrain_id"] = previous_terrain
	snapshot["seed_new_terrain_id"] = terrain_id
	return snapshot

func validation_fill_terrain(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	var result := {}
	if terrain_selected:
		result = _fill_terrain_region(_selected_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
		}
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["fill_result"] = result
	snapshot["filled_count"] = int(result.get("filled_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["source_terrain_id"] = String(result.get("source_terrain_id", ""))
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_set_terrain_line_start(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": TERRAIN_LINE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	_tool = TOOL_TERRAIN_LINE
	_pending_terrain_line_start = tile
	_last_message = "Terrain line start set at %d,%d. Apply uses %s with %s." % [
		x,
		y,
		TERRAIN_LINE_RULE_LABEL,
		_selected_terrain_id,
	]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = terrain_selected
	snapshot["terrain_selected"] = terrain_selected
	snapshot["path_rule"] = TERRAIN_LINE_RULE_ID
	snapshot["path_rule_label"] = TERRAIN_LINE_RULE_LABEL
	return snapshot

func validation_apply_terrain_line(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var end_tile := Vector2i(x, y)
	if not _tile_in_bounds(end_tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": TERRAIN_LINE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	if not _has_pending_terrain_line_start():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["terrain_selected"] = terrain_selected
		missing_snapshot["message"] = "Set a terrain line start tile before applying the line."
		missing_snapshot["path_rule"] = TERRAIN_LINE_RULE_ID
		missing_snapshot["path_rule_label"] = TERRAIN_LINE_RULE_LABEL
		return missing_snapshot
	var start_tile := _pending_terrain_line_start
	_selected_tile = end_tile
	_tool = TOOL_TERRAIN_LINE
	var result := {}
	if terrain_selected:
		result = _apply_terrain_line(start_tile, end_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
			"path_rule": TERRAIN_LINE_RULE_ID,
			"path_rule_label": TERRAIN_LINE_RULE_LABEL,
		}
	if bool(result.get("ok", false)):
		_pending_terrain_line_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["terrain_line_result"] = result
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["path_rule"] = String(result.get("path_rule", TERRAIN_LINE_RULE_ID))
	snapshot["path_rule_label"] = String(result.get("path_rule_label", TERRAIN_LINE_RULE_LABEL))
	snapshot["path_tiles"] = result.get("path_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["previous_terrain_by_tile"] = result.get("previous_terrain_by_tile", {})
	snapshot["path_count"] = int(result.get("path_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["start_tile"] = result.get("start_tile", {"x": start_tile.x, "y": start_tile.y})
	snapshot["end_tile"] = result.get("end_tile", {"x": end_tile.x, "y": end_tile.y})
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_set_terrain_rectangle_corner(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "rectangle_rule": TERRAIN_RECTANGLE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	_tool = TOOL_TERRAIN_RECTANGLE
	_pending_terrain_rectangle_corner = tile
	_last_message = "Terrain rectangle corner set at %d,%d. Apply uses %s with %s." % [
		x,
		y,
		TERRAIN_RECTANGLE_RULE_LABEL,
		_selected_terrain_id,
	]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = terrain_selected
	snapshot["terrain_selected"] = terrain_selected
	snapshot["rectangle_rule"] = TERRAIN_RECTANGLE_RULE_ID
	snapshot["rectangle_rule_label"] = TERRAIN_RECTANGLE_RULE_LABEL
	snapshot["tile_order"] = TERRAIN_RECTANGLE_TILE_ORDER
	return snapshot

func validation_apply_terrain_rectangle(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var opposite_tile := Vector2i(x, y)
	if not _tile_in_bounds(opposite_tile):
		return {"ok": false, "message": "Tile outside map.", "rectangle_rule": TERRAIN_RECTANGLE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	if not _has_pending_terrain_rectangle_corner():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["terrain_selected"] = terrain_selected
		missing_snapshot["message"] = "Set a terrain rectangle corner tile before applying the rectangle."
		missing_snapshot["rectangle_rule"] = TERRAIN_RECTANGLE_RULE_ID
		missing_snapshot["rectangle_rule_label"] = TERRAIN_RECTANGLE_RULE_LABEL
		missing_snapshot["tile_order"] = TERRAIN_RECTANGLE_TILE_ORDER
		return missing_snapshot
	var corner_tile := _pending_terrain_rectangle_corner
	_selected_tile = opposite_tile
	_tool = TOOL_TERRAIN_RECTANGLE
	var result := {}
	if terrain_selected:
		result = _apply_terrain_rectangle(corner_tile, opposite_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
			"rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
			"rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
			"tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		}
	if bool(result.get("ok", false)):
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["terrain_rectangle_result"] = result
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["rectangle_rule"] = String(result.get("rectangle_rule", TERRAIN_RECTANGLE_RULE_ID))
	snapshot["rectangle_rule_label"] = String(result.get("rectangle_rule_label", TERRAIN_RECTANGLE_RULE_LABEL))
	snapshot["tile_order"] = String(result.get("tile_order", TERRAIN_RECTANGLE_TILE_ORDER))
	snapshot["rectangle_tiles"] = result.get("rectangle_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["previous_terrain_by_tile"] = result.get("previous_terrain_by_tile", {})
	snapshot["rectangle_count"] = int(result.get("rectangle_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["corner_tile"] = result.get("corner_tile", {"x": corner_tile.x, "y": corner_tile.y})
	snapshot["opposite_tile"] = result.get("opposite_tile", {"x": opposite_tile.x, "y": opposite_tile.y})
	snapshot["bounds"] = result.get("bounds", _terrain_rectangle_bounds(corner_tile, opposite_tile))
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_toggle_road(x: int, y: int) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_ROAD
	var changed := _toggle_road(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	return snapshot

func validation_set_road_path_start(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": ROAD_PATH_RULE_ID}
	_selected_tile = tile
	_tool = TOOL_ROAD_PATH
	_pending_road_path_start = tile
	_last_message = "Road path start set at %d,%d. Apply uses %s." % [x, y, ROAD_PATH_RULE_LABEL]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	snapshot["path_rule"] = ROAD_PATH_RULE_ID
	snapshot["path_rule_label"] = ROAD_PATH_RULE_LABEL
	return snapshot

func validation_apply_road_path(x: int, y: int, action: String = "toggle") -> Dictionary:
	var end_tile := Vector2i(x, y)
	if not _tile_in_bounds(end_tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": ROAD_PATH_RULE_ID}
	if not _has_pending_road_path_start():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "Set a road path start tile before applying the path."
		missing_snapshot["path_rule"] = ROAD_PATH_RULE_ID
		missing_snapshot["path_rule_label"] = ROAD_PATH_RULE_LABEL
		return missing_snapshot
	var start_tile := _pending_road_path_start
	_selected_tile = end_tile
	_tool = TOOL_ROAD_PATH
	var result := _apply_road_path(start_tile, end_tile, action)
	if bool(result.get("ok", false)):
		_pending_road_path_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["road_path_result"] = result
	snapshot["road_path_action"] = String(result.get("road_path_action", ""))
	snapshot["requested_action"] = String(result.get("requested_action", action))
	snapshot["path_rule"] = String(result.get("path_rule", ROAD_PATH_RULE_ID))
	snapshot["path_rule_label"] = String(result.get("path_rule_label", ROAD_PATH_RULE_LABEL))
	snapshot["path_tiles"] = result.get("path_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["path_count"] = int(result.get("path_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["start_tile"] = result.get("start_tile", {"x": start_tile.x, "y": start_tile.y})
	snapshot["end_tile"] = result.get("end_tile", {"x": end_tile.x, "y": end_tile.y})
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_set_hero_start(x: int, y: int) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_HERO_START
	var changed := _set_hero_start(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["hero_position"] = {"x": OverworldRules.hero_position(_session).x, "y": OverworldRules.hero_position(_session).y}
	return snapshot

func validation_place_object(x: int, y: int, family: String, content_id: String) -> Dictionary:
	var family_selected := true
	var content_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	if content_id != "":
		content_selected = _select_object_content_by_id(content_id)
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_PLACE_OBJECT
	var changed := family_selected and content_selected and _place_object(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["family_selected"] = family_selected
	snapshot["content_selected"] = content_selected
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_preview_object_placement(x: int, y: int, family: String, content_id: String) -> Dictionary:
	var family_selected := true
	var content_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	if content_id != "":
		content_selected = _select_object_content_by_id(content_id)
	_selected_tile = Vector2i(x, y)
	_hovered_tile = _selected_tile
	_tool = TOOL_PLACE_OBJECT
	_last_object_authoring_recap = {}
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = family_selected and content_selected and not snapshot.get("selected_object_placement_preview", {}).is_empty()
	snapshot["family_selected"] = family_selected
	snapshot["content_selected"] = content_selected
	return snapshot

func validation_remove_object(x: int, y: int, family: String) -> Dictionary:
	var family_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_REMOVE_OBJECT
	var changed := family_selected and _remove_object(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["family_selected"] = family_selected
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_move_object(from_x: int, from_y: int, to_x: int, to_y: int, family: String = "") -> Dictionary:
	var source_tile := Vector2i(from_x, from_y)
	var destination_tile := Vector2i(to_x, to_y)
	if not _tile_in_bounds(source_tile) or not _tile_in_bounds(destination_tile):
		return {"ok": false, "message": "Source or destination tile outside map."}
	_selected_tile = source_tile
	_tool = TOOL_MOVE_OBJECT
	var source_detail := _preferred_move_detail_at(source_tile)
	if family != "":
		source_detail = {}
		for detail in _property_object_options_at(source_tile):
			if detail is Dictionary and String(detail.get("kind", "")) == family:
				source_detail = detail
				break
	if source_detail.is_empty():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No movable %s object at %d,%d." % [family if family != "" else "supported", from_x, from_y]
		return missing_snapshot
	var move_key := String(source_detail.get("property_key", ""))
	_pending_move_object_key = move_key
	_selected_property_object_key = move_key
	var before_detail: Dictionary = source_detail.duplicate(true)
	var result := _move_object_by_key(move_key, destination_tile)
	if bool(result.get("ok", false)):
		_pending_move_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		_selected_tile = destination_tile
		var after_detail := _object_detail_by_key(move_key)
		_set_object_authoring_recap("move", bool(result.get("changed", false)), before_detail, after_detail, source_tile, destination_tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["from"] = result.get("from", {"x": from_x, "y": from_y})
	snapshot["to"] = result.get("to", {"x": to_x, "y": to_y})
	snapshot["source_detail_before"] = before_detail
	snapshot["source_tile_inspection"] = _tile_inspection_payload(source_tile)
	snapshot["destination_tile_inspection"] = _tile_inspection_payload(destination_tile)
	return snapshot

func validation_duplicate_object(from_x: int, from_y: int, to_x: int, to_y: int, family: String = "") -> Dictionary:
	var source_tile := Vector2i(from_x, from_y)
	var destination_tile := Vector2i(to_x, to_y)
	if not _tile_in_bounds(source_tile) or not _tile_in_bounds(destination_tile):
		return {"ok": false, "message": "Source or destination tile outside map."}
	_selected_tile = source_tile
	_tool = TOOL_DUPLICATE_OBJECT
	var source_detail := _preferred_move_detail_at(source_tile)
	if family != "":
		source_detail = {}
		for detail in _property_object_options_at(source_tile):
			if detail is Dictionary and String(detail.get("kind", "")) == family:
				source_detail = detail
				break
	if source_detail.is_empty():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No duplicable %s object at %d,%d." % [family if family != "" else "supported", from_x, from_y]
		return missing_snapshot
	var duplicate_key := String(source_detail.get("property_key", ""))
	_pending_duplicate_object_key = duplicate_key
	_selected_property_object_key = duplicate_key
	var before_detail: Dictionary = source_detail.duplicate(true)
	var before_count := _placement_count()
	var result := _duplicate_object_by_key(duplicate_key, destination_tile)
	if bool(result.get("ok", false)):
		_pending_duplicate_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		_selected_tile = destination_tile
		var duplicated_placement = result.get("object", {})
		var duplicated_key := ""
		if duplicated_placement is Dictionary:
			duplicated_key = _object_property_key(String(before_detail.get("kind", "")), String(duplicated_placement.get("placement_id", "")))
		var after_detail := _object_detail_by_key(duplicated_key)
		_set_object_authoring_recap("duplicate", bool(result.get("changed", false)), before_detail, after_detail, source_tile, destination_tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["from"] = result.get("from", {"x": from_x, "y": from_y})
	snapshot["to"] = result.get("to", {"x": to_x, "y": to_y})
	snapshot["source_detail_before"] = before_detail
	snapshot["source_tile_inspection"] = _tile_inspection_payload(source_tile)
	snapshot["destination_tile_inspection"] = _tile_inspection_payload(destination_tile)
	snapshot["placement_count_before"] = before_count
	return snapshot

func validation_retheme_object(x: int, y: int, family: String, replacement_content_id: String) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	var family_selected := _select_object_family_by_id(family)
	var content_selected := false
	if family_selected:
		content_selected = _select_object_content_by_id(replacement_content_id)
	_selected_tile = tile
	_tool = TOOL_RETHEME_OBJECT
	var source_detail := _object_detail_for_family_at(tile, family)
	if not family_selected or not content_selected or source_detail.is_empty():
		_refresh_state()
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["family_selected"] = family_selected
		missing_snapshot["content_selected"] = content_selected
		missing_snapshot["message"] = "No rethemeable %s object at %d,%d for %s." % [family, x, y, replacement_content_id]
		return missing_snapshot
	var before_detail: Dictionary = source_detail.duplicate(true)
	var before_count := _placement_count()
	var result := _retheme_object_by_key(String(source_detail.get("property_key", "")), replacement_content_id)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(source_detail.get("property_key", "")))
		_set_object_authoring_recap("retheme", bool(result.get("changed", false)), before_detail, after_detail, tile, tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["family_selected"] = family_selected
	snapshot["content_selected"] = content_selected
	snapshot["source_detail_before"] = before_detail
	snapshot["object_before"] = result.get("object_before", before_detail)
	snapshot["object_after"] = result.get("object", {})
	snapshot["previous_content_id"] = String(result.get("previous_content_id", ""))
	snapshot["content_id"] = String(result.get("content_id", ""))
	snapshot["tile_inspection"] = _tile_inspection_payload(tile)
	snapshot["placement_count_before"] = before_count
	return snapshot

func validation_edit_object_property(x: int, y: int, family: String, property_name: String, value: Variant) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	_selected_tile = tile
	var selected := _select_property_object_at_tile(family)
	if not selected:
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No editable %s object at %d,%d." % [family, x, y]
		return missing_snapshot
	var before_detail := _object_detail_by_key(String(_selected_property_object_key))
	var previous_value = before_detail.get(property_name, null)
	var result := _apply_object_property_value(property_name, value)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(_selected_property_object_key))
		_set_object_authoring_recap(
			"edit_property",
			bool(result.get("changed", false)),
			before_detail,
			after_detail,
			tile,
			tile,
			{},
			property_name,
			previous_value,
			after_detail.get(property_name, null)
		)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_restore_selected_tile(x: int = -999, y: int = -999) -> Dictionary:
	if x != -999 and y != -999:
		var tile := Vector2i(x, y)
		if not _tile_in_bounds(tile):
			return {"ok": false, "message": "Tile outside map."}
		_selected_tile = tile
	var result := _restore_selected_tile_from_authored()
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["restore_result"] = result
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_tile_presentation(x: int, y: int) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_tile_presentation"):
		return {}
	return _map_view.call("validation_tile_presentation", Vector2i(x, y))

func validation_editor_restamp_payload(x: int, y: int) -> Dictionary:
	return _editor_restamp_payload_for_tile(Vector2i(x, y))

func _editor_restamp_payload_for_tile(tile: Vector2i) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_editor_restamp_payload"):
		return {}
	return _map_view.call("validation_editor_restamp_payload", tile)

func validation_launch_working_copy() -> Dictionary:
	if _session == null:
		return {"ok": false, "message": "No editor working copy is loaded."}
	var scenario_id := String(_session.scenario_id)
	var launch_readiness_gate := _editor_play_readiness_gate_payload()
	var launch_handoff := _editor_play_handoff_payload()
	_on_play_working_copy_pressed()
	return {
		"ok": SessionState.ensure_active_session().scenario_id == scenario_id,
		"scenario_id": scenario_id,
		"active_scenario_id": SessionState.ensure_active_session().scenario_id,
		"editor_working_copy": bool(SessionState.ensure_active_session().flags.get("editor_working_copy", false)),
		"editor_snapshot_available": SessionState.has_editor_working_copy_session(),
		"return_model": String(SessionState.ensure_active_session().flags.get("editor_return_model", "")),
		"launch_readiness_gate": launch_readiness_gate,
		"launch_handoff": launch_handoff,
	}

func validation_save_copy(target_dir: String = "", target_stem: String = "") -> Dictionary:
	return _save_package_working_copy(target_dir, target_stem)

func _tile_inspection_payload(tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"MapEditorShell._tile_inspection_payload", [self, tile])

func _select_object_family_by_id(family: String) -> bool:
	for index in range(_object_family_picker.get_item_count()):
		if String(_object_family_picker.get_item_metadata(index)) == family:
			_object_family_picker.select(index)
			_selected_object_family = family
			_selected_object_content_id = ""
			_rebuild_object_content_picker()
			return true
	return false

func _select_terrain_by_id(terrain_id: String) -> bool:
	for index in range(_terrain_picker.get_item_count()):
		if String(_terrain_picker.get_item_metadata(index)) == terrain_id:
			_terrain_picker.select(index)
			_selected_terrain_id = terrain_id
			return true
	return false

func _select_map_package_picker_by_id(package_id: String) -> bool:
	for index in range(_map_package_picker.get_item_count()):
		if String(_map_package_picker.get_item_metadata(index)) == package_id:
			_map_package_picker.select(index)
			_queue_editor_top_bar_layout_sync()
			return true
	return false

func _select_object_content_by_id(content_id: String) -> bool:
	for index in range(_object_content_picker.get_item_count()):
		if String(_object_content_picker.get_item_metadata(index)) == content_id:
			_object_content_picker.select(index)
			_selected_object_content_id = content_id
			return true
	return false
