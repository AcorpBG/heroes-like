extends Node

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const MANUAL_SAVE_DIALOG_SCENE := preload("res://scenes/shared/ManualSaveOverwriteDialog.tscn")

const EXPECTED_FRAME_PATH := "res://art/ui/runtime/main_menu/stage_dock_cartography.png"
const EXPECTED_SECONDARY_PATH := "res://art/ui/runtime/shared/button_secondary_normal.png"
const EXPECTED_PRIMARY_PATH := "res://art/ui/runtime/shared/button_primary_normal.png"
const EXPECTED_DANGER_PATH := "res://art/ui/runtime/shared/button_danger_normal.png"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_high_contrast := FrontierVisualKit.high_contrast_enabled()
	FrontierVisualKit.set_high_contrast_enabled(false)
	var primary := await _assert_dialog_case("primary")
	var danger := await _assert_dialog_case("danger")
	var manual := await _assert_manual_save_dialog()
	var high_contrast := await _assert_high_contrast_case()
	FrontierVisualKit.set_high_contrast_enabled(original_high_contrast)
	var report := {
		"ok": bool(primary.get("ok", false))
			and bool(danger.get("ok", false))
			and bool(manual.get("ok", false))
			and bool(high_contrast.get("ok", false)),
		"model": FrontierVisualKit.CONFIRMATION_DIALOG_SURFACE_MODEL,
		"primary": primary,
		"danger": danger,
		"manual_save": manual,
		"high_contrast": high_contrast,
	}
	if not bool(report["ok"]):
		push_error("Confirmation dialog visual surface report failed: %s" % JSON.stringify(report))
	print("CONFIRMATION_DIALOG_VISUAL_SURFACE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if bool(report["ok"]) else 1)


func _assert_dialog_case(confirm_role: String) -> Dictionary:
	var dialog := ConfirmationDialog.new()
	dialog.name = "%sDialog" % confirm_role.capitalize()
	dialog.title = "%s confirmation" % confirm_role.capitalize()
	dialog.dialog_text = "Preserve this exact consequential action message."
	dialog.exclusive = true
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dialog.min_size = Vector2i(612, 244)
	add_child(dialog)
	await get_tree().process_frame
	var cancel_button := dialog.get_cancel_button()
	var confirm_button := dialog.get_ok_button()
	cancel_button.text = "Keep Current State"
	confirm_button.text = "Continue"
	cancel_button.focus_mode = Control.FOCUS_ALL
	confirm_button.focus_mode = Control.FOCUS_ALL
	var before := _dialog_authority_contract(dialog)
	FrontierVisualKit.apply_confirmation_dialog(dialog, confirm_role)
	var after := _dialog_authority_contract(dialog)
	var panel_style := dialog.get_theme_stylebox("panel")
	var embedded_style := dialog.get_theme_stylebox("embedded_border")
	var expected_confirm_path := EXPECTED_DANGER_PATH if confirm_role == "danger" else EXPECTED_PRIMARY_PATH
	var result := {
		"ok": before == after
			and _frame_style_exact(panel_style)
			and _frame_style_exact(embedded_style)
			and panel_style != embedded_style
			and _button_style_path(cancel_button, "normal") == EXPECTED_SECONDARY_PATH
			and _button_style_path(confirm_button, "normal") == expected_confirm_path
			and _button_state_art_exact(cancel_button, "secondary")
			and _button_state_art_exact(confirm_button, confirm_role)
			and dialog.get_theme_color("title_color") == FrontierVisualKit.text_color("gold")
			and dialog.get_label().get_theme_color("font_color") == FrontierVisualKit.text_color("body"),
		"authority_exact": before == after,
		"panel_path": _style_texture_path(panel_style),
		"embedded_path": _style_texture_path(embedded_style),
		"cancel_path": _button_style_path(cancel_button, "normal"),
		"confirm_path": _button_style_path(confirm_button, "normal"),
		"confirm_role": confirm_role,
	}
	dialog.queue_free()
	await get_tree().process_frame
	return result


func _assert_manual_save_dialog() -> Dictionary:
	var dialog := MANUAL_SAVE_DIALOG_SCENE.instantiate() as ConfirmationDialog
	add_child(dialog)
	await get_tree().process_frame
	var result := {
		"ok": _frame_style_exact(dialog.get_theme_stylebox("panel"))
			and _frame_style_exact(dialog.get_theme_stylebox("embedded_border"))
			and _button_state_art_exact(dialog.get_cancel_button(), "secondary")
			and _button_state_art_exact(dialog.get_ok_button(), "danger")
			and dialog.get_cancel_button().text == "Keep Save"
			and dialog.exclusive,
		"cancel_text": dialog.get_cancel_button().text,
		"confirm_path": _button_style_path(dialog.get_ok_button(), "normal"),
		"exclusive": dialog.exclusive,
	}
	dialog.queue_free()
	await get_tree().process_frame
	return result


func _assert_high_contrast_case() -> Dictionary:
	var dialog := ConfirmationDialog.new()
	dialog.title = "High contrast confirmation"
	dialog.dialog_text = "The same action remains readable without decorative textures."
	add_child(dialog)
	await get_tree().process_frame
	var before := _dialog_authority_contract(dialog)
	FrontierVisualKit.set_high_contrast_enabled(true)
	FrontierVisualKit.apply_confirmation_dialog(dialog, "danger")
	var after := _dialog_authority_contract(dialog)
	var result := {
		"ok": before == after
			and dialog.get_theme_stylebox("panel") is StyleBoxFlat
			and dialog.get_theme_stylebox("embedded_border") is StyleBoxFlat
			and dialog.get_cancel_button().get_theme_stylebox("normal") is StyleBoxFlat
			and dialog.get_ok_button().get_theme_stylebox("normal") is StyleBoxFlat
			and dialog.get_theme_color("title_color") == FrontierVisualKit.text_color("gold")
			and dialog.get_label().get_theme_color("font_color") == FrontierVisualKit.text_color("body"),
		"authority_exact": before == after,
		"panel_flat": dialog.get_theme_stylebox("panel") is StyleBoxFlat,
		"confirm_flat": dialog.get_ok_button().get_theme_stylebox("normal") is StyleBoxFlat,
	}
	FrontierVisualKit.set_high_contrast_enabled(false)
	dialog.queue_free()
	await get_tree().process_frame
	return result


func _dialog_authority_contract(dialog: ConfirmationDialog) -> Dictionary:
	var cancel_button := dialog.get_cancel_button()
	var confirm_button := dialog.get_ok_button()
	return {
		"title": dialog.title,
		"dialog_text": dialog.dialog_text,
		"exclusive": dialog.exclusive,
		"initial_position": dialog.initial_position,
		"min_size": dialog.min_size,
		"max_size": dialog.max_size,
		"cancel_text": cancel_button.text,
		"confirm_text": confirm_button.text,
		"cancel_focus_mode": cancel_button.focus_mode,
		"confirm_focus_mode": confirm_button.focus_mode,
		"cancel_shortcut": cancel_button.shortcut,
		"confirm_shortcut": confirm_button.shortcut,
	}


func _frame_style_exact(style: StyleBox) -> bool:
	if not style is StyleBoxTexture:
		return false
	var texture_style := style as StyleBoxTexture
	return _style_texture_path(texture_style) == EXPECTED_FRAME_PATH \
		and is_equal_approx(texture_style.texture_margin_left, FrontierVisualKit.CONFIRMATION_DIALOG_TEXTURE_MARGIN) \
		and is_equal_approx(texture_style.texture_margin_top, FrontierVisualKit.CONFIRMATION_DIALOG_TEXTURE_MARGIN) \
		and is_equal_approx(texture_style.texture_margin_right, FrontierVisualKit.CONFIRMATION_DIALOG_TEXTURE_MARGIN) \
		and is_equal_approx(texture_style.texture_margin_bottom, FrontierVisualKit.CONFIRMATION_DIALOG_TEXTURE_MARGIN) \
		and is_equal_approx(texture_style.content_margin_left, FrontierVisualKit.CONFIRMATION_DIALOG_CONTENT_MARGIN) \
		and is_equal_approx(texture_style.content_margin_top, FrontierVisualKit.CONFIRMATION_DIALOG_CONTENT_MARGIN) \
		and is_equal_approx(texture_style.content_margin_right, FrontierVisualKit.CONFIRMATION_DIALOG_CONTENT_MARGIN) \
		and is_equal_approx(texture_style.content_margin_bottom, FrontierVisualKit.CONFIRMATION_DIALOG_CONTENT_MARGIN) \
		and texture_style.modulate_color == FrontierVisualKit.CONFIRMATION_DIALOG_FRAME_MODULATE


func _button_state_art_exact(button: BaseButton, role: String) -> bool:
	var resolved_role := "danger" if role == "danger" else ("primary" if role == "primary" else "secondary")
	for state in ["normal", "hover", "pressed", "disabled"]:
		if _button_style_path(button, state) != "res://art/ui/runtime/shared/button_%s_%s.png" % [resolved_role, state]:
			return false
	return button.get_theme_stylebox("focus") is StyleBoxFlat


func _button_style_path(button: BaseButton, state: String) -> String:
	return _style_texture_path(button.get_theme_stylebox(state))


func _style_texture_path(style: StyleBox) -> String:
	if not style is StyleBoxTexture:
		return ""
	var texture_style := style as StyleBoxTexture
	return String(texture_style.texture.resource_path) if texture_style.texture != null else ""
