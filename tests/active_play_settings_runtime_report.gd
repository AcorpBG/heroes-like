extends Node

const REPORT_ID := "ACTIVE_PLAY_SETTINGS_RUNTIME_REPORT"
const FOCUS_CYCLE_NAMES := [
	"Close",
	"MasterVolumeSlider",
	"MusicVolumeSlider",
	"EffectsVolumeSlider",
	"BattlePlaybackSpeedPicker",
	"UIScalePicker",
	"BattleCameraShakePicker",
	"ColorCuePicker",
	"HighContrastToggle",
	"ReduceMotionToggle",
	"ReduceFlashesToggle",
	"ReduceRepetitiveSoundsToggle",
]

var _failed := false
var _original_settings: Dictionary = {}
var _original_settings_file := PackedByteArray()
var _original_settings_file_existed := false
var _dialog_closed_counts := {}
var _original_window_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_settings_state()
	SettingsService.settings = SettingsService.build_default_settings()
	SettingsService.apply_settings()
	var resolution_result: Dictionary = SettingsService.set_presentation_resolution("1280x720")
	if not _require(bool(resolution_result.get("ok", false)), "Could not establish the 1280x720 active-play accessibility fixture."):
		_finish()
		return
	get_window().size = Vector2i(1280, 720)
	await _settle()

	if not await _check_overworld_settings():
		_finish()
		return
	if not await _check_town_settings():
		_finish()
		return
	if not await _check_battle_settings():
		_finish()
		return
	if not _check_persisted_reload():
		_finish()
		return

	print("%s PASS" % REPORT_ID)
	_finish()

func _check_overworld_settings() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expand_overworld_camera_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var hero_before := OverworldRules.hero_position(session)
	var adjacent_target := _first_open_adjacent_tile(session, hero_before)
	if not _require(adjacent_target.x >= 0, "Overworld Settings containment fixture has no explored adjacent open route target."):
		return false
	var route_selection: Dictionary = shell.validation_select_tile(adjacent_target.x, adjacent_target.y)
	await _settle()
	var route_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if not _require(
		bool(route_selection.get("ok", false))
		and route_before.get("selected_tile", {}) == {"x": adjacent_target.x, "y": adjacent_target.y}
		and route_before.get("hero_tile", {}) == {"x": hero_before.x, "y": hero_before.y}
		and not (route_before.get("route_preview", {}) as Dictionary).is_empty()
		and not (route_before.get("primary_action", {}) as Dictionary).is_empty()
		and bool(route_before.get("available", false)),
		"Overworld Settings containment did not establish a live selected adjacent route: %s" % route_before
	):
		return false
	shell.validation_set_debug_overlay_enabled(false)
	shell.validation_set_placement_debug_overlay_enabled(false)
	var before := _gameplay_signature(session)
	var opened: Dictionary = shell.validation_open_active_play_settings()
	await _settle()
	var dialog = shell.validation_active_play_settings_dialog()
	if not _require(bool(opened.get("visible", false)), "Overworld Settings command did not open the shared modal."):
		return false
	if not _require(_dialog_fits_viewport(dialog), "Overworld settings modal does not fit the active viewport."):
		return false
	if not _require(String(dialog.validation_snapshot().get("focus_owner", "")) == "MasterVolumeSlider", "Overworld settings modal did not own entry focus."):
		return false
	var accessibility: Dictionary = UiAccessibility.validation_snapshot(dialog)
	if not _require(bool(accessibility.get("ok", false)) and int(accessibility.get("named_control_count", 0)) >= 12, "Active-play settings controls are missing native accessibility semantics."):
		return false
	if not _require(dialog.validation_set_volume("MasterVolumeSlider", 55), "Overworld settings could not change Master volume."):
		return false
	if not _require(dialog.validation_select_option("BattlePlaybackSpeedPicker", "fast"), "Overworld settings could not select Fast battle playback."):
		return false
	if not _require(dialog.validation_select_option("UIScalePicker", 130), "Overworld settings could not select 130 percent UI scale."):
		return false
	if not _require(dialog.validation_set_toggle("HighContrastToggle", true), "Overworld settings could not enable High Contrast."):
		return false
	await _settle()
	var home_focus_fixture: Dictionary = shell.validation_focus_map_on_hero()
	var home_focus_snapshot: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var home_camera_expected := {
		"camera_focus_tile": (home_focus_snapshot.get("camera_focus_tile", {}) as Dictionary).duplicate(true),
		"camera_focus_tile_precise": (home_focus_snapshot.get("camera_focus_tile_precise", {}) as Dictionary).duplicate(true),
	}
	if not _require(bool(home_focus_fixture.get("ok", false)) and _pan_overworld_camera(shell), "Overworld Settings containment could not establish the 130-percent post-close Home camera fixture."):
		return false
	if not _require(_gameplay_signature(session) == before, "Overworld settings changed expedition gameplay state."):
		return false
	if not _require(_dialog_fits_1280_at_130(dialog), "Overworld settings modal does not fit 1280x720 at 130 percent UI scale: %s" % _dialog_1280_at_130_snapshot(dialog)):
		return false
	if not await _check_modal_focus_containment(shell, dialog, session, "Overworld"):
		return false
	if not await _check_overworld_unhandled_command_containment(shell, dialog, session):
		return false
	if not await _capture_if_requested("overworld_settings_top"):
		return false
	if not _require(dialog.validation_focus_control("ReduceRepetitiveSoundsToggle"), "Overworld settings could not focus the final readability control."):
		return false
	await _settle()
	if not _require(dialog.validation_control_visible("ReduceRepetitiveSoundsToggle"), "Focused final readability control remained clipped in the modal scroll."):
		return false
	if not await _capture_if_requested("overworld_settings_readability"):
		return false
	var close_count_before := int(_dialog_closed_counts.get("Overworld", 0))
	await _press_joypad_button(JOY_BUTTON_B)
	if not _require(not dialog.is_open(), "Overworld controller/keyboard Back did not close settings."):
		return false
	if not _require(int(_dialog_closed_counts.get("Overworld", 0)) == close_count_before + 1, "Overworld Back did not emit exactly one modal closed signal."):
		return false
	if not _require(_focus_name() == "Settings", "Overworld settings close did not restore focus to the Settings command."):
		return false
	if not await _check_overworld_post_close_commands(shell, session, adjacent_target, home_camera_expected):
		return false
	shell.queue_free()
	await _settle()
	return true

