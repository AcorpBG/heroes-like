extends PanelContainer
## Town screen army panel, HoMM style (docs/town-garrison-rows.md): the town's
## command squares (Build, Muster, Market, Mage Guild), then the garrison row
## (garrison hero portrait + seven slots) above the visiting row (the hero at
## the gate + seven slots). Clicks and drags become orders the Town screen sends
## to the rules; this panel never edits the session itself.

signal slot_order_requested(source_holder_id: String, source_slot: int, target_holder_id: String, target_slot: int, amount_token: String)
signal garrison_hero_requested(hero_id: String)
signal hero_sheet_requested(hero_id: String)

const CellScript = preload("res://scenes/overworld/HeroExchangeSlot.gd")
const SIDES := ["garrison", "visiting"]
const CELL_SIZE := Vector2(70, 70)
const GAP := 5
const COMMAND_EMBLEM_REGION := Rect2(18, 18, 92, 92)
const GOLD := Color(0.88, 0.70, 0.32)
const GOLD_DIM := Color(0.46, 0.37, 0.19)
const SELECTED := Color(1.0, 0.82, 0.34)
const FILL := Color(0.055, 0.065, 0.07, 1.0)
const CELL_FILL := Color(0.035, 0.05, 0.05, 0.96)
const MUTED := Color(0.62, 0.60, 0.52, 0.85)

var _command_grid: GridContainer
var _portraits := {}
var _cells := {}
var _state := {}
var _selection := {}
var _textures := {}
var _split: PanelContainer
var _split_slider: HSlider
var _split_label: Label
var _split_order := {}
var _last_refusal := ""

func _ready() -> void:
	add_theme_stylebox_override("panel", _box(FILL, GOLD_DIM, 2, 6, 8))
	var box := HBoxContainer.new()
	box.name = "ArmyPanelBox"
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_command_grid = GridContainer.new()
	_command_grid.name = "TownCommands"
	_command_grid.columns = 2
	_command_grid.add_theme_constant_override("h_separation", GAP)
	_command_grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(_command_grid)
	var rows := VBoxContainer.new()
	rows.name = "ArmyRows"
	rows.add_theme_constant_override("separation", GAP)
	box.add_child(rows)
	for side in SIDES:
		var row := HBoxContainer.new()
		row.name = "%sRow" % String(side).capitalize()
		row.add_theme_constant_override("separation", GAP)
		rows.add_child(row)
		row.add_child(_make_portrait(side))
		var cells := []
		for index in range(7):
			var cell = CellScript.new()
			cell.setup(self, side, "army", str(index), CELL_SIZE)
			cell.count_label.add_theme_font_size_override("font_size", 17)
			row.add_child(cell)
			cells.append(cell)
		_cells[side] = cells
	_build_split_popup()

## Moves the town's command buttons into the 2x2 command block as rounded
## squares the size of an army slot, cropped to their emblems so they read.
func set_command_buttons(buttons: Array) -> void:
	for button_value in buttons:
		var button := button_value as Button
		if button == null:
			continue
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
		_command_grid.add_child(button)
		button.custom_minimum_size = CELL_SIZE
		button.text = ""
		if button.icon is Texture2D and not (button.icon is AtlasTexture):
			var emblem := AtlasTexture.new()
			emblem.atlas = button.icon
			emblem.region = COMMAND_EMBLEM_REGION if button.icon.get_width() >= 128 else Rect2(Vector2.ZERO, button.icon.get_size())
			button.icon = emblem
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 60)
		_style_command_button(button)

func _style_command_button(button: Button) -> void:
	var normal := _box(Color(0.10, 0.09, 0.07, 1.0), GOLD, 2, 12, 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _box(Color(0.15, 0.12, 0.08, 1.0), SELECTED, 2, 12, 4))
	button.add_theme_stylebox_override("pressed", _box(Color(0.18, 0.14, 0.08, 1.0), SELECTED, 3, 12, 4))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), SELECTED, 2, 12, 4))
	button.add_theme_stylebox_override("disabled", _box(Color(0.05, 0.055, 0.055, 1.0), GOLD_DIM, 1, 12, 4))
	button.add_theme_color_override("icon_disabled_color", Color(0.55, 0.55, 0.55, 0.9))

