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
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
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
	if not _require(_gameplay_signature(session) == before, "Overworld settings changed expedition gameplay state."):
		return false
	if not _require(_dialog_fits_1280_at_130(dialog), "Overworld settings modal does not fit 1280x720 at 130 percent UI scale: %s" % _dialog_1280_at_130_snapshot(dialog)):
		return false
	if not await _check_modal_focus_containment(shell, dialog, session, "Overworld"):
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
	if not _require(_focus_name() == "Settings", "Battle controller/keyboard Back did not restore focus to the Settings command."):
		return false
	shell.queue_free()
	await _settle()
	return true

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
	elif surface_name == "Town":
		authority["town_cache"] = shell.validation_town_entity_cache_snapshot()
	return JSON.stringify(authority)

func _overworld_controller_route_authority(shell) -> Dictionary:
	var controller_routes: Dictionary = shell.validation_controller_route_cursor_snapshot()
	controller_routes.erase("focus_owner")
	return controller_routes

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
