extends Control

signal closed
signal setting_changed(setting_id: String)

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _panel: PanelContainer = %DialogPanel
@onready var _title: Label = %Title
@onready var _status: Label = %Status
@onready var _close_button: Button = %Close
@onready var _settings_scroll: ScrollContainer = %SettingsScroll
@onready var _master_slider: HSlider = %MasterVolumeSlider
@onready var _master_value: Label = %MasterVolumeValue
@onready var _music_slider: HSlider = %MusicVolumeSlider
@onready var _music_value: Label = %MusicVolumeValue
@onready var _effects_slider: HSlider = %EffectsVolumeSlider
@onready var _effects_value: Label = %EffectsVolumeValue
@onready var _battle_speed_picker: OptionButton = %BattlePlaybackSpeedPicker
@onready var _ui_scale_picker: OptionButton = %UIScalePicker
@onready var _battle_shake_picker: OptionButton = %BattleCameraShakePicker
@onready var _color_cue_picker: OptionButton = %ColorCuePicker
@onready var _high_contrast_toggle: CheckButton = %HighContrastToggle
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _reduce_flashes_toggle: CheckButton = %ReduceFlashesToggle
@onready var _reduce_repetitive_sounds_toggle: CheckButton = %ReduceRepetitiveSoundsToggle

var _syncing := false

func _ready() -> void:
	visible = false
	set_process_input(false)
	_apply_visual_theme()

func open_dialog() -> void:
	_sync_controls()
	visible = true
	set_process_input(true)
	move_to_front()
	call_deferred("_focus_first_control")

func close_dialog() -> void:
	if not visible:
		return
	visible = false
	set_process_input(false)
	closed.emit()

func is_open() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_dialog()
	get_viewport().set_input_as_handled()

func _focus_first_control() -> void:
	if visible and _master_slider != null:
		_master_slider.grab_focus()

func _sync_controls() -> void:
	_syncing = true
	_master_slider.value = SettingsService.master_volume_percent()
	_master_value.text = "%d%%" % SettingsService.master_volume_percent()
	_music_slider.value = SettingsService.music_volume_percent()
	_music_value.text = "%d%%" % SettingsService.music_volume_percent()
	_effects_slider.value = SettingsService.effects_volume_percent()
	_effects_value.text = "%d%%" % SettingsService.effects_volume_percent()
	_sync_option(_battle_speed_picker, SettingsService.build_battle_playback_speed_options(), "id", "normal")
	_sync_option(_ui_scale_picker, SettingsService.build_ui_scale_options(), "value", 100)
	_sync_option(_battle_shake_picker, SettingsService.build_battle_camera_shake_options(), "id", "full")
	_sync_option(_color_cue_picker, SettingsService.build_color_cue_options(), "id", "standard")
	_high_contrast_toggle.button_pressed = SettingsService.high_contrast_ui_enabled()
	_reduce_motion_toggle.button_pressed = SettingsService.reduced_motion_enabled()
	_reduce_flashes_toggle.button_pressed = SettingsService.reduced_flashes_enabled()
	_reduce_repetitive_sounds_toggle.button_pressed = SettingsService.reduced_repetitive_sounds_enabled()
	_status.text = "Saved on this device"
	_syncing = false
	_apply_visual_theme()

func _sync_option(picker: OptionButton, options: Array, metadata_key: String, fallback: Variant) -> void:
	picker.clear()
	var selected_index := 0
	for index in range(options.size()):
		var option: Dictionary = options[index] if options[index] is Dictionary else {}
		picker.add_item(String(option.get("label", fallback)), index)
		picker.set_item_metadata(index, option.get(metadata_key, fallback))
		if bool(option.get("selected", false)):
			selected_index = index
	if picker.get_item_count() > 0:
		picker.select(selected_index)

func _finish_setting_change(result: Dictionary, setting_id: String, defer_sync: bool = false) -> bool:
	if not bool(result.get("ok", false)):
		_sync_controls()
		_status.text = _settings_commit_failure_text(result)
		return false
	_status.text = "Saved on this device"
	setting_changed.emit(setting_id)
	if defer_sync:
		call_deferred("_sync_controls")
	return true

func _settings_commit_failure_text(result: Dictionary) -> String:
	var detail := String(result.get("message", "")).strip_edges()
	var message := "Not saved; previous setting restored."
	if detail != "" and detail.to_lower() not in message.to_lower():
		message = "%s %s" % [message, detail]
	return message.substr(0, 180)

func _on_close_pressed() -> void:
	close_dialog()

func _on_master_volume_changed(value: float) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_master_volume_percent(int(round(value)))
	_master_value.text = "%d%%" % SettingsService.master_volume_percent()
	_finish_setting_change(result, "master_volume")

func _on_music_volume_changed(value: float) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_music_volume_percent(int(round(value)))
	_music_value.text = "%d%%" % SettingsService.music_volume_percent()
	_finish_setting_change(result, "music_volume")

func _on_effects_volume_changed(value: float) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_effects_volume_percent(int(round(value)))
	_effects_value.text = "%d%%" % SettingsService.effects_volume_percent()
	_finish_setting_change(result, "effects_volume")