func _check_town_settings() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if not _require(not town.is_empty(), "Town settings fixture has no player town."):
		return false
	_move_active_hero_to_town(session, town)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var before := _gameplay_signature(session)
	var opened: Dictionary = shell.validation_open_active_play_settings()
	await _settle()
	var dialog = shell.validation_active_play_settings_dialog()
	if not _require(bool(opened.get("visible", false)) and SettingsService.master_volume_percent() == 55, "Town settings did not reopen with persisted active-play values."):
		return false
	if not _require(_dialog_fits_1280_at_130(dialog), "Town settings modal does not fit 1280x720 at 130 percent UI scale."):
		return false
	if not await _check_modal_focus_containment(shell, dialog, session, "Town"):
		return false
	if not _require(dialog.validation_set_toggle("ReduceMotionToggle", true), "Town settings could not enable Reduce Motion."):
		return false
	if not _require(dialog.validation_set_toggle("ReduceRepetitiveSoundsToggle", true), "Town settings could not enable reduced repeated sounds."):
		return false
	await _settle()
	if not _require(_gameplay_signature(session) == before, "Town settings changed town or expedition gameplay state."):
		return false
	if not await _capture_if_requested("town_settings"):
		return false
	var close_count_before := int(_dialog_closed_counts.get("Town", 0))
	await _press_joypad_button(JOY_BUTTON_B)
	if not _require(not dialog.is_open(), "Town controller/keyboard Back did not close settings."):
		return false
	if not _require(int(_dialog_closed_counts.get("Town", 0)) == close_count_before + 1, "Town Back did not emit exactly one modal closed signal."):
		return false
	if not _require(_focus_name() == "Settings", "Town controller/keyboard Back did not restore focus to the Settings command."):
		return false
	shell.queue_free()
	await _settle()
	return true

func _check_battle_settings() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if not _require(not encounter.is_empty(), "Battle settings fixture has no encounter."):
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var before := _gameplay_signature(session)
	var compact_layout: Dictionary = _battle_system_command_layout_contract(shell, true)
	if not _require(bool(compact_layout.get("ok", false)), "Compact Battle does not expose a contained essential system-command row at 1280x720/130 percent: %s" % compact_layout):
		return false
	var opened: Dictionary = shell.validation_open_active_play_settings()
	await _settle()
	var dialog = shell.validation_active_play_settings_dialog()
	if not _require(bool(opened.get("visible", false)) and SettingsService.reduced_motion_enabled(), "Battle settings did not reopen with persisted readability values."):
		return false
	if not _require(_dialog_fits_1280_at_130(dialog), "Battle settings modal does not fit 1280x720 at 130 percent UI scale."):
		return false
	if not await _check_modal_focus_containment(shell, dialog, session, "Battle"):
		return false
	if not _require(dialog.validation_select_option("BattlePlaybackSpeedPicker", "instant"), "Battle settings could not select Instant playback."):
		return false
	if not _require(dialog.validation_select_option("BattleCameraShakePicker", "off"), "Battle settings could not disable camera shake."):
		return false
	if not _require(dialog.validation_set_toggle("ReduceFlashesToggle", true), "Battle settings could not enable reduced flashes."):
		return false
	await _settle()
	if not _require(BattleRules.battle_presentation_speed(session) == "instant", "Active battle did not adopt the changed playback preference."):
		return false
	if not _require(_gameplay_signature(session) == before, "Battle settings changed combat state beyond presentation speed."):
		return false
	if not await _capture_if_requested("battle_settings"):
		return false
	var close_count_before := int(_dialog_closed_counts.get("Battle", 0))
	await _press_joypad_button(JOY_BUTTON_B)
	if not _require(not dialog.is_open(), "Battle controller/keyboard Back did not close settings."):
		return false
	if not _require(int(_dialog_closed_counts.get("Battle", 0)) == close_count_before + 1, "Battle Back did not emit exactly one modal closed signal."):
		return false
	var battle_settings_control := shell.get_node_or_null("%Settings") as Control
	var battle_close_focus_owner := get_viewport().gui_get_focus_owner() as Control
	var battle_focus_return_exact: bool = battle_settings_control != null and battle_settings_control.is_visible_in_tree() and battle_close_focus_owner == battle_settings_control
	if not _require(battle_focus_return_exact, "Battle controller/keyboard Back did not restore the visible compact Settings command: owner=%s settings_visible=%s." % [_focus_name(), battle_settings_control.is_visible_in_tree() if battle_settings_control != null else false]):
		return false
	var command_semantics_after_settings: Dictionary = _battle_system_command_semantics(shell)
	if not await _check_battle_system_command_layout_roundtrip(shell, session, before, command_semantics_after_settings):
		return false
	shell.queue_free()
	await _settle()
	return true

