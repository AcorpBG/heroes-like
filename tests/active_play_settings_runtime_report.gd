extends Node

const REPORT_ID := "ACTIVE_PLAY_SETTINGS_RUNTIME_REPORT"

var _failed := false
var _original_settings: Dictionary = {}
var _original_settings_file := PackedByteArray()
var _original_settings_file_existed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_settings_state()
	SettingsService.settings = SettingsService.build_default_settings()
	SettingsService.apply_settings()

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
	if not _require(_dialog_fits_viewport(dialog), "Overworld settings modal no longer fits after 130 percent UI scale."):
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
	await _press_action("ui_cancel")
	if not _require(not dialog.is_open(), "Overworld controller/keyboard Back did not close settings."):
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
	if not _require(dialog.validation_set_toggle("ReduceMotionToggle", true), "Town settings could not enable Reduce Motion."):
		return false
	if not _require(dialog.validation_set_toggle("ReduceRepetitiveSoundsToggle", true), "Town settings could not enable reduced repeated sounds."):
		return false
	await _settle()
	if not _require(_gameplay_signature(session) == before, "Town settings changed town or expedition gameplay state."):
		return false
	if not await _capture_if_requested("town_settings"):
		return false
	dialog.close_dialog()
	await _settle()
	if not _require(_focus_name() == "Settings", "Town settings close did not restore focus to the Settings command."):
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
	dialog.close_dialog()
	await _settle()
	if not _require(_focus_name() == "Settings", "Battle settings close did not restore focus to the Settings command."):
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

func _press_action(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
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
	var path := String(SettingsService.SETTINGS_FILE)
	_original_settings_file_existed = FileAccess.file_exists(path)
	if _original_settings_file_existed:
		_original_settings_file = FileAccess.get_file_as_bytes(path)

func _restore_settings_state() -> void:
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
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
