extends Control
## HoMM-style meeting screen for two friendly commanders sharing a field tile.
## The heroes face each other: portrait and primary stats, the seven army
## slots, worn and carried artifacts and the spells one can teach the other.
## It renders HeroCommandRules.field_exchange_state and emits orders built with
## HeroCommandRules.field_*_action_id; OverworldShell commits every order
## through OverworldRules.perform_rendezvous_action and calls refresh_exchange.

signal order_requested(action_id: String)
signal partner_requested(hero_id: String)
signal closed

const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
const CellScript = preload("res://scenes/overworld/HeroExchangeSlot.gd")
const FRAME := "res://art/ui/runtime/overworld/parchment_panel.png"
const PORTRAIT_FRAME := "res://art/ui/runtime/overworld/hero_frame.png"
const SIDES := ["left", "right"]
const ARMY_CELL := Vector2(84.0, 96.0)
const EQUIP_CELL := Vector2(72.0, 72.0)
const PACK_CELL := Vector2(60.0, 60.0)
const SPELL_CELL := Vector2(50.0, 50.0)
const PORTRAIT_SIZE := Vector2(138.0, 184.0)
const PACK_VISIBLE := 6
const SPELL_VISIBLE := 8
const SPINE_WIDTH := 150.0
const PANEL_MAX_WIDTH := 1580.0
const DRAG_ARMY := "hero_exchange_army"
const DRAG_ARTIFACT := "hero_exchange_artifact"
const EQUIP_CAPTIONS := {"boots": "Boots", "banner": "Banner", "armor": "Armor", "trinket": "Trinket", "trinket_2": "Trinket"}
const IDLE_HINT := "Click a stack, then a slot · Shift-click splits · Click an artifact or spell to hand it over"

var _state: Dictionary = {}
var _cells: Dictionary = {}
var _selected: Dictionary = {}
var _split_armed := false
var _split: Dictionary = {}
var _pack_page := {"left": 0, "right": 0}
var _spell_page := {"left": 0, "right": 0}
var _status_tone := "muted"
var _return_focus: WeakRef
var _panel: PanelContainer
var _status: Label
var _split_button: Button
var _done_button: Button
var _split_popup: PanelContainer
var _split_slider: HSlider
var _split_icon: TextureRect
var _split_title: Label
var _split_stay: Label
var _split_move: Label
var _split_confirm: Button
var _split_cancel: Button
var _headers: Dictionary = {}
var _pagers: Dictionary = {}
var _move_buttons: Dictionary = {}
var _teach_empty: Dictionary = {}
var _partner_row: VBoxContainer
var _texture_cache: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	set_process_input(false)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.023, 0.025, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "ExchangePanel"
	_panel.add_theme_stylebox_override("panel", Visuals.ornate_frame_style(FRAME, "frame", 54, 28))
	add_child(_panel)
	_panel.minimum_size_changed.connect(_layout.call_deferred)
	resized.connect(_layout)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	_panel.add_child(body)
	var grid := GridContainer.new()
	grid.name = "ExchangeGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	grid.add_child(_build_header("left"))
	grid.add_child(_build_partner_spine())
	grid.add_child(_build_header("right"))
	grid.add_child(_build_army_row("left"))
	grid.add_child(_build_move_spine("troops", "Troops"))
	grid.add_child(_build_army_row("right"))
	grid.add_child(_build_equip_row("left"))
	grid.add_child(_build_move_spine("artifacts", "Artifacts"))
	grid.add_child(_build_equip_row("right"))
	grid.add_child(_build_pack_row("left"))
	grid.add_child(_spine_caption("Backpack"))
	grid.add_child(_build_pack_row("right"))
	grid.add_child(_build_spell_row("left"))
	grid.add_child(_spine_caption("Teach spells"))
	grid.add_child(_build_spell_row("right"))
	body.add_child(_build_footer())
	_build_split_popup()

# --- Public surface -------------------------------------------------------

func open_exchange(state: Dictionary, return_control: Control = null) -> void:
	_return_focus = weakref(return_control) if return_control != null else null
	_selected.clear()
	_split_armed = false
	_pack_page = {"left": 0, "right": 0}
	_spell_page = {"left": 0, "right": 0}
	_close_split_popup()
	_set_status(IDLE_HINT, "muted")
	_apply_state(state)
	show()
	move_to_front()
	set_process_input(true)
	_layout()
	_focus_cycle()
	_done_button.call_deferred("grab_focus")

## Re-render after the owner committed an order; `result` is the rules result.
func refresh_exchange(state: Dictionary, result: Dictionary = {}) -> void:
	_selected.clear()
	_split_armed = false
	_close_split_popup()
	_apply_state(state)
	if not result.is_empty():
		_set_status(String(result.get("message", "")), "body" if bool(result.get("ok", false)) else "red")
	_focus_cycle()

func close_exchange() -> void:
	if not visible:
		return
	_close_split_popup()
	hide()
	set_process_input(false)
	var previous = _return_focus.get_ref() if _return_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()
	closed.emit()

