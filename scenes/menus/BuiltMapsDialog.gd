extends ConfirmationDialog
## The maps built earlier, to play one again (docs/skirmish-setup-screen.md):
## each as a small picture of its ground and towns, and the chosen one large,
## with who plays it. A view only: the main menu fills it and acts on its signals.

signal map_selected(scenario_id: String)
signal play_requested(scenario_id: String)

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
const Preview := preload("res://scripts/ui/MapPackagePreview.gd")
const ControlFlag := preload("res://scenes/overworld/OverworldControlFlag.gd")

const LIST_WIDTH := 330.0
const PICTURE_EDGE := 300.0
const THUMB_EDGE := 64.0
const HERO_SIZE := Vector2(48.0, 60.0)
const SEAT_CREST := 44.0
const CARD_CREST := 22.0
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)
const SIZE_NAMES := {36: "Small", 72: "Medium", 108: "Large", 144: "Extra Large"}
const WATER_NAMES := {"land": "Land", "normal_water": "Normal water", "islands": "Islands"}

## A level of a built map: its picture with the towns marked, start towns in
## their player's colour. Always square, whatever it is given to draw.
class MapPicture extends Control:
	const BACKING := Color("0c1113")
	const FRAME := Color(0.76, 0.60, 0.30)
	const OUTLINE := Color(0.03, 0.03, 0.03, 0.95)
	var _texture: Texture2D = null
	var _towns: Array = []
	var _map_size := Vector2i.ONE
	var _large := true

	func _init(edge: float, large: bool) -> void:
		_large = large
		custom_minimum_size = Vector2(edge, edge)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_level(preview: Dictionary, level: int) -> void:
		var levels: Array = preview.get("levels", [])
		_texture = levels[level] if level < levels.size() else null
		_map_size = preview.get("size", Vector2i.ONE)
		_towns = preview.get("towns", []).filter(func(town): return int(town.level) == level)
		queue_redraw()

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, BACKING)
		if _texture != null:
			var scale := minf(size.x / _map_size.x, size.y / _map_size.y)
			var field := Rect2((size - Vector2(_map_size) * scale) * 0.5, Vector2(_map_size) * scale)
			draw_texture_rect(_texture, field, false)
			for town in _towns:
				var start := bool(town.start)
				if not start and not _large:
					continue
				var slot := int(town.slot)
				var color: Color = ControlFlag.SLOT_COLORS[slot - 1] if slot >= 1 and slot <= ControlFlag.SLOT_COLORS.size() else ControlFlag.NEUTRAL
				var half := (6.0 if start else 3.5) if _large else 3.0
				var center := field.position + (Vector2(town.tile) + Vector2(0.5, 0.5)) * scale
				var mark := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
				draw_rect(mark.grow(1.5), OUTLINE)
				draw_rect(mark, color)
				if start and _large:
					draw_rect(mark.grow(1.5), Color(1.0, 0.93, 0.70), false, 1.0)
		draw_rect(area, FRAME, false, 1.0)

var _count: Label
var _cards: VBoxContainer
var _name: Label
var _pictures: Array = []
var _captions: Array = []
var _picture_boxes: Array = []
var _seats: HBoxContainer
var _chips: HFlowContainer
var _seed: Label
var _entries: Array = []
var _selected_id := ""
var _pending: Array = []
var _frames_open := 0

func _ready() -> void:
	title = ""
	borderless = true
	exclusive = true
	dialog_hide_on_ok = false
	add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	add_theme_constant_override("buttons_min_width", 120)
	add_theme_constant_override("buttons_min_height", 32)
	set_process(false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_label(head, "Built maps", "gold", 20)
	_count = _label(head, "", "muted", 13)
	_count.size_flags_vertical = Control.SIZE_SHRINK_END

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = LIST_WIDTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 6)
	scroll.add_child(_cards)
	var line := ColorRect.new()
	line.color = HAIRLINE
	line.custom_minimum_size.x = 1.0
	body.add_child(line)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	body.add_child(detail)
	_name = _label(detail, "", "gold", 24)
	var pictures := HBoxContainer.new()
	pictures.add_theme_constant_override("separation", 14)
	pictures.custom_minimum_size.x = PICTURE_EDGE * 2.0 + 14.0
	detail.add_child(pictures)
	for caption in ["Surface", "Underground"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		pictures.add_child(column)
		var picture := MapPicture.new(PICTURE_EDGE, true)
		column.add_child(picture)
		_pictures.append(picture)
		_captions.append(_label(column, caption, "muted", 12))
		_picture_boxes.append(column)
	_seats = HBoxContainer.new()
	_seats.add_theme_constant_override("separation", 10)
	_seats.custom_minimum_size.y = HERO_SIZE.y
	detail.add_child(_seats)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 6)
	_chips.add_theme_constant_override("v_separation", 5)
	# Room for two rows, so the window keeps its height from map to map.
	_chips.custom_minimum_size.y = 61.0
	detail.add_child(_chips)
	_seed = _label(detail, "", "muted", 12)

	get_ok_button().text = "Play"
	get_cancel_button().text = "Close"
	confirmed.connect(func():
		if _selected_id != "":
			play_requested.emit(_selected_id))
	canceled.connect(func(): VisualKit.hide_exclusive_dialog(self))

