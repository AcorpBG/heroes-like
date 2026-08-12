extends Node

const REPORT_ID := "MAP_EDITOR_DIRTY_WORKING_COPY_DESTRUCTIVE_TRANSITION_REGRESSION"
const SOURCE_STEM := "small-dawn-cairn-marsh-80034c5e"
const TARGET_STEM := "small-thorn-lantern-bend-b78aa337"
const FIXTURE_DIR := "user://maps"
const FAILURE_PHASES := ["precommit", "after_backup"]
const SAVE_FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const EDITOR_FOCUS_SOURCE_NAMES := [
	"MapPackagePicker",
	"LoadMap",
	"SaveCopy",
	"PlayWorkingCopy",
	"Menu",
	"Map",
	"InspectTool",
	"TerrainTool",
	"TerrainLineTool",
	"TerrainRectangleTool",
	"RoadTool",
	"RoadPathTool",
	"HeroStartTool",
	"PlaceObjectTool",
	"RemoveObjectTool",
	"MoveObjectTool",
	"DuplicateObjectTool",
	"RethemeObjectTool",
	"FillTerrain",
	"RestoreSelectedTile",
	"TerrainPicker",
	"ObjectFamilyPicker",
	"ObjectContentPicker",
	"SelectedObjectPicker",
	"PropertyOwnerPicker",
	"PropertyDifficultyPicker",
	"PropertyCollectedFlag",
	"ApplyObjectProperties",
]
const INITIAL_DISABLED_FOCUS_NAMES := [
	"MapPackagePicker",
	"LoadMap",
	"SaveCopy",
	"PlayWorkingCopy",
	"RestoreSelectedTile",
	"SelectedObjectPicker",
	"PropertyOwnerPicker",
	"PropertyDifficultyPicker",
	"PropertyCollectedFlag",
	"ApplyObjectProperties",
]
const TOOL_RAIL_PICKER_NAMES := [
	"TerrainPicker",
	"ObjectFamilyPicker",
	"ObjectContentPicker",
	"SelectedObjectPicker",
	"PropertyOwnerPicker",
	"PropertyDifficultyPicker",
]
const TOOL_RAIL_FAMILY_IDS := ["town", "resource", "artifact", "encounter"]

var _report_scene: Node
var _original_active_session = null
var _active_shell: Node = null
var _source_entry: Dictionary = {}
var _target_entry: Dictionary = {}
var _original_profile: Dictionary = {}
var _original_selected_slot := 1
var _original_summary_cache: Dictionary = {}
var _original_settings_transaction: Dictionary = {}
var _original_file_states: Dictionary = {}
var _original_window_size := Vector2i.ZERO
var _parent_probe_count := 0
var _focus_signal_counts := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_report_scene = self
	_original_active_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_selected_slot = SaveService.get_selected_manual_slot()
	_original_summary_cache = SaveService.validation_summary_cache_snapshot()
	_original_settings_transaction = _canonical_settings_transaction()
	_original_window_size = get_window().size
	for path in _tracked_authority_paths():
		_original_file_states[path] = _file_state(path)
	if not ClassDB.class_exists("MapPackageService"):
		_fail("Native MapPackageService is unavailable.")
		return
	var source_id := ScenarioSelectRules.maps_folder_package_id_for_stem(SOURCE_STEM)
	var target_id := ScenarioSelectRules.maps_folder_package_id_for_stem(TARGET_STEM)
	if source_id == "" or target_id == "":
		_fail("Shipped package fixture ids are unavailable.")
		return
	if not _package_files_exist():
		_fail("Shipped package fixture pairs are incomplete.")
		return
	if not _copy_fixture_pairs():
		_fail("Could not copy the two shipped package fixtures into isolated user data.")
		return
	print("%s CASE fixture_copy_ready" % REPORT_ID)
	var package_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({
		"package_dir": FIXTURE_DIR,
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	for entry_value in package_index.get("entries", []):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var package_stem := String(entry.get("package_stem", ""))
		if package_stem == SOURCE_STEM:
			_source_entry = entry.duplicate(true)
		elif package_stem == TARGET_STEM:
			_target_entry = entry.duplicate(true)
	if _source_entry.is_empty() or _target_entry.is_empty():
		_fail("Shipped package fixtures were not loadable through the editor index.")
		return
	source_id = String(_source_entry.get("package_id", source_id))
	target_id = String(_target_entry.get("package_id", target_id))
	print("%s CASE fixture_index_ready" % REPORT_ID)
	var original_package_state := _package_file_state()
	print("%s CASE command_focus_start" % REPORT_ID)
	var command_focus_result := await _validate_command_focus_matrix(source_id, original_package_state)
	if not bool(command_focus_result.get("ok", false)):
		return
	var shell = await _create_editor_shell()
	if shell == null:
		return
	print("%s CASE exclusive_parent_start" % REPORT_ID)
	var exclusive_result := await _validate_exclusive_parent_matrix(shell, source_id, target_id, original_package_state)
	if not bool(exclusive_result.get("ok", false)):
		return

	print("%s CASE menu_start" % REPORT_ID)
	var menu_result := await _validate_menu_transition(shell, source_id, original_package_state)
	if not bool(menu_result.get("ok", false)):
		return
	print("%s CASE package_start" % REPORT_ID)
	var package_result := await _validate_package_transition(shell, source_id, target_id, original_package_state)
	if not bool(package_result.get("ok", false)):
		return
	print("%s CASE native_close_start" % REPORT_ID)
	var close_result := await _validate_native_close(shell, source_id, original_package_state)
	if not bool(close_result.get("ok", false)):
		return
	print("%s CASE safe_quit_failure_start" % REPORT_ID)
	var failure_result := await _validate_safe_quit_failure_retry(shell, source_id, original_package_state)
	if not bool(failure_result.get("ok", false)):
		return
	print("%s CASE clean_controls_start" % REPORT_ID)
	var clean_result := await _validate_clean_controls(shell, source_id, target_id, original_package_state)
	if not bool(clean_result.get("ok", false)):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"menu": menu_result,
		"package": package_result,
		"native_close": close_result,
		"safe_quit_failure_retry": failure_result,
		"clean_controls": clean_result,
		"exclusive_parent": exclusive_result,
		"command_focus": command_focus_result,
		"save_version": SessionState.SAVE_VERSION,
	})])
	await _free_shell(shell)
	_cleanup()
	if SaveService.validation_summary_cache_snapshot() != _original_summary_cache \
			or _canonical_settings_transaction() != _original_settings_transaction \
			or _capture_file_states(_tracked_authority_paths()) != _original_file_states:
		_fail("Map Editor focused cleanup did not restore exact save/cache/settings authority.")
		return
	get_tree().quit(0)

