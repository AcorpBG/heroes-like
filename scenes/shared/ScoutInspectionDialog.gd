extends AcceptDialog

const UnitPortraits := preload("res://scripts/ui/UnitPortraitTexture.gd")

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
# The description's tone of a status line, as a text tone of the visual kit.
const TONES := {"ready": "gold", "used": "muted", "guarded": "red", "hostile": "red", "yours": "green", "neutral": "gold", "plain": "body"}
var snapshot: Dictionary = {}
var _content: VBoxContainer
# Mouse button that keeps a held report open; MOUSE_BUTTON_NONE for the normal
# dialog that waits for "Return to map".
var held_button := MOUSE_BUTTON_NONE

func _ready() -> void:
	title = "Scout report"
	dialog_hide_on_ok = false
	confirmed.connect(func(): VisualKit.hide_exclusive_dialog(self))
	canceled.connect(func(): VisualKit.hide_exclusive_dialog(self))
	visibility_changed.connect(func(): if not visible: _end_hold())
	window_input.connect(_on_window_input)
	set_process(false)
	_apply_visual_theme()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", VisualKit.SPACE_NORMAL)
	scroll.add_child(_content)

func _apply_visual_theme() -> void:
	get_ok_button().text = "Return to map"
	VisualKit.apply_button(get_ok_button(), "primary", 140, 32)
	var frame := VisualKit.texture_panel_style(VisualKit.CONFIRMATION_DIALOG_FRAME_PATH, "ink", 32, 16)
	add_theme_stylebox_override("panel", frame)
	add_theme_stylebox_override("embedded_border", frame.duplicate())
	add_theme_color_override("title_color", VisualKit.text_color("gold"))

func open_report(report: Dictionary, viewport_size: Vector2, hold_button := MOUSE_BUTTON_NONE) -> void:
	_apply_visual_theme()
	held_button = hold_button
	get_ok_button().visible = held_button == MOUSE_BUTTON_NONE
	snapshot = report.duplicate(true)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	# The shared description of the tile (scripts/ui/OverworldInspection.gd): what
	# it is, what it gives, where it stands for the selected hero, then its guard.
	var kind := String(report.get("kind", ""))
	_add_label(String(report.get("title", "Scout report")), "gold", 18)
	var kind_line := String(report.get("subtitle", ""))
	var ground := String(report.get("terrain", "Unknown"))
	if kind != "ground" and kind != "unscouted" and ground != "Unknown":
		kind_line = "On %s" % ground.to_lower() if kind_line == "" else "%s · on %s" % [kind_line, ground.to_lower()]
	if kind_line != "":
		_add_label(kind_line, "muted", 13)
	# A flavour line that already states what the building gives says it once.
	var gives := String(report.get("gives", ""))
	var flavour := String(report.get("flavour", ""))
	if gives != "" and not flavour.to_lower().contains(gives.to_lower()):
		_add_label(gives, "body", 14)
	for choice in report.get("choices", []):
		_add_label("  %s" % String(choice), "body", 13)
	if String(report.get("status", "")) != "":
		_add_label(String(report.get("status", "")), String(TONES.get(String(report.get("tone", "plain")), "body")), 14)
	if String(report.get("flavour", "")) != "":
		_add_label(String(report.get("flavour", "")), "muted", 13)
	for mark in report.get("marks", []):
		_add_label(String(mark), "muted", 13)
	var guard: Dictionary = report.get("guard", {}) if report.get("guard", {}) is Dictionary else {}
	if not guard.is_empty() and kind != "army":
		_add_label(String(guard.get("name", "Guard")), "gold", 15)
		if String(guard.get("troops", "")) != "":
			_add_label(String(guard.get("troops", "")), "muted", 13)
	for stack in report.get("stacks", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_content.add_child(row)
		var unit_texture := UnitPortraits.for_unit(String(stack.get("unit_id", "")))
		if unit_texture != null:
			var icon := TextureRect.new()
			icon.texture = unit_texture
			icon.custom_minimum_size = Vector2(36, 36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var label := Label.new()
		label.text = "%s × %d" % [stack.get("name", "Unit"), stack.get("count", 0)]
		label.tooltip_text = label.text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		VisualKit.apply_label(label, "body", 14)
		row.add_child(label)
	if not guard.is_empty():
		var battle: Array = []
		if kind != "army" and String(guard.get("reward", "")) != "":
			battle.append("Victory brings %s" % guard.get("reward", ""))
		if String(guard.get("battlefield", "")) != "":
			battle.append("Battlefield: %s" % guard.get("battlefield", ""))
		if not battle.is_empty():
			_add_label(" · ".join(battle), "body", 13)
		if not (report.get("stacks", []) as Array).is_empty():
			_add_label("Strength is an estimate against the selected hero's army; abilities, spells and ground can change the outcome.", "muted", 12)
	popup_centered(Vector2i(minf(480, viewport_size.x - 48), minf(480, viewport_size.y - 100)))
	if held_button == MOUSE_BUTTON_NONE:
		get_ok_button().grab_focus()
		return
	set_process(true)
	# The button may already be up when the report opens (a very short click).
	_close_if_released()

func _process(_delta: float) -> void:
	_close_if_released()

func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == held_button and not event.pressed:
		_close_if_released()

# The release can land on the map, on this window or outside the game window,
# so the held report follows the button state rather than one release event.
func _close_if_released() -> void:
	if held_button == MOUSE_BUTTON_NONE or not visible: return
	if Input.is_mouse_button_pressed(held_button): return
	VisualKit.hide_exclusive_dialog(self)

func _end_hold() -> void:
	held_button = MOUSE_BUTTON_NONE
	set_process(false)

func _add_label(text: String, tone: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualKit.apply_label(label, tone, font_size)
	_content.add_child(label)