func hero_id(side: String) -> String:
	return String(_hero(side).get("hero_id", ""))

## Click (or Enter) on a cell; `shift` asks to split the selected stack.
func press_cell(item: Control, shift: bool = false) -> void:
	match String(item.kind):
		"army":
			_press_army(String(item.side), int(item.key), shift)
		"equip", "pack":
			_press_artifact(item)
		"spell":
			_press_spell(item)

## Pointer or focus over a cell: with a stack selected, say what a click would do.
func hover_cell(item: Control) -> void:
	if _selected.is_empty() or String(item.kind) != "army" or _split_popup.visible:
		return
	if String(item.side) == String(_selected.side) and int(item.key) == int(_selected.slot):
		_set_status(_selection_hint(), "body")
		return
	var preview := _army_preview(String(_selected.side), int(_selected.slot), String(item.side), int(item.key), _split_armed)
	if String(preview.get("message", "")) != "":
		_set_status(String(preview.get("message", "")), "body" if bool(preview.get("allowed", false)) else "red")

func set_split_amount(amount: int) -> void:
	if _split_slider != null:
		_split_slider.value = amount

func confirm_split() -> void:
	if _split.is_empty() or not _split_popup.visible:
		return
	var split := _split.duplicate()
	var amount := int(_split_slider.value)
	_close_split_popup()
	_request(Heroes.field_slot_action_id(
		hero_id(String(split.source_side)), int(split.source_slot),
		hero_id(String(split.target_side)), int(split.target_slot),
		str(amount)
	))

func cell(side: String, kind: String, key: String) -> Control:
	return _cells.get(_cell_key(side, kind, key))

func validation_snapshot() -> Dictionary:
	var sides := {}
	for side in SIDES:
		var hero := _hero(side)
		var army := []
		for slot in hero.get("army", {}).get("slots", []):
			army.append([String(slot.get("unit_id", "")), int(slot.get("count", 0))])
		sides[side] = {
			"hero_id": hero_id(side),
			"name": String(hero.get("name", "")),
			"army": army,
			"equipped": hero.get("equipped", {}).duplicate(true),
			"inventory": hero.get("inventory", []).duplicate(true),
			"teachable": _teachable(side),
		}
	var legal := []
	var focusable := 0
	var art_loaded := 0
	for key in _cells.keys():
		var item: Control = _cells[key]
		if item.is_marked_legal():
			legal.append(String(key))
		if Visuals.is_keyboard_focusable(item):
			focusable += 1
		if item.item_id != "" and item.art.texture is Texture2D:
			art_loaded += 1
	legal.sort()
	var viewport_rect := get_viewport_rect()
	var panel_rect := _panel.get_global_rect()
	return {
		"visible": visible,
		"sides": sides,
		"partner_count": (_state.get("partners", []) as Array).size(),
		"selected": _selected.duplicate(),
		"split_armed": _split_armed,
		"split_open": _split_popup.visible,
		"split": _split.duplicate(),
		"split_min": int(_split_slider.min_value),
		"split_max": int(_split_slider.max_value),
		"split_value": int(_split_slider.value),
		"status": _status.text,
		"status_tone": _status_tone,
		"legal_targets": legal,
		"cell_count": _cells.size(),
		"focusable_cells": focusable,
		"loaded_art_cells": art_loaded,
		"done_focusable": Visuals.is_keyboard_focusable(_done_button),
		"panel_rect": {"x": panel_rect.position.x, "y": panel_rect.position.y, "width": panel_rect.size.x, "height": panel_rect.size.y},
		"panel_inside_viewport": viewport_rect.encloses(panel_rect),
		"scroll_containers": _scroll_container_count(self),
	}

# --- Drag and drop (delegated from HeroExchangeSlot) ----------------------

func begin_cell_drag(source: Control) -> Dictionary:
	if String(source.item_id) == "":
		return {}
	match String(source.kind):
		"army":
			_selected = {"side": String(source.side), "slot": int(source.key)}
			_update_marks()
			return {"kind": DRAG_ARMY, "screen": get_instance_id(), "side": String(source.side), "slot": int(source.key)}
		"equip", "pack":
			return {"kind": DRAG_ARTIFACT, "screen": get_instance_id(), "side": String(source.side), "artifact_id": String(source.item_id)}
	return {}

func can_drop_on_cell(target: Control, data: Variant) -> bool:
	var preview := _drop_preview(target, data, Input.is_key_pressed(KEY_SHIFT))
	if String(preview.get("message", "")) != "":
		_set_status(String(preview.get("message", "")), "body" if bool(preview.get("allowed", false)) else "red")
	return bool(preview.get("allowed", false))