func _validate_command_focus_matrix(source_id: String, package_state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for width in [1280, 1920]:
		var shell = await _create_editor_shell()
		if shell == null:
			return {}
		var layout_host := shell.get_parent() as Control
		layout_host.size = Vector2(float(width), 720.0)
		get_window().size = Vector2i(width, 720)
		await _settle()
		var row := await _validate_command_focus_row(shell, source_id, package_state, width)
		if row.is_empty():
			return {}
		rows.append(row)
		await _free_shell(shell)
	return {
		"ok": true,
		"source_count": EDITOR_FOCUS_SOURCE_NAMES.size(),
		"widths": [1280, 1920],
		"rows": rows,
		"physical_tab_shift_tab_full_cycle": true,
		"map_owned_dpad_entry_cursor_exit": true,
		"dynamic_disabled_rehome": true,
		"native_option_selection": true,
		"tool_scroll_reveal": true,
		"traversal_authority_exact": true,
	}

func _validate_command_focus_row(
	shell: Node,
	source_id: String,
	package_state: Dictionary,
	width: int
) -> Dictionary:
	var source_controls := _editor_focus_source_controls(shell)
	var source_names := _control_names(source_controls)
	if source_names != EDITOR_FOCUS_SOURCE_NAMES or source_names.size() != 28 \
			or _unique_strings(source_names).size() != 28:
		return _fail_dict("Map Editor %d focus source membership was not exact: %s" % [width, JSON.stringify(source_names)])
	for control in source_controls:
		if control.focus_mode != Control.FOCUS_ALL:
			return _fail_dict("Map Editor %d focus source %s was not keyboard/controller focusable." % [width, control.name])
	var picker: OptionButton = shell.get_node("%MapPackagePicker")
	# validation_skip_initial_package_index bypasses the real empty-index rebuild,
	# so reproduce its disabled picker state before validating the empty cycle.
	picker.disabled = true
	shell.call("_refresh_state")
	await _settle()
	var initial_disabled := _disabled_control_names(source_controls)
	if initial_disabled != INITIAL_DISABLED_FOCUS_NAMES:
		return _fail_dict("Map Editor %d empty-state disabled focus controls were not exact: %s" % [width, JSON.stringify(initial_disabled)])
	shell.call("_configure_editor_keyboard_focus")
	await _settle()
	var initial_cycle := _enabled_focus_controls(source_controls)
	if initial_cycle.size() != 18 or not _assert_focus_links_exact(initial_cycle):
		return _fail_dict("Map Editor %d empty-state focus links were not an exact closed enabled cycle." % width)
	var empty_authority := _full_authority_state(shell)
	var empty_cursor_live: Label = shell.get_node("%EditorMapCursorLive")
	var empty_semantic_timer: Timer = shell.get("_editor_map_cursor_semantic_timer") as Timer
	if String(shell.call("_editor_map_cursor_semantic_context")) != "" \
			or empty_cursor_live.text != "" \
			or not (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).is_empty() \
			or empty_semantic_timer == null or not empty_semantic_timer.is_stopped():
		return _fail_dict("Map Editor %d empty working-copy cursor semantics were not inactive and empty." % width)
	if not await _exercise_physical_focus_cycles(initial_cycle, "empty_%d" % width):
		return {}
	if _full_authority_state(shell) != empty_authority:
		return _fail_dict("Map Editor %d empty-state focus traversal mutated authority: %s" % [width, _first_difference(empty_authority, _full_authority_state(shell))])
	var empty_semantic_tooltips := _capture_tool_rail_semantic_tooltips(shell)
	var empty_layout := _tool_rail_layout_snapshot(shell, false, empty_semantic_tooltips)
	if not bool(empty_layout.get("ok", false)):
		return _fail_dict("Map Editor %d empty-state responsive ToolRail was not exact: %s" % [width, JSON.stringify(empty_layout)])

	if not await _reset_case(shell, source_id, false):
		return {}
	picker.disabled = false
	shell.call("_refresh_state")
	await _settle()
	var empty_tile := _first_property_empty_tile(shell)
	if empty_tile.x < 0:
		return _fail_dict("Map Editor %d package fixture had no empty property tile." % width)
	shell.call("validation_select_tile", empty_tile.x, empty_tile.y)
	await _settle()
	if not _property_disabled_state_exact(shell, true, true, true, true, true) \
			or not _assert_focus_links_exact(_enabled_focus_controls(source_controls)):
		return _fail_dict("Map Editor %d loaded empty-tile property controls were not disabled exactly." % width)

	var town_tile := _first_placement_tile(shell, "towns")
	var resource_tile := _first_placement_tile(shell, "resource_nodes")
	var encounter_tile := _first_placement_tile(shell, "encounters")
	if town_tile.x < 0 or resource_tile.x < 0 or encounter_tile.x < 0:
		return _fail_dict("Map Editor %d package fixture missed town/resource/encounter property controls." % width)
	shell.call("validation_select_tile", town_tile.x, town_tile.y)
	await _settle()
	if not _property_disabled_state_exact(shell, false, false, true, true, false) \
			or not _assert_focus_links_exact(_enabled_focus_controls(source_controls)):
		return _fail_dict("Map Editor %d town property enabled/disabled state was not exact." % width)
	var owner_picker: OptionButton = shell.get_node("%PropertyOwnerPicker")
	owner_picker.grab_focus()
	await _settle()
	shell.call("validation_select_tile", resource_tile.x, resource_tile.y)
	await _settle()
	if not _property_disabled_state_exact(shell, false, true, true, false, false) \
			or not _assert_focus_links_exact(_enabled_focus_controls(source_controls)) \
			or get_viewport().gui_get_focus_owner() != picker:
		return _fail_dict("Map Editor %d disabled property owner did not rehome focus to MapPackagePicker." % width)
	var terrain_picker: OptionButton = shell.get_node("%TerrainPicker")
	terrain_picker.grab_focus()
	await _settle()
	shell.call("_refresh_state")
	await _settle()
	if get_viewport().gui_get_focus_owner() != terrain_picker:
		return _fail_dict("Map Editor %d valid focus was not retained across synchronous refresh." % width)
	shell.call("validation_select_tile", encounter_tile.x, encounter_tile.y)
	await _settle()
	if not _property_disabled_state_exact(shell, false, true, false, true, false):
		return _fail_dict("Map Editor %d encounter property enabled/disabled state was not exact." % width)
	var family_layout := await _validate_tool_rail_family_layouts(shell, width)
	if not bool(family_layout.get("ok", false)):
		return {}
	var longest_selected_object := await _select_longest_property_object_fixture(shell)
	if not bool(longest_selected_object.get("ok", false)):
		return _fail_dict("Map Editor %d did not expose a long selected-object ToolRail fixture: %s" % [width, JSON.stringify(longest_selected_object)])
	var loaded_semantic_tooltips := _capture_tool_rail_semantic_tooltips(shell)
	var loaded_layout := _tool_rail_layout_snapshot(shell, true, loaded_semantic_tooltips)
	if not bool(loaded_layout.get("ok", false)):
		return _fail_dict("Map Editor %d loaded responsive ToolRail was not exact: %s" % [width, JSON.stringify(loaded_layout)])

	var loaded_cycle := _enabled_focus_controls(source_controls)
	if loaded_cycle.size() != 26 or not _assert_focus_links_exact(loaded_cycle):
		return _fail_dict("Map Editor %d loaded focus links were not an exact closed enabled cycle." % width)
	var loaded_authority := _full_authority_state(shell)
	if not await _exercise_physical_focus_cycles(loaded_cycle, "loaded_%d" % width):
		return {}
	if _full_authority_state(shell) != loaded_authority:
		return _fail_dict("Map Editor %d loaded focus traversal mutated authority: %s" % [width, _first_difference(loaded_authority, _full_authority_state(shell))])

	var apply_button: Button = shell.get_node("%ApplyObjectProperties")
	var tool_scroll: ScrollContainer = shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll")
	tool_scroll.scroll_vertical = 0
	await _settle()
	var reveal_before := _tool_scroll_reveal_snapshot(tool_scroll, apply_button)
	apply_button.grab_focus()
	await _settle()
	var reveal_after := _tool_scroll_reveal_snapshot(tool_scroll, apply_button)
	var reveal_checks := {
		"focus_owner_exact": get_viewport().gui_get_focus_owner() == apply_button,
		"scroll_positive": tool_scroll.scroll_vertical > 0,
		"vertical_fully_visible": bool(reveal_after.get("vertical_fully_visible", false)),
		"horizontal_fully_visible": bool(reveal_after.get("horizontal_fully_visible", false)),
		"full_height_intersection": absf(float(reveal_after.get("intersection_height", 0.0)) - float(reveal_after.get("button_height", 0.0))) <= 1.0,
		"full_width_intersection": absf(float(reveal_after.get("intersection_width", 0.0)) - float(reveal_after.get("button_width", 0.0))) <= 1.0,
		"button_width_unchanged": is_equal_approx(float(reveal_after.get("button_width", 0.0)), float(reveal_before.get("button_width", -1.0))),
		"scroll_width_unchanged": is_equal_approx(float(reveal_after.get("scroll_width", 0.0)), float(reveal_before.get("scroll_width", -1.0))),
		"button_fits_inner_viewport": float(reveal_after.get("button_width", 0.0)) <= float(reveal_after.get("inner_viewport_width", 0.0)) + 1.0,
		"button_visible": apply_button.is_visible_in_tree(),
		"scroll_ancestry_exact": tool_scroll.is_ancestor_of(apply_button),
	}
	var scroll_changed_or_initially_visible := int(reveal_after.get("scroll_vertical", 0)) > int(reveal_before.get("scroll_vertical", 0)) \
		or bool(reveal_before.get("vertical_fully_visible", false))
	if not _checks_exact(reveal_checks):
		# Failure-only diagnostic: a direct production reveal cannot rescue the
		# mandatory focus-entered result above; it only localizes callback vs geometry.
		shell.call("_reveal_editor_focus", apply_button)
		await _settle()
		var direct_reveal_diagnostic := _tool_scroll_reveal_snapshot(tool_scroll, apply_button)
		return _fail_dict("Map Editor %d focused Apply Properties reveal checks failed: %s" % [width, JSON.stringify({
			"checks": reveal_checks,
			"before": reveal_before,
			"after": reveal_after,
			"scroll_changed_or_initially_visible": scroll_changed_or_initially_visible,
			"direct_reveal_diagnostic_only": direct_reveal_diagnostic,
		})])
	var roundtrip := await _validate_tool_rail_resize_roundtrip(shell, package_state, width)
	if not bool(roundtrip.get("ok", false)):
		return {}

	_focus_signal_counts = {"terrain": 0, "inspect": 0, "family": 0}
	var command_background_before := _focus_background_authority(shell)
	var terrain_button: Button = shell.get_node("%TerrainTool")
	var inspect_button: Button = shell.get_node("%InspectTool")
	var family_picker: OptionButton = shell.get_node("%ObjectFamilyPicker")
	terrain_button.pressed.connect(_on_focus_probe_signal.bind("terrain"), CONNECT_ONE_SHOT)
	inspect_button.pressed.connect(_on_focus_probe_signal.bind("inspect"), CONNECT_ONE_SHOT)
	family_picker.item_selected.connect(_on_focus_probe_item_selected.bind("family"), CONNECT_ONE_SHOT)
	terrain_button.grab_focus()
	await _press_joypad_button(JOY_BUTTON_A)
	if int(_focus_signal_counts.get("terrain", 0)) != 1 \
			or String(shell.call("validation_dirty_transition_snapshot").get("tool", "")) != "terrain" \
			or get_viewport().gui_get_focus_owner() != terrain_button:
		return _fail_dict("Map Editor %d physical A did not activate Terrain exactly once and retain focus." % width)
	inspect_button.grab_focus()
	await _press_key(KEY_ENTER)
	if int(_focus_signal_counts.get("inspect", 0)) != 1 \
			or String(shell.call("validation_dirty_transition_snapshot").get("tool", "")) != "inspect" \
			or get_viewport().gui_get_focus_owner() != inspect_button:
		return _fail_dict("Map Editor %d physical Enter did not activate Inspect exactly once and retain focus." % width)

	var family_before := family_picker.selected
	var family_expected := (family_before + 1) % family_picker.get_item_count()
	family_picker.grab_focus()
	await _press_joypad_button(JOY_BUTTON_A)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	await _press_key(KEY_ENTER)
	if family_picker.selected != family_expected or int(_focus_signal_counts.get("family", 0)) != 1 \
			or family_picker.get_popup().visible or get_viewport().gui_get_focus_owner() != family_picker:
		return _fail_dict("Map Editor %d OptionButton native selection/focus did not survive synchronous item_selected refresh." % width)
	if _focus_background_authority(shell) != command_background_before or _package_file_state() != package_state:
		return _fail_dict("Map Editor %d representative command activation changed background authority: %s" % [
			width,
			_first_difference(command_background_before, _focus_background_authority(shell)),
		])
	var canvas_result := await _validate_canvas_interaction_row(shell, source_id, package_state, width)
	if canvas_result.is_empty():
		return {}
	return {
		"width": width,
		"source_count": source_names.size(),
		"empty_cycle_count": initial_cycle.size(),
		"loaded_cycle_count": loaded_cycle.size(),
		"tab_shift_tab_full_cycle": true,
		"map_owned_dpad": true,
		"disabled_rehome": true,
		"valid_focus_retained": true,
		"tool_scroll_revealed": true,
		"tool_rail_responsive": true,
		"tool_rail_columns": int(loaded_layout.get("columns", 0)),
		"tool_rail_family_ids": family_layout.get("family_ids", []).duplicate(),
		"tool_rail_long_selected_object": String(longest_selected_object.get("text", "")),
		"tool_rail_resize_roundtrip": roundtrip,
		"a_enter_once": true,
		"option_native_refresh": true,
		"canvas_interaction": canvas_result,
		"authority_exact": true,
	}

func _validate_canvas_interaction_row(
	shell: Node,
	source_id: String,
	package_state: Dictionary,
	width: int
) -> Dictionary:
	if not await _reset_case(shell, source_id, false):
		return {}
	var map_view: Control = shell.get_node("%Map")
	var menu_button: Button = shell.get_node("%Menu")
	var inspect_button: Button = shell.get_node("%InspectTool")
	var dialog: ConfirmationDialog = shell.get_node("DirtyTransitionConfirmationDialog")
	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session)
	if map_view.focus_mode != Control.FOCUS_ALL or map_size.x < 3 or map_size.y < 3:
		return _fail_dict("Map Editor %d canvas fixture was not bounded and focusable." % width)
	var semantic_result := await _validate_editor_map_cursor_semantic_matrix(shell, source_id, package_state, width)
	if semantic_result.is_empty():
		return {}
	if not await _reset_case(shell, source_id, false):
		return {}
	# Tab owns the exact 28-surface traversal even across Map; D-pad may enter
	# Map from the preceding Menu command, then belongs to the canvas cursor.
	menu_button.grab_focus()
	await _press_key(KEY_TAB)
	if get_viewport().gui_get_focus_owner() != map_view:
		return _fail_dict("Map Editor %d Tab did not enter Map from Menu." % width)
	await _press_key(KEY_TAB)
	if get_viewport().gui_get_focus_owner() != inspect_button:
		return _fail_dict("Map Editor %d Tab did not leave Map for Inspect." % width)
	await _press_key(KEY_TAB, true)
	if get_viewport().gui_get_focus_owner() != map_view:
		return _fail_dict("Map Editor %d Shift-Tab did not re-enter Map from Inspect." % width)
	await _press_key(KEY_TAB, true)
	if get_viewport().gui_get_focus_owner() != menu_button:
		return _fail_dict("Map Editor %d Shift-Tab did not leave Map for Menu." % width)
	shell.call("validation_select_tile", 0, 0)
	var entry_authority := _focus_background_authority(shell)
	var entry_dirty := _canvas_dirty(shell)
	menu_button.grab_focus()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	if get_viewport().gui_get_focus_owner() != map_view:
		return _fail_dict("Map Editor %d D-pad did not enter Map from Menu." % width)
	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	if get_viewport().gui_get_focus_owner() != map_view or _canvas_selected_tile(shell) != Vector2i(1, 0) \
			or _focus_background_authority(shell) != entry_authority or _canvas_dirty(shell) != entry_dirty:
		return _fail_dict("Map Editor %d Map did not own D-pad cursor movement exactly/read-only." % width)
	await _press_joypad_button(JOY_BUTTON_B)
	if get_viewport().gui_get_focus_owner() != inspect_button:
		return _fail_dict("Map Editor %d Map-owned D-pad path did not exit to active Inspect focus." % width)

	# Keyboard arrows and D-pad presses move one clamped tile while leaving the
	# working copy and all external authority byte-for-byte unchanged.
	shell.call("validation_select_tile", 0, 0)
	map_view.grab_focus()
	await _settle()
	var navigation_authority := _focus_background_authority(shell)
	var navigation_dirty := _canvas_dirty(shell)
	await _press_key(KEY_LEFT)
	await _press_key(KEY_UP)
	if _canvas_selected_tile(shell) != Vector2i.ZERO \
			or _focus_background_authority(shell) != navigation_authority \
			or _canvas_dirty(shell) != navigation_dirty:
		return _fail_dict("Map Editor %d canvas keyboard bounds were not clamped/read-only." % width)
	await _press_key(KEY_RIGHT)
	if _canvas_selected_tile(shell) != Vector2i(1, 0):
		return _fail_dict("Map Editor %d canvas keyboard arrow did not move exactly one tile." % width)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	if _canvas_selected_tile(shell) != Vector2i(1, 1) \
			or _focus_background_authority(shell) != navigation_authority \
			or _canvas_dirty(shell) != navigation_dirty:
		return _fail_dict("Map Editor %d canvas D-pad did not move exactly one read-only tile." % width)
	var camera_result := await _validate_canvas_camera_follow_and_mouse(shell, map_view, navigation_authority, navigation_dirty, package_state, width)
	if camera_result.is_empty():
		return {}

	# A held D-pad direction moves immediately, starts at 0.36 seconds, ignores
	# duplicate presses without stepping or restarting, ignores a nonmatching
	# release, repeats at the boundary, then uses the exact 0.09 interval.
	var repeat_start := Vector2i(clampi(map_size.x / 2, 1, map_size.x - 2), clampi(map_size.y / 2, 1, map_size.y - 2))
	shell.call("validation_select_tile", repeat_start.x, repeat_start.y)
	map_view.grab_focus()
	await _settle()
	var repeat_authority := _focus_background_authority(shell)
	var repeat_dirty := _canvas_dirty(shell)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true, 7)
	var first_repeat := _editor_map_repeat_snapshot(shell)
	if _canvas_selected_tile(shell) != repeat_start + Vector2i.RIGHT \
			or not is_equal_approx(float(first_repeat.get("wait_time", 0.0)), 0.36) \
			or first_repeat.get("direction", Vector2i.ZERO) != Vector2i.RIGHT \
			or int(first_repeat.get("button", -1)) != JOY_BUTTON_DPAD_RIGHT \
			or int(first_repeat.get("device", -1)) != 7:
		return _fail_dict("Map Editor %d D-pad initial step/repeat delay was not exact: %s" % [width, JSON.stringify(first_repeat)])
	var repeat_timer: Timer = shell.get("_editor_map_joypad_repeat_timer") as Timer
	repeat_timer.start(0.21)
	var duplicate_tile := _canvas_selected_tile(shell)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true, 7)
	var duplicate_repeat := _editor_map_repeat_snapshot(shell)
	if _canvas_selected_tile(shell) != duplicate_tile \
			or not is_equal_approx(float(duplicate_repeat.get("wait_time", 0.0)), 0.21) \
			or duplicate_repeat.get("direction", Vector2i.ZERO) != Vector2i.RIGHT:
		return _fail_dict("Map Editor %d duplicate D-pad press stepped or restarted repeat: %s" % [width, JSON.stringify(duplicate_repeat)])
	await _send_joypad_button_event(JOY_BUTTON_DPAD_LEFT, false, 7)
	if _editor_map_repeat_snapshot(shell).get("direction", Vector2i.ZERO) != Vector2i.RIGHT:
		return _fail_dict("Map Editor %d nonmatching D-pad release cleared the held direction." % width)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, false, 7)
	if not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d matching D-pad release did not stop the duplicate-repeat fixture." % width)
	var actual_start := _canvas_selected_tile(shell)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true, 7)
	var actual_immediate := _canvas_selected_tile(shell)
	if actual_immediate != actual_start + Vector2i.RIGHT:
		return _fail_dict("Map Editor %d actual Timer fixture missed its immediate D-pad step." % width)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_LEFT, false, 7)
	if not await _await_exact_canvas_timer_step(shell, actual_immediate + Vector2i.RIGHT, 600):
		return _fail_dict("Map Editor %d configured 0.36 Timer did not emit exactly one first repeat." % width)
	var boundary_repeat := _editor_map_repeat_snapshot(shell)
	if not is_equal_approx(float(boundary_repeat.get("wait_time", 0.0)), 0.09):
		return _fail_dict("Map Editor %d actual first repeat did not rearm the 0.09 interval: %s" % [width, JSON.stringify(boundary_repeat)])
	if not await _await_exact_canvas_timer_step(shell, actual_immediate + (Vector2i.RIGHT * 2), 250):
		return _fail_dict("Map Editor %d configured 0.09 Timer did not emit exactly one rate repeat." % width)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, false, 7)
	if not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d matching D-pad release did not stop repeat." % width)
	if _focus_background_authority(shell) != repeat_authority or _canvas_dirty(shell) != repeat_dirty \
			or _package_file_state() != package_state:
		return _fail_dict("Map Editor %d held D-pad navigation mutated working-copy/background authority." % width)

	# Focus loss and modal ownership both stop a held direction. Accept/cancel
	# buttons remain edge-triggered and never enter the repeat state.
	map_view.grab_focus()
	await _send_joypad_button_event(JOY_BUTTON_DPAD_LEFT, true, 0)
	inspect_button.grab_focus()
	await _settle()
	if not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d canvas focus loss did not stop held D-pad repeat." % width)
	map_view.grab_focus()
	await _press_joypad_button(JOY_BUTTON_B)
	if get_viewport().gui_get_focus_owner() != inspect_button or not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d canvas B did not restore the active Inspect tool without repeat." % width)
	map_view.grab_focus()
	var echo_before := _canvas_action_state(shell)
	await _send_key_event(KEY_ENTER, true, true)
	if _canvas_action_state(shell) != echo_before:
		return _fail_dict("Map Editor %d canvas accepted an echo Enter event." % width)
	await _send_key_event(KEY_ENTER, false)
	await _press_joypad_button(JOY_BUTTON_A)
	if not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d canvas A incorrectly entered repeat." % width)

	# Make the existing working copy dirty, then prove opening its native modal
	# cancels an active hold before the dialog owns input.
	var dirty_tile := _first_property_empty_tile(shell)
	var dirty_terrain := _alternate_terrain_id(shell, dirty_tile)
	if dirty_tile.x < 0 or dirty_terrain == "":
		return _fail_dict("Map Editor %d canvas modal-stop terrain fixture was unavailable." % width)
	shell.call("validation_paint_terrain", dirty_tile.x, dirty_tile.y, dirty_terrain)
	map_view.grab_focus()
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true, 0)
	shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	if not dialog.visible or not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d dirty modal did not stop canvas repeat." % width)
	shell.call("validation_cancel_dirty_transition")
	await _settle()

	var action_modes: Array[String] = []
	if width == 1280:
		action_modes.assign(["inspect", "terrain"])
	else:
		action_modes.assign(["road", "road_path"])
	var action_rows: Array[Dictionary] = []
	for mode in action_modes:
		var action_result := await _validate_canvas_action_direct_parity(shell, source_id, package_state, width, mode)
		if action_result.is_empty():
			return {}
		action_rows.append(action_result)
	if width == 1920 and not await _validate_canvas_mouse_inspect_parity(shell, source_id, package_state, width):
		return {}
	return {
		"width": width,
		"source_count": EDITOR_FOCUS_SOURCE_NAMES.size(),
		"keyboard_dpad_bounds_read_only": true,
		"selected_tile_visible": true,
		"camera_follow_and_native_mouse": camera_result,
		"duplicate_press_zero_step_no_restart": true,
		"matching_nonmatching_release": true,
		"repeat_initial_delay_seconds": 0.36,
		"repeat_interval_seconds": 0.09,
		"focus_modal_stop": true,
		"accept_cancel_nonrepeat": true,
		"cursor_semantics": semantic_result,
		"action_rows": action_rows,
		"mouse_picker_dialog_paths_unchanged": true,
	}

