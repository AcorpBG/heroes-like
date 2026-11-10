extends AcceptDialog

const UnitPortraits := preload("res://scripts/ui/UnitPortraitTexture.gd")

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
# The description's tone of a status line, as a text tone of the visual kit.
const TONES := {"ready": "gold", "used": "muted", "guarded": "red", "hostile": "red", "yours": "green", "neutral": "gold", "plain": "body"}
# The card (docs/overworld-info-card.md): the sidebar's dark lacquer and thin
# gold border, only as tall as what it says.
const CARD_WIDTH := 440
const ICON_SIZE := 56
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)
# Lighter than the card, so a dark-cloaked unit keeps its outline.
const ICON_BACKING := Color(0.30, 0.27, 0.23, 1.0)
const ICON_BORDER := Color(0.76, 0.60, 0.30, 1.0)
var snapshot: Dictionary = {}
var _content: VBoxContainer
var _scroll: ScrollContainer
# Mouse button that keeps a held report open; MOUSE_BUTTON_NONE for the normal
# dialog that waits for "Return to map".
var held_button := MOUSE_BUTTON_NONE

func _ready() -> void:
	title = ""
	# The card is its own frame: no title bar or close button around it.
	borderless = true
	dialog_hide_on_ok = false
	confirmed.connect(func(): VisualKit.hide_exclusive_dialog(self))
	canceled.connect(func(): VisualKit.hide_exclusive_dialog(self))
	visibility_changed.connect(func(): if not visible: _end_hold())
	window_input.connect(_on_window_input)
	set_process(false)
	_apply_visual_theme()
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)

func _apply_visual_theme() -> void:
	get_ok_button().text = "Return to map"
	VisualKit.apply_button(get_ok_button(), "primary", 140, 32)
	var frame := VisualKit.info_card_style()
	add_theme_stylebox_override("panel", frame)
	add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())

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
	_add_label(String(report.get("title", "Scout report")), "gold", 20)
	var kind_line := String(report.get("subtitle", ""))
	var ground := String(report.get("terrain", "Unknown"))
	if kind != "ground" and kind != "unscouted" and ground != "Unknown":
		kind_line = "On %s" % ground.to_lower() if kind_line == "" else "%s · on %s" % [kind_line, ground.to_lower()]
	if kind_line != "":
		_add_label(kind_line, "muted", 13)
	# A flavour line that already states what the building gives says it once.
	var gives := String(report.get("gives", ""))
	var flavour := String(report.get("flavour", ""))
	var status := String(report.get("status", ""))
	var marks: Array = report.get("marks", []) if report.get("marks", []) is Array else []
	var says_what := gives != "" and not flavour.to_lower().contains(gives.to_lower())
	if says_what or status != "" or flavour != "" or not marks.is_empty():
		_add_hairline()
	if says_what:
		_add_label(gives, "body", 14)
	for choice in report.get("choices", []):
		_add_label("  %s" % String(choice), "body", 13)
	if status != "":
		_add_label(status, String(TONES.get(String(report.get("tone", "plain")), "body")), 14)
	if flavour != "":
		_add_label(flavour, "muted", 13)
	for mark in marks:
		_add_label(String(mark), "muted", 13)
	var guard: Dictionary = report.get("guard", {}) if report.get("guard", {}) is Dictionary else {}
	if not guard.is_empty() and kind != "army":
		_add_hairline()
		_add_label(String(guard.get("name", "Guard")), "gold", 15)
		if String(guard.get("troops", "")) != "":
			_add_label(String(guard.get("troops", "")), "muted", 13)
	for stack in report.get("stacks", []):
		_add_stack_row(stack)
	if not guard.is_empty():
		var battle: Array = []
		if kind != "army" and String(guard.get("reward", "")) != "":
			battle.append("Victory brings %s" % guard.get("reward", ""))
		if String(guard.get("battlefield", "")) != "":
			battle.append("Battlefield: %s" % guard.get("battlefield", ""))
		if not battle.is_empty():
			_add_hairline()
			_add_label(" · ".join(battle), "muted", 13)
	# Only as tall as what it says, up to the screen.
	var frame := VisualKit.info_card_style()
	var chrome := frame.get_minimum_size().y + (56.0 if get_ok_button().visible else 0.0)
	var wanted := _content.get_combined_minimum_size().y
	var height := minf(wanted + chrome, viewport_size.y - 100.0)
	_scroll.custom_minimum_size = Vector2(0.0, maxf(0.0, height - chrome))
	popup_centered(Vector2i(int(minf(CARD_WIDTH, viewport_size.x - 48)), int(height)))
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

func _content_width() -> float:
	return float(CARD_WIDTH) - VisualKit.info_card_style().get_minimum_size().x

func _add_label(text: String, tone: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A wrapped label needs its width to know its height.
	label.custom_minimum_size.x = _content_width()
	VisualKit.apply_label(label, tone, font_size)
	_content.add_child(label)

func _add_hairline() -> void:
	var line := ColorRect.new()
	line.color = HAIRLINE
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(line)

## One stack of another side's army: its icon in a framed tile, its name and its
## size band's word (owner decision, 2026-11-10: neither the count nor the
## band's range is told; intelligence may sharpen this later).
func _add_stack_row(stack: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = ICON_BACKING
	tile_style.border_color = ICON_BORDER
	tile_style.set_border_width_all(2)
	tile_style.set_corner_radius_all(5)
	tile_style.set_content_margin_all(3)
	tile.add_theme_stylebox_override("panel", tile_style)
	row.add_child(tile)
	var unit_texture := UnitPortraits.bust_for_unit(String(stack.get("unit_id", "")))
	if unit_texture != null:
		var icon := TextureRect.new()
		icon.texture = unit_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tile.add_child(icon)
	var label := Label.new()
	label.text = "%s · %s" % [stack.get("name", "Unit"), stack.get("size", "")]
	label.tooltip_text = label.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	VisualKit.apply_label(label, "body", 16)
	row.add_child(label)
