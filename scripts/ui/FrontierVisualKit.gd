extends RefCounted

const TEXT_TONES := {
	"title": Color(0.98, 0.96, 0.90, 1.0),
	"body": Color(0.86, 0.90, 0.93, 1.0),
	"muted": Color(0.78, 0.82, 0.87, 1.0),
	"gold": Color(0.97, 0.88, 0.61, 1.0),
	"teal": Color(0.78, 0.90, 0.90, 1.0),
	"green": Color(0.84, 0.92, 0.78, 1.0),
	"red": Color(0.93, 0.76, 0.70, 1.0),
	"blue": Color(0.80, 0.86, 0.96, 1.0),
}

const HIGH_CONTRAST_TEXT_TONES := {
	"title": Color(1.0, 1.0, 1.0, 1.0),
	"body": Color(0.96, 0.98, 1.0, 1.0),
	"muted": Color(0.86, 0.90, 0.94, 1.0),
	"gold": Color(1.0, 0.91, 0.32, 1.0),
	"teal": Color(0.45, 0.95, 1.0, 1.0),
	"green": Color(0.68, 1.0, 0.55, 1.0),
	"red": Color(1.0, 0.58, 0.52, 1.0),
	"blue": Color(0.65, 0.80, 1.0, 1.0),
}

const COLOR_CUE_MODE_STANDARD := "standard"
const COLOR_CUE_MODE_ASSISTED := "assisted"

const ASSISTED_TEXT_TONES := {
	"green": Color(0.48, 0.82, 1.0, 1.0),
	"red": Color(1.0, 0.68, 0.30, 1.0),
}

const ASSISTED_HIGH_CONTRAST_TEXT_TONES := {
	"green": Color(0.42, 0.92, 1.0, 1.0),
	"red": Color(1.0, 0.72, 0.24, 1.0),
}

const ASSISTED_PANEL_TONES := {
	"green": {
		"bg": Color(0.08, 0.14, 0.19, 0.97),
		"border": Color(0.30, 0.72, 0.96, 0.98),
	},
	"red": {
		"bg": Color(0.20, 0.13, 0.06, 0.97),
		"border": Color(0.94, 0.58, 0.20, 0.98),
	},
}

const ASSISTED_SEMANTIC_COLORS := {
	"player": Color(0.0, 0.45, 0.70, 1.0),
	"enemy": Color(0.90, 0.36, 0.0, 1.0),
	"neutral": Color(0.66, 0.70, 0.76, 1.0),
	"move": Color(0.20, 0.76, 0.88, 1.0),
	"target": Color(0.95, 0.55, 0.12, 1.0),
	"blocked": Color(0.78, 0.28, 0.68, 1.0),
}

const HIGH_CONTRAST_PANEL_BORDERS := {
	"banner": Color(1.0, 0.88, 0.36, 1.0),
	"gold": Color(1.0, 0.88, 0.36, 1.0),
	"earth": Color(1.0, 0.70, 0.32, 1.0),
	"teal": Color(0.40, 0.92, 1.0, 1.0),
	"green": Color(0.62, 0.96, 0.48, 1.0),
	"blue": Color(0.62, 0.76, 1.0, 1.0),
	"red": Color(1.0, 0.48, 0.42, 1.0),
	"ink": Color(0.88, 0.94, 1.0, 1.0),
	"frame": Color(0.88, 0.94, 1.0, 1.0),
	"smoke": Color(1.0, 0.88, 0.36, 1.0),
	"clear": Color(0.0, 0.0, 0.0, 0.0),
}