func _validate_editor_map_cursor_semantic_matrix(
	shell: Node,
	source_id: String,
	package_state: Dictionary,
	width: int
) -> Dictionary:
	var map_view: Control = shell.get_node("%Map")
	var live: Label = shell.get_node("%EditorMapCursorLive")
	var semantic_timer: Timer = shell.get("_editor_map_cursor_semantic_timer") as Timer
	var session = shell.get("_session")
	var external_authority_before := _semantic_external_authority(shell)
	var empty_tile := _first_semantic_empty_tile(shell)
	var road_tile := _first_semantic_road_tile(shell)
	var object_tile := _first_placement_tile(shell, "towns")
	if semantic_timer == null or empty_tile.x < 0 or road_tile.x < 0 or object_tile.x < 0:
		return _fail_dict("Map Editor %d cursor semantic material fixtures were unavailable." % width)
	var context_rows := [
		{"id": "empty", "tile": empty_tile, "tool": "inspect", "material": "no road or objects"},
		{"id": "road", "tile": road_tile, "tool": "road", "material": "road "},
		{"id": "object", "tile": object_tile, "tool": "place_object", "material": "object"},
	]
	var context_results: Array[Dictionary] = []
	for row_value in context_rows:
		var row: Dictionary = row_value
		var target: Vector2i = row.get("tile", Vector2i(-1, -1))
		var step := _semantic_step_fixture(shell, target)
		var start: Vector2i = step.get("start", Vector2i(-1, -1))
		var direction: Vector2i = step.get("direction", Vector2i.ZERO)
		if start.x < 0 or direction == Vector2i.ZERO:
			return _fail_dict("Map Editor %d cursor semantic %s row had no adjacent physical start." % [width, row.get("id", "")])
		shell.call("validation_select_tile", start.x, start.y)
		shell.call("validation_set_tool", String(row.get("tool", "inspect")))
		map_view.grab_focus()
		await _settle()
		shell.call("_cancel_editor_map_cursor_semantic")
		var authority_before := _semantic_read_only_authority(shell)
		await _press_canvas_direction_key(direction)
		var pending: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
		var expected_context := String(shell.call("_editor_map_cursor_semantic_context"))
		var pending_selected: Dictionary = pending.get("selected_tile", {}) if pending.get("selected_tile", {}) is Dictionary else {}
		var pending_checks := {
			"selected_exact": _canvas_selected_tile(shell) == target,
			"live_empty_before_settle": live.text == "",
			"pending_context": String(pending.get("kind", "")) == "context",
			"pending_generation_current": int(pending.get("generation", -1)) == int(shell.get("_editor_map_cursor_semantic_generation")),
			"pending_session_identity": is_same(pending.get("session_ref"), session),
			"pending_session_id": String(pending.get("session_id", "")) == String(session.session_id),
			"pending_tile_exact": pending_selected == {"x": target.x, "y": target.y},
			"pending_tool_exact": String(pending.get("tool", "")) == String(row.get("tool", "")),
			"pending_label_identity": is_same(pending.get("label_ref"), live),
			"timer_active": not semantic_timer.is_stopped(),
			"timer_wait_exact": is_equal_approx(semantic_timer.wait_time, 0.42),
			"synchronous_context_current": expected_context != "" and expected_context.begins_with("Tile %d,%d." % [target.x, target.y]),
		}
		if not _checks_exact(pending_checks):
			return _fail_dict("Map Editor %d cursor semantic %s scheduling was not exact: %s" % [width, row.get("id", ""), JSON.stringify(pending_checks)])
		if not await _await_editor_map_semantic_text(live, expected_context, 1000):
			return _fail_dict("Map Editor %d cursor semantic %s did not publish through the real 0.42 Timer: %s" % [width, row.get("id", ""), live.text])
		var context_checks := _editor_map_semantic_context_checks(shell, target, String(row.get("tool", "")), String(row.get("material", "")), expected_context)
		context_checks["authority_exact"] = _semantic_read_only_authority(shell) == authority_before
		context_checks["pending_consumed"] = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).is_empty()
		context_checks["timer_stopped"] = semantic_timer.is_stopped()
		if not _checks_exact(context_checks):
			return _fail_dict("Map Editor %d cursor semantic %s context was not exact: %s / %s" % [width, row.get("id", ""), JSON.stringify(context_checks), live.text])
		var active_tool_focus: Control = shell.call("_active_tool_focus_control") as Control
		active_tool_focus.grab_focus()
		await _settle()
		if live.text != "" or not (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).is_empty() or not semantic_timer.is_stopped():
			return _fail_dict("Map Editor %d cursor semantic %s did not cancel on focus loss." % [width, row.get("id", "")])
		context_results.append({"id": row.get("id", ""), "tile": {"x": target.x, "y": target.y}, "tool": row.get("tool", ""), "bounded": true})

	# The real 0.36/0.09 repeat Timer must keep the polite label silent while
	# navigation is in flight, then the independent 0.42 Timer publishes only
	# the final settled tile after the matching physical release.
	if not await _reset_case(shell, source_id, false):
		return {}
	session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session)
	var hold_start := Vector2i(clampi(map_size.x / 2, 1, map_size.x - 4), clampi(map_size.y / 2, 1, map_size.y - 2))
	shell.call("validation_select_tile", hold_start.x, hold_start.y)
	map_view.grab_focus()
	await _settle()
	shell.call("_cancel_editor_map_cursor_semantic")
	var hold_authority := _semantic_read_only_authority(shell)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true, 23)
	var immediate_tile := hold_start + Vector2i.RIGHT
	if _canvas_selected_tile(shell) != immediate_tile or live.text != "":
		return _fail_dict("Map Editor %d cursor semantic hold missed its silent immediate step." % width)
	if not await _await_exact_canvas_timer_step_silent(shell, immediate_tile + Vector2i.RIGHT, live, 600):
		return _fail_dict("Map Editor %d cursor semantic hold did not keep the 0.36 repeat silent." % width)
	if not await _await_exact_canvas_timer_step_silent(shell, immediate_tile + (Vector2i.RIGHT * 2), live, 250):
		return _fail_dict("Map Editor %d cursor semantic hold did not coalesce the 0.09 repeat silently." % width)
	await _send_joypad_button_event(JOY_BUTTON_DPAD_RIGHT, false, 23)
	var held_final_tile := _canvas_selected_tile(shell)
	var held_pending: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	var held_expected := String(shell.call("_editor_map_cursor_semantic_context"))
	var repeat_timer: Timer = shell.get("_editor_map_joypad_repeat_timer") as Timer
	var held_release_checks := {
		"selected_final_exact": _canvas_selected_tile(shell) == held_final_tile,
		"final_row_exact": held_final_tile.y == hold_start.y,
		"final_progress_after_two_repeats": held_final_tile.x >= immediate_tile.x + 2,
		"final_in_bounds": held_final_tile.x >= 0 and held_final_tile.y >= 0 and held_final_tile.x < map_size.x and held_final_tile.y < map_size.y,
		"live_empty": live.text == "",
		"pending_context": String(held_pending.get("kind", "")) == "context",
		"pending_tile_exact": held_pending.get("selected_tile", {}) == {"x": held_final_tile.x, "y": held_final_tile.y},
		"semantic_timer_active": not semantic_timer.is_stopped(),
		"semantic_timer_wait_exact": is_equal_approx(semantic_timer.wait_time, 0.42),
		"pending_generation_current": int(held_pending.get("generation", -1)) == int(shell.get("_editor_map_cursor_semantic_generation")),
		"pending_session_identity": is_same(held_pending.get("session_ref"), session),
		"pending_session_id_exact": String(held_pending.get("session_id", "")) == String(session.session_id),
		"pending_tool_exact": String(held_pending.get("tool", "")) == "inspect",
		"pending_label_identity": is_same(held_pending.get("label_ref"), live),
		"held_direction_cleared": shell.get("_held_editor_map_joypad_direction") == Vector2i.ZERO,
		"held_action_cleared": String(shell.get("_held_editor_map_joypad_action")) == "",
		"held_button_cleared": int(shell.get("_held_editor_map_joypad_button")) == -1,
		"held_device_cleared": int(shell.get("_held_editor_map_joypad_device")) == -1,
		"repeat_timer_stopped": repeat_timer != null and repeat_timer.is_stopped(),
	}
	if not _checks_exact(held_release_checks):
		var held_pending_compact := held_pending.duplicate(true)
		held_pending_compact.erase("session_ref")
		held_pending_compact.erase("label_ref")
		var held_release_failure := {
			"checks": held_release_checks,
			"released_final_tile": held_final_tile,
			"actual_tile": _canvas_selected_tile(shell),
			"live_text": live.text,
			"pending_compact": held_pending_compact,
			"pending_session_identity": is_same(held_pending.get("session_ref"), session),
			"pending_label_identity": is_same(held_pending.get("label_ref"), live),
			"semantic_timer_stopped": semantic_timer.is_stopped(),
			"semantic_timer_wait": semantic_timer.wait_time,
			"semantic_timer_time_left": semantic_timer.time_left,
			"repeat_timer_stopped": repeat_timer == null or repeat_timer.is_stopped(),
			"repeat_timer_wait": repeat_timer.wait_time if repeat_timer != null else -1.0,
			"repeat_timer_time_left": repeat_timer.time_left if repeat_timer != null else -1.0,
			"held_direction": shell.get("_held_editor_map_joypad_direction"),
			"held_action": String(shell.get("_held_editor_map_joypad_action")),
			"held_button": int(shell.get("_held_editor_map_joypad_button")),
			"held_device": int(shell.get("_held_editor_map_joypad_device")),
		}
		return _fail_dict("Map Editor %d held cursor semantic final pending state was not exact: %s" % [width, JSON.stringify(held_release_failure)])
	if not await _await_editor_map_semantic_text(live, held_expected, 1000) \
			or _semantic_read_only_authority(shell) != hold_authority:
		return _fail_dict("Map Editor %d held cursor semantic did not publish only the final read-only context." % width)

	# A clamped boundary and a real mouse hover must not schedule, replace, or
	# announce keyboard-cursor semantics.
	shell.call("validation_select_tile", 0, 0)
	map_view.grab_focus()
	await _settle()
	shell.call("_cancel_editor_map_cursor_semantic")
	var silent_authority := _semantic_read_only_authority(shell)
	await _press_key(KEY_LEFT)
	var silent_state := _editor_map_semantic_state(shell)
	if _canvas_selected_tile(shell) != Vector2i.ZERO or not bool(silent_state.get("inactive", false)) \
			or _semantic_read_only_authority(shell) != silent_authority:
		return _fail_dict("Map Editor %d clamped cursor no-op scheduled or mutated semantics." % width)
	map_view.call("_set_camera_center", Vector2(0, 0), true)
	await _settle()
	await _hover_map_tile(shell, Vector2i.ZERO)
	if not bool(_editor_map_semantic_state(shell).get("inactive", false)) \
			or _semantic_read_only_authority(shell) != silent_authority:
		return _fail_dict("Map Editor %d native mouse hover scheduled cursor semantics." % width)

	# A/Enter publishes one immediate bounded result and clears through the real
	# 1.2 second Timer. An old result clear cannot disturb a replacement context.
	var accept_tile := empty_tile
	shell.call("validation_select_tile", accept_tile.x, accept_tile.y)
	shell.call("validation_set_tool", "inspect")
	map_view.grab_focus()
	await _settle()
	shell.call("_cancel_editor_map_cursor_semantic")
	var accept_authority := _focus_background_authority(shell)
	await _press_joypad_button(JOY_BUTTON_A)
	var accept_result := live.text
	var accept_pending: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	if not accept_result.begins_with("Map action result at %d,%d:" % [accept_tile.x, accept_tile.y]) \
			or accept_result.length() > 320 \
			or String(accept_pending.get("kind", "")) != "result_clear" \
			or accept_pending.get("label_text", "") != accept_result \
			or not is_same(accept_pending.get("focus_ref"), map_view) \
			or semantic_timer.is_stopped() or not is_equal_approx(semantic_timer.wait_time, 1.2) \
			or _focus_background_authority(shell) != accept_authority:
		return _fail_dict("Map Editor %d physical A result semantic was not immediate, bounded, and exact once." % width)
	if not await _await_editor_map_semantic_clear(shell, live, 1800):
		return _fail_dict("Map Editor %d physical A result semantic did not clear through the real 1.2 Timer." % width)

	map_view.grab_focus()
	await _press_key(KEY_ENTER)
	var stale_result: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	var replacement_step := _semantic_step_fixture(shell, _canvas_selected_tile(shell))
	var replacement_direction: Vector2i = replacement_step.get("reverse_direction", Vector2i.ZERO)
	if replacement_direction == Vector2i.ZERO:
		return _fail_dict("Map Editor %d stale-result replacement had no bounded direction." % width)
	await _press_canvas_direction_key(replacement_direction)
	var replacement_before: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	var replacement_generation := int(shell.get("_editor_map_cursor_semantic_generation"))
	var replacement_timer_wait := semantic_timer.wait_time
	var replacement_label := live.text
	shell.call("_clear_editor_map_cursor_semantic_result", stale_result)
	var replacement_after: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	if replacement_after != replacement_before \
			or int(shell.get("_editor_map_cursor_semantic_generation")) != replacement_generation \
			or semantic_timer.is_stopped() or not is_equal_approx(semantic_timer.wait_time, replacement_timer_wait) \
			or live.text != replacement_label:
		return _fail_dict("Map Editor %d stale result clear disturbed its replacement cursor context." % width)
	var replacement_expected := String(shell.call("_editor_map_cursor_semantic_context"))
	if not await _await_editor_map_semantic_text(live, replacement_expected, 1000):
		return _fail_dict("Map Editor %d replacement cursor context did not survive stale clear." % width)

	# B/Escape restores the exact active command, announces the fallback wording
	# once, and clears on the same bounded result lifetime.
	shell.call("validation_set_tool", "terrain")
	map_view.grab_focus()
	await _settle()
	shell.call("_cancel_editor_map_cursor_semantic")
	var cancel_tile := _canvas_selected_tile(shell)
	await _press_key(KEY_ESCAPE)
	var terrain_focus: Control = shell.call("_active_tool_focus_control") as Control
	var expected_cancel := "Canvas navigation ended at %d,%d. Focus returned to the Terrain command." % [cancel_tile.x, cancel_tile.y]
	var cancel_pending: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	var cancel_repeat_timer: Timer = shell.get("_editor_map_joypad_repeat_timer") as Timer
	var cancel_checks := {
		"live_text_exact": live.text == expected_cancel,
		"focus_owner_exact": get_viewport().gui_get_focus_owner() == terrain_focus,
		"pending_result_clear": String(cancel_pending.get("kind", "")) == "result_clear",
		"pending_focus_identity": is_same(cancel_pending.get("focus_ref"), terrain_focus),
		"semantic_timer_active": not semantic_timer.is_stopped(),
		"semantic_timer_wait_exact": is_equal_approx(semantic_timer.wait_time, 1.2),
		"pending_generation_current": int(cancel_pending.get("generation", -1)) == int(shell.get("_editor_map_cursor_semantic_generation")),
		"pending_session_identity": is_same(cancel_pending.get("session_ref"), session),
		"pending_session_id_exact": String(cancel_pending.get("session_id", "")) == String(session.session_id),
		"pending_label_identity": is_same(cancel_pending.get("label_ref"), live),
		"pending_label_text_exact": String(cancel_pending.get("label_text", "")) == expected_cancel,
		"held_direction_cleared": shell.get("_held_editor_map_joypad_direction") == Vector2i.ZERO,
		"held_action_cleared": String(shell.get("_held_editor_map_joypad_action")) == "",
		"held_button_cleared": int(shell.get("_held_editor_map_joypad_button")) == -1,
		"held_device_cleared": int(shell.get("_held_editor_map_joypad_device")) == -1,
		"repeat_timer_stopped": cancel_repeat_timer != null and cancel_repeat_timer.is_stopped(),
	}
	if not _checks_exact(cancel_checks):
		var cancel_pending_compact := cancel_pending.duplicate(true)
		cancel_pending_compact.erase("session_ref")
		cancel_pending_compact.erase("focus_ref")
		cancel_pending_compact.erase("label_ref")
		var actual_focus := get_viewport().gui_get_focus_owner()
		var cancel_failure := {
			"checks": cancel_checks,
			"expected_text": expected_cancel,
			"actual_text": live.text,
			"expected_focus_path": String(terrain_focus.get_path()) if terrain_focus != null else "",
			"expected_focus_name": String(terrain_focus.name) if terrain_focus != null else "",
			"actual_focus_path": String(actual_focus.get_path()) if actual_focus != null else "",
			"actual_focus_name": String(actual_focus.name) if actual_focus != null else "",
			"pending_compact": cancel_pending_compact,
			"pending_focus_identity": is_same(cancel_pending.get("focus_ref"), terrain_focus),
			"pending_session_identity": is_same(cancel_pending.get("session_ref"), session),
			"pending_label_identity": is_same(cancel_pending.get("label_ref"), live),
			"current_generation": int(shell.get("_editor_map_cursor_semantic_generation")),
			"semantic_timer_stopped": semantic_timer.is_stopped(),
			"semantic_timer_wait": semantic_timer.wait_time,
			"semantic_timer_time_left": semantic_timer.time_left,
			"repeat_timer_stopped": cancel_repeat_timer == null or cancel_repeat_timer.is_stopped(),
			"repeat_timer_wait": cancel_repeat_timer.wait_time if cancel_repeat_timer != null else -1.0,
			"repeat_timer_time_left": cancel_repeat_timer.time_left if cancel_repeat_timer != null else -1.0,
			"held_direction": shell.get("_held_editor_map_joypad_direction"),
			"held_action": String(shell.get("_held_editor_map_joypad_action")),
			"held_button": int(shell.get("_held_editor_map_joypad_button")),
			"held_device": int(shell.get("_held_editor_map_joypad_device")),
		}
		return _fail_dict("Map Editor %d physical B/Escape fallback-focus semantic was not exact: %s" % [width, JSON.stringify(cancel_failure)])
	if not await _await_editor_map_semantic_clear(shell, live, 1800):
		return _fail_dict("Map Editor %d physical B/Escape result semantic did not clear through the real Timer." % width)

	# Focus, modal ownership, session replacement, and tree exit all cancel the
	# pending identity rather than allowing stale text into a new owner/session.
	if not await _reset_case(shell, source_id, false):
		return {}
	if not await _stage_editor_map_semantic_pending(shell, map_view):
		return _fail_dict("Map Editor %d focus cancellation did not establish a pending cursor context." % width)
	var inspect_focus: Control = shell.get_node("%InspectTool")
	inspect_focus.grab_focus()
	await _settle()
	if not bool(_editor_map_semantic_state(shell).get("inactive", false)):
		return _fail_dict("Map Editor %d focus transfer did not cancel pending cursor semantics." % width)
	var dirty_tile := _first_property_empty_tile(shell)
	var alternate_terrain := _alternate_terrain_id(shell, dirty_tile)
	if dirty_tile.x < 0 or alternate_terrain == "":
		return _fail_dict("Map Editor %d modal semantic cancellation fixture was unavailable." % width)
	shell.call("validation_paint_terrain", dirty_tile.x, dirty_tile.y, alternate_terrain)
	if not await _stage_editor_map_semantic_pending(shell, map_view):
		return _fail_dict("Map Editor %d modal cancellation did not establish a pending cursor context." % width)
	shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	if not shell.get_node("DirtyTransitionConfirmationDialog").visible \
			or not bool(_editor_map_semantic_state(shell).get("inactive", false)):
		return _fail_dict("Map Editor %d dirty modal ownership did not cancel cursor semantics." % width)
	shell.call("validation_cancel_dirty_transition")
	await _settle()
	if not await _reset_case(shell, source_id, false):
		return {}
	if not await _stage_editor_map_semantic_pending(shell, map_view):
		return _fail_dict("Map Editor %d session replacement did not establish a pending cursor context." % width)
	var prior_session = shell.get("_session")
	var replacement_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if replacement_session == null \
			or String(replacement_session.session_id) == "" \
			or String(replacement_session.scenario_id) != "river-pass" \
			or is_same(replacement_session, prior_session) \
			or not bool(shell.call("_resume_working_copy_from_memory", replacement_session)) \
			or not is_same(shell.get("_session"), replacement_session) \
			or not bool(_editor_map_semantic_state(shell).get("inactive", false)):
		return _fail_dict("Map Editor %d session replacement did not cancel cursor semantic identity." % width)
	if not await _reset_case(shell, source_id, false):
		return {}
	if not await _stage_editor_map_semantic_pending(shell, map_view):
		return _fail_dict("Map Editor %d tree cancellation did not establish a pending cursor context." % width)
	shell.call("_exit_tree")
	if not bool(_editor_map_semantic_state(shell).get("inactive", false)):
		return _fail_dict("Map Editor %d tree exit did not cancel cursor semantics." % width)
	if not await _reset_case(shell, source_id, false) \
			or _package_file_state() != package_state \
			or _semantic_external_authority(shell) != external_authority_before \
			or _canvas_dirty(shell) \
			or String(shell.call("validation_snapshot").get("tool", "")) != "inspect":
		return _fail_dict("Map Editor %d cursor semantic lifecycle did not restore package authority." % width)
	return {
		"ok": true,
		"width": width,
		"context_rows": context_results,
		"hold_initial_seconds": 0.36,
		"hold_rate_seconds": 0.09,
		"semantic_debounce_seconds": 0.42,
		"result_visible_seconds": 1.2,
		"final_only": true,
		"boundary_and_hover_silent": true,
		"accept_cancel_immediate_once": true,
		"stale_clear_replacement_safe": true,
		"focus_modal_session_tree_cancellation": true,
		"authority_exact": true,
	}

