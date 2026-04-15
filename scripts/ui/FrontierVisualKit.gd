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

static func text_color(tone: String) -> Color:
	return TEXT_TONES.get(tone, TEXT_TONES["body"])

static func panel_style(tone: String, corner_radius: int = 16) -> StyleBoxFlat:
	var palette: Dictionary = PANEL_TONES.get(tone, PANEL_TONES.ink)
	var style := StyleBoxFlat.new()
	style.bg_color = palette.get("bg", Color(0.10, 0.12, 0.15, 0.97))
	style.border_color = palette.get("border", Color(0.50, 0.60, 0.68, 0.96))
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

static func badge_style(tone: String) -> StyleBoxFlat:
	var style := panel_style(tone, 12)
	style.shadow_size = 3
	return style

static func apply_panel(panel: PanelContainer, tone: String, corner_radius: int = 16) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(tone, corner_radius))

static func apply_badge(panel: PanelContainer, tone: String) -> void:
	panel.add_theme_stylebox_override("panel", badge_style(tone))

static func apply_button(button: BaseButton, role: String = "secondary", width: float = 160.0, height: float = 34.0, font_size: int = 14) -> void:
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	_apply_button_theme(button, role)

static func apply_option_button(button: OptionButton, role: String = "secondary", width: float = 150.0, height: float = 36.0, font_size: int = 14) -> void:
	apply_button(button, role, width, height, font_size)

static func _apply_button_theme(button: BaseButton, role: String) -> void:
	var palette: Dictionary = BUTTON_ROLES.get(role, BUTTON_ROLES.secondary)
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
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", TEXT_TONES["title"])
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.50, 0.53))

static func apply_item_list(item_list: ItemList, tone: String = "ink") -> void:
	item_list.add_theme_stylebox_override("panel", panel_style(tone, 14))
	item_list.add_theme_color_override("font_color", TEXT_TONES["body"])
	item_list.add_theme_color_override("font_selected_color", TEXT_TONES["title"])
	item_list.add_theme_color_override("guide_color", Color(0.28, 0.34, 0.39, 0.70))
	item_list.add_theme_color_override("selection_fill", text_color("gold").darkened(0.58))
	item_list.add_theme_color_override("selection_color", text_color("gold"))

static func apply_tab_container(tabs: TabContainer, tone: String = "ink") -> void:
	tabs.add_theme_stylebox_override("panel", panel_style(tone, 18))
	tabs.add_theme_stylebox_override("tab_selected", badge_style("gold"))
	tabs.add_theme_stylebox_override("tab_hovered", badge_style("teal"))
	tabs.add_theme_stylebox_override("tab_unselected", badge_style("ink"))
	tabs.add_theme_color_override("font_selected_color", TEXT_TONES["title"])
	tabs.add_theme_color_override("font_unselected_color", TEXT_TONES["muted"])
	tabs.add_theme_color_override("font_hovered_color", TEXT_TONES["body"])

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