func _check_battle_system_command_layout_roundtrip(shell, session, gameplay_before: String, command_semantics_before: Dictionary) -> bool:
	var wide_scale_result: Dictionary = SettingsService.set_ui_scale_percent(100)
	var wide_resolution_result: Dictionary = SettingsService.set_presentation_resolution("1920x1080")
	get_window().size = Vector2i(1920, 1080)
	await _settle()
	var wide_layout: Dictionary = _battle_system_command_layout_contract(shell, false)
	if not _require(
		bool(wide_scale_result.get("ok", false))
		and bool(wide_resolution_result.get("ok", false))
		and get_window().size == Vector2i(1920, 1080)
		and SettingsService.ui_scale_percent() == 100
		and bool(wide_layout.get("ok", false)),
		"Wide Battle did not retain its complete two-column system-command surface: %s" % wide_layout
	):
		return false
	if not _require(_battle_system_command_semantics(shell) == command_semantics_before, "Wide Battle changed system-command labels, tooltips, focusability, selection, or item metadata."):
		return false

	var compact_scale_result: Dictionary = SettingsService.set_ui_scale_percent(130)
	var compact_resolution_result: Dictionary = SettingsService.set_presentation_resolution("1280x720")
	get_window().size = Vector2i(1280, 720)
	await _settle()
	var restored_compact_layout: Dictionary = _battle_system_command_layout_contract(shell, true)
	return (
		_require(bool(compact_scale_result.get("ok", false)) and bool(compact_resolution_result.get("ok", false)), "Battle compact layout could not restore the persisted 1280x720/130 percent fixture.")
		and _require(get_window().size == Vector2i(1280, 720) and SettingsService.ui_scale_percent() == 130, "Battle compact layout restored the wrong runtime size or UI scale.")
		and _require(bool(restored_compact_layout.get("ok", false)), "Battle essential system commands were not contained after the wide-to-compact round trip: %s" % restored_compact_layout)
		and _require(_battle_system_command_semantics(shell) == command_semantics_before, "Battle compact round trip changed system-command labels, tooltips, focusability, selection, or item metadata.")
		and _require(_gameplay_signature(session) == gameplay_before, "Battle responsive command reflow changed combat authority.")
	)

