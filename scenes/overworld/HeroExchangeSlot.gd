extends Button
## One cell of the hero meeting screen: an army slot, a worn or carried
## artifact, or a teachable spell. Clicks and drag & drop are delegated to the
## owning HeroExchangeScreen, which turns them into HeroCommandRules orders.

const FILL := Color(0.035, 0.05, 0.05, 0.96)
const HOVER_FILL := Color(0.08, 0.11, 0.10, 1.0)
const BORDER := Color(0.46, 0.37, 0.19, 1.0)
const HOVER_BORDER := Color(0.88, 0.68, 0.27, 1.0)
const SELECTED_BORDER := Color(1.0, 0.82, 0.34, 1.0)
const LEGAL_BORDER := Color(0.52, 0.80, 0.56, 1.0)

var screen: Control
var side := ""
var kind := ""
var key := ""
var item_id := ""
var art: TextureRect
var count_label: Label
var caption: Label
var _selected := false
var _legal := false

func setup(owner_screen: Control, cell_side: String, cell_kind: String, cell_key: String, cell_size: Vector2) -> void:
	screen = owner_screen
	side = cell_side
	kind = cell_kind
	key = cell_key
	name = "%s_%s_%s" % [side.capitalize(), kind.capitalize(), key]
	custom_minimum_size = cell_size
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	art = TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 3.0 if kind == "army" else 6.0
	art.offset_left = inset
	art.offset_top = inset
	art.offset_right = -inset
	art.offset_bottom = -inset
	add_child(art)
	caption = Label.new()
	caption.name = "Caption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.62, 0.60, 0.52, 0.85))
	add_child(caption)
	count_label = Label.new()
	count_label.name = "Count"
	count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.offset_right = -5.0
	count_label.offset_bottom = -1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	count_label.add_theme_constant_override("outline_size", 6)
	add_child(count_label)
	pressed.connect(func(): screen.press_cell(self, Input.is_key_pressed(KEY_SHIFT)))
	mouse_entered.connect(func(): screen.hover_cell(self))
	focus_entered.connect(func(): screen.hover_cell(self))
	_apply_styles()

## `texture` null shows an empty cell; `count` <= 0 hides the count badge.
func show_item(id: String, texture: Texture2D, count: int, empty_caption: String, tooltip: String) -> void:
	item_id = id
	art.texture = texture
	art.modulate = Color(1, 1, 1, 1)
	count_label.text = str(count) if count > 0 else ""
	caption.text = empty_caption if id == "" else ""
	tooltip_text = tooltip
	accessibility_name = tooltip

func set_marks(selected: bool, legal: bool) -> void:
	if selected == _selected and legal == _legal:
		return
	_selected = selected
	_legal = legal
	_apply_styles()

func is_marked_selected() -> bool:
	return _selected

func is_marked_legal() -> bool:
	return _legal

func _apply_styles() -> void:
	var border := SELECTED_BORDER if _selected else (LEGAL_BORDER if _legal else BORDER)
	var width := 3 if _selected else (2 if _legal else 1)
	add_theme_stylebox_override("normal", _style(FILL, border, width))
	add_theme_stylebox_override("hover", _style(HOVER_FILL, SELECTED_BORDER if _selected else HOVER_BORDER, maxi(width, 2)))
	add_theme_stylebox_override("pressed", _style(HOVER_FILL, SELECTED_BORDER, 3))
	add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), HOVER_BORDER, 2))
	add_theme_stylebox_override("disabled", _style(Color(0.025, 0.035, 0.034, 0.86), Color(0.25, 0.25, 0.22, 0.8), 1))

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or screen == null:
		return null
	var payload: Dictionary = screen.begin_cell_drag(self)
	if payload.is_empty():
		return null
	# A drag preview may only be set while the viewport is dragging.
	if get_viewport().gui_is_dragging():
		var preview := TextureRect.new()
		preview.texture = art.texture
		preview.custom_minimum_size = size * 0.9
		preview.size = size * 0.9
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.modulate = Color(1, 1, 1, 0.85)
		set_drag_preview(preview)
	return payload

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not disabled and screen != null and screen.can_drop_on_cell(self, data)

func _drop_data(_position: Vector2, data: Variant) -> void:
	screen.drop_on_cell(self, data, Input.is_key_pressed(KEY_SHIFT))
