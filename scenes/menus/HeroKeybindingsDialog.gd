class_name HeroKeybindingsDialog
extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

signal dismissed

@onready var _panel: PanelContainer = %BindingPanel
@onready var _title_label: Label = %BindingTitle
@onready var _preset_label: Label = %BindingPreset
@onready var _binding_grid: GridContainer = %BindingGrid
@onready var _status_label: Label = %BindingStatus
@onready var _reset_button: Button = %ResetBindings
@onready var _close_button: Button = %CloseBindings

var _binding_buttons := {}
var _waiting_action := StringName()
var _return_focus: Control

func _ready() -> void:
	_build_binding_rows()
	_apply_theme()
	_refresh_bindings()
	visible = false
	set_process_input(false)

func open_dialog(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_waiting_action = StringName()
	_status_label.text = "Select a direction to change its key."
	_refresh_bindings()
	visible = true
	set_process_input(true)
	var first_button := _first_binding_button()
	if first_button != null:
		first_button.call_deferred("grab_focus")

func refresh_dialog() -> void:
	_refresh_bindings()

func refresh_theme() -> void:
	_apply_theme()

func close_dialog() -> void:
	_waiting_action = StringName()
	visible = false
	set_process_input(false)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.call_deferred("grab_focus")
	dismissed.emit()

func validation_snapshot() -> Dictionary:
	var bindings := []
	for option in SettingsService.build_hero_movement_binding_options():
		bindings.append(option.duplicate(true))
	var panel_rect := _panel.get_global_rect()
	var viewport_rect := get_viewport_rect()
	return {
		"visible": visible,
		"waiting_action": String(_waiting_action),
		"preset": _preset_label.text,
		"status": _status_label.text,
		"bindings": bindings,
		"button_count": _binding_buttons.size(),
		"custom": SettingsService.has_custom_hero_movement_bindings(),
		"panel_rect": {"x": panel_rect.position.x, "y": panel_rect.position.y, "width": panel_rect.size.x, "height": panel_rect.size.y},
		"viewport_rect": {"width": viewport_rect.size.x, "height": viewport_rect.size.y},
		"fits_viewport": panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= viewport_rect.end.x and panel_rect.end.y <= viewport_rect.end.y,
	}

func validation_begin_capture(action: StringName) -> bool:
	if not _binding_buttons.has(action):
		return false
	_begin_capture(action)
	return true

func validation_capture_key(keycode: int) -> Dictionary:
	if _waiting_action == StringName():
		return {"ok": false, "reason": "not_waiting"}
	return _apply_captured_key(keycode)

func validation_reset() -> void:
	_on_reset_bindings_pressed()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _waiting_action == StringName():
			close_dialog()
		else:
			_waiting_action = StringName()
			_status_label.text = "Binding unchanged."
			_refresh_bindings()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if _waiting_action == StringName():
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.shift_pressed or key_event.meta_pressed:
		_status_label.text = "Modifier chords are reserved."
		get_viewport().set_input_as_handled()
		return
	var keycode := int(key_event.physical_keycode)
	if keycode <= 0:
		keycode = int(key_event.keycode)
	_apply_captured_key(keycode)
	get_viewport().set_input_as_handled()

func _build_binding_rows() -> void:
	for child in _binding_grid.get_children():
		child.queue_free()
	_binding_buttons.clear()
	for option in SettingsService.build_hero_movement_binding_options():
		var action := StringName(option.get("action", ""))
		var label := Label.new()
		label.text = String(option.get("label", String(action)))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FrontierVisualKit.apply_label(label, "body", 14)
		_binding_grid.add_child(label)
		var button := Button.new()
		button.name = "Binding_%s" % String(action)
		button.focus_mode = Control.FOCUS_ALL
		button.clip_text = true
		button.tooltip_text = "Change %s movement key" % label.text
		button.pressed.connect(_begin_capture.bind(action))
		FrontierVisualKit.apply_button(button, "secondary", 172.0, 36.0, 14)
		_binding_grid.add_child(button)
		_binding_buttons[action] = button

func _apply_theme() -> void:
	FrontierVisualKit.apply_panel(_panel, "ink", 8)
	FrontierVisualKit.apply_label(_title_label, "title", 22)
	FrontierVisualKit.apply_label(_preset_label, "muted", 13)
	FrontierVisualKit.apply_label(_status_label, "gold", 13)
	FrontierVisualKit.apply_button(_reset_button, "secondary", 154.0, 36.0, 14)
	FrontierVisualKit.apply_button(_close_button, "primary", 110.0, 36.0, 14)

func _refresh_bindings() -> void:
	_preset_label.text = "%s preset%s" % [
		SettingsService.keyboard_navigation_layout_label(),
		" + custom movement" if SettingsService.has_custom_hero_movement_bindings() else "",
	]
	for option in SettingsService.build_hero_movement_binding_options():
		var action := StringName(option.get("action", ""))
		var button := _binding_buttons.get(action) as Button
		if button == null:
			continue
		button.text = "Press key..." if action == _waiting_action else String(option.get("key_label", "Unbound"))
		button.tooltip_text = "Change %s movement key (current: %s)" % [
			String(option.get("label", String(action))),
			String(option.get("key_label", "Unbound")),
		]
	_reset_button.disabled = not SettingsService.has_custom_hero_movement_bindings()

func _begin_capture(action: StringName) -> void:
	_waiting_action = action
	_status_label.text = "%s: press one key." % SettingsService.hero_movement_action_label(action)
	_refresh_bindings()

func _apply_captured_key(keycode: int) -> Dictionary:
	var action := _waiting_action
	var result := SettingsService.set_hero_movement_key(action, keycode)
	if not bool(result.get("ok", false)):
		_status_label.text = "That key is reserved."
		return result
	_waiting_action = StringName()
	var swapped_action := StringName(result.get("swapped_action", ""))
	if swapped_action != StringName():
		_status_label.text = "%s set to %s; %s was swapped." % [
			SettingsService.hero_movement_action_label(action),
			SettingsService.hero_movement_key_label(keycode),
			SettingsService.hero_movement_action_label(swapped_action),
		]
	else:
		_status_label.text = "%s set to %s." % [
			SettingsService.hero_movement_action_label(action),
			SettingsService.hero_movement_key_label(keycode),
		]
	_refresh_bindings()
	return result

func _on_reset_bindings_pressed() -> void:
	SettingsService.reset_hero_movement_bindings()
	_waiting_action = StringName()
	_status_label.text = "%s preset restored." % SettingsService.keyboard_navigation_layout_label()
	_refresh_bindings()

func _on_close_bindings_pressed() -> void:
	close_dialog()

func _first_binding_button() -> Button:
	for option in SettingsService.build_hero_movement_binding_options():
		var button := _binding_buttons.get(StringName(option.get("action", ""))) as Button
		if button != null:
			return button
	return null