## `state` holds one entry per side: holder_id ("" when nobody stands at the
## gate), hero_id, hero_name, portrait path and the seven slot snapshots.
func configure(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if not _selection_still_valid():
		_selection = {}
	for side in SIDES:
		var row: Dictionary = _state.get(side, {})
		_show_portrait(side, row)
		var slots: Array = row.get("slots", [])
		var cells: Array = _cells.get(side, [])
		for index in range(cells.size()):
			var cell = cells[index]
			var slot: Dictionary = slots[index] if index < slots.size() and slots[index] is Dictionary else {}
			cell.disabled = String(row.get("holder_id", "")) == ""
			if bool(slot.get("occupied", false)):
				cell.show_item(String(slot.get("unit_id", "")), _texture(String(slot.get("portrait", ""))), int(slot.get("count", 0)), "", "%s x%d\nClick, then click a slot to move, merge or swap. Shift splits." % [String(slot.get("unit_name", "")), int(slot.get("count", 0))])
			else:
				cell.show_item("", null, 0, "", "Empty slot")
	_sync_marks()

func clear_selection() -> void:
	_selection = {}
	_sync_marks()

## Escape closes the split slider, then the selection; true when it did.
func cancel_transient() -> bool:
	if _split != null and _split.visible:
		_cancel_split()
		return true
	if not _selection.is_empty():
		clear_selection()
		return true
	return false

func validation_snapshot() -> Dictionary:
	var rows := {}
	for side in SIDES:
		var row: Dictionary = _state.get(side, {})
		var occupied := 0
		for slot in row.get("slots", []):
			if slot is Dictionary and bool(slot.get("occupied", false)):
				occupied += 1
		rows[side] = {
			"holder_id": String(row.get("holder_id", "")),
			"hero_id": String(row.get("hero_id", "")),
			"occupied_slots": occupied,
			"cell_count": (_cells.get(side, []) as Array).size(),
			"portrait_visible": (_portraits.get(side) as Control).visible if _portraits.has(side) else false,
		}
	return {
		"model": "homm_town_garrison_visiting_rows",
		"rows": rows,
		"command_count": _command_grid.get_child_count(),
		"selection": _selection.duplicate(true),
		"last_refusal": _last_refusal,
		"visible": is_visible_in_tree(),
	}

func validation_press_slot(side: String, slot_index: int, shift: bool = false) -> void:
	var cells: Array = _cells.get(side, [])
	if slot_index >= 0 and slot_index < cells.size():
		press_cell(cells[slot_index], shift)

func validation_press_portrait(side: String, double_click: bool = false) -> void:
	_portrait_pressed(side, double_click)

func validation_confirm_split(count: int) -> void:
	_split_slider.value = count
	_confirm_split()

# --- HeroExchangeSlot owner protocol ----------------------------------------

func press_cell(cell, shift: bool) -> void:
	var side := String(cell.side)
	var slot_index := int(cell.key)
	var row: Dictionary = _state.get(side, {})
	if String(row.get("holder_id", "")) == "":
		return
	if _selection.has("slot"):
		var from_side := String(_selection.get("side", ""))
		var from_slot := int(_selection.get("slot", -1))
		if from_side == side and from_slot == slot_index:
			clear_selection()
			return
		_order_move(from_side, from_slot, side, slot_index, shift)
		return
	if _slot_occupied(side, slot_index):
		_selection = {"side": side, "slot": slot_index}
		_sync_marks()

func hover_cell(_cell) -> void:
	pass

func begin_cell_drag(cell) -> Dictionary:
	if not _slot_occupied(String(cell.side), int(cell.key)):
		return {}
	_selection = {"side": String(cell.side), "slot": int(cell.key)}
	_sync_marks()
	return {"kind": "town_army_slot", "side": String(cell.side), "slot": int(cell.key)}

func can_drop_on_cell(cell, data: Variant) -> bool:
	return data is Dictionary and String(data.get("kind", "")) == "town_army_slot" and String(_state.get(String(cell.side), {}).get("holder_id", "")) != ""

func drop_on_cell(cell, data: Variant, shift: bool) -> void:
	if not can_drop_on_cell(cell, data):
		return
	_order_move(String(data.get("side", "")), int(data.get("slot", -1)), String(cell.side), int(cell.key), shift)

# --- orders ------------------------------------------------------------------

func _order_move(from_side: String, from_slot: int, to_side: String, to_slot: int, shift: bool) -> void:
	var source_holder := String(_state.get(from_side, {}).get("holder_id", ""))
	var target_holder := String(_state.get(to_side, {}).get("holder_id", ""))
	if source_holder == "" or target_holder == "" or (from_side == to_side and from_slot == to_slot):
		clear_selection()
		return
	var target_occupied := _slot_occupied(to_side, to_slot)
	var same_unit := target_occupied and _slot_unit(to_side, to_slot) == _slot_unit(from_side, from_slot)
	if shift and (not target_occupied or same_unit) and _slot_count(from_side, from_slot) > 1:
		_open_split(from_side, from_slot, to_side, to_slot)
		return
	clear_selection()
	slot_order_requested.emit(source_holder, from_slot, target_holder, to_slot, "all")

func _open_split(from_side: String, from_slot: int, to_side: String, to_slot: int) -> void:
	var available := _slot_count(from_side, from_slot)
	_split_order = {"from_side": from_side, "from_slot": from_slot, "to_side": to_side, "to_slot": to_slot}
	_split_slider.min_value = 1
	_split_slider.max_value = maxi(1, available - 1) if not _slot_occupied(to_side, to_slot) or from_side != to_side else available
	_split_slider.value = maxi(1, int(available / 2))
	_update_split_label()
	_split.visible = true
	_split.global_position = global_position + Vector2(size.x * 0.5 - _split.get_combined_minimum_size().x * 0.5, -_split.get_combined_minimum_size().y - 8.0)

func _confirm_split() -> void:
	if _split_order.is_empty():
		return
	var order := _split_order
	_split_order = {}
	_split.visible = false
	clear_selection()
	slot_order_requested.emit(
		String(_state.get(String(order.from_side), {}).get("holder_id", "")),
		int(order.from_slot),
		String(_state.get(String(order.to_side), {}).get("holder_id", "")),
		int(order.to_slot),
		str(int(_split_slider.value))
	)

func _cancel_split() -> void:
	_split_order = {}
	_split.visible = false
	clear_selection()

func _update_split_label() -> void:
	if _split_order.is_empty():
		return
	var available := _slot_count(String(_split_order.from_side), int(_split_order.from_slot))
	var moving := int(_split_slider.value)
	_split_label.text = "%d  |  %d" % [available - moving, moving]

# --- hero portraits -------------------------------------------------------------

func _make_portrait(side: String) -> Button:
	var portrait := Button.new()
	portrait.name = "%sPortrait" % String(side).capitalize()
	portrait.custom_minimum_size = CELL_SIZE
	portrait.focus_mode = Control.FOCUS_ALL
	portrait.clip_contents = true
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 3
	art.offset_top = 3
	art.offset_right = -3
	art.offset_bottom = -3
	portrait.add_child(art)
	var caption := Label.new()
	caption.name = "Caption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", MUTED)
	portrait.add_child(caption)
	portrait.gui_input.connect(_on_portrait_gui_input.bind(side))
	portrait.set_drag_forwarding(_portrait_drag_data.bind(side), _portrait_can_drop.bind(side), _portrait_drop.bind(side))
	_portraits[side] = portrait
	return portrait