func drop_on_cell(target: Control, data: Variant, shift: bool = false) -> void:
	if not bool(_drop_preview(target, data, shift).get("allowed", false)):
		return
	if String(data.get("kind", "")) == DRAG_ARMY:
		if shift:
			_open_split_popup(String(data.side), int(data.slot), String(target.side), int(target.key))
		else:
			_request(Heroes.field_slot_action_id(hero_id(String(data.side)), int(data.slot), hero_id(String(target.side)), int(target.key), "all"))
		return
	var target_slot := String(target.key) if String(target.kind) == "equip" else Heroes.FIELD_ARTIFACT_PACK_SLOT
	_request(Heroes.field_artifact_place_action_id(hero_id(String(data.side)), hero_id(String(target.side)), String(data.artifact_id), target_slot))

func _drop_preview(target: Control, data: Variant, shift: bool) -> Dictionary:
	if not (data is Dictionary) or data.get("screen") != get_instance_id():
		return {"allowed": false}
	match String(data.get("kind", "")):
		DRAG_ARMY:
			if String(target.kind) != "army":
				return {"allowed": false}
			return _army_preview(String(data.side), int(data.slot), String(target.side), int(target.key), shift)
		DRAG_ARTIFACT:
			return _artifact_drop_preview(String(data.side), String(data.artifact_id), target)
	return {"allowed": false}

# --- Layout ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _split_popup.visible:
		_close_split_popup()
		_focus_cycle()
		_set_status(IDLE_HINT, "muted")
	elif not _selected.is_empty() or _split_armed:
		_clear_selection()
	else:
		close_exchange()

func _layout() -> void:
	if _panel == null:
		return
	var minimum := _panel.get_combined_minimum_size()
	var width := clampf(PANEL_MAX_WIDTH, minimum.x, maxf(minimum.x, size.x - 48.0))
	_panel.size = Vector2(width, minimum.y)
	_panel.position = ((size - _panel.size) * 0.5).floor()
	if _split_popup != null and _split_popup.visible:
		_split_popup.size = _split_popup.get_combined_minimum_size()
		_split_popup.position = Vector2(
			floorf((size.x - _split_popup.size.x) * 0.5),
			floorf(_panel.position.y + _panel.size.y - _split_popup.size.y - 92.0)
		)

func _build_header(side: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "%sHeader" % side.capitalize()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_END if side == "right" else BoxContainer.ALIGNMENT_BEGIN
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Visuals.ornate_frame_style(PORTRAIT_FRAME, "frame", 26, 6))
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if side == "right" else HORIZONTAL_ALIGNMENT_LEFT
	var name_label := _label(info, "", 28, "gold", align)
	name_label.name = "HeroName"
	var level_label := _label(info, "", 17, "body", align)
	level_label.name = "HeroLevel"
	var stats_row := HBoxContainer.new()
	stats_row.name = "PrimaryStats"
	stats_row.add_theme_constant_override("separation", 16)
	stats_row.alignment = BoxContainer.ALIGNMENT_END if side == "right" else BoxContainer.ALIGNMENT_BEGIN
	info.add_child(stats_row)
	var stat_values := []
	for stat in ["attack", "defense", "power", "knowledge"]:
		var stat_box := VBoxContainer.new()
		stat_box.add_theme_constant_override("separation", -4)
		stat_box.mouse_filter = Control.MOUSE_FILTER_PASS
		_label(stat_box, String(stat).capitalize(), 15, "muted", HORIZONTAL_ALIGNMENT_CENTER)
		var value := _label(stat_box, "0", 28, "title", HORIZONTAL_ALIGNMENT_CENTER)
		value.mouse_filter = Control.MOUSE_FILTER_PASS
		stats_row.add_child(stat_box)
		stat_values.append(value)
	var resources := _label(info, "", 15, "muted", align)
	resources.name = "HeroResources"
	if side == "right":
		row.add_child(info)
		row.add_child(frame)
	else:
		row.add_child(frame)
		row.add_child(info)
	_headers[side] = {"portrait": portrait, "name": name_label, "level": level_label, "stats": stat_values, "resources": resources}
	return row

func _build_partner_spine() -> Control:
	_partner_row = VBoxContainer.new()
	_partner_row.name = "PartnerSwitch"
	_partner_row.custom_minimum_size = Vector2(SPINE_WIDTH, 0)
	_partner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_partner_row.add_theme_constant_override("separation", 6)
	return _partner_row