func _battle_system_command_layout_contract(shell, compact: bool) -> Dictionary:
	var viewport_rect: Rect2 = shell.get_viewport_rect()
	var footer_row := shell.get_node_or_null("%FooterRow") as GridContainer
	var action_panel := shell.get_node_or_null("%ActionPanel") as Control
	var action_bar := shell.get_node_or_null("%ActionBar") as Control
	var action_guide := shell.get_node_or_null("%ActionGuide") as Label
	var system_panel := shell.get_node_or_null("%SystemPanel") as Control
	var system_actions := shell.get_node_or_null("%SystemActions") as Control
	var system_body := shell.get_node_or_null("%SystemBody") as Control
	var speed_bar := shell.get_node_or_null("%SpeedBar") as Control
	var board := shell.get_node_or_null("%BattleBoard") as Control
	var required_commands: Array[Control] = []
	for node_name in ["SaveSlot", "Save", "Settings", "Menu"]:
		var command := shell.get_node_or_null("%%%s" % node_name) as Control
		if command != null:
			required_commands.append(command)
	var action_controls: Array[Control] = []
	for node_name in ["Advance", "Strike", "Shoot", "Defend", "QuickResolve", "Retreat", "Surrender"]:
		var action_control := shell.get_node_or_null("%%%s" % node_name) as Control
		if action_control != null:
			action_controls.append(action_control)
	var required_visible_and_contained := required_commands.size() == 4
	for command in required_commands:
		required_visible_and_contained = required_visible_and_contained and command.is_visible_in_tree() and command.focus_mode != Control.FOCUS_NONE and viewport_rect.grow(1.0).encloses(command.get_global_rect())
	var actions_visible_and_contained := action_controls.size() == 7
	for action_control in action_controls:
		actions_visible_and_contained = actions_visible_and_contained and action_control.is_visible_in_tree() and viewport_rect.grow(1.0).encloses(action_control.get_global_rect())
	var command_order_exact := required_commands.size() == 4
	for index in range(1, required_commands.size()):
		command_order_exact = command_order_exact and required_commands[index - 1].get_global_rect().end.x <= required_commands[index].get_global_rect().position.x + 1.0
	var child_arrangement_exact := false
	if footer_row != null and action_panel != null and system_panel != null:
		child_arrangement_exact = (
			system_panel.get_global_rect().position.y >= action_panel.get_global_rect().end.y - 1.0
			if compact
			else system_panel.get_global_rect().position.x >= action_panel.get_global_rect().end.x - 1.0
		)
	var structural_nodes_present := footer_row != null and action_panel != null and action_bar != null and action_guide != null and system_panel != null and system_actions != null and system_body != null and speed_bar != null and board != null
	var structural_containment_exact := false
	var board_contract_exact := false
	if structural_nodes_present:
		structural_containment_exact = (
			viewport_rect.grow(1.0).encloses(footer_row.get_global_rect())
			and footer_row.get_global_rect().grow(1.0).encloses(action_panel.get_global_rect())
			and footer_row.get_global_rect().grow(1.0).encloses(system_panel.get_global_rect())
			and action_panel.get_global_rect().grow(1.0).encloses(action_bar.get_global_rect())
			and system_panel.get_global_rect().grow(1.0).encloses(system_actions.get_global_rect())
		)
		board_contract_exact = viewport_rect.grow(1.0).encloses(board.get_global_rect()) and board.size.x + 1.0 >= board.custom_minimum_size.x and board.size.y + 1.0 >= board.custom_minimum_size.y
	var ok := (
		structural_nodes_present
		and footer_row.columns == (1 if compact else 2)
		and system_panel.is_visible_in_tree()
		and system_panel.has_theme_stylebox_override("panel") == compact
		and (not compact or system_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
		and system_body.is_visible_in_tree() == not compact
		and speed_bar.is_visible_in_tree() == not compact
		and action_guide.text.split("\n", false).size() == (2 if compact else 3)
		and not action_guide.tooltip_text.strip_edges().is_empty()
		and required_visible_and_contained
		and actions_visible_and_contained
		and command_order_exact
		and child_arrangement_exact
		and structural_containment_exact
		and board_contract_exact
	)
	return {
		"ok": ok,
		"compact": compact,
		"viewport_rect": viewport_rect,
		"footer_columns": footer_row.columns if footer_row != null else -1,
		"footer_rect": footer_row.get_global_rect() if footer_row != null else Rect2(),
		"action_panel_rect": action_panel.get_global_rect() if action_panel != null else Rect2(),
		"action_guide_line_count": action_guide.text.split("\n", false).size() if action_guide != null else 0,
		"system_panel_rect": system_panel.get_global_rect() if system_panel != null else Rect2(),
		"system_panel_compact_style": system_panel.has_theme_stylebox_override("panel") if system_panel != null else false,
		"system_actions_rect": system_actions.get_global_rect() if system_actions != null else Rect2(),
		"system_body_visible": system_body.is_visible_in_tree() if system_body != null else false,
		"speed_visible": speed_bar.is_visible_in_tree() if speed_bar != null else false,
		"board_rect": board.get_global_rect() if board != null else Rect2(),
		"board_minimum": board.custom_minimum_size if board != null else Vector2.ZERO,
		"required_command_count": required_commands.size(),
		"action_control_count": action_controls.size(),
		"required_visible_and_contained": required_visible_and_contained,
		"actions_visible_and_contained": actions_visible_and_contained,
		"command_order_exact": command_order_exact,
		"child_arrangement_exact": child_arrangement_exact,
		"structural_containment_exact": structural_containment_exact,
		"board_contract_exact": board_contract_exact,
	}

func _battle_system_command_semantics(shell) -> Dictionary:
	var semantics := {}
	for node_name in ["Save", "Settings", "Menu", "SpeedNormal", "SpeedFast", "SpeedInstant"]:
		var button := shell.get_node_or_null("%%%s" % node_name) as Button
		semantics[node_name] = {
			"text": button.text,
			"tooltip": button.tooltip_text,
			"focus_mode": button.focus_mode,
			"disabled": button.disabled,
		} if button != null else {}
	var save_slot := shell.get_node_or_null("%SaveSlot") as OptionButton
	var save_slot_items: Array = []
	if save_slot != null:
		for index in range(save_slot.item_count):
			save_slot_items.append({
				"text": save_slot.get_item_text(index),
				"metadata": save_slot.get_item_metadata(index),
				"disabled": save_slot.is_item_disabled(index),
			})
	semantics["SaveSlot"] = {
		"focus_mode": save_slot.focus_mode if save_slot != null else Control.FOCUS_NONE,
		"selected": save_slot.selected if save_slot != null else -1,
		"items": save_slot_items,
	}
	var system_body := shell.get_node_or_null("%SystemBody") as Label
	semantics["SystemBody"] = {
		"text": system_body.text if system_body != null else "",
		"tooltip": system_body.tooltip_text if system_body != null else "",
	}
	var action_guide := shell.get_node_or_null("%ActionGuide") as Label
	semantics["ActionGuideTooltip"] = action_guide.tooltip_text if action_guide != null else ""
	return semantics

func _check_persisted_reload() -> bool:
	SettingsService.settings = {}
	SettingsService.load_settings()
	return (
		_require(SettingsService.master_volume_percent() == 55, "Active-play Master volume did not survive config reload.")
		and _require(SettingsService.battle_playback_speed_id() == "instant", "Active-play battle speed did not survive config reload.")
		and _require(SettingsService.ui_scale_percent() == 130, "Active-play UI scale did not survive config reload.")
		and _require(SettingsService.high_contrast_ui_enabled(), "Active-play High Contrast did not survive config reload.")
		and _require(SettingsService.reduced_motion_enabled(), "Active-play Reduce Motion did not survive config reload.")
		and _require(SettingsService.reduced_flashes_enabled(), "Active-play Reduce Flashes did not survive config reload.")
		and _require(SettingsService.reduced_repetitive_sounds_enabled(), "Active-play reduced repeated sounds did not survive config reload.")
	)

func _dialog_fits_viewport(dialog: Control) -> bool:
	var panel: Control = dialog.get_node("%DialogPanel")
	return dialog.get_viewport_rect().grow(1.0).encloses(panel.get_global_rect())

func _dialog_fits_1280_at_130(dialog: Control) -> bool:
	return bool(_dialog_1280_at_130_snapshot(dialog).get("ok", false))

func _dialog_1280_at_130_snapshot(dialog: Control) -> Dictionary:
	var panel: Control = dialog.get_node("%DialogPanel")
	var viewport_rect := dialog.get_viewport_rect()
	var panel_rect := panel.get_global_rect()
	return (
		{
			"ok": (
				SettingsService.presentation_resolution_id() == "1280x720"
				and get_window().size == Vector2i(1280, 720)
				and SettingsService.ui_scale_percent() == 130
				and viewport_rect.grow(1.0).encloses(panel_rect)
			),
			"resolution_id": SettingsService.presentation_resolution_id(),
			"window_size": get_window().size,
			"display_server_window_size": DisplayServer.window_get_size(),
			"ui_scale_percent": SettingsService.ui_scale_percent(),
			"viewport_rect": viewport_rect,
			"panel_rect": panel_rect,
		}
	)

func _check_modal_focus_containment(shell, dialog: Control, session, surface_name: String) -> bool:
	if not _require(_focus_name() == "MasterVolumeSlider", "%s settings did not start keyboard/controller traversal at Master volume." % surface_name):
		return false
	if not dialog.closed.is_connected(_on_dialog_closed.bind(surface_name)):
		dialog.closed.connect(_on_dialog_closed.bind(surface_name))

	var reverse_cycle := [FOCUS_CYCLE_NAMES[0]]
	for index in range(FOCUS_CYCLE_NAMES.size() - 1, 0, -1):
		reverse_cycle.append(FOCUS_CYCLE_NAMES[index])
	if not await _check_focus_button_cycle(dialog, surface_name, JOY_BUTTON_RIGHT_SHOULDER, "right shoulder/ui_focus_next", FOCUS_CYCLE_NAMES):
		return false
	if not await _check_close_boundary_accept(shell, dialog, session, surface_name, "right shoulder/ui_focus_next"):
		return false
	if not await _check_focus_button_cycle(dialog, surface_name, JOY_BUTTON_LEFT_SHOULDER, "left shoulder/ui_focus_prev", reverse_cycle):
		return false
	if not await _check_close_boundary_accept(shell, dialog, session, surface_name, "left shoulder/ui_focus_prev"):
		return false
	if not await _check_focus_button_cycle(dialog, surface_name, JOY_BUTTON_DPAD_DOWN, "D-pad down/ui_down", FOCUS_CYCLE_NAMES):
		return false
	if not await _check_focus_button_cycle(dialog, surface_name, JOY_BUTTON_DPAD_UP, "D-pad up/ui_up", reverse_cycle):
		return false
	if not await _check_focus_key_cycle(dialog, surface_name, KEY_TAB, false, "Tab/ui_focus_next", FOCUS_CYCLE_NAMES):
		return false
	if not await _check_focus_key_cycle(dialog, surface_name, KEY_TAB, true, "Shift+Tab/ui_focus_prev", reverse_cycle):
		return false
	if not await _check_focus_key_cycle(dialog, surface_name, KEY_DOWN, false, "Arrow Down/ui_down", FOCUS_CYCLE_NAMES):
		return false
	if not await _check_focus_key_cycle(dialog, surface_name, KEY_UP, false, "Arrow Up/ui_up", reverse_cycle):
		return false

	if not _require(dialog.validation_focus_control("ReduceRepetitiveSoundsToggle"), "%s settings could not focus the vertical lower boundary." % surface_name):
		return false
	await _settle()
	if not _require(dialog.validation_control_visible("ReduceRepetitiveSoundsToggle"), "%s vertical traversal left the final modal control clipped." % surface_name):
		return false

	var master_slider: HSlider = dialog.get_node("%MasterVolumeSlider")
	master_slider.grab_focus()
	await _settle()
	var volume_before := master_slider.value
	await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
	if not _require(_focus_name() == "MasterVolumeSlider" and master_slider.value < volume_before, "%s ui_left did not adjust Master volume while retaining modal focus." % surface_name):
		return false
	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	if not _require(_focus_name() == "MasterVolumeSlider" and is_equal_approx(master_slider.value, volume_before), "%s ui_right did not restore Master volume while retaining modal focus." % surface_name):
		return false

	var speed_picker: OptionButton = dialog.get_node("%BattlePlaybackSpeedPicker")
	speed_picker.grab_focus()
	await _settle()
	var selection_before := speed_picker.selected
	var authority_before := _modal_authority_signature(shell, session, surface_name, true)
	await _press_joypad_button(JOY_BUTTON_A)
	var popup := speed_picker.get_popup()
	if not _require(dialog.is_open() and popup.visible, "%s physical A/ui_accept did not remain modal and open the focused battle-speed popup." % surface_name):
		return false
	if not _require(speed_picker.selected == selection_before, "%s physical A/ui_accept changed the battle-speed selection without a popup choice." % surface_name):
		return false
	if not _require(_popup_owns_focus(speed_picker), "%s battle-speed popup did not own controller focus after physical A/ui_accept." % surface_name):
		return false
	if not _require(_modal_authority_signature(shell, session, surface_name, true) == authority_before, "%s physical A/ui_accept changed session/save/cache/routes/settings authority behind the modal." % surface_name):
		return false
	await _press_joypad_button(JOY_BUTTON_B)
	if not _require(dialog.is_open() and not popup.visible and _focus_is_inside(dialog), "%s popup physical B/ui_cancel did not return focus to the still-open settings modal." % surface_name):
		return false
	return true

func _check_overworld_unhandled_command_containment(shell, dialog: Control, session) -> bool:
	var master_slider: HSlider = dialog.get_node("%MasterVolumeSlider")
	master_slider.grab_focus()
	await _settle()
	var exact_authority := _overworld_unhandled_authority_signature(shell, dialog, session)
	for command_value in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		var command: Key = command_value
		await _press_physical_key(command)
		if not _require(
			dialog.is_open()
			and _focus_name() == "MasterVolumeSlider"
			and _overworld_unhandled_authority_signature(shell, dialog, session) == exact_authority,
			"Overworld Settings physical %s escaped the modal or changed dialog/focus/session/day/hero/movement/selected-route/camera/overlay/save/cache/settings/routes authority." % OS.get_keycode_string(command)
		):
			return false
	var close_button: Button = dialog.get_node("%Close")
	close_button.grab_focus()
	await _settle()
	var unhandled_authority := _overworld_unhandled_authority_signature(shell, dialog, session)
	for command_value in [KEY_F3, KEY_F4, KEY_HOME]:
		var command: Key = command_value
		await _press_physical_key(command)
		if not _require(
			dialog.is_open()
			and _focus_name() == "Close"
			and _overworld_unhandled_authority_signature(shell, dialog, session) == unhandled_authority,
			"Overworld Settings physical %s escaped the modal or changed dialog/focus/session/day/hero/movement/selected-route/camera/overlay/save/cache/settings/routes authority." % OS.get_keycode_string(command)
		):
			return false

	master_slider.grab_focus()
	await _settle()
	var background_before_arrows := _background_authority_signature(shell, session, "Overworld")
	await _press_physical_key(KEY_DOWN)
	if not _require(
		dialog.is_open()
		and _focus_name() == "MusicVolumeSlider"
		and _background_authority_signature(shell, session, "Overworld") == background_before_arrows,
		"Overworld Settings physical Down did not remain in the modal or changed live background authority."
	):
		return false
	await _press_physical_key(KEY_UP)
	if not _require(
		dialog.is_open()
		and _focus_name() == "MasterVolumeSlider"
		and _overworld_unhandled_authority_signature(shell, dialog, session) == exact_authority,
		"Overworld Settings physical Up did not restore exact modal focus and authority."
	):
		return false

	var reduce_flashes_toggle: CheckButton = dialog.get_node("%ReduceFlashesToggle")
	reduce_flashes_toggle.grab_focus()
	await _settle()
	var toggle_before := reduce_flashes_toggle.button_pressed
	var native_background_before := _modal_authority_signature(shell, session, "Overworld", false)
	await _press_physical_key(KEY_SPACE)
	if not _require(
		dialog.is_open()
		and _focus_name() == "ReduceFlashesToggle"
		and reduce_flashes_toggle.button_pressed != toggle_before
		and _modal_authority_signature(shell, session, "Overworld", false) == native_background_before,
		"Overworld Settings physical Space did not toggle only the focused native modal control."
	):
		return false
	await _press_physical_key(KEY_SPACE)
	if not _require(reduce_flashes_toggle.button_pressed == toggle_before, "Overworld Settings physical Space did not restore the focused native toggle."):
		return false
	await _click_control(reduce_flashes_toggle)
	if not _require(
		dialog.is_open()
		and reduce_flashes_toggle.button_pressed != toggle_before
		and _modal_authority_signature(shell, session, "Overworld", false) == native_background_before,
		"Overworld Settings mouse click did not toggle only the visible native modal control."
	):
		return false
	await _click_control(reduce_flashes_toggle)
	if not _require(reduce_flashes_toggle.button_pressed == toggle_before, "Overworld Settings mouse click did not restore the native toggle."):
		return false
	return true

func _check_overworld_post_close_commands(shell, session, adjacent_target: Vector2i, home_camera_expected: Dictionary) -> bool:
	var home_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _press_physical_key(KEY_HOME)
	var home_after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if not _require(
		home_after.get("camera_focus_tile", {}) == home_camera_expected.get("camera_focus_tile", {})
		and home_after.get("camera_focus_tile_precise", {}) == home_camera_expected.get("camera_focus_tile_precise", {})
		and (
			home_after.get("camera_focus_tile", {}) != home_before.get("camera_focus_tile", {})
			or home_after.get("camera_focus_tile_precise", {}) != home_before.get("camera_focus_tile_precise", {})
		),
		"Overworld physical Home did not focus the camera on the hero exactly once after Settings closed: before=%s after=%s" % [home_before, home_after]
	):
		return false

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	await _settle()
	var movement_before := int(session.overworld.get("movement", {}).get("current", 0))
	await _press_physical_key(KEY_ENTER)
	var movement_after := int(session.overworld.get("movement", {}).get("current", 0))
	if not _require(
		OverworldRules.hero_position(session) == adjacent_target
		and movement_after == movement_before - 1,
		"Overworld physical Enter did not execute the selected adjacent primary command exactly once after Settings closed. hero=%s movement=%d->%d" % [OverworldRules.hero_position(session), movement_before, movement_after]
	):
		return false

	var debug_before: Dictionary = shell.validation_debug_overlay_snapshot()
	await _press_physical_key(KEY_F3)
	var debug_after: Dictionary = shell.validation_debug_overlay_snapshot()
	if not _require(not bool(debug_before.get("enabled", true)) and bool(debug_after.get("enabled", false)), "Overworld physical F3 did not toggle the debug overlay exactly once after Settings closed."):
		return false
	var placement_before: Dictionary = shell.validation_placement_debug_overlay_snapshot()
	await _press_physical_key(KEY_F4)
	var placement_after: Dictionary = shell.validation_placement_debug_overlay_snapshot()
	if not _require(not bool(placement_before.get("enabled", true)) and bool(placement_after.get("enabled", false)), "Overworld physical F4 did not toggle the placement overlay exactly once after Settings closed."):
		return false
	return true

func _check_focus_button_cycle(dialog: Control, surface_name: String, button_index: int, input_label: String, expected_cycle: Array) -> bool:
	if not _require(_seed_modal_focus(dialog, String(expected_cycle[0])), "%s could not seed %s focus traversal." % [surface_name, input_label]):
		return false
	await _settle()
	var visited := {}
	for expected_name_value in expected_cycle:
		var expected_name := String(expected_name_value)
		if not _require(_focus_name() == expected_name, "%s %s focus order expected %s and found %s." % [surface_name, input_label, expected_name, _focus_name()]):
			return false
		visited[expected_name] = true
		await _press_joypad_button(button_index)
		if not _require(_focus_is_inside(dialog), "%s %s escaped the settings modal after %s." % [surface_name, input_label, expected_name]):
			return false
	if not _require(visited.size() == FOCUS_CYCLE_NAMES.size() and _focus_name() == String(expected_cycle[0]), "%s %s did not close its exact 12-control modal cycle." % [surface_name, input_label]):
		return false
	return true

func _check_focus_key_cycle(dialog: Control, surface_name: String, keycode: Key, shift_pressed: bool, input_label: String, expected_cycle: Array) -> bool:
	if not _require(_seed_modal_focus(dialog, String(expected_cycle[0])), "%s could not seed %s focus traversal." % [surface_name, input_label]):
		return false
	await _settle()
	var visited := {}
	for expected_name_value in expected_cycle:
		var expected_name := String(expected_name_value)
		if not _require(_focus_name() == expected_name, "%s %s focus order expected %s and found %s." % [surface_name, input_label, expected_name, _focus_name()]):
			return false
		visited[expected_name] = true
		await _press_key(keycode, shift_pressed)
		if not _require(_focus_is_inside(dialog), "%s %s escaped the settings modal after %s." % [surface_name, input_label, expected_name]):
			return false
	if not _require(visited.size() == FOCUS_CYCLE_NAMES.size() and _focus_name() == String(expected_cycle[0]), "%s %s did not close its exact 12-control modal cycle." % [surface_name, input_label]):
		return false
	return true

func _seed_modal_focus(dialog: Control, control_name: String) -> bool:
	var control := dialog.get_node_or_null("%%%s" % control_name) as Control
	if control == null:
		return false
	control.grab_focus()
	return true

func _check_close_boundary_accept(shell, dialog: Control, session, surface_name: String, input_label: String) -> bool:
	if not _require(_focus_name() == "Close", "%s %s did not finish on the wrapped modal Close boundary." % [surface_name, input_label]):
		return false
	var authority_before := _background_authority_signature(shell, session, surface_name)
	var close_count_before := int(_dialog_closed_counts.get(surface_name, 0))
	await _press_joypad_button(JOY_BUTTON_A)
	if not _require(not dialog.is_open() and int(_dialog_closed_counts.get(surface_name, 0)) == close_count_before + 1, "%s physical A/ui_accept did not activate only the wrapped modal Close boundary." % surface_name):
		return false
	var reopened: Dictionary = shell.validation_open_active_play_settings()
	await _settle()
	if not _require(bool(reopened.get("visible", false)) and dialog.is_open() and _focus_name() == "MasterVolumeSlider", "%s settings did not restore modal ownership after wrapped-boundary Accept." % surface_name):
		return false
	if not _require(_dialog_fits_1280_at_130(dialog), "%s settings lost its 1280x720 at 130 percent focus-cycle fixture after reopen." % surface_name):
		return false
	if not _require(_background_authority_signature(shell, session, surface_name) == authority_before, "%s wrapped-boundary Accept changed session/save/cache/routes/settings authority." % surface_name):
		return false
	return true

func _focus_is_inside(dialog: Control) -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner != null and (focus_owner == dialog or dialog.is_ancestor_of(focus_owner))

func _popup_owns_focus(picker: OptionButton) -> bool:
	var popup := picker.get_popup()
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner == picker or focus_owner == popup or (focus_owner != null and popup.is_ancestor_of(focus_owner))

func _on_dialog_closed(surface_name: String) -> void:
	_dialog_closed_counts[surface_name] = int(_dialog_closed_counts.get(surface_name, 0)) + 1

func _modal_authority_signature(shell, session, surface_name: String, include_settings: bool) -> String:
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	shell_route.erase("focus_owner")
	var authority := {
		"session": _gameplay_signature(session),
		"surface_state": _surface_gameplay_authority(session, surface_name),
		"shell_routes": shell_route,
		"app_routes": AppRouter.validation_active_play_return_snapshot(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
	}
	if include_settings:
		authority["settings"] = SettingsService.validation_settings_transaction_snapshot()
	if surface_name == "Overworld":
		authority["controller_routes"] = _overworld_controller_route_authority(shell)
		authority["debug_overlay"] = shell.validation_debug_overlay_snapshot()
		authority["placement_debug_overlay"] = shell.validation_placement_debug_overlay_snapshot()
	elif surface_name == "Town":
		authority["town_cache"] = shell.validation_town_entity_cache_snapshot()
	return JSON.stringify(authority)

func _background_authority_signature(shell, session, surface_name: String) -> String:
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	shell_route.erase("focus_owner")
	var authority := {
		"session": _gameplay_signature(session),
		"surface_state": _surface_gameplay_authority(session, surface_name),
		"shell_routes": shell_route,
		"app_routes": AppRouter.validation_active_play_return_snapshot(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": SettingsService.validation_settings_transaction_snapshot(),
	}
	if surface_name == "Overworld":
		authority["controller_routes"] = _overworld_controller_route_authority(shell)
		authority["debug_overlay"] = shell.validation_debug_overlay_snapshot()
		authority["placement_debug_overlay"] = shell.validation_placement_debug_overlay_snapshot()
	elif surface_name == "Town":
		authority["town_cache"] = shell.validation_town_entity_cache_snapshot()
	return JSON.stringify(authority)

func _overworld_controller_route_authority(shell) -> Dictionary:
	var controller_routes: Dictionary = shell.validation_controller_route_cursor_snapshot()
	controller_routes.erase("focus_owner")
	return controller_routes

func _overworld_unhandled_authority_signature(shell, dialog: Control, session) -> String:
	return JSON.stringify({
		"dialog": dialog.validation_snapshot(),
		"background": _background_authority_signature(shell, session, "Overworld"),
	})

func _surface_gameplay_authority(session, surface_name: String) -> Dictionary:
	var snapshot: Dictionary = session.to_dict()
	var overworld: Dictionary = snapshot.get("overworld", {}) if snapshot.get("overworld", {}) is Dictionary else {}
	if surface_name == "Overworld":
		return {
			"day": snapshot.get("day", 0),
			"active_hero_id": overworld.get("active_hero_id", ""),
			"hero_position": overworld.get("hero_position", {}),
			"player_resources": overworld.get("player_resources", {}),
		}
	if surface_name == "Town":
		var town := _first_player_town(session)
		return {
			"day": snapshot.get("day", 0),
			"active_hero_id": overworld.get("active_hero_id", ""),
			"town_player_resources": overworld.get("player_resources", {}),
			"town_built_buildings": town.get("built_buildings", []),
			"town": town,
		}
	var battle: Dictionary = snapshot.get("battle", {}) if snapshot.get("battle", {}) is Dictionary else {}
	battle.erase(BattleRules.PRESENTATION_SPEED_KEY)
	return {
		"battle_round": battle.get("round", 0),
		"battle_turn_index": battle.get("turn_index", 0),
		"battle_rng_state": battle.get(BattleRules.DAMAGE_RNG_STATE_KEY, 0),
		"battle_rng_roll_count": battle.get(BattleRules.DAMAGE_RNG_ROLL_COUNT_KEY, 0),
		"battle": battle,
	}

func _gameplay_signature(session) -> String:
	var snapshot: Dictionary = session.to_dict()
	var battle: Dictionary = snapshot.get("battle", {}) if snapshot.get("battle", {}) is Dictionary else {}
	battle.erase(BattleRules.PRESENTATION_SPEED_KEY)
	snapshot["battle"] = battle
	return JSON.stringify(snapshot)

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _first_open_adjacent_tile(session, origin: Vector2i) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for direction_value in [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1),
	]:
		var direction: Vector2i = direction_value
		var tile := origin + direction
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		if not OverworldRules.is_tile_explored(session, tile.x, tile.y):
			continue
		if _tile_has_overworld_object(session, tile):
			continue
		return tile
	return Vector2i(-1, -1)

func _expand_overworld_camera_fixture(session) -> void:
	var source_rows: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	var expanded_rows: Array = []
	for y in range(16):
		var row: Array = source_rows[y].duplicate(true) if y < source_rows.size() and source_rows[y] is Array else []
		while row.size() < 24:
			row.append("grass")
		expanded_rows.append(row)
	session.overworld["map"] = expanded_rows
	session.overworld["map_size"] = {"width": 24, "height": 16}

func _tile_has_overworld_object(session, tile: Vector2i) -> bool:
	for collection_name in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for object_value in session.overworld.get(collection_name, []):
			if not (object_value is Dictionary):
				continue
			var object: Dictionary = object_value
			if int(object.get("x", -1)) != tile.x or int(object.get("y", -1)) != tile.y:
				continue
			if collection_name == "resource_nodes" or collection_name == "artifact_nodes":
				if bool(object.get("collected", false)):
					continue
			elif collection_name == "encounters" and OverworldRules.is_encounter_resolved(session, object):
				continue
			return true
	return false

func _pan_overworld_camera(shell) -> bool:
	for delta_value in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		var delta: Vector2i = delta_value
		var pan_result: Dictionary = shell.validation_pan_map(delta.x, delta.y)
		if bool(pan_result.get("changed", false)):
			return true
	return false

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _focus_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return "none" if focus_owner == null else String(focus_owner.name)

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

func _press_key(keycode: Key, shift_pressed: bool = false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.shift_pressed = shift_pressed
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.shift_pressed = shift_pressed
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _press_physical_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _click_control(control: Control) -> void:
	var click_position := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	var window_id: int = int(viewport.get_window_id()) if viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = click_position
	motion.global_position = click_position
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var pressed := InputEventMouseButton.new()
	pressed.window_id = window_id
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = click_position
	pressed.global_position = click_position
	pressed.pressed = true
	viewport.push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.window_id = window_id
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = click_position
	released.global_position = click_position
	released.pressed = false
	viewport.push_input(released, true)
	await _settle()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_if_requested(stem: String) -> bool:
	var capture_dir := OS.get_environment("ACTIVE_PLAY_SETTINGS_CAPTURE_DIR")
	if capture_dir == "":
		return true
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := "%s/%s.png" % [absolute_dir, stem]
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return _require(false, "The active renderer could not provide pixels for %s." % path)
	var error := image.save_png(path)
	return _require(error == OK, "Could not save settings capture %s: %s." % [path, error])

func _capture_settings_state() -> void:
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_window_size = get_window().size
	var path := String(SettingsService.SETTINGS_FILE)
	_original_settings_file_existed = FileAccess.file_exists(path)
	if _original_settings_file_existed:
		_original_settings_file = FileAccess.get_file_as_bytes(path)

func _restore_settings_state() -> void:
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	get_window().size = _original_window_size
	var path := String(SettingsService.SETTINGS_FILE)
	if _original_settings_file_existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_original_settings_file)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	_restore_settings_state()
	get_tree().quit(1 if _failed else 0)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error("%s: %s" % [REPORT_ID, message])
	return false