const PANEL_TONES := {
	"banner": {
		"bg": Color(0.13, 0.16, 0.16, 0.97),
		"border": Color(0.86, 0.72, 0.40, 0.96),
	},
	"gold": {
		"bg": Color(0.17, 0.14, 0.10, 0.97),
		"border": Color(0.88, 0.72, 0.40, 0.96),
	},
	"earth": {
		"bg": Color(0.16, 0.13, 0.11, 0.97),
		"border": Color(0.80, 0.59, 0.35, 0.96),
	},
	"teal": {
		"bg": Color(0.11, 0.15, 0.17, 0.97),
		"border": Color(0.47, 0.70, 0.75, 0.96),
	},
	"green": {
		"bg": Color(0.11, 0.16, 0.13, 0.97),
		"border": Color(0.57, 0.74, 0.44, 0.96),
	},
	"blue": {
		"bg": Color(0.11, 0.14, 0.20, 0.97),
		"border": Color(0.55, 0.64, 0.91, 0.96),
	},
	"red": {
		"bg": Color(0.19, 0.12, 0.11, 0.97),
		"border": Color(0.86, 0.45, 0.37, 0.96),
	},
	"ink": {
		"bg": Color(0.10, 0.12, 0.15, 0.97),
		"border": Color(0.50, 0.60, 0.68, 0.96),
	},
	"frame": {
		"bg": Color(0.06, 0.08, 0.09, 1.0),
		"border": Color(0.56, 0.66, 0.71, 0.96),
	},
	"smoke": {
		"bg": Color(0.05, 0.06, 0.08, 0.76),
		"border": Color(0.80, 0.69, 0.45, 0.82),
	},
	"clear": {
		"bg": Color(0.0, 0.0, 0.0, 0.0),
		"border": Color(0.0, 0.0, 0.0, 0.0),
	},
}

const BUTTON_ROLES := {
	"primary": {
		"fill": Color(0.37, 0.26, 0.15, 0.98),
		"hover": Color(0.45, 0.31, 0.18, 1.0),
		"pressed": Color(0.27, 0.18, 0.11, 1.0),
		"border": Color(0.89, 0.73, 0.41, 0.97),
	},
	"secondary": {
		"fill": Color(0.18, 0.22, 0.25, 0.98),
		"hover": Color(0.24, 0.29, 0.33, 1.0),
		"pressed": Color(0.14, 0.17, 0.20, 1.0),
		"border": Color(0.52, 0.62, 0.68, 0.96),
	},
	"danger": {
		"fill": Color(0.29, 0.14, 0.12, 0.98),
		"hover": Color(0.37, 0.18, 0.15, 1.0),
		"pressed": Color(0.22, 0.10, 0.09, 1.0),
		"border": Color(0.88, 0.48, 0.39, 0.97),
	},
	"spine": {
		"fill": Color(0.11, 0.14, 0.17, 0.84),
		"hover": Color(0.15, 0.19, 0.23, 0.92),
		"pressed": Color(0.08, 0.11, 0.13, 0.96),
		"border": Color(0.81, 0.68, 0.42, 0.86),
	},
	"spine_active": {
		"fill": Color(0.31, 0.22, 0.14, 0.92),
		"hover": Color(0.40, 0.28, 0.17, 0.96),
		"pressed": Color(0.24, 0.17, 0.11, 0.98),
		"border": Color(0.92, 0.77, 0.47, 0.94),
	},
}

const HIGH_CONTRAST_BUTTON_ROLES := {
	"primary": {
		"fill": Color(0.16, 0.12, 0.02, 1.0),
		"hover": Color(0.30, 0.23, 0.03, 1.0),
		"pressed": Color(0.08, 0.06, 0.01, 1.0),
		"border": Color(1.0, 0.88, 0.32, 1.0),
	},
	"secondary": {
		"fill": Color(0.025, 0.035, 0.045, 1.0),
		"hover": Color(0.11, 0.16, 0.20, 1.0),
		"pressed": Color(0.0, 0.0, 0.0, 1.0),
		"border": Color(0.88, 0.94, 1.0, 1.0),
	},
	"danger": {
		"fill": Color(0.20, 0.02, 0.01, 1.0),
		"hover": Color(0.36, 0.05, 0.03, 1.0),
		"pressed": Color(0.10, 0.0, 0.0, 1.0),
		"border": Color(1.0, 0.48, 0.42, 1.0),
	},
}

static var _high_contrast_enabled := false
static var _color_cue_mode := COLOR_CUE_MODE_STANDARD

const BUTTON_ART_ROOT := "res://art/ui/runtime/shared"

static func set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> void:
	label.tooltip_text = full_text
	label.text = compact_text(full_text, max_lines, max_chars, drop_headings)