func _build_move_spine(kind: String, caption: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "%sSpine" % kind.capitalize()
	box.custom_minimum_size = Vector2(SPINE_WIDTH, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 6)
	_label(box, caption, 16, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	for side in SIDES:
		var button := Button.new()
		button.name = "%sAll%s" % [kind.capitalize(), "Right" if side == "left" else "Left"]
		button.text = "All  →" if side == "left" else "←  All"
		Visuals.apply_button(button, "secondary", SPINE_WIDTH - 20.0, 34.0, 15)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_move_all_pressed.bind(kind, side))
		box.add_child(button)
		_move_buttons["%s:%s" % [kind, side]] = button
	return box

func _spine_caption(text: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(SPINE_WIDTH, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(box, text, 16, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	return box

func _row(side: String, row_name: String, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%s%s" % [side.capitalize(), row_name]
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", separation)
	row.alignment = BoxContainer.ALIGNMENT_END if side == "right" else BoxContainer.ALIGNMENT_BEGIN
	return row

func _build_army_row(side: String) -> Control:
	var row := _row(side, "Army", 7)
	for slot_index in range(Heroes.ARMY_SLOT_COUNT):
		row.add_child(_make_cell(side, "army", str(slot_index), ARMY_CELL))
	return row

func _build_equip_row(side: String) -> Control:
	var row := _row(side, "Equipped", 8)
	for slot in Artifacts.EQUIPMENT_SLOTS:
		row.add_child(_make_cell(side, "equip", String(slot), EQUIP_CELL))
	return row

func _build_pack_row(side: String) -> Control:
	var row := _row(side, "Backpack", 6)
	row.custom_minimum_size.y = PACK_CELL.y
	var previous := _pager_button("‹", "Previous backpack page")
	previous.pressed.connect(_turn_page.bind(side, "pack", -1))
	row.add_child(previous)
	for index in range(PACK_VISIBLE):
		row.add_child(_make_cell(side, "pack", str(index), PACK_CELL))
	var next := _pager_button("›", "Next backpack page")
	next.pressed.connect(_turn_page.bind(side, "pack", 1))
	row.add_child(next)
	_pagers["%s:pack" % side] = [previous, next]
	return row

func _build_spell_row(side: String) -> Control:
	var row := _row(side, "Spells", 6)
	row.custom_minimum_size.y = SPELL_CELL.y
	var previous := _pager_button("‹", "Previous spells")
	previous.pressed.connect(_turn_page.bind(side, "spell", -1))
	row.add_child(previous)
	var empty := _label(row, "Nothing new to teach", 14, "muted")
	empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_teach_empty[side] = empty
	for index in range(SPELL_VISIBLE):
		row.add_child(_make_cell(side, "spell", str(index), SPELL_CELL))
	var next := _pager_button("›", "More spells")
	next.pressed.connect(_turn_page.bind(side, "spell", 1))
	row.add_child(next)
	_pagers["%s:spell" % side] = [previous, next]
	return row

func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.name = "ExchangeFooter"
	footer.add_theme_constant_override("separation", 14)
	_status = Label.new()
	_status.name = "ExchangeStatus"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	footer.add_child(_status)
	_split_button = Button.new()
	_split_button.name = "SplitStack"
	_split_button.text = "Split"
	_split_button.toggle_mode = true
	_split_button.tooltip_text = "Split the selected stack: choose a stack, then an empty slot or the same creature on either hero. Shift-click does the same."
	Visuals.apply_button(_split_button, "secondary", 120.0, 42.0, 16)
	_split_button.toggled.connect(_on_split_toggled)
	footer.add_child(_split_button)
	_done_button = Button.new()
	_done_button.name = "DoneExchange"
	_done_button.text = "Done"
	_done_button.tooltip_text = "Close the meeting · Escape"
	Visuals.apply_button(_done_button, "primary", 170.0, 42.0, 17)
	_done_button.pressed.connect(close_exchange)
	footer.add_child(_done_button)
	return footer

func _build_split_popup() -> void:
	# An opaque backing keeps the rows underneath from showing through the frame.
	_split_popup = PanelContainer.new()
	_split_popup.name = "SplitPopup"
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.07, 0.10, 0.10, 1.0)
	backing.set_corner_radius_all(6)
	backing.shadow_color = Color(0, 0, 0, 0.5)
	backing.shadow_size = 12
	_split_popup.add_theme_stylebox_override("panel", backing)
	_split_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_split_popup.hide()
	add_child(_split_popup)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Visuals.ornate_frame_style(PORTRAIT_FRAME, "frame", 26, 18))
	_split_popup.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	_split_icon = TextureRect.new()
	_split_icon.custom_minimum_size = Vector2(80, 80)
	_split_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_split_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_split_icon)
	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 6)
	row.add_child(middle)
	_split_title = _label(middle, "", 18, "gold", HORIZONTAL_ALIGNMENT_CENTER)
	var amounts := HBoxContainer.new()
	amounts.add_theme_constant_override("separation", 12)
	middle.add_child(amounts)
	_split_stay = _label(amounts, "0", 26, "title", HORIZONTAL_ALIGNMENT_RIGHT)
	_split_stay.custom_minimum_size.x = 64
	_split_slider = HSlider.new()
	_split_slider.name = "SplitAmount"
	_split_slider.custom_minimum_size = Vector2(260, 28)
	_split_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_split_slider.step = 1
	_split_slider.accessibility_name = "Creatures moved by the split"
	Visuals.apply_range(_split_slider, "gold")
	_split_slider.value_changed.connect(func(_value): _update_split_labels())
	amounts.add_child(_split_slider)
	_split_move = _label(amounts, "0", 26, "title", HORIZONTAL_ALIGNMENT_LEFT)
	_split_move.custom_minimum_size.x = 64
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)
	_split_confirm = Button.new()
	_split_confirm.name = "ConfirmSplit"
	_split_confirm.text = "Split"
	Visuals.apply_button(_split_confirm, "primary", 110.0, 38.0, 16)
	_split_confirm.pressed.connect(confirm_split)
	buttons.add_child(_split_confirm)
	_split_cancel = Button.new()
	_split_cancel.name = "CancelSplit"
	_split_cancel.text = "Cancel"
	Visuals.apply_button(_split_cancel, "secondary", 110.0, 34.0, 15)
	_split_cancel.pressed.connect(func():
		_close_split_popup()
		_clear_selection())
	buttons.add_child(_split_cancel)