## entries: the built maps as the rules list them; selected_id is the one shown
## as chosen. The newest map comes first.
func open_maps(entries: Array, selected_id: String) -> void:
	add_theme_stylebox_override("panel", VisualKit.info_card_style())
	VisualKit.apply_button(get_ok_button(), "primary", 120, 32)
	VisualKit.apply_button(get_cancel_button(), "secondary", 120, 32)
	_entries = entries.duplicate()
	_entries.sort_custom(func(a, b): return _built_time(a) > _built_time(b))
	_count.text = "%d map%s" % [_entries.size(), "" if _entries.size() == 1 else "s"]
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for entry in _entries:
		_cards.add_child(_card(entry))
	_selected_id = selected_id
	if _entry(selected_id).is_empty() and not _entries.is_empty():
		_selected_id = String(_entries[0].get("scenario_id", ""))
	# The chosen map's picture is read first, then the rest, one each frame.
	_pending = _entries.filter(func(entry): return not Preview.has_preview(entry))
	for index in range(_pending.size()):
		if String(_pending[index].get("scenario_id", "")) == _selected_id:
			_pending.push_front(_pending.pop_at(index))
	_frames_open = 0
	set_process(not _pending.is_empty())
	_show_selected()
	reset_size()
	popup_centered()
	for card in _cards.get_children():
		if String(card.get_meta("id")) == _selected_id:
			card.grab_focus()

## Whether the chosen map can be played now, and why not.
func set_playable(playable: bool, reason: String) -> void:
	get_ok_button().disabled = not playable or _selected_id == ""
	get_ok_button().tooltip_text = reason

func _process(_delta: float) -> void:
	if not visible or _pending.is_empty():
		set_process(false)
		return
	# The window is drawn before the first package is read.
	_frames_open += 1
	if _frames_open < 3:
		return
	Preview.build(_pending.pop_front())
	_show_pictures()

func _select(scenario_id: String) -> void:
	if _entry(scenario_id).is_empty():
		return
	_selected_id = scenario_id
	_show_selected()
	map_selected.emit(scenario_id)

func _show_selected() -> void:
	for card in _cards.get_children():
		card.set_pressed_no_signal(String(card.get_meta("id")) == _selected_id)
	var entry := _entry(_selected_id)
	_name.text = String(entry.get("display_name", ""))
	var levels := int(entry.get("map_size", {}).get("level_count", 1))
	_picture_boxes[1].visible = levels > 1
	_captions[0].visible = levels > 1
	_clear(_seats)
	_clear(_chips)
	if entry.is_empty():
		_seed.text = ""
		_show_pictures()
		return
	var metadata: Dictionary = entry.get("metadata", {})
	var config: Dictionary = metadata.get("normalized_config", {})
	var hero_id := String(metadata.get("runtime_player_setup", {}).get("hero_id", ""))
	var hero := ContentService.get_hero(hero_id) if hero_id != "" else {}
	var factions := _seat_factions(entry)
	if not hero.is_empty():
		var frame := PanelContainer.new()
		frame.custom_minimum_size = HERO_SIZE
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame_style := _outline(Color(0.76, 0.60, 0.30), 1, 4, Color(0.30, 0.27, 0.23))
		frame_style.set_content_margin_all(2)
		frame.add_theme_stylebox_override("panel", frame_style)
		frame.add_child(_picture(String(ContentService.get_hero_art(hero_id).get("portrait", "")), true))
		frame.tooltip_text = "Your commander: %s" % String(hero.get("name", hero_id))
		_seats.add_child(frame)
	for index in range(factions.size()):
		if index == 1:
			var versus := _label(_seats, "vs", "muted", 13)
			versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_seats.add_child(_seat_crest(String(factions[index]), index + 1, SEAT_CREST, index == 0))
	var width := int(entry.get("map_size", {}).get("width", 0))
	_chip("%s %d" % [String(SIZE_NAMES[width]), width] if SIZE_NAMES.has(width) else "%d x %d" % [width, int(entry.get("map_size", {}).get("height", 0))])
	_chip("%d players" % int(entry.get("player_count", factions.size())))
	_chip("Surface + underground" if levels > 1 else "Surface")
	var water := String(config.get("water_mode", ""))
	if water != "":
		_chip(String(WATER_NAMES.get(water, water.capitalize())))
	var monsters := String(config.get("monster_strength", ""))
	if monsters != "":
		_chip("%s monsters" % monsters.capitalize())
	var towns := int(metadata.get("component_counts", {}).get("town_count", 0))
	if towns > 0:
		_chip("%d towns" % towns)
	var seed := str(config.get("seed", ""))
	_seed.text = "Seed %s" % seed if seed != "" else ""
	_show_pictures()