static func compact_text(full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> String:
	var raw_lines := full_text.split("\n", false)
	var lines: Array[String] = []
	for raw_line in raw_lines:
		var line := raw_line.strip_edges()
		if line == "":
			continue
		if drop_headings and raw_lines.size() > 1 and not line.begins_with("-") and "|" not in line and ":" not in line and line == line.capitalize():
			continue
		if line.begins_with("- "):
			line = line.trim_prefix("- ").strip_edges()
		if line.length() > max_chars:
			line = "%s..." % line.left(max_chars - 3)
		lines.append(line)
	if lines.is_empty():
		return full_text.strip_edges()
	if lines.size() > max_lines:
		var hidden := lines.size() - max_lines
		lines = lines.slice(0, max_lines)
		lines.append("+ %d more" % hidden)
	return "\n".join(lines)

static func placeholder_label(text: String, tone: String = "muted") -> Label:
	var placeholder := Label.new()
	placeholder.text = text
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_label(placeholder, tone, 13)
	return placeholder

static func apply_label(label: Label, tone: String, font_size: int = -1) -> void:
	label.add_theme_color_override("font_color", text_color(tone))
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)

static func apply_labels(labels: Array, tone: String, font_size: int = -1) -> void:
	for label in labels:
		if label is Label:
			apply_label(label, tone, font_size)

static func set_high_contrast_enabled(enabled: bool) -> void:
	_high_contrast_enabled = enabled

static func high_contrast_enabled() -> bool:
	return _high_contrast_enabled

static func set_color_cue_mode(mode: String) -> void:
	_color_cue_mode = COLOR_CUE_MODE_ASSISTED if mode == COLOR_CUE_MODE_ASSISTED else COLOR_CUE_MODE_STANDARD

static func color_cue_mode() -> String:
	return _color_cue_mode

static func color_cue_assist_enabled() -> bool:
	return color_cue_mode() == COLOR_CUE_MODE_ASSISTED

static func semantic_color(role: String, fallback: Color) -> Color:
	if not color_cue_assist_enabled():
		return fallback
	return ASSISTED_SEMANTIC_COLORS.get(role, fallback)

static func text_color(tone: String) -> Color:
	var palette := HIGH_CONTRAST_TEXT_TONES if high_contrast_enabled() else TEXT_TONES
	if color_cue_assist_enabled():
		var assisted_palette := ASSISTED_HIGH_CONTRAST_TEXT_TONES if high_contrast_enabled() else ASSISTED_TEXT_TONES
		if assisted_palette.has(tone):
			return assisted_palette[tone]
	return palette.get(tone, palette["body"])

static func panel_style(tone: String, corner_radius: int = 16) -> StyleBoxFlat:
	var palette: Dictionary = PANEL_TONES.get(tone, PANEL_TONES.ink)
	if color_cue_assist_enabled() and ASSISTED_PANEL_TONES.has(tone):
		palette = ASSISTED_PANEL_TONES[tone]
	if high_contrast_enabled():
		var border: Color = HIGH_CONTRAST_PANEL_BORDERS.get(tone, HIGH_CONTRAST_PANEL_BORDERS["ink"])
		if color_cue_assist_enabled() and tone == "green":
			border = ASSISTED_HIGH_CONTRAST_TEXT_TONES["green"]
		elif color_cue_assist_enabled() and tone == "red":
			border = ASSISTED_HIGH_CONTRAST_TEXT_TONES["red"]
		palette = {
			"bg": Color(0.012, 0.016, 0.022, 0.995) if tone != "clear" else Color(0.0, 0.0, 0.0, 0.0),
			"border": border,
		}
	var style := StyleBoxFlat.new()
	style.bg_color = palette.get("bg", Color(0.10, 0.12, 0.15, 0.97))
	style.border_color = palette.get("border", Color(0.50, 0.60, 0.68, 0.96))
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