func _make_cell(side: String, kind: String, key: String, cell_size: Vector2) -> Control:
	var item := CellScript.new()
	item.setup(self, side, kind, key, cell_size)
	_cells[_cell_key(side, kind, key)] = item
	return item

func _pager_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	Visuals.apply_button(button, "secondary", 30.0, 44.0, 20)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button

func _label(parent: Node, text: String, font_size: int, tone: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Visuals.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label

# --- Rendering ------------------------------------------------------------

func _apply_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	for side in SIDES:
		var hero := _hero(side)
		_update_header(side, hero)
		_update_army(side, hero)
		_update_equipped(side, hero)
		_update_pack(side, hero)
		_update_spells(side)
	_update_partners()
	_update_move_buttons()
	_update_marks()

func _update_header(side: String, hero: Dictionary) -> void:
	var header: Dictionary = _headers.get(side, {})
	(header.portrait as TextureRect).texture = _texture(String(hero.get("portrait", "")))
	(header.portrait as TextureRect).tooltip_text = String(hero.get("name", ""))
	(header.name as Label).text = String(hero.get("name", ""))
	(header.level as Label).text = "Level %d · %s" % [int(hero.get("level", 1)), String(hero.get("archetype", ""))]
	var stats: Array = hero.get("stats", [])
	for index in range((header.stats as Array).size()):
		var value_label: Label = header.stats[index]
		var stat: Dictionary = stats[index] if index < stats.size() and stats[index] is Dictionary else {}
		value_label.text = str(int(stat.get("value", 0)))
		value_label.tooltip_text = "%s %d (base %d, +%d from artifacts and specialties)" % [String(stat.get("label", "")), int(stat.get("value", 0)), int(stat.get("base", 0)), int(stat.get("bonus", 0))] if int(stat.get("bonus", 0)) != 0 else "%s %d" % [String(stat.get("label", "")), int(stat.get("value", 0))]
	var mana: Dictionary = hero.get("mana", {})
	var movement: Dictionary = hero.get("movement", {})
	(header.resources as Label).text = "Mana %d/%d  ·  Move %d/%d" % [int(mana.get("current", 0)), int(mana.get("max", 0)), int(movement.get("current", 0)), int(movement.get("max", 0))]

func _update_army(side: String, hero: Dictionary) -> void:
	var army: Dictionary = hero.get("army", {})
	var manageable := bool(army.get("capacity_valid", true))
	for slot_index in range(Heroes.ARMY_SLOT_COUNT):
		var item: Control = cell(side, "army", str(slot_index))
		var slot := _army_slot(side, slot_index)
		item.disabled = not manageable
		if bool(slot.get("occupied", false)):
			item.show_item(
				String(slot.get("unit_id", "")),
				_texture(String(slot.get("battle_icon", ""))),
				int(slot.get("count", 0)),
				"",
				"%s × %d\nTier %d %s" % [String(slot.get("unit_name", "")), int(slot.get("count", 0)), int(slot.get("tier", 1)), String(slot.get("role", "")).capitalize()]
			)
		else:
			item.show_item("", null, 0, "", "Empty army slot %d" % (slot_index + 1))
	if not manageable:
		_set_status(String(army.get("message", "This army exceeds seven stacks.")), "red")

func _update_equipped(side: String, hero: Dictionary) -> void:
	var equipped: Dictionary = hero.get("equipped", {})
	for slot in Artifacts.EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		var item: Control = cell(side, "equip", String(slot))
		if artifact_id == "":
			item.show_item("", null, 0, String(EQUIP_CAPTIONS.get(slot, "")), "Empty %s slot" % String(EQUIP_CAPTIONS.get(slot, slot)).to_lower())
		else:
			item.show_item(artifact_id, _texture(Artifacts.artifact_icon_path(artifact_id)), 0, "", _artifact_tooltip(side, artifact_id))

func _update_pack(side: String, hero: Dictionary) -> void:
	var inventory: Array = hero.get("inventory", [])
	var pages := maxi(1, int(ceil(float(inventory.size()) / float(PACK_VISIBLE))))
	_pack_page[side] = clampi(int(_pack_page.get(side, 0)), 0, pages - 1)
	for index in range(PACK_VISIBLE):
		var item: Control = cell(side, "pack", str(index))
		var inventory_index := int(_pack_page[side]) * PACK_VISIBLE + index
		var artifact_id := String(inventory[inventory_index]) if inventory_index < inventory.size() else ""
		if artifact_id == "":
			item.show_item("", null, 0, "", "Backpack")
		else:
			item.show_item(artifact_id, _texture(Artifacts.artifact_icon_path(artifact_id)), 0, "", _artifact_tooltip(side, artifact_id))
	var pagers: Array = _pagers.get("%s:pack" % side, [])
	for pager in pagers:
		pager.visible = inventory.size() > PACK_VISIBLE
	if pagers.size() == 2:
		pagers[0].disabled = int(_pack_page[side]) <= 0
		pagers[1].disabled = int(_pack_page[side]) >= pages - 1

func _update_spells(side: String) -> void:
	var teachable := _teachable(side)
	var pages := maxi(1, int(ceil(float(teachable.size()) / float(SPELL_VISIBLE))))
	_spell_page[side] = clampi(int(_spell_page.get(side, 0)), 0, pages - 1)
	var partner_name := String(_hero(_other(side)).get("name", "the other commander"))
	for index in range(SPELL_VISIBLE):
		var item: Control = cell(side, "spell", str(index))
		var spell_index := int(_spell_page[side]) * SPELL_VISIBLE + index
		item.visible = spell_index < teachable.size()
		if not item.visible:
			item.show_item("", null, 0, "", "")
			continue
		var spell_id := String(teachable[spell_index])
		var spell := ContentService.get_spell(spell_id)
		item.show_item(spell_id, _texture(Spells.spell_icon_path(spell_id)), 0, "", "Teach %s to %s\nTier %d %s spell · %d mana" % [
			String(spell.get("name", spell_id)), partner_name,
			int(spell.get("tier", 1)), String(spell.get("context", "battle")), int(spell.get("mana_cost", 0)),
		])
	(_teach_empty[side] as Label).visible = teachable.is_empty()
	var pagers: Array = _pagers.get("%s:spell" % side, [])
	for pager in pagers:
		pager.visible = teachable.size() > SPELL_VISIBLE
	if pagers.size() == 2:
		pagers[0].disabled = int(_spell_page[side]) <= 0
		pagers[1].disabled = int(_spell_page[side]) >= pages - 1

func _update_partners() -> void:
	for child in _partner_row.get_children():
		_partner_row.remove_child(child)
		child.queue_free()
	var partners: Array = _state.get("partners", [])
	if partners.size() < 2:
		return
	_label(_partner_row, "Meet", 14, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	for partner_value in partners:
		var partner: Dictionary = partner_value if partner_value is Dictionary else {}
		var partner_id := String(partner.get("hero_id", ""))
		var button := Button.new()
		button.name = "Partner_%s" % partner_id
		button.text = String(partner.get("name", partner_id)).get_slice(" ", 0)
		button.tooltip_text = "Exchange with %s" % String(partner.get("name", partner_id))
		button.toggle_mode = true
		button.button_pressed = partner_id == hero_id("right")
		Visuals.apply_button(button, "primary" if button.button_pressed else "secondary", SPINE_WIDTH - 20.0, 32.0, 14)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func(): partner_requested.emit(partner_id))
		_partner_row.add_child(button)

func _update_move_buttons() -> void:
	for side in SIDES:
		var hero := _hero(side)
		var partner := _hero(_other(side))
		var troops: Button = _move_buttons.get("troops:%s" % side)
		troops.disabled = int(hero.get("army", {}).get("troop_count", 0)) <= 0
		troops.tooltip_text = "Move all troops from %s to %s. One creature stays if %s would be left empty." % [hero.get("name", ""), partner.get("name", ""), hero.get("name", "")]
		var artifacts: Button = _move_buttons.get("artifacts:%s" % side)
		var owned := _owned_artifacts(side)
		artifacts.disabled = owned.is_empty()
		artifacts.tooltip_text = "Hand every artifact of %s to %s (worn where a slot is free, otherwise in the backpack)." % [hero.get("name", ""), partner.get("name", "")]

func _update_marks() -> void:
	for key in _cells.keys():
		var item: Control = _cells[key]
		if String(item.kind) != "army":
			item.set_marks(false, false)
			continue
		var selected := not _selected.is_empty() and String(item.side) == String(_selected.side) and int(item.key) == int(_selected.slot)
		var legal := false
		if not _selected.is_empty() and not selected:
			legal = bool(_army_preview(String(_selected.side), int(_selected.slot), String(item.side), int(item.key), _split_armed).get("allowed", false))
		item.set_marks(selected, legal)
	if _split_button != null:
		_split_button.set_pressed_no_signal(_split_armed)

# --- Interaction ----------------------------------------------------------

func _press_army(side: String, slot_index: int, shift: bool) -> void:
	var slot := _army_slot(side, slot_index)
	if _selected.is_empty():
		if not bool(slot.get("occupied", false)):
			_set_status("Choose a stack first.", "muted")
			return
		_selected = {"side": side, "slot": slot_index}
		_split_armed = _split_armed or shift
		_set_status(_selection_hint(), "body")
		_update_marks()
		return
	if String(_selected.side) == side and int(_selected.slot) == slot_index:
		_clear_selection()
		return
	if shift or _split_armed:
		_open_split_popup(String(_selected.side), int(_selected.slot), side, slot_index)
		return
	# Every whole-stack order goes to the rules, which explain any refusal.
	_request(Heroes.field_slot_action_id(hero_id(String(_selected.side)), int(_selected.slot), hero_id(side), slot_index, "all"))

func _press_artifact(item: Control) -> void:
	var artifact_id := String(item.item_id)
	if artifact_id == "":
		_set_status("Drag an artifact here, or click one to hand it over.", "muted")
		return
	var side := String(item.side)
	_request(Heroes.field_artifact_place_action_id(hero_id(side), hero_id(_other(side)), artifact_id, ""))

func _press_spell(item: Control) -> void:
	var spell_id := String(item.item_id)
	if spell_id == "":
		return
	var side := String(item.side)
	_request(Heroes.field_spell_share_action_id(hero_id(side), hero_id(_other(side)), spell_id))

func _on_move_all_pressed(kind: String, side: String) -> void:
	var source := hero_id(side)
	var target := hero_id(_other(side))
	if kind == "troops":
		_request(Heroes.field_troops_all_action_id(source, target))
	else:
		_request(Heroes.field_artifacts_all_action_id(source, target))

func _on_split_toggled(enabled: bool) -> void:
	_split_armed = enabled
	if _split_armed:
		_set_status("Choose an empty slot or the same creature for the split." if not _selected.is_empty() else "Choose the stack to split.", "body")
	else:
		_set_status(_selection_hint() if not _selected.is_empty() else IDLE_HINT, "muted")
	_update_marks()

func _turn_page(side: String, kind: String, delta: int) -> void:
	if kind == "pack":
		_pack_page[side] = int(_pack_page.get(side, 0)) + delta
		_update_pack(side, _hero(side))
	else:
		_spell_page[side] = int(_spell_page.get(side, 0)) + delta
		_update_spells(side)
	_focus_cycle()

func _open_split_popup(source_side: String, source_slot: int, target_side: String, target_slot: int) -> void:
	var preview := _army_preview(source_side, source_slot, target_side, target_slot, true)
	if not bool(preview.get("allowed", false)):
		_set_status(String(preview.get("message", "")), "red")
		UiAudio.play_invalid("HeroExchangeScreen.split", {"message": String(preview.get("message", ""))})
		return
	var source := _army_slot(source_side, source_slot)
	var count := int(source.get("count", 0))
	_split = {"source_side": source_side, "source_slot": source_slot, "target_side": target_side, "target_slot": target_slot, "count": count}
	_split_slider.min_value = 1
	_split_slider.max_value = count - 1
	_split_slider.set_value_no_signal(maxi(1, count / 2))
	_split_icon.texture = _texture(String(source.get("battle_icon", "")))
	_split_title.text = "Split %s" % String(source.get("unit_name", ""))
	_update_split_labels()
	_set_status("Split %s → %s slot %d · set the amount, then Split · Escape cancels" % [
		String(source.get("unit_name", "")), String(_hero(target_side).get("name", "")), target_slot + 1,
	], "body")
	_split_popup.show()
	_split_popup.move_to_front()
	_layout()
	Visuals.configure_focus_cycle([_split_popup])
	_split_slider.call_deferred("grab_focus")

func _close_split_popup() -> void:
	_split.clear()
	if _split_popup != null:
		_split_popup.hide()

func _update_split_labels() -> void:
	var count := int(_split.get("count", 0))
	var moving := int(_split_slider.value)
	_split_stay.text = str(count - moving)
	_split_move.text = str(moving)
	_split_stay.tooltip_text = "Stays with %s" % String(_hero(String(_split.get("source_side", "left"))).get("name", ""))
	_split_move.tooltip_text = "Moves to %s slot %d" % [String(_hero(String(_split.get("target_side", "left"))).get("name", "")), int(_split.get("target_slot", 0)) + 1]

func _clear_selection() -> void:
	_selected.clear()
	_split_armed = false
	_set_status(IDLE_HINT, "muted")
	_update_marks()

func _request(action_id: String) -> void:
	order_requested.emit(action_id)

func _set_status(text: String, tone: String) -> void:
	if _status == null:
		return
	_status_tone = tone
	_status.text = text
	_status.tooltip_text = text
	Visuals.apply_label(_status, tone, 16)

func _selection_hint() -> String:
	var slot := _army_slot(String(_selected.get("side", "")), int(_selected.get("slot", -1)))
	return "%s × %d — %s" % [
		String(slot.get("unit_name", "")),
		int(slot.get("count", 0)),
		"choose an empty slot or the same creature to split" if _split_armed else "choose a slot to move, merge or swap · Shift-click splits",
	]

# --- Local previews (presentation only; the rules stay authoritative) -----

func _army_preview(source_side: String, source_slot: int, target_side: String, target_slot: int, split: bool = false) -> Dictionary:
	var source := _army_slot(source_side, source_slot)
	var target := _army_slot(target_side, target_slot)
	if not bool(source.get("occupied", false)) or target.is_empty():
		return {"allowed": false, "message": ""}
	if source_side == target_side and source_slot == target_slot:
		return {"allowed": false, "message": "Choose a different slot."}
	var unit_name := String(source.get("unit_name", ""))
	var count := int(source.get("count", 0))
	var swap := bool(target.get("occupied", false)) and String(target.get("unit_id", "")) != String(source.get("unit_id", ""))
	var recipient := String(_hero(target_side).get("name", ""))
	if split:
		if swap:
			return {"allowed": false, "message": "A split stack needs an empty slot or the same creature."}
		if count < 2:
			return {"allowed": false, "message": "A single %s cannot be split." % unit_name}
		return {"allowed": true, "message": "Split %s → %s slot %d" % [unit_name, recipient, target_slot + 1]}
	if source_side != target_side and not swap and _occupied_slots(source_side) <= 1:
		return {"allowed": false, "message": "%s must keep at least one troop stack." % String(_hero(source_side).get("name", ""))}
	var verb := "Swap" if swap else ("Merge" if bool(target.get("occupied", false)) else "Move")
	return {"allowed": true, "message": "%s %d %s → %s slot %d" % [verb, count, unit_name, recipient, target_slot + 1]}

func _artifact_drop_preview(source_side: String, artifact_id: String, target: Control) -> Dictionary:
	var target_side := String(target.side)
	var artifact_name := Artifacts.artifact_name(artifact_id)
	var cross := target_side != source_side
	if cross and artifact_id in _owned_artifacts(target_side):
		return {"allowed": false, "message": "%s already owns %s." % [String(_hero(target_side).get("name", "")), artifact_name]}
	var worn_slot := ""
	var equipped: Dictionary = _hero(source_side).get("equipped", {})
	for slot in equipped.keys():
		if String(equipped[slot]) == artifact_id:
			worn_slot = String(slot)
	match String(target.kind):
		"equip":
			var slot := String(target.key)
			if not Artifacts.equipment_slot_accepts(slot, artifact_id):
				var fits := Artifacts.artifact_slot(artifact_id)
				return {"allowed": false, "message": "%s %s." % [artifact_name, "is carried in the backpack, not worn" if fits == "" else "is worn in the %s slot" % fits]}
			if not cross and worn_slot == slot:
				return {"allowed": false, "message": ""}
			return {"allowed": true, "message": "Equip %s on %s" % [artifact_name, String(_hero(target_side).get("name", ""))]}
		"pack":
			if not cross and worn_slot == "":
				return {"allowed": false, "message": ""}
			return {"allowed": true, "message": "Stow %s in %s's backpack" % [artifact_name, String(_hero(target_side).get("name", ""))]}
	return {"allowed": false, "message": ""}

# --- Data helpers ---------------------------------------------------------

func _hero(side: String) -> Dictionary:
	var hero = _state.get(side, {})
	return hero if hero is Dictionary else {}

func _other(side: String) -> String:
	return "right" if side == "left" else "left"

func _army_slot(side: String, slot_index: int) -> Dictionary:
	var slots: Array = _hero(side).get("army", {}).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return slots[slot_index]

func _occupied_slots(side: String) -> int:
	var count := 0
	for slot in _hero(side).get("army", {}).get("slots", []):
		if slot is Dictionary and bool(slot.get("occupied", false)):
			count += 1
	return count

func _owned_artifacts(side: String) -> Array:
	var hero := _hero(side)
	var owned := []
	for slot in Artifacts.EQUIPMENT_SLOTS:
		var artifact_id := String(hero.get("equipped", {}).get(slot, ""))
		if artifact_id != "":
			owned.append(artifact_id)
	for artifact_id in hero.get("inventory", []):
		owned.append(String(artifact_id))
	return owned

func _teachable(side: String) -> Array:
	var partner_spells: Array = _hero(_other(side)).get("spell_ids", [])
	var teachable := []
	for spell_id in _hero(side).get("spell_ids", []):
		if String(spell_id) not in partner_spells:
			teachable.append(String(spell_id))
	return teachable

func _artifact_tooltip(side: String, artifact_id: String) -> String:
	var partner := _hero(_other(side))
	var hint := "%s already owns one" % String(partner.get("name", "")) if artifact_id in _owned_artifacts(_other(side)) else "Click to hand to %s · drag onto a slot" % String(partner.get("name", ""))
	return "%s\n%s\n%s" % [Artifacts.artifact_name(artifact_id), Artifacts.artifact_effect_summary(artifact_id), hint]

func _cell_key(side: String, kind: String, key: String) -> String:
	return "%s:%s:%s" % [side, kind, key]

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	_texture_cache[path] = texture
	return texture

func _focus_cycle() -> void:
	if _split_popup != null and _split_popup.visible:
		Visuals.configure_focus_cycle([_split_popup])
	elif _panel != null:
		Visuals.configure_focus_cycle([_panel])

func _scroll_container_count(node: Node) -> int:
	var count := 1 if node is ScrollContainer else 0
	for child in node.get_children():
		count += _scroll_container_count(child)
	return count