## Hands every picture what has been read of its map so far.
func _show_pictures() -> void:
	for card in _cards.get_children():
		(card.get_meta("picture") as MapPicture).show_level(Preview.cached(_entry(String(card.get_meta("id")))), 0)
	var preview := Preview.cached(_entry(_selected_id))
	for level in range(_pictures.size()):
		(_pictures[level] as MapPicture).show_level(preview, level)

func _card(entry: Dictionary) -> Button:
	var scenario_id := String(entry.get("scenario_id", ""))
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size.y = THUMB_EDGE + 16.0
	card.set_meta("id", scenario_id)
	card.add_theme_stylebox_override("normal", _outline(GOLD_DIM, 1, 6, Color(0.10, 0.085, 0.07, 0.92)))
	card.add_theme_stylebox_override("hover", _outline(GOLD, 1, 6, Color(0.17, 0.14, 0.10, 0.96)))
	for state in ["pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(state, _outline(GOLD, 2, 6, Color(0.22, 0.17, 0.10, 0.96)))
	card.add_theme_stylebox_override("focus", _outline(Color(1.0, 0.93, 0.70), 2, 6, Color(0, 0, 0, 0)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var picture := MapPicture.new(THUMB_EDGE, false)
	row.add_child(picture)
	card.set_meta("picture", picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := _label(text, String(entry.get("display_name", scenario_id)), "gold", 16)
	title.clip_text = true
	var crests := HBoxContainer.new()
	crests.add_theme_constant_override("separation", 4)
	crests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(crests)
	var factions := _seat_factions(entry)
	for index in range(factions.size()):
		var crest := _seat_crest(String(factions[index]), index + 1, CARD_CREST, false)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crests.add_child(crest)
	var width := int(entry.get("map_size", {}).get("width", 0))
	var size_tag := _label(crests, String(SIZE_NAMES.get(width, "%d" % width)), "muted", 12)
	size_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.pressed.connect(func():
		card.set_pressed_no_signal(true)
		_select(scenario_id))
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT and not get_ok_button().disabled:
			play_requested.emit(scenario_id))
	return card

## A seat's faction crest in a ring of the seat's colour, the colour its start
## town has on the picture.
func _seat_crest(faction_id: String, slot: int, edge: float, yours: bool) -> Control:
	var ring := PanelContainer.new()
	ring.custom_minimum_size = Vector2(edge, edge)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color: Color = ControlFlag.SLOT_COLORS[slot - 1] if slot >= 1 and slot <= ControlFlag.SLOT_COLORS.size() else ControlFlag.NEUTRAL
	var style := _outline(color, 2 if edge >= 32.0 else 1, int(edge / 2.0), Color(0.06, 0.05, 0.04, 0.85))
	style.set_content_margin_all(3 if edge >= 32.0 else 2)
	ring.add_theme_stylebox_override("panel", style)
	var faction := ContentService.get_faction(faction_id)
	var crest_path := String(ContentService.get_faction_crest(faction_id).get("icon_path", ""))
	if crest_path != "" and ResourceLoader.exists(crest_path, "Texture2D"):
		ring.add_child(_picture(crest_path, false))
	else:
		var unknown := _label(ring, "?", "gold", int(edge * 0.5))
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring.tooltip_text = "%s: %s" % ["You" if yours else "Player %d" % slot, String(faction.get("name", "Unknown faction"))]
	return ring

func _chip(text: String) -> void:
	var chip := PanelContainer.new()
	var style := _outline(GOLD_DIM, 1, 7, Color(0.10, 0.085, 0.07, 0.92))
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", style)
	_label(chip, text, "body", 13)
	_chips.add_child(chip)

## The factions of the seats, yours first, as the map was built.
func _seat_factions(entry: Dictionary) -> Array:
	var config: Dictionary = entry.get("metadata", {}).get("normalized_config", {})
	var factions = config.get("seat_faction_ids")
	if not (factions is Array) or factions.is_empty():
		factions = config.get("faction_ids", [])
	var seats: Array = factions.duplicate() if factions is Array else []
	seats.resize(int(entry.get("player_count", seats.size())))
	return seats.map(func(faction): return String(faction) if faction != null else "")

func _entry(scenario_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("scenario_id", "")) == scenario_id:
			return entry
	return {}

func _built_time(entry: Dictionary) -> int:
	return int(entry.get("map_file_identity", {}).get("modified_time", 0))

func _picture(path: String, cover: bool) -> TextureRect:
	var picture := TextureRect.new()
	if path != "" and ResourceLoader.exists(path, "Texture2D"):
		picture.texture = load(path) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _outline(border: Color, width: int, radius: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VisualKit.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