func _show_portrait(side: String, row: Dictionary) -> void:
	var portrait: Button = _portraits.get(side)
	var art := portrait.get_node("Art") as TextureRect
	var caption := portrait.get_node("Caption") as Label
	var hero_id := String(row.get("hero_id", ""))
	art.texture = _texture(String(row.get("portrait", ""))) if hero_id != "" else null
	caption.text = "" if hero_id != "" else ("Garrison" if side == "garrison" else "Gate")
	var hero_name := String(row.get("hero_name", ""))
	if hero_id == "":
		portrait.tooltip_text = "No hero holds the garrison. Click the visiting hero, then here, to move them in." if side == "garrison" else "No hero waits at the gate."
	else:
		portrait.tooltip_text = "%s %s\nClick to select, click again or double-click for the hero sheet.\nClick the other portrait (or drag onto it) to %s." % [
			hero_name,
			"holds the garrison" if side == "garrison" else "visits at the gate",
			"swap or step out to the gate" if side == "garrison" else "move into the garrison",
		]

func _on_portrait_gui_input(event: InputEvent, side: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_portrait_pressed(side, event.double_click)
		accept_event()
	elif not (event is InputEventMouse) and event.is_action_pressed("ui_accept") and not event.is_echo():
		_portrait_pressed(side, false)
		accept_event()

## HoMM rules: click selects a hero, clicking it again opens the hero sheet,
## clicking the other portrait moves the selected hero there (or swaps).
func _portrait_pressed(side: String, double_click: bool) -> void:
	var hero_id := String(_state.get(side, {}).get("hero_id", ""))
	if double_click and hero_id != "":
		clear_selection()
		hero_sheet_requested.emit(hero_id)
		return
	if _selection.has("portrait"):
		var from_side := String(_selection.get("side", ""))
		if from_side == side:
			clear_selection()
			if hero_id != "":
				hero_sheet_requested.emit(hero_id)
			return
		_portrait_order(from_side, side)
		return
	if hero_id != "":
		_selection = {"side": side, "portrait": true}
		_sync_marks()

func _portrait_order(from_side: String, to_side: String) -> void:
	clear_selection()
	var moving_id := String(_state.get(from_side, {}).get("hero_id", ""))
	if moving_id == "":
		return
	if from_side == "visiting" and to_side == "garrison":
		garrison_hero_requested.emit(moving_id)
	elif from_side == "garrison" and to_side == "visiting":
		var visitor_id := String(_state.get("visiting", {}).get("hero_id", ""))
		garrison_hero_requested.emit(visitor_id)

func _portrait_drag_data(_at: Vector2, side: String) -> Variant:
	var hero_id := String(_state.get(side, {}).get("hero_id", ""))
	if hero_id == "":
		return null
	var preview := TextureRect.new()
	preview.texture = (_portraits[side].get_node("Art") as TextureRect).texture
	preview.custom_minimum_size = CELL_SIZE * 0.9
	preview.size = CELL_SIZE * 0.9
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"kind": "town_hero_portrait", "side": side}

