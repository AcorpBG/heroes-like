extends VBoxContainer
## The settings, as one column in the setup screen's look
## (docs/skirmish-setup-screen.md): sections of rows, each setting a row of pills
## with the chosen one in gold, the volumes as sliders, and the actions at the
## foot. A view only: the main menu hands it the state (show_settings) and acts
## on its signals.

signal option_chosen(key: String, id: String)
signal toggle_changed(key: String, on: bool)
## dragging: the slider is held; the value is a preview until it is let go.
signal volume_changed(key: String, value: float, dragging: bool)
signal action_requested(key: String)
signal back_requested

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")

const ROW_LABEL_WIDTH := 138.0
const PILL_HEIGHT := 27.0
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const PILL_FILL := Color(0.10, 0.085, 0.07, 0.92)
const PILL_HOVER := Color(0.17, 0.14, 0.10, 0.96)
const INK := Color(0.11, 0.08, 0.04)
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)

var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _actions: HBoxContainer
var _back_button: Button
# key -> {kind, shell, ids}; a row is rebuilt only when what it offers changes.
var _rows := {}
var _layout_key := ""
var _dragging := {}

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_title = _label(self, "Settings", "gold", 26)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 5)
	_scroll.add_child(_body)
	_status = _label(self, "", "muted", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	add_child(_actions)

## The control a newly opened settings menu focuses: the first setting's choice.
func entry_control() -> Control:
	for key in _rows:
		var target := focus_target(key)
		if target != null:
			return target
	return _back_button

## The control that stands for a setting or an action: its chosen pill, its
## slider or its button.
func focus_target(key: String) -> Control:
	if _rows.has(key):
		var entry: Dictionary = _rows[key]
		if entry.kind == "volume":
			return entry.slider
		var first: Control = null
		for pill in entry.shell.get_children():
			if pill is Button:
				if first == null:
					first = pill
				if pill.button_pressed:
					return pill
		return first
	for button in _actions.get_children():
		if button is Button and String(button.get_meta("key", "")) == key:
			return button
	return null

func ensure_visible(control: Control) -> void:
	if control != null and _scroll.is_ancestor_of(control):
		_scroll.ensure_control_visible(control)

## state: sections ([{title, rows}]); a row is {kind, key, label, tooltip} with,
## by kind, "choice": options ([{id, label}]) and selected; "switch": on;
## "volume": value (0 to 100); "button": text. status; actions ([{key, text,
## tooltip, role}]); theme (the contrast and colour cue modes: the column is
## rebuilt when they change, as its colours do).
func show_settings(state: Dictionary) -> void:
	var sections: Array = state.get("sections", [])
	var layout_key := "%s|%s" % [String(state.get("theme", "")), str(sections.map(func(section): return [section.get("title", ""), section.get("rows", []).map(func(row): return row.get("key", ""))]))]
	if layout_key != _layout_key:
		_layout_key = layout_key
		_build(sections)
		# The frame's own texts and buttons take the new colours too.
		VisualKit.apply_label(_title, "gold", 26)
		VisualKit.apply_label(_status, "muted", 12)
		for child in _actions.get_children():
			_actions.remove_child(child)
			child.queue_free()
		_back_button = null
	for section in sections:
		for row in section.get("rows", []):
			_sync_row(row)
	_status.text = String(state.get("status", ""))
	_status.tooltip_text = "%s\n%s" % [_status.text, String(state.get("status_tooltip", ""))]
	_sync_actions(state.get("actions", []))

func _build(sections: Array) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_rows.clear()
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		if index > 0:
			var gap := Control.new()
			gap.custom_minimum_size.y = 2.0
			_body.add_child(gap)
			var line := ColorRect.new()
			line.color = HAIRLINE
			line.custom_minimum_size.y = 1.0
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_body.add_child(line)
		_label(_body, String(section.get("title", "")), "gold", 17)
		for row in section.get("rows", []):
			_build_row(row)

func _build_row(row: Dictionary) -> void:
	var key := String(row.get("key", ""))
	var kind := String(row.get("kind", "choice"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	_body.add_child(line)
	var label := _label(line, String(row.get("label", key)), "muted", 13)
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, PILL_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	var entry := {"kind": kind, "ids": [], "label": label}
	if kind == "volume":
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size = Vector2(160.0, PILL_HEIGHT)
		line.add_child(slider)
		var percent := _label(line, "", "body", 13)
		percent.custom_minimum_size.x = 44.0
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.drag_started.connect(func(): _dragging[key] = true)
		slider.drag_ended.connect(func(_changed: bool):
			_dragging.erase(key)
			volume_changed.emit(key, slider.value, false))
		slider.value_changed.connect(func(value: float):
			percent.text = "%d%%" % int(round(value))
			volume_changed.emit(key, value, _dragging.has(key)))
		# A slider hidden while held gets no drag_ended: its value is kept then.
		slider.visibility_changed.connect(func():
			if _dragging.has(key) and not slider.is_visible_in_tree():
				_dragging.erase(key)
				volume_changed.emit(key, slider.value, false))
		entry.slider = slider
		entry.percent = percent
		entry.shell = line
	else:
		var choices := HFlowContainer.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_theme_constant_override("h_separation", 6)
		choices.add_theme_constant_override("v_separation", 5)
		line.add_child(choices)
		entry.shell = choices
	_rows[key] = entry

func _sync_row(row: Dictionary) -> void:
	var key := String(row.get("key", ""))
	if not _rows.has(key):
		return
	var entry: Dictionary = _rows[key]
	var tooltip := String(row.get("tooltip", ""))
	(entry.label as Label).tooltip_text = tooltip
	match String(entry.kind):
		"volume":
			var slider: HSlider = entry.slider
			slider.tooltip_text = tooltip
			if not _dragging.has(key):
				slider.set_value_no_signal(float(row.get("value", 0.0)))
				(entry.percent as Label).text = "%d%%" % int(round(slider.value))
		"switch":
			_sync_pills(entry, key, [{"id": "on", "label": "On"}, {"id": "off", "label": "Off"}], "on" if bool(row.get("on", false)) else "off", tooltip, true)
		"button":
			_sync_pills(entry, key, [{"id": "", "label": String(row.get("text", ""))}], "-", tooltip, false)
		_:
			_sync_pills(entry, key, row.get("options", []), String(row.get("selected", "")), tooltip, true)

func _sync_pills(entry: Dictionary, key: String, options: Array, selected: String, tooltip: String, toggles: bool) -> void:
	var flow: Container = entry.shell
	var ids := options.map(func(option): return "%s|%s" % [String(option.get("id", "")), String(option.get("label", ""))])
	if ids != entry.ids:
		entry.ids = ids
		# The focused pill keeps the focus through a rebuild of its row.
		var focused := ""
		var had_focus := false
		for child in flow.get_children():
			if child.has_focus():
				had_focus = true
				focused = String(child.get_meta("id", ""))
			flow.remove_child(child)
			child.queue_free()
		for option in options:
			var pill := _pill(String(option.get("label", "")), toggles)
			pill.set_meta("id", String(option.get("id", "")))
			pill.pressed.connect(_on_pill_pressed.bind(key, pill, String(entry.kind)))
			flow.add_child(pill)
			if had_focus and String(option.get("id", "")) == focused:
				pill.grab_focus.call_deferred()
	for pill in flow.get_children():
		pill.tooltip_text = tooltip
		if toggles:
			pill.set_pressed_no_signal(String(pill.get_meta("id")) == selected)

func _on_pill_pressed(key: String, pill: Button, kind: String) -> void:
	match kind:
		"button":
			action_requested.emit(key)
		"switch":
			pill.set_pressed_no_signal(true)
			toggle_changed.emit(key, String(pill.get_meta("id")) == "on")
		_:
			# A chosen pill stays chosen when pressed again.
			pill.set_pressed_no_signal(true)
			option_chosen.emit(key, String(pill.get_meta("id")))

func _sync_actions(actions: Array) -> void:
	var keys := actions.map(func(action): return String(action.get("key", "")))
	var have := []
	for button in _actions.get_children():
		if button is Button and button != _back_button:
			have.append(String(button.get_meta("key", "")))
	if keys != have or _back_button == null:
		for child in _actions.get_children():
			_actions.remove_child(child)
			child.queue_free()
		for action in actions:
			var button := Button.new()
			button.set_meta("key", String(action.get("key", "")))
			button.name = "Settings%s" % String(action.get("key", "")).to_pascal_case()
			VisualKit.apply_button(button, String(action.get("role", "secondary")), 150, 40, 14)
			button.pressed.connect(func(): action_requested.emit(String(button.get_meta("key"))))
			_actions.add_child(button)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions.add_child(spacer)
		_back_button = Button.new()
		_back_button.name = "SettingsBack"
		_back_button.text = "Back"
		_back_button.tooltip_text = "Return to the main menu. Changes are already saved."
		VisualKit.apply_button(_back_button, "primary", 140, 40, 16)
		_back_button.pressed.connect(func(): back_requested.emit())
		_actions.add_child(_back_button)
	for action in actions:
		for button in _actions.get_children():
			if button is Button and String(button.get_meta("key", "")) == String(action.get("key", "")):
				button.text = String(action.get("text", ""))
				button.tooltip_text = String(action.get("tooltip", ""))

func _pill(text: String, toggles: bool) -> Button:
	var pill := Button.new()
	pill.text = text
	pill.toggle_mode = toggles
	pill.custom_minimum_size.y = PILL_HEIGHT
	pill.add_theme_font_size_override("font_size", 13)
	var idle := _outline(GOLD_DIM, 1, PILL_FILL)
	var hover := _outline(GOLD, 1, PILL_HOVER)
	var chosen := _outline(GOLD, 1, GOLD)
	for style in [idle, hover, chosen]:
		style.content_margin_left = 11.0
		style.content_margin_right = 11.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override("normal", idle)
	pill.add_theme_stylebox_override("hover", hover)
	pill.add_theme_stylebox_override("disabled", idle)
	for state in ["pressed", "hover_pressed"]:
		pill.add_theme_stylebox_override(state, chosen if toggles else hover)
	pill.add_theme_stylebox_override("focus", _outline(Color(1.0, 0.93, 0.70), 2, Color(0, 0, 0, 0)))
	pill.add_theme_color_override("font_color", VisualKit.text_color("body"))
	pill.add_theme_color_override("font_hover_color", VisualKit.text_color("gold"))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		pill.add_theme_color_override(state, INK if toggles else VisualKit.text_color("gold"))
	return pill

func _outline(border: Color, width: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.anti_aliasing = true
	return style

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	VisualKit.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label