static func texture_panel_style(path: String, fallback_tone: String = "ink", texture_margin: int = 32, content_margin: int = 10, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> StyleBox:
	if high_contrast_enabled():
		return panel_style(fallback_tone)
	if path == "" or not ResourceLoader.exists(path):
		return panel_style(fallback_tone)
	var texture := load(path)
	if not texture is Texture2D:
		return panel_style(fallback_tone)
	var texture_2d: Texture2D = texture
	var max_x_margin: int = max(0, int(floor(float(texture_2d.get_width()) * 0.5)) - 1)
	var max_y_margin: int = max(0, int(floor(float(texture_2d.get_height()) * 0.5)) - 1)
	var safe_texture_margin: int = min(texture_margin, 24)
	var x_margin: int = clampi(safe_texture_margin, 0, max_x_margin)
	var y_margin: int = clampi(safe_texture_margin, 0, max_y_margin)
	var style := StyleBoxTexture.new()
	style.texture = texture_2d
	style.texture_margin_left = x_margin
	style.texture_margin_right = x_margin
	style.texture_margin_top = y_margin
	style.texture_margin_bottom = y_margin
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.draw_center = true
	style.modulate_color = modulate
	return style

static func badge_style(tone: String) -> StyleBoxFlat:
	var style := panel_style(tone, 12)
	style.shadow_size = 3
	return style

static func apply_panel(panel: PanelContainer, tone: String, corner_radius: int = 16) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(tone, corner_radius))