func _editor_map_semantic_context_checks(shell: Node, tile: Vector2i, tool: String, material: String, text: String) -> Dictionary:
	var terrain_id := String(shell.call("_terrain_at", tile))
	var terrain_label := String(shell.call("_terrain_label_for_id", terrain_id))
	if terrain_label == "":
		terrain_label = terrain_id if terrain_id != "" else "unknown"
	var tool_label := String(shell.call("_tool_label", tool))
	var material_exact := text.contains(material)
	if material == "object":
		var details: Array = shell.call("_object_details_at", tile, true)
		material_exact = not details.is_empty()
		if material_exact and details[0] is Dictionary:
			var detail: Dictionary = details[0]
			var kind := String(shell.call("_humanize_editor_id", String(detail.get("kind", "object"))))
			var object_name := String(detail.get("name", detail.get("content_id", ""))).strip_edges()
			material_exact = text.contains("%s %s" % [kind, object_name]) if object_name != "" else text.contains(kind)
	return {
		"whole_text_exact": text == String(shell.call("_editor_map_cursor_semantic_context")),
		"bounded_nonempty": text != "" and text.length() <= 320,
		"single_line": not text.contains("\n") and not text.contains("\r"),
		"tile_exact": text.begins_with("Tile %d,%d." % [tile.x, tile.y]),
		"terrain_exact": text.contains("Terrain %s;" % terrain_label),
		"material_exact": material_exact,
		"tool_exact": text.contains("Tool %s." % tool_label),
		"accept_exact": text.contains("A/Enter:"),
		"cancel_exact": text.ends_with("B/Escape: return to tool commands."),
	}

func _semantic_read_only_authority(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	return {
		"background": _focus_background_authority(shell),
		"dirty": bool(snapshot.get("dirty", false)),
		"tool": String(snapshot.get("tool", "")),
	}

func _semantic_external_authority(shell: Node) -> Dictionary:
	var authority := _focus_background_authority(shell)
	authority.erase("working_copy")
	return authority

func _editor_map_semantic_state(shell: Node) -> Dictionary:
	var live: Label = shell.get_node("%EditorMapCursorLive")
	var timer: Timer = shell.get("_editor_map_cursor_semantic_timer") as Timer
	var pending: Dictionary = shell.get("_editor_map_cursor_semantic_pending") as Dictionary
	return {
		"text": live.text,
		"pending": pending.duplicate(true),
		"generation": int(shell.get("_editor_map_cursor_semantic_generation")),
		"timer_stopped": timer != null and timer.is_stopped(),
		"inactive": live.text == "" and pending.is_empty() and timer != null and timer.is_stopped(),
	}

func _semantic_step_fixture(shell: Node, target: Vector2i) -> Dictionary:
	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session) if session != null else Vector2i.ZERO
	for direction_value in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var direction: Vector2i = direction_value
		var start: Vector2i = target - direction
		if start.x >= 0 and start.y >= 0 and start.x < map_size.x and start.y < map_size.y:
			return {"start": start, "direction": direction, "reverse_direction": -direction}
	return {"start": Vector2i(-1, -1), "direction": Vector2i.ZERO, "reverse_direction": Vector2i.ZERO}

func _stage_editor_map_semantic_pending(shell: Node, map_view: Control) -> bool:
	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session) if session != null else Vector2i.ZERO
	if map_size.x < 3 or map_size.y < 1:
		return false
	var start := Vector2i(clampi(map_size.x / 2, 1, map_size.x - 2), clampi(map_size.y / 2, 0, map_size.y - 1))
	shell.call("validation_select_tile", start.x, start.y)
	map_view.grab_focus()
	await _settle()
	shell.call("_cancel_editor_map_cursor_semantic")
	await _press_key(KEY_RIGHT)
	var pending: Dictionary = shell.get("_editor_map_cursor_semantic_pending") as Dictionary
	var timer: Timer = shell.get("_editor_map_cursor_semantic_timer") as Timer
	return _canvas_selected_tile(shell) == start + Vector2i.RIGHT \
		and String(pending.get("kind", "")) == "context" \
		and timer != null and not timer.is_stopped() \
		and is_equal_approx(timer.wait_time, 0.42)

func _first_semantic_empty_tile(shell: Node) -> Vector2i:
	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session) if session != null else Vector2i.ZERO
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			if not bool(shell.call("_has_road_at", tile)) and (shell.call("_object_details_at", tile, true) as Array).is_empty():
				return tile
	return Vector2i(-1, -1)

func _first_semantic_road_tile(shell: Node) -> Vector2i:
	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session) if session != null else Vector2i.ZERO
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			if bool(shell.call("_has_road_at", tile)):
				return tile
	return Vector2i(-1, -1)

func _await_exact_canvas_timer_step_silent(shell: Node, expected_tile: Vector2i, live: Label, timeout_msec: int) -> bool:
	var before := _canvas_selected_tile(shell)
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() <= deadline:
		await get_tree().process_frame
		if live.text != "":
			return false
		var current := _canvas_selected_tile(shell)
		if current == expected_tile:
			return current != before
		if current != before:
			return false
	return false