func _portrait_can_drop(_at: Vector2, data: Variant, side: String) -> bool:
	return data is Dictionary and String(data.get("kind", "")) == "town_hero_portrait" and String(data.get("side", "")) != side

func _portrait_drop(_at: Vector2, data: Variant, side: String) -> void:
	if _portrait_can_drop(_at, data, side):
		_portrait_order(String(data.get("side", "")), side)

# --- helpers ---------------------------------------------------------------------

func _slot(side: String, slot_index: int) -> Dictionary:
	var slots: Array = _state.get(side, {}).get("slots", [])
	return slots[slot_index] if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary else {}

func _slot_occupied(side: String, slot_index: int) -> bool:
	return bool(_slot(side, slot_index).get("occupied", false))

func _slot_unit(side: String, slot_index: int) -> String:
	return String(_slot(side, slot_index).get("unit_id", ""))

func _slot_count(side: String, slot_index: int) -> int:
	return int(_slot(side, slot_index).get("count", 0))

func _selection_still_valid() -> bool:
	if _selection.is_empty():
		return true
	var side := String(_selection.get("side", ""))
	if _selection.has("portrait"):
		return String(_state.get(side, {}).get("hero_id", "")) != ""
	return _slot_occupied(side, int(_selection.get("slot", -1)))

func _sync_marks() -> void:
	for side in SIDES:
		var cells: Array = _cells.get(side, [])
		for index in range(cells.size()):
			var selected: bool = _selection.has("slot") and String(_selection.get("side", "")) == side and int(_selection.get("slot", -1)) == index
			var legal: bool = _selection.has("slot") and not selected and String(_state.get(side, {}).get("holder_id", "")) != ""
			cells[index].set_marks(selected, legal)
		var portrait: Button = _portraits.get(side)
		if portrait == null:
			continue
		var portrait_selected: bool = _selection.has("portrait") and String(_selection.get("side", "")) == side
		var portrait_target: bool = _selection.has("portrait") and not portrait_selected
		var has_hero := String(_state.get(side, {}).get("hero_id", "")) != ""
		var border := SELECTED if portrait_selected else (Color(0.52, 0.80, 0.56) if portrait_target else (GOLD if has_hero else GOLD_DIM))
		var width := 3 if portrait_selected else (2 if portrait_target or has_hero else 1)
		portrait.add_theme_stylebox_override("normal", _box(CELL_FILL, border, width, 3, 0))
		portrait.add_theme_stylebox_override("hover", _box(Color(0.08, 0.11, 0.10, 1.0), SELECTED, maxi(width, 2), 3, 0))
		portrait.add_theme_stylebox_override("pressed", _box(Color(0.08, 0.11, 0.10, 1.0), SELECTED, 3, 3, 0))
		portrait.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), SELECTED, 2, 3, 0))

func _build_split_popup() -> void:
	_split = PanelContainer.new()
	_split.name = "SplitPopup"
	_split.top_level = true
	_split.visible = false
	_split.add_theme_stylebox_override("panel", _box(FILL, GOLD, 2, 6, 10))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_split.add_child(box)
	_split_slider = HSlider.new()
	_split_slider.custom_minimum_size = Vector2(200, 28)
	_split_slider.step = 1
	_split_slider.value_changed.connect(func(_value): _update_split_label())
	box.add_child(_split_slider)
	_split_label = Label.new()
	_split_label.custom_minimum_size = Vector2(80, 0)
	_split_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.80))
	box.add_child(_split_label)
	var ok := Button.new()
	ok.text = "Split"
	ok.pressed.connect(_confirm_split)
	box.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_cancel_split)
	box.add_child(cancel)
	add_child(_split)

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]

func _box(fill: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