static func apply_art_panel(panel: PanelContainer, path: String, fallback_tone: String = "ink", texture_margin: int = 32, content_margin: int = 10, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	panel.add_theme_stylebox_override("panel", texture_panel_style(path, fallback_tone, texture_margin, content_margin, modulate))

static func apply_badge(panel: PanelContainer, tone: String) -> void:
	panel.add_theme_stylebox_override("panel", badge_style(tone))

static func apply_button(button: BaseButton, role: String = "secondary", width: float = 160.0, height: float = 34.0, font_size: int = 14) -> void:
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	_apply_button_theme(button, role)

static func apply_option_button(button: OptionButton, role: String = "secondary", width: float = 150.0, height: float = 36.0, font_size: int = 14) -> void:
	apply_button(button, role, width, height, font_size)

static func configure_focus_cycle(surfaces: Array) -> Array:
	var controls: Array = []
	for surface in surfaces:
		_collect_keyboard_focus_controls(surface, controls)
	if controls.size() < 2:
		return controls
	for index in range(controls.size()):
		var control: Control = controls[index]
		var next_control: Control = controls[(index + 1) % controls.size()]
		var previous_control: Control = controls[(index - 1 + controls.size()) % controls.size()]
		control.focus_next = control.get_path_to(next_control)
		control.focus_previous = control.get_path_to(previous_control)
	return controls

static func grab_keyboard_focus(root: Control, preferred: Control, controls: Array, force: bool = false) -> Control:
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return null
	var owner := root.get_viewport().gui_get_focus_owner()
	if not force and owner is Control and (owner == root or root.is_ancestor_of(owner)) and is_keyboard_focusable(owner):
		return owner
	var target := preferred if is_keyboard_focusable(preferred) else null
	if target == null:
		for value in controls:
			if value is Control and is_keyboard_focusable(value):
				target = value
				break
	if target != null:
		target.grab_focus()
	return target

static func is_keyboard_focusable(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or control.is_queued_for_deletion():
		return false
	if not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	return not (control is BaseButton and control.disabled)

static func _collect_keyboard_focus_controls(node: Node, controls: Array) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is CanvasItem and node.is_inside_tree() and not node.is_visible_in_tree():
		return
	if node is Control and is_keyboard_focusable(node) and not controls.has(node):
		controls.append(node)
	for child in node.get_children():
		_collect_keyboard_focus_controls(child, controls)

static func _apply_button_theme(button: BaseButton, role: String) -> void:
	var palette: Dictionary = BUTTON_ROLES.get(role, BUTTON_ROLES.secondary)
	if high_contrast_enabled():
		var contrast_role := role if HIGH_CONTRAST_BUTTON_ROLES.has(role) else ("primary" if role == "spine_active" else "secondary")
		palette = HIGH_CONTRAST_BUTTON_ROLES.get(contrast_role, HIGH_CONTRAST_BUTTON_ROLES.secondary)
	if color_cue_assist_enabled() and role == "danger":
		palette = palette.duplicate(true)
		palette["fill"] = Color(0.24, 0.11, 0.02, 1.0)
		palette["hover"] = Color(0.39, 0.20, 0.03, 1.0)
		palette["pressed"] = Color(0.13, 0.055, 0.01, 1.0)
		palette["border"] = ASSISTED_HIGH_CONTRAST_TEXT_TONES["red"] if high_contrast_enabled() else ASSISTED_TEXT_TONES["red"]
	var normal := StyleBoxFlat.new()
	normal.bg_color = palette.get("fill", Color(0.18, 0.22, 0.25, 0.98))
	normal.border_color = palette.get("border", Color(0.52, 0.62, 0.68, 0.96))
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	normal.shadow_size = 3
	var hover := normal.duplicate()
	hover.bg_color = palette.get("hover", Color(0.24, 0.29, 0.33, 1.0))
	var pressed := normal.duplicate()
	pressed.bg_color = palette.get("pressed", Color(0.14, 0.17, 0.20, 1.0))
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.14, 0.15, 0.92)
	disabled.border_color = Color(0.28, 0.32, 0.35, 0.72)
	var art_role := _button_art_role(role)
	button.add_theme_stylebox_override("normal", _button_art_style(art_role, "normal", normal))
	button.add_theme_stylebox_override("hover", _button_art_style(art_role, "hover", hover))
	button.add_theme_stylebox_override("pressed", _button_art_style(art_role, "pressed", pressed))
	button.add_theme_stylebox_override("disabled", _button_art_style(art_role, "disabled", disabled))
	button.add_theme_stylebox_override("focus", _button_focus_style())
	button.add_theme_color_override("font_color", text_color("title"))
	button.add_theme_color_override("font_disabled_color", Color(0.68, 0.72, 0.76) if high_contrast_enabled() else Color(0.48, 0.50, 0.53))

static func _button_focus_style(corner_radius: int = 10) -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus.border_color = Color(1.0, 0.92, 0.20, 1.0) if high_contrast_enabled() else Color(1.0, 0.84, 0.40, 1.0)
	focus.set_border_width_all(4 if high_contrast_enabled() else 3)
	focus.set_corner_radius_all(corner_radius)
	focus.set_expand_margin_all(2.0)
	return focus

static func _button_art_role(role: String) -> String:
	if role == "primary" or role == "spine_active":
		return "primary"
	if role == "danger":
		return "danger"
	return "secondary"

static func _button_art_style(art_role: String, state: String, fallback: StyleBox) -> StyleBox:
	if high_contrast_enabled():
		return fallback
	var path := "%s/button_%s_%s.png" % [BUTTON_ART_ROOT, art_role, state]
	if not ResourceLoader.exists(path):
		return fallback
	return texture_panel_style(path, "ink", 12, 8)

static func apply_item_list(item_list: ItemList, tone: String = "ink") -> void:
	item_list.add_theme_stylebox_override("panel", panel_style(tone, 14))
	item_list.add_theme_color_override("font_color", text_color("body"))
	item_list.add_theme_color_override("font_selected_color", text_color("title"))
	item_list.add_theme_color_override("guide_color", Color(0.28, 0.34, 0.39, 0.70))
	item_list.add_theme_color_override("selection_fill", text_color("gold").darkened(0.58))
	item_list.add_theme_color_override("selection_color", text_color("gold"))

static func apply_tab_container(tabs: TabContainer, tone: String = "ink") -> void:
	tabs.add_theme_stylebox_override("panel", panel_style(tone, 18))
	tabs.add_theme_stylebox_override("tab_selected", badge_style("gold"))
	tabs.add_theme_stylebox_override("tab_hovered", badge_style("teal"))
	tabs.add_theme_stylebox_override("tab_unselected", badge_style("ink"))
	tabs.add_theme_color_override("font_selected_color", text_color("title"))
	tabs.add_theme_color_override("font_unselected_color", text_color("muted"))
	tabs.add_theme_color_override("font_hovered_color", text_color("body"))

static func apply_range(range_control: Range, tone: String = "gold") -> void:
	range_control.add_theme_color_override("font_color", text_color("body"))
	if range_control is Slider:
		var slider: Slider = range_control
		slider.add_theme_stylebox_override("grabber_area", badge_style("ink"))
		slider.add_theme_stylebox_override("grabber_area_highlight", badge_style("teal"))
		slider.add_theme_stylebox_override("slider", badge_style("gold" if tone == "gold" else tone))
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = text_color(tone)
		grabber.border_color = Color(0.14, 0.16, 0.18, 0.92)
		grabber.set_corner_radius_all(8)
		grabber.set_border_width_all(2)
		slider.add_theme_stylebox_override("grabber", grabber)
		slider.add_theme_stylebox_override("grabber_highlight", grabber)
