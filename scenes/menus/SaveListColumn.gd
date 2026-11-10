extends VBoxContainer
## The saved games, as one column in the setup screen's look
## (docs/skirmish-setup-screen.md): a card for each save with its hero, day,
## faction and difficulty, then the chosen save's name and its actions. A view
## only: the main menu hands it the state (show_saves) and acts on its signals.

signal save_chosen(key: String)
signal load_requested
signal delete_requested
signal name_edited(text: String)
signal name_applied
signal back_requested

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")

const THUMB_SIZE := Vector2(48.0, 60.0)
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)

var _cards: VBoxContainer
var _scroll: ScrollContainer
var _empty: Label
var _notice: Label
var _name_row: HBoxContainer
var _name_edit: LineEdit
var _name_button: Button
var _load_button: Button
var _delete_button: Button
var _back_button: Button
var _keys: Array = []

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_label(self, "Load game", "gold", 26)
	_empty = _label(self, "No saved games yet. Start a skirmish: the game keeps an autosave of each day, and you can save by hand at any time.", "muted", 14)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 6)
	_scroll.add_child(_cards)

	_notice = _label(self, "", "gold", 13)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 8)
	add_child(_name_row)
	_name_edit = LineEdit.new()
	_name_edit.name = "SaveColumnName"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.y = 32.0
	_name_edit.add_theme_font_size_override("font_size", 14)
	_name_edit.text_changed.connect(func(text: String): name_edited.emit(text))
	_name_edit.text_submitted.connect(func(_text: String): name_applied.emit())
	_name_row.add_child(_name_edit)
	_name_button = Button.new()
	VisualKit.apply_button(_name_button, "secondary", 120, 32, 14)
	_name_button.pressed.connect(func(): name_applied.emit())
	_name_row.add_child(_name_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	_load_button = Button.new()
	_load_button.name = "SaveColumnLoad"
	_load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualKit.apply_button(_load_button, "primary", 280, 44, 18)
	_load_button.pressed.connect(func(): load_requested.emit())
	actions.add_child(_load_button)
	_delete_button = Button.new()
	VisualKit.apply_button(_delete_button, "danger", 128, 44, 14)
	_delete_button.pressed.connect(func(): delete_requested.emit())
	actions.add_child(_delete_button)
	_back_button = Button.new()
	_back_button.name = "SaveColumnBack"
	_back_button.text = "Back"
	_back_button.tooltip_text = "Return to the main menu."
	VisualKit.apply_button(_back_button, "secondary", 90, 44, 14)
	_back_button.pressed.connect(func(): back_requested.emit())
	actions.add_child(_back_button)

## The control a newly opened save menu focuses.
func entry_control() -> Control:
	return _load_button if not _load_button.disabled else _back_button

## state: saves ([{key, title, line, sub, hero_id, latest, tooltip}]) with
## selected (a key); notice; name ({visible, text, placeholder, tooltip,
## button, button_disabled}); load and delete ({text, disabled, tooltip}, delete
## also visible).
func show_saves(state: Dictionary) -> void:
	var saves: Array = state.get("saves", [])
	var keys := saves.map(func(save): return "%s|%s|%s|%s" % [save.get("key", ""), save.get("title", ""), save.get("line", ""), save.get("sub", "")])
	if keys != _keys:
		_keys = keys
		for child in _cards.get_children():
			_cards.remove_child(child)
			child.queue_free()
		for save in saves:
			_cards.add_child(_card(save))
	for card in _cards.get_children():
		card.set_pressed_no_signal(String(card.get_meta("key")) == String(state.get("selected", "")))
	_empty.visible = saves.is_empty()
	_scroll.visible = not saves.is_empty()
	_notice.text = String(state.get("notice", ""))
	_notice.visible = _notice.text != ""
	var name: Dictionary = state.get("name", {})
	_name_row.visible = bool(name.get("visible", false))
	if _name_edit.text != String(name.get("text", "")) and not _name_edit.has_focus():
		_name_edit.text = String(name.get("text", ""))
	_name_edit.placeholder_text = String(name.get("placeholder", ""))
	_name_edit.tooltip_text = String(name.get("tooltip", ""))
	_name_button.text = String(name.get("button", "Save name"))
	_name_button.disabled = bool(name.get("button_disabled", true))
	var load: Dictionary = state.get("load", {})
	_load_button.text = String(load.get("text", "Load game"))
	_load_button.disabled = bool(load.get("disabled", true))
	_load_button.tooltip_text = String(load.get("tooltip", ""))
	var delete: Dictionary = state.get("delete", {})
	_delete_button.text = String(delete.get("text", "Delete"))
	_delete_button.visible = bool(delete.get("visible", false))
	_delete_button.disabled = bool(delete.get("disabled", true))
	_delete_button.tooltip_text = String(delete.get("tooltip", ""))

func _card(save: Dictionary) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size.y = THUMB_SIZE.y + 16.0
	card.set_meta("key", String(save.get("key", "")))
	card.tooltip_text = String(save.get("tooltip", ""))
	var idle := _outline(GOLD_DIM, 1, Color(0.10, 0.085, 0.07, 0.92))
	var hover := _outline(GOLD, 1, Color(0.17, 0.14, 0.10, 0.96))
	var chosen := _outline(GOLD, 2, Color(0.22, 0.17, 0.10, 0.96))
	card.add_theme_stylebox_override("normal", idle)
	card.add_theme_stylebox_override("hover", hover)
	for state in ["pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(state, chosen)
	card.add_theme_stylebox_override("focus", _outline(Color(1.0, 0.93, 0.70), 2, Color(0, 0, 0, 0)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = THUMB_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := _outline(Color(0.76, 0.60, 0.30), 1, Color(0.30, 0.27, 0.23))
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	row.add_child(frame)
	var path := String(ContentService.get_hero_art(String(save.get("hero_id", ""))).get("portrait", ""))
	if path != "" and ResourceLoader.exists(path, "Texture2D"):
		var face := TextureRect.new()
		face.texture = load(path) as Texture2D
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(head)
	var title := _label(head, String(save.get("title", "Save")), "gold", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	if bool(save.get("latest", false)):
		_label(head, "Latest", "green", 12)
	_label(text, String(save.get("line", "")), "body", 13).clip_text = true
	_label(text, String(save.get("sub", "")), "muted", 12).clip_text = true
	card.pressed.connect(func():
		card.set_pressed_no_signal(true)
		save_chosen.emit(String(save.get("key", ""))))
	return card

func _outline(border: Color, width: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.anti_aliasing = true
	return style

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VisualKit.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label