func _await_editor_map_semantic_text(live: Label, expected: String, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() <= deadline:
		await get_tree().process_frame
		if live.text != "":
			return live.text == expected
	return false

func _await_editor_map_semantic_clear(shell: Node, live: Label, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() <= deadline:
		await get_tree().process_frame
		if live.text == "" and (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).is_empty():
			var timer: Timer = shell.get("_editor_map_cursor_semantic_timer") as Timer
			return timer != null and timer.is_stopped()
	return false

func _validate_canvas_camera_follow_and_mouse(
	shell: Node,
	map_view: Control,
	authority_before: Dictionary,
	dirty_before: bool,
	package_state: Dictionary,
	width: int
) -> Dictionary:
	var initial_metrics: Dictionary = map_view.call("validation_view_metrics")
	var initial_map_size: Dictionary = initial_metrics.get("map_size", {})
	map_view.call("_set_camera_center", Vector2(float(initial_map_size.get("x", 1)) * 0.5, float(initial_map_size.get("y", 1)) * 0.5), true)
	await _settle()
	var before: Dictionary = map_view.call("validation_view_metrics")
	if not bool(before.get("pan_supported", false)):
		return _fail_dict("Map Editor %d canvas camera fixture did not support bounded panning." % width)
	var chosen_probe := await _choose_camera_pan_probe(map_view, before, 1)
	var direction: Vector2i = chosen_probe.get("direction", Vector2i.ZERO)
	var chosen_delta: Vector2 = chosen_probe.get("delta", Vector2.ZERO)
	if direction == Vector2i.ZERO or chosen_delta.length() <= 0.01 \
			or not bool(chosen_probe.get("restored_exact", false)) \
			or not bool(chosen_probe.get("all_probes_restored_exact", false)) \
			or not bool(chosen_probe.get("axis_aligned", false)):
		return _fail_dict("Map Editor %d canvas camera had no deterministic available clamped direction." % width)
	var before_precise := _camera_precise(before)
	var cursor_start := Vector2i(
		clampi(roundi(before_precise.x), 1, int(before.get("map_size", {}).get("x", 1)) - 2),
		clampi(roundi(before_precise.y), 1, int(before.get("map_size", {}).get("y", 1)) - 2)
	)
	shell.call("validation_select_tile", cursor_start.x, cursor_start.y)
	map_view.grab_focus()
	await _settle()
	await _press_canvas_direction_key(direction)
	var after: Dictionary = map_view.call("validation_view_metrics")
	var expected_focus := before_precise + chosen_delta
	var actual_cursor := _canvas_selected_tile(shell)
	var expected_cursor := cursor_start + direction
	var authority_after := _focus_background_authority(shell)
	var dirty_after := _canvas_dirty(shell)
	var camera_checks := {
		"precise_focus_exact": _vector2_approx(_camera_precise(after), expected_focus),
		"selected_tile_exact": actual_cursor == expected_cursor,
		"selected_visible_exact": _canvas_selected_tile_visible(shell),
		"background_authority_exact": authority_after == authority_before,
		"dirty_exact": dirty_after == dirty_before,
	}
	if not _checks_exact(camera_checks):
		return _fail_dict("Map Editor %d canvas physical cursor/camera follow was not exact: %s" % [width, JSON.stringify({
			"checks": camera_checks,
			"focus_before": before_precise,
			"chosen_delta": chosen_delta,
			"focus_expected": expected_focus,
			"focus_actual": _camera_precise(after),
			"cursor_start": cursor_start,
			"cursor_expected": expected_cursor,
			"cursor_actual": actual_cursor,
			"visible_bounds": after.get("visible_bounds", {}).duplicate(true),
			"dirty_before": dirty_before,
			"dirty_after": dirty_after,
			"authority_differences": _top_level_differences(authority_before, authority_after) \
				if not bool(camera_checks.get("background_authority_exact", false)) else {},
		})])

	# Native mouse drag must pan without releasing a tile activation. The wheel
	# then pans by the shared MapView three-tile increment. Both remain read-only.
	var map_size: Dictionary = before.get("map_size", {})
	map_view.call("_set_camera_center", Vector2(float(map_size.get("x", 1)) * 0.5, float(map_size.get("y", 1)) * 0.5), true)
	await _settle()
	var selected_before_drag := _canvas_selected_tile(shell)
	var drag_metrics_before: Dictionary = map_view.call("validation_view_metrics")
	var drag_before := _camera_precise(drag_metrics_before)
	var drag_probe := await _choose_camera_pan_probe(map_view, drag_metrics_before, 1)
	var drag_direction: Vector2i = drag_probe.get("direction", Vector2i.ZERO)
	var drag_expected_delta: Vector2 = drag_probe.get("delta", Vector2.ZERO)
	var drag_tile_extent := float(drag_metrics_before.get("tile_extent", 0.0))
	if drag_direction == Vector2i.ZERO or drag_expected_delta.length() <= 0.01 \
			or drag_tile_extent <= 0.0 \
			or not bool(drag_probe.get("axis_aligned", false)) \
			or not bool(drag_probe.get("restored_exact", false)) \
			or not bool(drag_probe.get("all_probes_restored_exact", false)):
		return _fail_dict("Map Editor %d native drag fixture had no method-matched available camera direction." % width)
	await _drag_map_view(map_view, -Vector2(drag_direction) * drag_tile_extent)
	var drag_after := _camera_precise(map_view.call("validation_view_metrics"))
	var selected_after_drag := _canvas_selected_tile(shell)
	var drag_authority_after := _focus_background_authority(shell)
	var drag_dirty_after := _canvas_dirty(shell)
	var drag_checks := {
		"drag_camera_changed": drag_after.distance_to(drag_before) > 0.01,
		"drag_camera_exact": _vector2_approx(drag_after, drag_before + drag_expected_delta),
		"selected_tile_unchanged": selected_after_drag == selected_before_drag,
		"background_authority_exact": drag_authority_after == authority_before,
		"dirty_exact": drag_dirty_after == dirty_before,
	}
	if not _checks_exact(drag_checks):
		return _fail_dict("Map Editor %d native mouse drag did not pan or leaked into tile activation: %s" % [width, JSON.stringify({
			"checks": drag_checks,
			"drag_before": drag_before,
			"drag_after": drag_after,
			"drag_delta": drag_after - drag_before,
			"drag_expected_delta": drag_expected_delta,
			"drag_direction": drag_direction,
			"drag_tile_extent": drag_tile_extent,
			"selected_before": selected_before_drag,
			"selected_after": selected_after_drag,
			"dirty_before": dirty_before,
			"dirty_after": drag_dirty_after,
			"authority_differences": _top_level_differences(authority_before, drag_authority_after) \
				if not bool(drag_checks.get("background_authority_exact", false)) else {},
		})])
	map_view.call("_set_camera_center", Vector2(float(map_size.get("x", 1)) * 0.5, float(map_size.get("y", 1)) * 0.5), true)
	await _settle()
	var wheel_metrics_before: Dictionary = map_view.call("validation_view_metrics")
	var wheel_before := _camera_precise(wheel_metrics_before)
	var wheel_probe := await _choose_camera_pan_probe(map_view, wheel_metrics_before, 3)
	var wheel_direction: Vector2i = wheel_probe.get("direction", Vector2i.ZERO)
	var wheel_delta: Vector2 = wheel_probe.get("delta", Vector2.ZERO)
	if wheel_direction == Vector2i.ZERO or wheel_delta.length() <= 0.01 \
			or not bool(wheel_probe.get("restored_exact", false)) \
			or not bool(wheel_probe.get("all_probes_restored_exact", false)) \
			or not bool(wheel_probe.get("axis_aligned", false)):
		return _fail_dict("Map Editor %d wheel fixture had no bounded camera direction." % width)
	await _wheel_map_view(map_view, _wheel_button_for_direction(wheel_direction))
	var wheel_after := _camera_precise(map_view.call("validation_view_metrics"))
	if not _vector2_approx(wheel_after, wheel_before + wheel_delta) \
			or _canvas_selected_tile(shell) != selected_before_drag \
			or _focus_background_authority(shell) != authority_before \
			or _canvas_dirty(shell) != dirty_before \
			or _package_file_state() != package_state:
		return _fail_dict("Map Editor %d native wheel pan/read-only authority was not exact: %s" % [width, JSON.stringify({"before": wheel_before, "after": wheel_after})])
	return {
		"precise_directional_follow": true,
		"selected_visible": true,
		"drag_pan_tile_activation_suppressed": true,
		"wheel_pan_tiles": 3,
		"authority_exact": true,
	}

func _editor_focus_source_controls(shell: Node) -> Array[Control]:
	var controls: Array[Control] = []
	for value in shell.call("_editor_focus_surfaces"):
		if value is Control:
			controls.append(value)
	return controls

func _validate_canvas_action_direct_parity(
	shell: Node,
	source_id: String,
	package_state: Dictionary,
	width: int,
	mode: String
) -> Dictionary:
	if not await _reset_case(shell, source_id, false):
		return {}
	var setup := _prepare_canvas_action(shell, mode)
	if not bool(setup.get("ok", false)):
		return _fail_dict("Map Editor %d canvas %s action fixture was unavailable: %s" % [width, mode, JSON.stringify(setup)])
	var map_view: Control = shell.get_node("%Map")
	var authority_before := _focus_background_authority(shell)
	map_view.grab_focus()
	await _settle()
	var accept_kind := "joypad_a" if mode in ["inspect", "road"] else "enter"
	await _activate_canvas_action(map_view, setup, accept_kind, false, shell)
	var physical_state := _canvas_action_state(shell)
	if _focus_background_authority(shell).duplicate(true).merged({"working_copy": authority_before.get("working_copy", {})}, true) \
			!= authority_before or _package_file_state() != package_state:
		return _fail_dict("Map Editor %d canvas %s action changed external authority." % [width, mode])

	if not await _reset_case(shell, source_id, false):
		return {}
	var direct_setup := _prepare_canvas_action(shell, mode)
	var direct_setup_checks := _canvas_setup_equality_checks(setup, direct_setup)
	if direct_setup != setup or not _checks_exact(direct_setup_checks):
		return _fail_dict("Map Editor %d canvas %s direct-control fixture was not identical: %s" % [
			width,
			mode,
			JSON.stringify({"checks": direct_setup_checks, "differences": _canvas_setup_differences(setup, direct_setup)}),
		])
	await _activate_canvas_action(map_view, direct_setup, accept_kind, true, shell)
	var direct_state := _canvas_action_state(shell)
	if _focus_background_authority(shell).duplicate(true).merged({"working_copy": authority_before.get("working_copy", {})}, true) \
			!= authority_before or _package_file_state() != package_state:
		return _fail_dict("Map Editor %d canvas %s direct control changed external authority." % [width, mode])
	if physical_state != direct_state:
		return _fail_dict("Map Editor %d canvas %s physical/direct action parity failed: %s" % [
			width,
			mode,
			_first_difference(direct_state, physical_state),
		])
	if not bool(physical_state.get("session_identity_coherent", false)) \
			or not bool(direct_state.get("session_identity_coherent", false)):
		return _fail_dict("Map Editor %d canvas %s action session identity was not internally coherent." % [width, mode])
	if mode != "inspect" and not bool(physical_state.get("dirty", false)):
		return _fail_dict("Map Editor %d canvas %s action did not dirty its working copy." % [width, mode])
	if mode == "inspect" and physical_state.get("working_copy", {}) != setup.get("working_copy", {}):
		return _fail_dict("Map Editor %d canvas inspect action was not read-only." % width)

	# Cancel always restores the currently active tool, never activates it.
	map_view.grab_focus()
	await _press_key(KEY_ESCAPE)
	var expected_tool_focus: Control = shell.call("_active_tool_focus_control") as Control
	if get_viewport().gui_get_focus_owner() != expected_tool_focus or not _editor_map_repeat_stopped(shell):
		return _fail_dict("Map Editor %d canvas %s Escape did not restore exact active-tool focus." % [width, mode])
	return {
		"mode": mode,
		"accept": accept_kind,
		"direct_parity_exact": true,
		"two_step": mode == "road_path",
		"dirty": bool(physical_state.get("dirty", false)),
		"active_tool_focus_restored": true,
	}

func _validate_canvas_mouse_inspect_parity(shell: Node, source_id: String, package_state: Dictionary, width: int) -> bool:
	if not await _reset_case(shell, source_id, false):
		return false
	var setup := _prepare_canvas_action(shell, "inspect")
	if not bool(setup.get("ok", false)):
		_fail("Map Editor %d mouse-inspect fixture was unavailable." % width)
		return false
	var start: Vector2i = setup.get("start", Vector2i.ZERO)
	var map_view: Control = shell.get_node("%Map")
	map_view.call("_set_camera_center", Vector2(start), true)
	await _settle()
	var click_metrics: Dictionary = map_view.call("validation_view_metrics")
	var click_board: Dictionary = click_metrics.get("board_rect", {})
	var click_viewport: Dictionary = click_metrics.get("viewport_rect", {})
	var click_map_size: Dictionary = click_metrics.get("map_size", {})
	var click_cell_size := Vector2(
		float(click_board.get("width", 0.0)) / maxf(float(click_map_size.get("x", 1)), 1.0),
		float(click_board.get("height", 0.0)) / maxf(float(click_map_size.get("y", 1)), 1.0)
	)
	var local_center := Vector2(float(click_board.get("x", 0.0)), float(click_board.get("y", 0.0))) \
		+ Vector2((float(start.x) + 0.5) * click_cell_size.x, (float(start.y) + 0.5) * click_cell_size.y)
	var viewport_rect := Rect2(
		Vector2(float(click_viewport.get("x", 0.0)), float(click_viewport.get("y", 0.0))),
		Vector2(float(click_viewport.get("width", 0.0)), float(click_viewport.get("height", 0.0)))
	)
	var local_map_rect := Rect2(Vector2.ZERO, map_view.size)
	var mapped_tile: Vector2i = map_view.call("_tile_from_local", local_center)
	var click_geometry_checks := {
		"center_inside_viewport": viewport_rect.has_point(local_center),
		"center_inside_map": local_map_rect.has_point(local_center),
		"mapped_tile_exact": mapped_tile == start,
	}
	if not _checks_exact(click_geometry_checks):
		_fail("Map Editor %d mouse-inspect fixture did not map the visible tile center exactly: %s" % [width, JSON.stringify({
			"checks": click_geometry_checks,
			"start": start,
			"mapped_tile": mapped_tile,
			"local_center": local_center,
			"viewport_rect": viewport_rect,
			"map_rect": local_map_rect,
		})])
		return false
	var authority_before := _focus_background_authority(shell)
	await _click_map_tile(shell, start)
	var mouse_state := _canvas_action_state(shell)
	if _focus_background_authority(shell) != authority_before or _package_file_state() != package_state:
		_fail("Map Editor %d canvas mouse inspect mutated background authority." % width)
		return false
	if not await _reset_case(shell, source_id, false):
		return false
	var direct_setup := _prepare_canvas_action(shell, "inspect")
	var mouse_setup_checks := _canvas_setup_equality_checks(setup, direct_setup)
	if direct_setup != setup or not _checks_exact(mouse_setup_checks):
		_fail("Map Editor %d mouse-inspect direct fixture was not identical: %s" % [
			width,
			JSON.stringify({"checks": mouse_setup_checks, "differences": _canvas_setup_differences(setup, direct_setup)}),
		])
		return false
	shell.call("_on_map_tile_pressed", direct_setup.get("start", Vector2i.ZERO))
	await _settle()
	var mouse_direct_state := _canvas_action_state(shell)
	var mouse_action_checks := _canvas_action_state_equality_checks(mouse_state, mouse_direct_state)
	if mouse_direct_state != mouse_state or not _checks_exact(mouse_action_checks):
		_fail("Map Editor %d canvas mouse inspect did not retain direct click parity: %s" % [
			width,
			JSON.stringify({"checks": mouse_action_checks, "differences": _top_level_differences(mouse_state, mouse_direct_state)}),
		])
		return false
	if not bool(mouse_state.get("session_identity_coherent", false)) \
			or not bool(mouse_direct_state.get("session_identity_coherent", false)):
		_fail("Map Editor %d canvas mouse/direct session identity was not internally coherent." % width)
		return false
	return true

func _prepare_canvas_action(shell: Node, mode: String) -> Dictionary:
	var session = shell.get("_session")
	if session == null:
		return {}
	var start := _first_property_empty_tile(shell)
	if start.x < 0:
		return {}
	var map_size := OverworldRules.derive_map_size(session)
	var finish := Vector2i(mini(start.x + 1, map_size.x - 1), start.y)
	if finish == start:
		finish = Vector2i(maxi(start.x - 1, 0), start.y)
	shell.call("validation_select_tile", start.x, start.y)
	match mode:
		"inspect":
			shell.call("validation_set_tool", "inspect")
		"terrain":
			var terrain_id := _alternate_terrain_id(shell, start)
			if terrain_id == "":
				return {}
			shell.call("validation_select_terrain", terrain_id)
			shell.call("validation_set_tool", "terrain")
		"road":
			shell.call("validation_set_tool", "road")
		"road_path":
			shell.call("validation_set_tool", "road_path")
		_:
			return {}
	var canonical_working_copy := _canonical_canvas_working_copy(session.to_dict())
	return {
		"ok": true,
		"mode": mode,
		"start": start,
		"finish": finish,
		"working_copy": canonical_working_copy.get("payload", {}),
		"session_identity_coherent": bool(canonical_working_copy.get("identity_coherent", false)),
		"selected_terrain_id": String(shell.get("_selected_terrain_id")),
	}

func _canvas_setup_equality_checks(before: Dictionary, after: Dictionary) -> Dictionary:
	var checks := {
		"whole_setup_exact": after == before,
		"ok_exact": after.get("ok") == before.get("ok"),
		"mode_exact": after.get("mode") == before.get("mode"),
		"start_exact": after.get("start") == before.get("start"),
		"finish_exact": after.get("finish") == before.get("finish"),
		"selected_terrain_id_exact": after.get("selected_terrain_id") == before.get("selected_terrain_id"),
		"before_session_identity_coherent": bool(before.get("session_identity_coherent", false)),
		"after_session_identity_coherent": bool(after.get("session_identity_coherent", false)),
		"working_copy_exact": after.get("working_copy") == before.get("working_copy"),
	}
	var before_working: Dictionary = before.get("working_copy", {})
	var after_working: Dictionary = after.get("working_copy", {})
	var working_keys: Array = before_working.keys()
	for key in after_working.keys():
		if key not in working_keys:
			working_keys.append(key)
	working_keys.sort_custom(func(a, b): return String(a) < String(b))
	for key in working_keys:
		checks["working_copy_%s_exact" % String(key)] = before_working.has(key) \
			and after_working.has(key) and before_working[key] == after_working[key]
	return checks

func _canvas_setup_differences(before: Dictionary, after: Dictionary) -> Dictionary:
	var differences := {}
	for key in ["ok", "mode", "start", "finish", "selected_terrain_id", "session_identity_coherent"]:
		if before.get(key) != after.get(key):
			differences[key] = {"before": before.get(key), "after": after.get(key)}
	var before_working: Dictionary = before.get("working_copy", {})
	var after_working: Dictionary = after.get("working_copy", {})
	var working_keys: Array = before_working.keys()
	for key in after_working.keys():
		if key not in working_keys:
			working_keys.append(key)
	working_keys.sort_custom(func(a, b): return String(a) < String(b))
	var working_differences := {}
	for key in working_keys:
		if not before_working.has(key) or not after_working.has(key) or before_working[key] != after_working[key]:
			working_differences[String(key)] = {
				"before": before_working.get(key),
				"after": after_working.get(key),
			}
	if not working_differences.is_empty():
		differences["working_copy"] = working_differences
	return differences

func _top_level_differences(before: Dictionary, after: Dictionary) -> Dictionary:
	var differences := {}
	var keys: Array = before.keys()
	for key in after.keys():
		if key not in keys:
			keys.append(key)
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key in keys:
		if not before.has(key) or not after.has(key) or before[key] != after[key]:
			differences[String(key)] = {
				"exact": false,
				"before": before.get(key),
				"after": after.get(key),
			}
	return differences

func _activate_canvas_action(
	map_view: Control,
	setup: Dictionary,
	accept_kind: String,
	direct: bool,
	shell: Node
) -> void:
	var start: Vector2i = setup.get("start", Vector2i.ZERO)
	var finish: Vector2i = setup.get("finish", start)
	if direct:
		shell.call("_on_map_tile_pressed", start)
	else:
		if accept_kind == "joypad_a":
			await _press_joypad_button(JOY_BUTTON_A)
		else:
			await _press_key(KEY_ENTER)
	if String(setup.get("mode", "")) != "road_path":
		return
	if direct:
		shell.call("_on_map_tile_pressed", finish)
	else:
		shell.call("validation_select_tile", finish.x, finish.y)
		shell.call("validation_set_tool", "road_path")
		map_view.grab_focus()
		await _settle()
		if accept_kind == "joypad_a":
			await _press_joypad_button(JOY_BUTTON_A)
		else:
			await _press_key(KEY_ENTER)
	await _settle()

func _canvas_action_state(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var session = shell.get("_session")
	var canonical_working_copy := _canonical_canvas_working_copy(session.to_dict() if session != null else {})
	return {
		"working_copy": canonical_working_copy.get("payload", {}),
		"session_identity_coherent": bool(canonical_working_copy.get("identity_coherent", false)),
		"dirty": bool(snapshot.get("dirty", false)),
		"tool": String(snapshot.get("tool", "")),
		"selected_tile": snapshot.get("selected_tile", {}).duplicate(true),
		"status_text": String(snapshot.get("status_text", "")),
		"terrain_placement": snapshot.get("terrain_placement", {}).duplicate(true),
		"road_tile_count": int(snapshot.get("road_tile_count", -1)),
		"pending_road_path_start": snapshot.get("pending_road_path_start", {}).duplicate(true),
	}

func _canvas_action_state_equality_checks(before: Dictionary, after: Dictionary) -> Dictionary:
	var checks := {"whole_action_state_exact": after == before}
	var keys: Array = before.keys()
	for key in after.keys():
		if key not in keys:
			keys.append(key)
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key in keys:
		checks["action_state_%s_exact" % String(key)] = before.has(key) \
			and after.has(key) and before[key] == after[key]
	return checks

func _canonical_canvas_working_copy(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"identity_coherent": false, "payload": {}}
	var payload: Dictionary = (value as Dictionary).duplicate(true)
	var root_session_id := String(payload.get("session_id", ""))
	var overworld: Dictionary = (payload.get("overworld", {}) as Dictionary).duplicate(true)
	var adoption: Dictionary = (overworld.get("native_random_map_package_session_adoption", {}) as Dictionary).duplicate(true)
	var adoption_session_id := String(adoption.get("session_id", ""))
	var identity_coherent := root_session_id != "" and root_session_id == adoption_session_id
	payload.erase("session_id")
	adoption.erase("session_id")
	overworld["native_random_map_package_session_adoption"] = adoption
	payload["overworld"] = overworld
	return {"identity_coherent": identity_coherent, "payload": payload}

func _alternate_terrain_id(shell: Node, tile: Vector2i) -> String:
	var session = shell.get("_session")
	if session == null:
		return ""
	var current := String(session.overworld.get("map", [])[tile.y][tile.x])
	var snapshot: Dictionary = shell.call("validation_snapshot")
	for terrain_value in snapshot.get("terrain_options", []):
		if terrain_value is Dictionary:
			var terrain_id := String(terrain_value.get("id", ""))
			if terrain_id != "" and terrain_id != current:
				return terrain_id
	return ""

func _canvas_selected_tile(shell: Node) -> Vector2i:
	var selected: Dictionary = shell.call("validation_snapshot").get("selected_tile", {})
	return Vector2i(int(selected.get("x", -1)), int(selected.get("y", -1)))

func _canvas_dirty(shell: Node) -> bool:
	return bool(shell.call("validation_snapshot").get("dirty", true))

func _await_exact_canvas_timer_step(shell: Node, expected_tile: Vector2i, timeout_msec: int) -> bool:
	var before := _canvas_selected_tile(shell)
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() <= deadline:
		await get_tree().process_frame
		var current := _canvas_selected_tile(shell)
		if current == expected_tile:
			return current != before
		if current != before:
			return false
	return false

func _click_map_tile(shell: Node, tile: Vector2i) -> void:
	var map_view: Control = shell.get_node("%Map")
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var board: Dictionary = metrics.get("board_rect", {})
	var map_size: Dictionary = metrics.get("map_size", {})
	var cell_size := Vector2(
		float(board.get("width", 0.0)) / maxf(float(map_size.get("x", 1)), 1.0),
		float(board.get("height", 0.0)) / maxf(float(map_size.get("y", 1)), 1.0)
	)
	var local_position := Vector2(float(board.get("x", 0.0)), float(board.get("y", 0.0))) \
		+ Vector2((float(tile.x) + 0.5) * cell_size.x, (float(tile.y) + 0.5) * cell_size.y)
	var root_position := map_view.get_global_rect().position + local_position
	var motion := InputEventMouseMotion.new()
	motion.position = root_position
	motion.global_position = root_position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed_state in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = root_position
		event.global_position = root_position
		event.pressed = pressed_state
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _settle()

func _hover_map_tile(shell: Node, tile: Vector2i) -> void:
	var map_view: Control = shell.get_node("%Map")
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var board: Dictionary = metrics.get("board_rect", {})
	var map_size: Dictionary = metrics.get("map_size", {})
	var cell_size := Vector2(
		float(board.get("width", 0.0)) / maxf(float(map_size.get("x", 1)), 1.0),
		float(board.get("height", 0.0)) / maxf(float(map_size.get("y", 1)), 1.0)
	)
	var local_position := Vector2(float(board.get("x", 0.0)), float(board.get("y", 0.0))) \
		+ Vector2((float(tile.x) + 0.5) * cell_size.x, (float(tile.y) + 0.5) * cell_size.y)
	var root_position := map_view.get_global_rect().position + local_position
	var motion := InputEventMouseMotion.new()
	motion.position = root_position
	motion.global_position = root_position
	get_viewport().push_input(motion, true)
	await _settle()

func _canvas_selected_tile_visible(shell: Node) -> bool:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var selected: Dictionary = snapshot.get("selected_tile", {})
	var bounds: Dictionary = snapshot.get("map_viewport", {}).get("visible_bounds", {})
	var tile := Vector2i(int(selected.get("x", -1)), int(selected.get("y", -1)))
	return tile.x >= int(bounds.get("x", 0)) and tile.y >= int(bounds.get("y", 0)) \
		and tile.x < int(bounds.get("x", 0)) + int(bounds.get("width", 0)) \
		and tile.y < int(bounds.get("y", 0)) + int(bounds.get("height", 0))

func _camera_precise(metrics: Dictionary) -> Vector2:
	var focus: Dictionary = metrics.get("camera_focus_tile_precise", {})
	return Vector2(float(focus.get("x", 0.0)), float(focus.get("y", 0.0)))

func _choose_camera_pan_probe(map_view: Control, metrics: Dictionary, amount: int) -> Dictionary:
	var origin := _camera_precise(metrics)
	var chosen := {"direction": Vector2i.ZERO, "delta": Vector2.ZERO, "restored_exact": false, "axis_aligned": false}
	var all_probes_restored_exact := true
	var chosen_magnitude := 0.0
	for candidate in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var probe := await _probe_camera_pan_delta(map_view, origin, candidate, amount)
		all_probes_restored_exact = all_probes_restored_exact and bool(probe.get("restored_exact", false))
		if not all_probes_restored_exact:
			break
		var delta: Vector2 = probe.get("delta", Vector2.ZERO)
		if bool(probe.get("axis_aligned", false)) and delta.length() > chosen_magnitude + 0.0001:
			chosen = probe
			chosen_magnitude = delta.length()
	chosen["all_probes_restored_exact"] = all_probes_restored_exact
	return chosen

func _probe_camera_pan_delta(map_view: Control, origin: Vector2, direction: Vector2i, amount: int) -> Dictionary:
	map_view.call("pan_tiles", direction * amount)
	await _settle()
	var delta := _camera_precise(map_view.call("validation_view_metrics")) - origin
	map_view.call("_set_camera_center", origin, true)
	await _settle()
	var restored_exact := _vector2_approx(_camera_precise(map_view.call("validation_view_metrics")), origin)
	var signed_component := delta.dot(Vector2(direction))
	var orthogonal_component := absf(delta.dot(Vector2(-direction.y, direction.x)))
	return {
		"direction": direction,
		"delta": delta,
		"restored_exact": restored_exact,
		"axis_aligned": orthogonal_component <= 0.001 and signed_component > 0.01,
		"signed_component": signed_component,
		"orthogonal_component": orthogonal_component,
	}

func _wheel_button_for_direction(direction: Vector2i) -> MouseButton:
	match direction:
		Vector2i.LEFT: return MOUSE_BUTTON_WHEEL_LEFT
		Vector2i.RIGHT: return MOUSE_BUTTON_WHEEL_RIGHT
		Vector2i.UP: return MOUSE_BUTTON_WHEEL_UP
		_: return MOUSE_BUTTON_WHEEL_DOWN

func _press_canvas_direction_key(direction: Vector2i) -> void:
	match direction:
		Vector2i.LEFT: await _press_key(KEY_LEFT)
		Vector2i.RIGHT: await _press_key(KEY_RIGHT)
		Vector2i.UP: await _press_key(KEY_UP)
		Vector2i.DOWN: await _press_key(KEY_DOWN)

func _vector2_approx(left: Vector2, right: Vector2) -> bool:
	return left.distance_to(right) <= 0.001

func _drag_map_view(map_view: Control, delta: Vector2) -> void:
	var root_center := map_view.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = root_center
	press.global_position = root_center
	press.pressed = true
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = root_center + delta
	motion.global_position = root_center + delta
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = root_center + delta
	release.global_position = root_center + delta
	release.pressed = false
	get_viewport().push_input(release, true)
	await _settle()

func _wheel_map_view(map_view: Control, button_index: MouseButton) -> void:
	var root_center := map_view.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = root_center
	event.global_position = root_center
	event.pressed = true
	get_viewport().push_input(event, true)
	await _settle()

func _editor_map_repeat_snapshot(shell: Node) -> Dictionary:
	var timer: Timer = shell.get("_editor_map_joypad_repeat_timer") as Timer
	return {
		"direction": shell.get("_held_editor_map_joypad_direction"),
		"action": String(shell.get("_held_editor_map_joypad_action")),
		"button": int(shell.get("_held_editor_map_joypad_button")),
		"device": int(shell.get("_held_editor_map_joypad_device")),
		"stopped": timer == null or timer.is_stopped(),
		"wait_time": timer.wait_time if timer != null else -1.0,
	}

func _editor_map_repeat_stopped(shell: Node) -> bool:
	var snapshot := _editor_map_repeat_snapshot(shell)
	return bool(snapshot.get("stopped", false)) \
		and snapshot.get("direction", Vector2i.ONE) == Vector2i.ZERO \
		and String(snapshot.get("action", "invalid")) == "" \
		and int(snapshot.get("button", 0)) == -1 \
		and int(snapshot.get("device", 0)) == -1

func _enabled_focus_controls(controls: Array[Control]) -> Array[Control]:
	var enabled: Array[Control] = []
	for control in controls:
		if control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE \
				and not (control is BaseButton and (control as BaseButton).disabled):
			enabled.append(control)
	return enabled

func _control_names(controls: Array[Control]) -> Array[String]:
	var names: Array[String] = []
	for control in controls:
		names.append(String(control.name))
	return names

func _disabled_control_names(controls: Array[Control]) -> Array[String]:
	var names: Array[String] = []
	for control in controls:
		if control is BaseButton and (control as BaseButton).disabled:
			names.append(String(control.name))
	return names

func _unique_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if value not in unique:
			unique.append(value)
	return unique

func _assert_focus_links_exact(controls: Array[Control]) -> bool:
	if controls.size() < 2:
		return false
	for index in range(controls.size()):
		var control := controls[index]
		var next_control := controls[(index + 1) % controls.size()]
		var previous_control := controls[(index - 1 + controls.size()) % controls.size()]
		if control.get_node_or_null(control.focus_next) != next_control \
				or control.get_node_or_null(control.focus_previous) != previous_control \
				or control.get_node_or_null(control.focus_neighbor_bottom) != next_control \
				or control.get_node_or_null(control.focus_neighbor_top) != previous_control:
			return false
	return true

func _exercise_physical_focus_cycles(controls: Array[Control], label: String) -> bool:
	for direction in ["tab", "shift_tab"]:
		controls[0].grab_focus()
		await _settle()
		var visited: Array[String] = [String(controls[0].name)]
		for step in range(1, controls.size() + 1):
			match direction:
				"tab": await _press_key(KEY_TAB)
				"shift_tab": await _press_key(KEY_TAB, true)
			var expected_index := step % controls.size() if direction == "tab" \
				else (controls.size() - (step % controls.size())) % controls.size()
			var expected := controls[expected_index]
			if get_viewport().gui_get_focus_owner() != expected:
				_fail("Map Editor %s physical %s focus step %d expected %s, got %s." % [
					label,
					direction,
					step,
					expected.name,
					get_viewport().gui_get_focus_owner().name if get_viewport().gui_get_focus_owner() != null else "none",
				])
				return false
			if step < controls.size():
				visited.append(String(expected.name))
		var expected_names := _control_names(controls)
		if direction == "shift_tab":
			var reverse_expected_names: Array[String] = [expected_names[0]]
			reverse_expected_names.append_array(_reversed_strings(expected_names.slice(1)))
			expected_names = reverse_expected_names
		if visited != expected_names or _unique_strings(visited).size() != controls.size():
			_fail("Map Editor %s physical %s cycle duplicated or skipped controls: %s." % [label, direction, JSON.stringify(visited)])
			return false
	return true

func _reversed_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for index in range(values.size() - 1, -1, -1):
		result.append(String(values[index]))
	return result

func _property_disabled_state_exact(
	shell: Node,
	selected_disabled: bool,
	owner_disabled: bool,
	difficulty_disabled: bool,
	collected_disabled: bool,
	apply_disabled: bool
) -> bool:
	return (shell.get_node("%SelectedObjectPicker") as OptionButton).disabled == selected_disabled \
		and (shell.get_node("%PropertyOwnerPicker") as OptionButton).disabled == owner_disabled \
		and (shell.get_node("%PropertyDifficultyPicker") as OptionButton).disabled == difficulty_disabled \
		and (shell.get_node("%PropertyCollectedFlag") as CheckBox).disabled == collected_disabled \
		and (shell.get_node("%ApplyObjectProperties") as Button).disabled == apply_disabled

func _tool_rail_layout_snapshot(
	shell: Node,
	require_selected_items: bool,
	expected_semantic_tooltips: Dictionary
) -> Dictionary:
	var map_view: Control = shell.get_node("%Map")
	var tool_rail: Control = shell.get_node("%ToolRail")
	var tool_scroll: ScrollContainer = shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll")
	var tool_box: Control = shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll/ToolBox")
	var tool_buttons: GridContainer = shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll/ToolBox/ToolButtons")
	var scroll_rect := tool_scroll.get_global_rect()
	var vbar := tool_scroll.get_v_scroll_bar()
	var hbar := tool_scroll.get_h_scroll_bar()
	var inner_rect := scroll_rect
	if vbar != null and vbar.visible:
		inner_rect.size.x -= vbar.size.x
	if hbar != null and hbar.visible:
		inner_rect.size.y -= hbar.size.y
	var descendant_differences := {}
	var visible_descendant_count := 0
	var controls: Array[Control] = [tool_box]
	for node_value in tool_box.find_children("*", "Control", true, false):
		if node_value is Control:
			controls.append(node_value as Control)
	for control in controls:
		if not control.is_visible_in_tree():
			continue
		visible_descendant_count += 1
		var rect := control.get_global_rect()
		if not _rect_horizontally_contained(inner_rect, rect):
			descendant_differences[String(control.get_path())] = {
				"rect": rect,
				"inner_rect": inner_rect,
			}
	var picker_contracts := {}
	var picker_checks := {}
	for picker_name in TOOL_RAIL_PICKER_NAMES:
		var picker: OptionButton = shell.get_node("%%%s" % picker_name)
		var popup := picker.get_popup()
		var item_texts: Array[String] = []
		var popup_texts: Array[String] = []
		for index in range(picker.get_item_count()):
			item_texts.append(picker.get_item_text(index))
		for index in range(popup.get_item_count()):
			popup_texts.append(popup.get_item_text(index))
		var selected_valid := picker.selected >= 0 and picker.selected < picker.get_item_count()
		var selected_text := picker.get_item_text(picker.selected) if selected_valid else ""
		var contract := {
			"selected": picker.selected,
			"selected_text": selected_text,
			"display_text": picker.text,
			"selected_metadata": picker.get_item_metadata(picker.selected) if selected_valid else null,
			"item_texts": item_texts,
			"popup_texts": popup_texts,
			"tooltip": picker.tooltip_text,
			"expected_semantic_tooltip": String(expected_semantic_tooltips.get(String(picker_name), "")),
			"fit_to_longest_item": picker.fit_to_longest_item,
			"clip_text": picker.clip_text,
			"rect": picker.get_global_rect(),
		}
		picker_contracts[String(picker_name)] = contract
		picker_checks[String(picker_name)] = (
			_rect_horizontally_contained(inner_rect, picker.get_global_rect())
			and not picker.fit_to_longest_item
			and picker.clip_text
			and item_texts == popup_texts
			and picker.tooltip_text == String(expected_semantic_tooltips.get(String(picker_name), ""))
			and (not require_selected_items or (selected_valid and selected_text != "" and picker.text == selected_text))
		)
	var two_column_width := _measured_two_column_minimum_width(tool_buttons)
	var expected_columns := 2 if two_column_width <= inner_rect.size.x + 0.5 else 1
	var checks := {
		"live_map_minimum_width": map_view.size.x >= 820.0,
		"tool_rail_minimum_width": tool_rail.size.x >= 340.0,
		"tool_box_horizontally_contained": _rect_horizontally_contained(inner_rect, tool_box.get_global_rect()),
		"all_visible_descendants_horizontally_contained": descendant_differences.is_empty(),
		"horizontal_scroll_range_empty": hbar != null and hbar.max_value <= hbar.page + 1.0,
		"horizontal_scroll_zero": hbar != null and absf(hbar.value) <= 0.5 and tool_scroll.scroll_horizontal == 0,
		"columns_match_measured_fit": tool_buttons.columns == expected_columns,
		"six_picker_contracts_exact": TOOL_RAIL_PICKER_NAMES.size() == 6 and _checks_exact(picker_checks),
	}
	return {
		"ok": _checks_exact(checks),
		"checks": checks,
		"map_width": map_view.size.x,
		"rail_width": tool_rail.size.x,
		"scroll_rect": scroll_rect,
		"inner_rect": inner_rect,
		"tool_box_rect": tool_box.get_global_rect(),
		"visible_descendant_count": visible_descendant_count,
		"descendant_differences": descendant_differences,
		"hbar_value": hbar.value if hbar != null else -1.0,
		"hbar_max": hbar.max_value if hbar != null else -1.0,
		"hbar_page": hbar.page if hbar != null else -1.0,
		"vscroll": tool_scroll.scroll_vertical,
		"columns": tool_buttons.columns,
		"expected_columns": expected_columns,
		"two_column_minimum_width": two_column_width,
		"picker_checks": picker_checks,
		"picker_contracts": picker_contracts,
	}

func _rect_horizontally_contained(outer: Rect2, inner: Rect2, tolerance: float = 1.0) -> bool:
	return inner.position.x >= outer.position.x - tolerance \
		and inner.end.x <= outer.end.x + tolerance

func _measured_two_column_minimum_width(tool_buttons: GridContainer) -> float:
	var column_widths := [0.0, 0.0]
	var visible_index := 0
	for child_value in tool_buttons.get_children():
		if not (child_value is Control) or not (child_value as Control).visible:
			continue
		var control := child_value as Control
		var column_index := visible_index % 2
		column_widths[column_index] = maxf(float(column_widths[column_index]), control.get_combined_minimum_size().x)
		visible_index += 1
	if visible_index < 2:
		return float(column_widths[0])
	return float(column_widths[0]) + float(column_widths[1]) + float(tool_buttons.get_theme_constant("h_separation"))

func _tool_rail_picker_state(shell: Node) -> Dictionary:
	var result := {}
	for picker_name in TOOL_RAIL_PICKER_NAMES:
		var picker: OptionButton = shell.get_node("%%%s" % picker_name)
		var popup := picker.get_popup()
		var selected_valid := picker.selected >= 0 and picker.selected < picker.get_item_count()
		var item_texts: Array[String] = []
		var popup_texts: Array[String] = []
		for index in range(picker.get_item_count()):
			item_texts.append(picker.get_item_text(index))
		for index in range(popup.get_item_count()):
			popup_texts.append(popup.get_item_text(index))
		result[String(picker_name)] = {
			"selected": picker.selected,
			"text": picker.get_item_text(picker.selected) if selected_valid else "",
			"metadata": picker.get_item_metadata(picker.selected) if selected_valid else null,
			"tooltip": picker.tooltip_text,
			"item_count": picker.get_item_count(),
			"item_texts": item_texts,
			"popup_texts": popup_texts,
		}
	return result

func _capture_tool_rail_semantic_tooltips(shell: Node) -> Dictionary:
	var result := {}
	for picker_name in TOOL_RAIL_PICKER_NAMES:
		var picker: OptionButton = shell.get_node("%%%s" % picker_name)
		result[String(picker_name)] = picker.tooltip_text
	return result

func _validate_tool_rail_family_layouts(shell: Node, width: int) -> Dictionary:
	var family_picker: OptionButton = shell.get_node("%ObjectFamilyPicker")
	var original_family := String(family_picker.get_item_metadata(family_picker.selected))
	var family_ids: Array[String] = []
	var family_columns := {}
	for index in range(family_picker.get_item_count()):
		family_picker.select(index)
		shell.call("_on_object_family_selected", index)
		await _settle()
		var family_id := String(family_picker.get_item_metadata(family_picker.selected))
		var expected_family_id: String = TOOL_RAIL_FAMILY_IDS[index] if index < TOOL_RAIL_FAMILY_IDS.size() else ""
		if family_picker.selected != index or family_id != expected_family_id:
			return _fail_dict("Map Editor %d ToolRail family selection %d was not source-exact: selected=%d actual=%s expected=%s" % [
				width,
				index,
				family_picker.selected,
				family_id,
				expected_family_id,
			])
		family_ids.append(family_id)
		var semantic_tooltips := _capture_tool_rail_semantic_tooltips(shell)
		var snapshot := _tool_rail_layout_snapshot(shell, true, semantic_tooltips)
		if not bool(snapshot.get("ok", false)):
			return _fail_dict("Map Editor %d ToolRail family %s was not horizontally exact: %s" % [width, family_id, JSON.stringify(snapshot)])
		family_columns[family_id] = int(snapshot.get("columns", 0))
	for index in range(family_picker.get_item_count()):
		if String(family_picker.get_item_metadata(index)) == original_family:
			family_picker.select(index)
			shell.call("_on_object_family_selected", index)
			await _settle()
			break
	if family_picker.selected < 0 \
			or String(family_picker.get_item_metadata(family_picker.selected)) != original_family:
		return _fail_dict("Map Editor %d ToolRail family selection did not restore %s exactly." % [width, original_family])
	if family_ids != TOOL_RAIL_FAMILY_IDS:
		return _fail_dict("Map Editor %d ToolRail family ids were not exact: %s" % [width, JSON.stringify(family_ids)])
	return {"ok": true, "family_ids": family_ids, "columns": family_columns}

func _select_longest_property_object_fixture(shell: Node) -> Dictionary:
	var session = shell.get("_session")
	if session == null:
		return {}
	var selected_picker: OptionButton = shell.get_node("%SelectedObjectPicker")
	var best := {"text": "", "tile": Vector2i(-1, -1), "index": -1}
	for key in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for placement_value in session.overworld.get(key, []):
			if not (placement_value is Dictionary):
				continue
			var tile := Vector2i(int(placement_value.get("x", -1)), int(placement_value.get("y", -1)))
			shell.call("validation_select_tile", tile.x, tile.y)
			await _settle()
			for index in range(selected_picker.get_item_count()):
				var text := selected_picker.get_item_text(index)
				if text.length() > String(best.get("text", "")).length():
					best = {"text": text, "tile": tile, "index": index}
	var best_tile: Vector2i = best.get("tile", Vector2i(-1, -1))
	var best_index := int(best.get("index", -1))
	if best_tile.x < 0 or best_index < 0 or String(best.get("text", "")) == "":
		return best
	shell.call("validation_select_tile", best_tile.x, best_tile.y)
	await _settle()
	if best_index >= selected_picker.get_item_count():
		return best
	shell.call("_on_selected_property_object_selected", best_index)
	await _settle()
	best["ok"] = selected_picker.selected == best_index \
		and selected_picker.text == String(best.get("text", ""))
	return best

func _validate_tool_rail_resize_roundtrip(shell: Node, package_state: Dictionary, initial_width: int) -> Dictionary:
	var layout_host := shell.get_parent() as Control
	var tool_scroll: ScrollContainer = shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll")
	var focus_before := get_viewport().gui_get_focus_owner() as Control
	var picker_state_before := _tool_rail_picker_state(shell)
	var vscroll_before := tool_scroll.scroll_vertical
	var authority_before := _focus_background_authority(shell)
	var semantic_tooltips_before := _capture_tool_rail_semantic_tooltips(shell)
	var initial_layout := _tool_rail_layout_snapshot(shell, true, semantic_tooltips_before)
	var resize_width := 1920 if initial_width == 1280 else 1280
	layout_host.size = Vector2(float(resize_width), 720.0)
	get_window().size = Vector2i(resize_width, 720)
	await _settle()
	var resized_layout := _tool_rail_layout_snapshot(shell, true, semantic_tooltips_before)
	if not bool(resized_layout.get("ok", false)):
		return _fail_dict("Map Editor %d->%d ToolRail resize was not exact: %s" % [initial_width, resize_width, JSON.stringify(resized_layout)])
	layout_host.size = Vector2(float(initial_width), 720.0)
	get_window().size = Vector2i(initial_width, 720)
	await _settle()
	var restored_layout := _tool_rail_layout_snapshot(shell, true, semantic_tooltips_before)
	var picker_state_after := _tool_rail_picker_state(shell)
	var checks := {
		"initial_layout_exact": bool(initial_layout.get("ok", false)),
		"resized_layout_exact": bool(resized_layout.get("ok", false)),
		"restored_layout_exact": bool(restored_layout.get("ok", false)),
		"focus_identity_exact": get_viewport().gui_get_focus_owner() == focus_before,
		"picker_selection_and_tooltip_exact": picker_state_after == picker_state_before,
		"vertical_scroll_exact": tool_scroll.scroll_vertical == vscroll_before,
		"columns_restored_exact": restored_layout.get("columns") == initial_layout.get("columns"),
		"background_authority_exact": _focus_background_authority(shell) == authority_before,
		"package_files_exact": _package_file_state() == package_state,
	}
	if not _checks_exact(checks):
		return _fail_dict("Map Editor %d->%d->%d ToolRail resize did not restore exact focus/selection/scroll/authority: %s" % [
			initial_width,
			resize_width,
			initial_width,
			JSON.stringify({
				"checks": checks,
				"initial_layout": initial_layout,
				"resized_layout": resized_layout,
				"restored_layout": restored_layout,
				"picker_before": picker_state_before,
				"picker_after": picker_state_after,
				"vscroll_before": vscroll_before,
				"vscroll_after": tool_scroll.scroll_vertical,
			}),
		])
	return {
		"ok": true,
		"widths": [initial_width, resize_width, initial_width],
		"initial_columns": int(initial_layout.get("columns", 0)),
		"resized_columns": int(resized_layout.get("columns", 0)),
		"restored_columns": int(restored_layout.get("columns", 0)),
		"focus_selection_scroll_authority_exact": true,
	}

func _tool_scroll_reveal_snapshot(tool_scroll: ScrollContainer, button: Control) -> Dictionary:
	var scroll_rect := tool_scroll.get_global_rect()
	var button_rect := button.get_global_rect()
	var intersection := scroll_rect.intersection(button_rect)
	var vscroll := tool_scroll.get_v_scroll_bar()
	var focus_owner := get_viewport().gui_get_focus_owner()
	return {
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"scroll_vertical": tool_scroll.scroll_vertical,
		"vbar_value": vscroll.value,
		"vbar_max": vscroll.max_value,
		"vbar_page": vscroll.page,
		"vbar_width": vscroll.size.x if vscroll.visible else 0.0,
		"inner_viewport_width": scroll_rect.size.x - (vscroll.size.x if vscroll.visible else 0.0),
		"scroll_rect": scroll_rect,
		"button_rect": button_rect,
		"intersection_rect": intersection,
		"intersection_area": intersection.get_area(),
		"intersection_width": intersection.size.x,
		"intersection_height": intersection.size.y,
		"scroll_width": scroll_rect.size.x,
		"button_width": button_rect.size.x,
		"button_height": button_rect.size.y,
		"horizontal_fully_visible": button_rect.position.x >= scroll_rect.position.x - 1.0 \
			and button_rect.end.x <= scroll_rect.end.x - (vscroll.size.x if vscroll.visible else 0.0) + 1.0,
		"vertical_fully_visible": button_rect.position.y >= scroll_rect.position.y - 1.0 \
			and button_rect.end.y <= scroll_rect.end.y + 1.0,
		"button_enclosed": scroll_rect.encloses(button_rect),
		"button_visible": button.is_visible_in_tree(),
		"scroll_visible": tool_scroll.is_visible_in_tree(),
		"scroll_ancestry_exact": tool_scroll.is_ancestor_of(button),
	}

func _first_property_empty_tile(shell: Node) -> Vector2i:
	var session = shell.get("_session")
	if session == null:
		return Vector2i(-1, -1)
	var occupied := {}
	for key in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for placement_value in session.overworld.get(key, []):
			if placement_value is Dictionary:
				occupied["%d,%d" % [int(placement_value.get("x", -1)), int(placement_value.get("y", -1))]] = true
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not occupied.has("%d,%d" % [x, y]):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _first_placement_tile(shell: Node, key: String) -> Vector2i:
	var session = shell.get("_session")
	if session == null:
		return Vector2i(-1, -1)
	var placements = session.overworld.get(key, [])
	if not (placements is Array) or placements.is_empty() or not (placements[0] is Dictionary):
		return Vector2i(-1, -1)
	return Vector2i(int(placements[0].get("x", -1)), int(placements[0].get("y", -1)))

func _on_focus_probe_signal(signal_id: String) -> void:
	_focus_signal_counts[signal_id] = int(_focus_signal_counts.get(signal_id, 0)) + 1

func _on_focus_probe_item_selected(_index: int, signal_id: String) -> void:
	_on_focus_probe_signal(signal_id)

func _focus_background_authority(shell: Node) -> Dictionary:
	var session = shell.get("_session")
	return {
		"working_copy": session.to_dict() if session != null else {},
		"active_session": SessionState.ensure_active_session().to_dict() if SessionState.has_playable_session() else {},
		"packages": _package_file_state(),
		"files": _capture_file_states(_tracked_authority_paths()),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _canonical_settings_transaction(),
		"profile": CampaignProgression.profile.duplicate(true),
		"selected_slot": SaveService.get_selected_manual_slot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"close_guard": AppRouter.validation_safe_close_guard_snapshot(),
		"return_route": AppRouter.validation_active_play_return_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
	}

func _validate_exclusive_parent_matrix(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	var rows := [
		{"id": "menu_1280", "width": 1280, "action": "menu", "cancel": "joypad_b", "confirm": "joypad_a"},
		{"id": "menu_1920", "width": 1920, "action": "menu", "cancel": "escape", "confirm": "enter"},
		{"id": "package_1280", "width": 1280, "action": "package", "cancel": "joypad_b", "confirm": "mouse"},
		{"id": "package_1920", "width": 1920, "action": "package", "cancel": "escape", "confirm": "joypad_a"},
		{"id": "quit_1280", "width": 1280, "action": "quit", "cancel": "joypad_b", "confirm": "enter"},
		{"id": "quit_1920", "width": 1920, "action": "quit", "cancel": "escape", "confirm": "mouse"},
	]
	var results: Array[Dictionary] = []
	for row_value in rows:
		var row: Dictionary = row_value
		var result := await _validate_exclusive_parent_row(shell, source_id, target_id, package_state, row)
		if result.is_empty():
			return {}
		results.append(result)
	return {"ok": true, "rows": results, "widths": [1280, 1920], "real_parent_probe": true, "stale_pending_release_noop": true}

func _validate_exclusive_parent_row(
	shell: Node,
	source_id: String,
	target_id: String,
	package_state: Dictionary,
	row: Dictionary
) -> Dictionary:
	var width := int(row.get("width", 1280))
	var action := String(row.get("action", "menu"))
	var layout_host := shell.get_parent() as Control
	var parent_probe: Button = shell.get_meta("exclusive_parent_probe") as Button
	if layout_host == null or parent_probe == null:
		return _fail_dict("Exclusive Map Editor host/probe is unavailable.")
	layout_host.size = Vector2(float(width), 720.0)
	get_window().size = Vector2i(width, 720)
	await _settle()
	if not await _reset_case(shell, source_id, true):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	if action == "package":
		var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
		if not bool(selected.get("ok", false)):
			return _fail_dict("Exclusive package row could not select its captured target.")
	var origin: Button = shell.get_node("%LoadMap") if action == "package" else shell.get_node("%Menu")
	origin.grab_focus()
	await _settle()
	await _open_dirty_transition(shell, action, target_id)
	var dialog: ConfirmationDialog = shell.get_node("DirtyTransitionConfirmationDialog")
	var opened: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var geometry := _exclusive_parent_click_geometry(parent_probe, dialog)
	if not _dirty_transition_opened_exact(opened, action, target_id, origin, dialog, width) or not bool(geometry.get("exact", false)):
		return _fail_dict("Exclusive %s row did not open with exact bounded native focus: %s / %s" % [action, JSON.stringify(opened), JSON.stringify(geometry)])
	var authority_before_block := _full_authority_state(shell)
	var transaction_before_block := _dirty_transaction_snapshot(shell)
	var parent_before := _parent_probe_count
	await _click_control(parent_probe)
	await _settle()
	var blocked_checks := {
		"probe_blocked": _parent_probe_count == parent_before,
		"transaction_exact": _dirty_transaction_snapshot(shell) == transaction_before_block,
		"authority_exact": _full_authority_state(shell) == authority_before_block,
		"safe_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(blocked_checks):
		return _fail_dict("Exclusive %s first parent click escaped: %s" % [action, JSON.stringify(blocked_checks)])
	await _send_cancel(String(row.get("cancel", "joypad_b")))
	var canceled: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(canceled.get("pending", true)) or bool(canceled.get("dialog_visible", true)) \
			or int(canceled.get("cancel_count", 0)) != 1 or int(canceled.get("confirm_count", 0)) != 0 \
			or get_viewport().gui_get_focus_owner() != origin \
			or _full_authority_state(shell) != authority_before_block:
		return _fail_dict("Exclusive %s physical cancel was not exact: %s" % [action, JSON.stringify(canceled)])
	var positive_before := _parent_probe_count
	var positive_authority := _full_authority_state(shell)
	await _click_control(parent_probe)
	await _settle()
	if _parent_probe_count != positive_before + 1 or _full_authority_state(shell) != positive_authority:
		return _fail_dict("Exclusive %s identical parent probe was not actionable after close." % action)

	# Queue a physical press into the root bridge, replace the pending Dictionary
	# synchronously, then deliver the release normally. Both stale events must no-op.
	await _open_dirty_transition(shell, action, target_id)
	var stale_pressed := InputEventKey.new()
	stale_pressed.keycode = KEY_ESCAPE
	stale_pressed.physical_keycode = KEY_ESCAPE
	stale_pressed.pressed = true
	shell.call("_on_root_window_input", stale_pressed)
	shell.call("validation_cancel_dirty_transition")
	shell.call("validation_request_dirty_transition", action, target_id if action == "package" else "")
	await _settle()
	var replacement_before := _dirty_transaction_snapshot(shell)
	var stale_released := InputEventKey.new()
	stale_released.keycode = KEY_ESCAPE
	stale_released.physical_keycode = KEY_ESCAPE
	stale_released.pressed = false
	Input.parse_input_event(stale_released)
	await _settle()
	if _dirty_transaction_snapshot(shell) != replacement_before or not dialog.visible \
			or dialog.get_cancel_button().get_viewport().gui_get_focus_owner() != dialog.get_cancel_button():
		return _fail_dict("Exclusive %s stale pending/release reached its replacement." % action)
	var authority_before_second := _full_authority_state(shell)
	var parent_before_second := _parent_probe_count
	await _click_control(parent_probe)
	await _settle()
	if _parent_probe_count != parent_before_second or _dirty_transaction_snapshot(shell) != replacement_before \
			or _full_authority_state(shell) != authority_before_second:
		return _fail_dict("Exclusive %s second parent click changed authority." % action)
	await _send_confirm(dialog, String(row.get("confirm", "enter")))
	await _settle()
	var confirmed: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var consequence_exact := false
	match action:
		"menu":
			consequence_exact = int(confirmed.get("menu_route_count", 0)) == 1
		"package":
			var editor_snapshot: Dictionary = shell.call("validation_snapshot")
			consequence_exact = int(confirmed.get("package_action_count", 0)) == 1 \
				and String(editor_snapshot.get("editor_source_package_id", "")) == target_id
		"quit":
			var quit_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
			consequence_exact = int(confirmed.get("quit_attempt_count", 0)) == 1 \
				and int(quit_snapshot.get("quit_attempt_count", 0)) == 1 \
				and int(quit_snapshot.get("suppressed_quit_count", 0)) == 1
	if bool(confirmed.get("pending", true)) or bool(confirmed.get("dialog_visible", true)) \
			or int(confirmed.get("confirm_count", 0)) != 1 or not consequence_exact \
			or _package_file_state() != package_state:
		return _fail_dict("Exclusive %s deliberate confirm was not exact: %s" % [action, JSON.stringify(confirmed)])
	return {"id": row.get("id"), "width": width, "action": action, "cancel": row.get("cancel"), "confirm": row.get("confirm"), "blocked": true, "stale_noop": true}

func _open_dirty_transition(shell: Node, action: String, target_id: String) -> void:
	if action == "quit":
		get_tree().root.close_requested.emit()
	else:
		shell.call("validation_request_dirty_transition", action, target_id if action == "package" else "")
	await _settle()

func _send_cancel(method: String) -> void:
	if method == "escape":
		await _press_key(KEY_ESCAPE)
	else:
		await _press_joypad_button(JOY_BUTTON_B)

func _send_confirm(dialog: ConfirmationDialog, method: String) -> void:
	dialog.get_ok_button().grab_focus()
	await get_tree().process_frame
	match method:
		"joypad_a": await _press_joypad_button(JOY_BUTTON_A)
		"mouse": await _click_control(dialog.get_ok_button())
		_: await _press_key(KEY_ENTER)

func _validate_menu_transition(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	if not await _reset_case(shell, source_id, true):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	var origin: Button = shell.get_node("%Menu")
	var before := _protected_state(shell)
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	if not _assert_dialog(shell, "menu", "", "Keep Editing", "Menu"):
		return {}
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Menu controller B"):
		return {}
	var request: Dictionary = shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	if not bool(request.get("pending", false)) or not _assert_dialog(shell, "menu", "", "Keep Editing", "Menu"):
		return _fail_dict("Menu confirmation did not reopen for Escape.")
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Menu Escape"):
		return {}
	request = shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if not bool(confirmed.get("ok", false)) or int(confirmed.get("route_attempt_delta", 0)) != 1 \
			or int(snapshot.get("confirm_count", 0)) != 1 or int(snapshot.get("menu_route_count", 0)) != 1:
		return _fail_dict("Menu confirmation did not execute exactly once: %s" % JSON.stringify({"result": confirmed, "snapshot": snapshot}))
	if _package_file_state() != package_state:
		return _fail_dict("Menu confirmation mutated shipped package files.")
	return {"ok": true, "cancel_count": 2, "confirm_count": 1, "route_count": 1}

func _validate_package_transition(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	if not await _reset_case(shell, source_id, true):
		return {}
	var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
	if not bool(selected.get("ok", false)):
		return _fail_dict("Target package fixture was not indexed: %s" % JSON.stringify(selected))
	var origin: Button = shell.get_node("%LoadMap")
	var before := _protected_state(shell)
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	if not _assert_dialog(shell, "package", target_id, "Keep Editing", "LoadMap"):
		return {}
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Package controller B"):
		return {}
	var request: Dictionary = shell.call("validation_request_dirty_transition", "package", target_id)
	await _settle()
	if not bool(request.get("pending", false)):
		return _fail_dict("Package confirmation did not reopen for Escape: %s" % JSON.stringify(request))
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Package Escape"):
		return {}
	request = shell.call("validation_request_dirty_transition", "package", target_id)
	await _settle()
	var redirected: Dictionary = shell.call("validation_select_map_package_id", source_id)
	if not bool(redirected.get("ok", false)):
		return _fail_dict("Could not stage package-selection redirect control.")
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var transition: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if not bool(confirmed.get("ok", false)) or String(confirmed.get("package_id", "")) != target_id \
			or int(confirmed.get("load_attempt_delta", 0)) != 1 \
			or String(snapshot.get("editor_source_package_id", "")) != target_id \
			or int(transition.get("package_action_count", 0)) != 1 or int(transition.get("confirm_count", 0)) != 1:
		return _fail_dict("Package confirmation did not use its immutable captured identity exactly once: %s" % JSON.stringify({"result": confirmed, "source": snapshot.get("editor_source_package_id", ""), "transition": transition}))
	if _package_file_state() != package_state:
		return _fail_dict("Package replacement mutated shipped package files.")
	return {"ok": true, "captured_target": true, "cancel_count": 2, "confirm_count": 1, "load_count": 1}

func _validate_native_close(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	var active = _seed_canonical_active_session(31)
	if active == null:
		return _fail_dict("Could not seed the native-close autosave control.")
	if not await _reset_case(shell, source_id, true):
		return {}
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	var origin: Button = shell.get_node("%LoadMap")
	origin.grab_focus()
	await get_tree().process_frame
	var before := _protected_state(shell)
	get_tree().root.close_requested.emit()
	await _settle()
	if not _assert_dialog(shell, "quit", "", "Keep Editing", "LoadMap"):
		return {}
	AppRouter.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await _settle()
	var duplicate: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if int(duplicate.get("duplicate_request_count", 0)) != 1 or int(duplicate.get("request_count", 0)) != 1:
		return _fail_dict("Duplicate native-close notification created another confirmation: %s" % JSON.stringify(duplicate))
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Native close controller B"):
		return {}
	get_tree().root.close_requested.emit()
	await _settle()
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Native close Escape"):
		return {}
	get_tree().root.close_requested.emit()
	await _settle()
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var router: Dictionary = AppRouter.validation_safe_quit_snapshot()
	var guard: Dictionary = AppRouter.validation_safe_close_guard_snapshot()
	if not bool(confirmed.get("ok", false)) or not bool(confirmed.get("quit_requested", false)) \
			or int(router.get("quit_attempt_count", 0)) != 1 or int(router.get("suppressed_quit_count", 0)) != 1 \
			or int(guard.get("bypass_consume_count", 0)) != 1:
		return _fail_dict("Confirmed native close did not authorize exactly one suppressed quit: %s" % JSON.stringify({"result": confirmed, "router": router, "guard": guard}))
	if _package_file_state() != package_state:
		return _fail_dict("Native-close confirmation mutated shipped package files.")
	return {"ok": true, "cancel_count": 2, "confirm_count": 1, "quit_count": 1, "duplicate_guarded": true}

func _validate_safe_quit_failure_retry(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	var phase_results := {}
	for phase in FAILURE_PHASES:
		var active = _seed_canonical_active_session(40 + phase_results.size())
		if active == null:
			return _fail_dict("Could not seed safe-quit failure phase %s." % phase)
		if not await _reset_case(shell, source_id, true):
			return {}
		AppRouter.validation_set_quit_suppressed(true)
		AppRouter.validation_reset_safe_quit_state()
		AppRouter.validation_set_safe_close_guard_target(shell)
		var origin: Button = shell.get_node("%Menu")
		origin.grab_focus()
		await get_tree().process_frame
		var before := _protected_state(shell)
		var autosave_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]
		var old_bytes := FileAccess.get_file_as_bytes(autosave_path)
		OS.set_environment(SAVE_FAILURE_ENV, phase)
		get_tree().root.close_requested.emit()
		await _settle()
		var failed: Dictionary = shell.call("validation_confirm_dirty_transition")
		OS.set_environment(SAVE_FAILURE_ENV, "")
		await _settle()
		var failed_router: Dictionary = AppRouter.validation_safe_quit_snapshot()
		if bool(failed.get("ok", true)) or String(failed.get("reason", "")) != "autosave_failed" \
				or int(failed_router.get("quit_attempt_count", -1)) != 0:
			return _fail_dict("Safe-quit %s failure was not honest: %s" % [phase, JSON.stringify({"result": failed, "router": failed_router})])
		if not _assert_protected_state(shell, before, package_state, "%s safe-quit failure" % phase) \
				or FileAccess.get_file_as_bytes(autosave_path) != old_bytes or _transaction_artifacts_exist(autosave_path):
			return {}
		get_tree().root.close_requested.emit()
		await _settle()
		var retried: Dictionary = shell.call("validation_confirm_dirty_transition")
		var retry_router: Dictionary = AppRouter.validation_safe_quit_snapshot()
		if not bool(retried.get("ok", false)) or int(retry_router.get("quit_attempt_count", 0)) != 1 \
				or int(retry_router.get("suppressed_quit_count", 0)) != 1 or int(retry_router.get("save_attempt_count", 0)) != 2:
			return _fail_dict("Safe-quit %s retry did not save then quit exactly once: %s" % [phase, JSON.stringify({"result": retried, "router": retry_router})])
		phase_results[phase] = {"failure_preserved": true, "retry_quit_count": 1}
	return {"ok": true, "phases": phase_results}

func _validate_clean_controls(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	_seed_canonical_active_session(51)
	if not await _reset_case(shell, source_id, false):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	var menu: Dictionary = shell.call("_on_menu_pressed")
	if not bool(menu.get("ok", false)) or bool(menu.get("pending", true)) or int(menu.get("route_attempt_delta", 0)) != 1:
		return _fail_dict("Clean Menu did not remain direct: %s" % JSON.stringify(menu))
	var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
	var package: Dictionary = shell.call("_on_load_map_pressed")
	if not bool(selected.get("ok", false)) or not bool(package.get("ok", false)) or not bool(package.get("direct", false)) \
			or bool(package.get("pending", true)) or int(package.get("load_attempt_delta", 0)) != 1:
		return _fail_dict("Clean package load did not remain direct: %s" % JSON.stringify(package))
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	get_tree().root.close_requested.emit()
	await _settle()
	var close_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	var transition: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(transition.get("dialog_visible", true)) or int(close_snapshot.get("quit_attempt_count", 0)) != 1 \
			or int(close_snapshot.get("suppressed_quit_count", 0)) != 1:
		return _fail_dict("Clean native close did not remain direct: %s" % JSON.stringify({"router": close_snapshot, "transition": transition}))
	if _package_file_state() != package_state:
		return _fail_dict("Clean controls mutated shipped package files.")
	return {"ok": true, "menu_direct": true, "package_direct": true, "native_close_direct": true}

func _create_editor_shell():
	var layout_host := Control.new()
	layout_host.name = "MapEditorExclusiveLayoutHost"
	layout_host.size = Vector2(1280.0, 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	_active_shell = shell
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "MapEditorExclusiveParentProbe"
	parent_probe.text = "Map Editor parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(230.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	parent_probe.pressed.connect(_on_parent_probe_pressed)
	layout_host.add_child(parent_probe)
	shell.set_meta("exclusive_parent_probe", parent_probe)
	await _settle()
	AppRouter.validation_set_safe_close_guard_target(shell)
	return shell

func _on_parent_probe_pressed() -> void:
	_parent_probe_count += 1

func _reset_case(shell: Node, source_id: String, dirty: bool) -> bool:
	shell.call("validation_reset_dirty_transition_state")
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	shell.set("_map_package_entries", [_source_entry.duplicate(true), _target_entry.duplicate(true)])
	var picker: OptionButton = shell.get_node("%MapPackagePicker")
	picker.clear()
	for entry in [_source_entry, _target_entry]:
		picker.add_item(String(entry.get("display_name", entry.get("package_stem", "Map Package"))))
		picker.set_item_metadata(picker.get_item_count() - 1, String(entry.get("package_id", "")))
	var loaded: bool = bool(shell.call("_load_maps_folder_package_entry_working_copy", _source_entry.duplicate(true)))
	if not loaded:
		_fail("Editor could not load shipped package fixture %s." % source_id)
		return false
	if dirty:
		var session = shell.get("_session")
		var current := String(session.overworld.get("map", [])[0][0])
		var replacement := "forest" if current != "forest" else "grass"
		shell.call("validation_set_tool", "terrain")
		shell.call("validation_select_tile", 0, 0)
		var edit: Dictionary = shell.call("validation_paint_terrain", 0, 0, replacement)
		if not bool(edit.get("ok", false)) or not bool(shell.call("validation_dirty_transition_snapshot").get("dirty", false)):
			_fail("Could not dirty editor working copy deterministically: %s" % JSON.stringify(edit))
			return false
	await _settle()
	return true

func _assert_dialog(shell: Node, action: String, package_id: String, cancel_text: String, origin_name: String) -> bool:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var dialog: ConfirmationDialog = shell.get_node("DirtyTransitionConfirmationDialog")
	var cancel_button := dialog.get_cancel_button()
	var focus_owner := cancel_button.get_viewport().gui_get_focus_owner()
	if not bool(snapshot.get("pending", false)) or not bool(snapshot.get("dialog_visible", false)) \
			or String(snapshot.get("action", "")) != action or String(snapshot.get("package_id", "")) != package_id \
			or String(snapshot.get("cancel_text", "")) != cancel_text or String(snapshot.get("return_focus_name", "")) != origin_name \
			or focus_owner != cancel_button:
		_fail("%s confirmation did not open with safe native-dialog focus: %s" % [action, JSON.stringify(snapshot)])
		return false
	return true

func _assert_canceled_exact(shell: Node, before: Dictionary, origin: Control, package_state: Dictionary, label: String) -> bool:
	await _settle()
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(snapshot.get("pending", true)) or bool(snapshot.get("dialog_visible", true)) or get_viewport().gui_get_focus_owner() != origin:
		_fail("%s did not close and restore exact origin focus: %s" % [label, JSON.stringify(snapshot)])
		return false
	return _assert_protected_state(shell, before, package_state, label)

func _assert_protected_state(shell: Node, before: Dictionary, package_state: Dictionary, label: String) -> bool:
	var after := _protected_state(shell)
	if after != before:
		_fail("%s changed protected editor/session/save state: %s" % [label, _first_difference(before, after)])
		return false
	if _package_file_state() != package_state:
		_fail("%s changed shipped package bytes." % label)
		return false
	return true

func _protected_state(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var session = shell.get("_session")
	return {
		"working_copy": session.to_dict() if session != null else {},
		"dirty": bool(snapshot.get("dirty", false)),
		"tool": String(snapshot.get("tool", "")),
		"selected_tile": snapshot.get("selected_tile", {}).duplicate(true),
		"selected_map_package_id": String(snapshot.get("selected_map_package_id", "")),
		"active_session": SessionState.ensure_active_session().to_dict() if SessionState.has_playable_session() else {},
		"save_files": _save_file_state(),
	}

func _seed_canonical_active_session(day: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	SessionState.set_active_session(session)
	OS.set_environment(SAVE_FAILURE_ENV, "")
	var saved: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(saved.get("ok", false)):
		return null
	var restored = SaveService.restore_autosave_session()
	if restored == null:
		return null
	SessionState.set_active_session(restored)
	return restored

func _package_files_exist() -> bool:
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			if not FileAccess.file_exists("res://maps/%s.%s" % [stem, extension]):
				return false
	return true

func _copy_fixture_pairs() -> bool:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			var source := "res://maps/%s.%s" % [stem, extension]
			var target := "%s/%s.%s" % [FIXTURE_DIR, stem, extension]
			var copy_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(source),
				ProjectSettings.globalize_path(target)
			)
			if copy_error != OK:
				return false
	return true

func _package_file_state() -> Dictionary:
	var state := {}
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			for root in ["res://maps", FIXTURE_DIR]:
				var path := "%s/%s.%s" % [root, stem, extension]
				state[path] = {"size": FileAccess.get_size(path), "sha256": FileAccess.get_sha256(path)}
	return state

func _save_file_state() -> Dictionary:
	var state := {}
	var paths: Array[String] = ["%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]]
	for slot in [1, 2, 3]:
		paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot])
	for path in paths:
		state[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return state

func _transaction_artifacts_exist(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return FileAccess.file_exists(String(artifacts.get("candidate", ""))) or FileAccess.file_exists(String(artifacts.get("backup", "")))

func _dirty_transition_opened_exact(snapshot: Dictionary, action: String, target_id: String, origin: Control, dialog: ConfirmationDialog, width: int) -> bool:
	var position: Vector2i = snapshot.get("dialog_position", Vector2i(-1, -1))
	var size: Vector2i = snapshot.get("dialog_size", Vector2i.ZERO)
	return dialog.exclusive and bool(snapshot.get("pending", false)) and bool(snapshot.get("dialog_visible", false)) \
		and String(snapshot.get("action", "")) == action \
		and String(snapshot.get("package_id", "")) == (target_id if action == "package" else "") \
		and String(snapshot.get("cancel_text", "")) == "Keep Editing" \
		and String(snapshot.get("return_focus_name", "")) == String(origin.name) \
		and dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button() \
		and position.x >= 0 and position.y >= 0 and position.x + size.x <= width and position.y + size.y <= 720

func _dirty_transaction_snapshot(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var compact := {}
	for key in ["pending", "dialog_visible", "action", "package_id", "package_label", "source", "cancel_text", "confirm_text", "dialog_focus_owner", "return_focus_name", "dialog_position", "dialog_size", "dirty", "request_count", "cancel_count", "confirm_count", "duplicate_request_count", "menu_route_count", "package_action_count", "quit_attempt_count", "routing_enabled", "last_result"]:
		compact[key] = snapshot.get(key)
	return compact

func _exclusive_parent_click_geometry(control: Button, dialog: ConfirmationDialog) -> Dictionary:
	var parent_click := _control_root_click_position(control)
	var parent_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var cancel_button := dialog.get_cancel_button()
	var child_click := _control_root_click_position(cancel_button)
	var child_rect := _control_root_rect(cancel_button)
	return {
		"exact": control.get_viewport() == get_viewport() and control.is_visible_in_tree() and not control.disabled \
			and parent_rect.has_point(parent_click) and get_viewport().get_visible_rect().has_point(parent_click) \
			and not dialog_rect.has_point(parent_click) and cancel_button.get_viewport() == dialog \
			and child_rect.has_point(child_click) and dialog_rect.has_point(child_click) \
			and get_viewport().get_visible_rect().encloses(dialog_rect),
		"parent_click": parent_click,
		"parent_rect": parent_rect,
		"dialog_rect": dialog_rect,
		"child_click": child_click,
	}

func _click_control(control: Control) -> void:
	var source_viewport := control.get_viewport()
	var click_position := _control_root_click_position(control)
	var window_id: int = int(source_viewport.get_window_id()) if source_viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = click_position
	motion.global_position = click_position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed_state in [true, false]:
		var event := InputEventMouseButton.new()
		event.window_id = window_id
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_position
		event.global_position = click_position
		event.pressed = pressed_state
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _settle()

func _control_root_click_position(control: Control) -> Vector2:
	var position := control.get_global_rect().get_center()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		position += Vector2((source_viewport as Window).position)
	return position

func _control_root_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		rect.position += Vector2((source_viewport as Window).position)
	return rect

func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _full_authority_state(shell: Node) -> Dictionary:
	var editor_snapshot: Dictionary = shell.call("validation_snapshot")
	for key in ["dirty_transition", "focus_owner"]:
		editor_snapshot.erase(key)
	return {
		"protected": _protected_state(shell),
		"editor": editor_snapshot,
		"packages": _package_file_state(),
		"files": _capture_file_states(_tracked_authority_paths()),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _canonical_settings_transaction(),
		"profile": CampaignProgression.profile.duplicate(true),
		"selected_slot": SaveService.get_selected_manual_slot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"close_guard": AppRouter.validation_safe_close_guard_snapshot(),
		"return_route": AppRouter.validation_active_play_return_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
	}

func _canonical_settings_transaction() -> Dictionary:
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	transaction["input_map"] = _canonical_input_map(transaction.get("input_map", {}))
	var runtime: Dictionary = (transaction.get("runtime_display", {}) as Dictionary).duplicate(true)
	runtime.erase("size")
	runtime.erase("position")
	transaction["runtime_display"] = runtime
	return transaction

func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var row: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var events := []
		for event_value in row.get("events", []):
			if event_value is InputEvent:
				events.append(_serialize_input_event(event_value))
		result[String(action_value)] = {"exists": bool(row.get("exists", false)), "deadzone": float(row.get("deadzone", 0.5)), "events": events}
	return result

func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := String(property.get("name", ""))
		if property_name == "" or property_name == "script":
			continue
		properties[property_name] = var_to_str(input_event.get(property_name))
	return {"class": input_event.get_class(), "text": input_event.as_text(), "properties": properties}

func _tracked_authority_paths() -> Array[String]:
	var base_paths: Array[String] = [
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
		SettingsService.SETTINGS_FILE,
	]
	for slot in [1, 2, 3]:
		base_paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot])
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			base_paths.append("%s/%s.%s" % [FIXTURE_DIR, stem, extension])
	var paths: Array[String] = []
	for path in base_paths:
		if path not in paths:
			paths.append(path)
		for artifact in SaveService.validation_transaction_artifact_paths(path).values():
			var artifact_path := String(artifact)
			if artifact_path != "" and artifact_path not in paths:
				paths.append(artifact_path)
	for path in [SettingsService.SETTINGS_CANDIDATE_FILE, SettingsService.SETTINGS_BACKUP_FILE]:
		if path not in paths:
			paths.append(path)
	return paths

func _capture_file_states(paths: Array[String]) -> Dictionary:
	var states := {}
	for path in paths:
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func _restore_file_state(path: String, state: Dictionary) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not bool(state.get("exists", false)):
		return
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(state.get("bytes", PackedByteArray()))

func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> String:
	if typeof(expected) != typeof(actual):
		return "%s type %s != %s" % [path, typeof(expected), typeof(actual)]
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				return "%s.%s presence differs" % [path, key]
			var nested := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if nested != "":
				return nested
		return ""
	if expected is Array:
		if expected.size() != actual.size():
			return "%s size %d != %d" % [path, expected.size(), actual.size()]
		for index in range(expected.size()):
			var nested := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if nested != "":
				return nested
		return ""
	return "" if expected == actual else "%s differs" % path

func _press_key(keycode: Key, shift_pressed: bool = false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.shift_pressed = shift_pressed
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.shift_pressed = shift_pressed
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _send_joypad_button_event(button_index: int, pressed: bool, device: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func _send_key_event(keycode: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await get_tree().process_frame

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _free_shell(shell: Node) -> void:
	AppRouter.validation_set_safe_close_guard_target(null)
	if is_instance_valid(shell) and is_instance_valid(shell.get_parent()):
		shell.get_parent().queue_free()
	await _settle()
	_active_shell = null

func _fail_dict(message: String) -> Dictionary:
	_fail(message)
	return {}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	OS.set_environment(SAVE_FAILURE_ENV, "")
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	if is_instance_valid(_active_shell):
		AppRouter.validation_set_safe_close_guard_target(null)
		if is_instance_valid(_active_shell.get_parent()):
			_active_shell.get_parent().queue_free()
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_profile.duplicate(true)
	SaveService.set_selected_manual_slot(_original_selected_slot)
	for path in _original_file_states:
		_restore_file_state(String(path), _original_file_states[path])
	SaveService._slot_summary_cache = _original_summary_cache.duplicate(true)
	get_window().size = _original_window_size