func _on_battle_playback_speed_selected(index: int) -> void:
	if _syncing or index < 0 or index >= _battle_speed_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_battle_playback_speed_id(String(_battle_speed_picker.get_item_metadata(index)))
	_finish_setting_change(result, "battle_playback_speed")

func _on_ui_scale_selected(index: int) -> void:
	if _syncing or index < 0 or index >= _ui_scale_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_ui_scale_percent(int(_ui_scale_picker.get_item_metadata(index)))
	_finish_setting_change(result, "ui_scale", true)

func _on_battle_camera_shake_selected(index: int) -> void:
	if _syncing or index < 0 or index >= _battle_shake_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_battle_camera_shake_mode_id(String(_battle_shake_picker.get_item_metadata(index)))
	_finish_setting_change(result, "battle_camera_shake")

func _on_color_cue_selected(index: int) -> void:
	if _syncing or index < 0 or index >= _color_cue_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_color_cue_mode_id(String(_color_cue_picker.get_item_metadata(index)))
	_finish_setting_change(result, "color_cues")
	_apply_visual_theme()

func _on_high_contrast_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_high_contrast_ui_enabled(enabled)
	_finish_setting_change(result, "high_contrast")
	_apply_visual_theme()

func _on_reduce_motion_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_reduced_motion_enabled(enabled)
	_finish_setting_change(result, "reduced_motion")

func _on_reduce_flashes_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_reduced_flashes_enabled(enabled)
	_finish_setting_change(result, "reduced_flashes")

func _on_reduce_repetitive_sounds_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var result: Dictionary = SettingsService.set_reduced_repetitive_sounds_enabled(enabled)
	_finish_setting_change(result, "reduced_repetitive_sounds")

func _apply_visual_theme() -> void:
	if _panel == null:
		return
	FrontierVisualKit.apply_panel(_panel, "ink", 8)
	FrontierVisualKit.apply_label(_title, "title", 20)
	FrontierVisualKit.apply_label(_status, "muted", 12)
	for label in find_children("*Label", "Label", true, false):
		if label is Label and label != _title and label != _status:
			FrontierVisualKit.apply_label(label, "body", 13)
	FrontierVisualKit.apply_button(_close_button, "secondary", 92.0, 36.0, 13)
	for picker in [_battle_speed_picker, _ui_scale_picker, _battle_shake_picker, _color_cue_picker]:
		FrontierVisualKit.apply_option_button(picker, "secondary", 220.0, 36.0, 13)
	for toggle in [_high_contrast_toggle, _reduce_motion_toggle, _reduce_flashes_toggle, _reduce_repetitive_sounds_toggle]:
		FrontierVisualKit.apply_button(toggle, "secondary", 220.0, 36.0, 13)
	for slider in [_master_slider, _music_slider, _effects_slider]:
		FrontierVisualKit.apply_range(slider, "gold")

func validation_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"rect": get_global_rect(),
		"panel_rect": _panel.get_global_rect(),
		"focus_owner": String(get_viewport().gui_get_focus_owner().name) if get_viewport().gui_get_focus_owner() != null else "",
		"status": _status.text,
		"master_volume": SettingsService.master_volume_percent(),
		"music_volume": SettingsService.music_volume_percent(),
		"effects_volume": SettingsService.effects_volume_percent(),
		"battle_playback_speed": SettingsService.battle_playback_speed_id(),
		"ui_scale_percent": SettingsService.ui_scale_percent(),
		"battle_camera_shake": SettingsService.battle_camera_shake_mode_id(),
		"color_cue_mode": SettingsService.color_cue_mode_id(),
		"high_contrast": SettingsService.high_contrast_ui_enabled(),
		"reduced_motion": SettingsService.reduced_motion_enabled(),
		"reduced_flashes": SettingsService.reduced_flashes_enabled(),
		"reduced_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
	}

func validation_select_option(control_name: String, metadata: Variant) -> bool:
	var picker := get_node_or_null("%%%s" % control_name) as OptionButton
	if picker == null:
		return false
	for index in range(picker.get_item_count()):
		if picker.get_item_metadata(index) == metadata:
			picker.select(index)
			picker.item_selected.emit(index)
			return true
	return false

func validation_set_toggle(control_name: String, enabled: bool) -> bool:
	var toggle := get_node_or_null("%%%s" % control_name) as CheckButton
	if toggle == null:
		return false
	toggle.button_pressed = enabled
	toggle.toggled.emit(enabled)
	return true

func validation_set_volume(control_name: String, value: int) -> bool:
	var slider := get_node_or_null("%%%s" % control_name) as HSlider
	if slider == null:
		return false
	slider.value = value
	return true

func validation_focus_control(control_name: String) -> bool:
	var control := get_node_or_null("%%%s" % control_name) as Control
	if control == null:
		return false
	control.grab_focus()
	_settings_scroll.ensure_control_visible(control)
	return true

func validation_control_visible(control_name: String) -> bool:
	var control := get_node_or_null("%%%s" % control_name) as Control
	if control == null:
		return false
	return _settings_scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect())
