class_name ArmyStackBar
extends VBoxContainer

signal operation_requested(source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String)
signal selection_changed(snapshot: Dictionary)

const SLOT_COUNT := 7
const SLOT_SIZE := Vector2(38.0, 48.0)
const COMPACT_SLOT_SIZE := Vector2(28.0, 38.0)
const SELECTED_MODULATE := Color(1.0, 0.82, 0.34, 1.0)
const OCCUPIED_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const EMPTY_MODULATE := Color(0.64, 0.69, 0.72, 0.88)
const SLOT_FILL := Color(0.035, 0.055, 0.052, 0.98)
const SLOT_HOVER_FILL := Color(0.09, 0.12, 0.105, 1.0)
const SLOT_BORDER := Color(0.50, 0.39, 0.18, 1.0)
const SLOT_HOVER_BORDER := Color(0.88, 0.68, 0.27, 1.0)

var _holders: Array = []
var _can_manage := true
var _selected_holder_id := ""
var _selected_slot_index := -1
var _amount_token := "all"
var _status_label: Label
var _mode_row: HBoxContainer
var _holders_box: VBoxContainer
var _mode_buttons: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _texture_cache: Dictionary = {}
var _missing_textures: Dictionary = {}
var _compact_mode := false

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_static_surface()
	_rebuild_holder_rows()

func configure(holders: Array, can_manage: bool = true) -> void:
	_holders = holders.duplicate(true)
	_can_manage = can_manage
	if not _selected_slot_still_valid():
		clear_selection()
	_rebuild_holder_rows()

func set_compact_mode(compact: bool) -> void:
	if _compact_mode == compact:
		return
	_compact_mode = compact
	for button_value in _slot_buttons.values():
		var button := button_value as Button
		if button != null:
			button.custom_minimum_size = COMPACT_SLOT_SIZE if _compact_mode else SLOT_SIZE
			button.add_theme_constant_override("icon_max_width", 16 if _compact_mode else 22)

func clear_selection() -> void:
	_selected_holder_id = ""
	_selected_slot_index = -1
	_update_status()
	_update_slot_styles()
	selection_changed.emit(validation_snapshot())

func validation_snapshot() -> Dictionary:
	var holder_rows := []
	for holder_value in _holders:
		if holder_value is Dictionary:
			holder_rows.append(holder_value.duplicate(true))
	var button_rows := []
	for key_value in _slot_buttons.keys():
		var key := String(key_value)
		var button: Button = _slot_buttons.get(key)
		if button == null:
			continue
		var button_rect := button.get_global_rect()
		button_rows.append({
			"key": key,
			"focus_mode": button.focus_mode,
			"disabled": button.disabled,
			"text": button.text,
			"tooltip": button.tooltip_text,
			"icon_loaded": button.icon is Texture2D,
			"selected": key == _slot_key(_selected_holder_id, _selected_slot_index),
			"rect": {"x": button_rect.position.x, "y": button_rect.position.y, "width": button_rect.size.x, "height": button_rect.size.y},
		})
	button_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("key", "")) < String(right.get("key", "")))
	return {
		"model": "authoritative_seven_slot_army_bar",
		"holder_count": _holders.size(),
		"slot_count_per_holder": SLOT_COUNT,
		"can_manage": _can_manage,
		"compact": _compact_mode,
		"selected_holder_id": _selected_holder_id,
		"selected_slot_index": _selected_slot_index,
		"amount_token": _amount_token,
		"instruction": _status_label.text if _status_label != null else "",
		"holders": holder_rows,
		"buttons": button_rows,
	}

func _build_static_surface() -> void:
	if _holders_box != null:
		return
	var heading := Label.new()
	heading.text = "Formation"
	heading.tooltip_text = "Select a stack, choose Move All or a split amount, then choose its destination slot."
	add_child(heading)
	_holders_box = VBoxContainer.new()
	_holders_box.name = "ArmyHolderRows"
	_holders_box.add_theme_constant_override("separation", 5)
	add_child(_holders_box)
	var mode_row := HBoxContainer.new()
	_mode_row = mode_row
	mode_row.name = "ArmyModeRow"
	mode_row.add_theme_constant_override("separation", 4)
	for definition in [
		{"token": "all", "label": "All", "tooltip": "Move, merge, or swap the complete selected stack."},
		{"token": "half", "label": "Half", "tooltip": "Move half of the selected stack into an empty slot or matching unit stack."},
		{"token": "1", "label": "One", "tooltip": "Move one unit into an empty slot or matching unit stack."},
	]:
		var button := Button.new()
		var token := String(definition.get("token", "all"))
		button.text = String(definition.get("label", token))
		button.tooltip_text = String(definition.get("tooltip", ""))
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_amount_mode_pressed.bind(token))
		mode_row.add_child(button)
		_mode_buttons[token] = button
	add_child(mode_row)
	_status_label = Label.new()
	_status_label.name = "ArmyInstruction"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Choose stack → destination"
	_status_label.tooltip_text = "Select a stack, choose an amount, then choose its destination slot."
	add_child(_status_label)
	_update_mode_styles()

func _rebuild_holder_rows() -> void:
	if _holders_box == null:
		return
	for child in _holders_box.get_children():
		_holders_box.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	for holder_value in _holders:
		if not (holder_value is Dictionary):
			continue
		var holder: Dictionary = holder_value
		var holder_id := String(holder.get("holder_id", ""))
		var capacity_valid := bool(holder.get("capacity_valid", true))
		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = "%s · %d" % [String(holder.get("holder_label", holder_id)), int(holder.get("troop_count", 0))]
		label.clip_text = true
		label.tooltip_text = label.text
		row_box.add_child(label)
		var slots_row := HBoxContainer.new()
		slots_row.add_theme_constant_override("separation", 3)
		var slots: Array = holder.get("slots", []) if holder.get("slots", []) is Array else []
		for slot_index in range(SLOT_COUNT):
			var slot: Dictionary = slots[slot_index] if slot_index < slots.size() and slots[slot_index] is Dictionary else {"slot_index": slot_index, "occupied": false, "holder_id": holder_id}
			var button := _make_slot_button(holder_id, slot_index, slot)
			button.disabled = button.disabled or not capacity_valid
			slots_row.add_child(button)
			_slot_buttons[_slot_key(holder_id, slot_index)] = button
		row_box.add_child(slots_row)
		if not capacity_valid:
			var warning := Label.new()
			warning.name = "ArmyOverflowWarning"
			warning.text = "%d stacks / 7 · %d excess\nTown Log → Transfers" % [int(holder.get("occupied_slot_count", 0)), int(holder.get("overflow_stack_count", 0))]
			warning.add_theme_font_size_override("font_size", 12)
			warning.tooltip_text = String(holder.get("message", ""))
			for stack in holder.get("overflow_stacks", []):
				warning.tooltip_text += "\n%s × %d" % [String(stack.get("unit_name", stack.get("unit_id", ""))), int(stack.get("count", 0))]
			warning.focus_mode = Control.FOCUS_ALL
			row_box.add_child(warning)
		_holders_box.add_child(row_box)
	_update_mode_styles()
	_update_status()
	_update_slot_styles()
	var has_valid_holder := _holders.any(func(holder): return holder is Dictionary and bool(holder.get("capacity_valid", true)))
	_mode_row.visible = has_valid_holder
	_status_label.visible = has_valid_holder

func _make_slot_button(holder_id: String, slot_index: int, slot: Dictionary) -> Button:
	var button := Button.new()
	var occupied := bool(slot.get("occupied", false))
	button.custom_minimum_size = COMPACT_SLOT_SIZE if _compact_mode else SLOT_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = not _can_manage
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 16 if _compact_mode else 22)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_disabled_color", Color(0.84, 0.82, 0.74))
	button.add_theme_stylebox_override("normal", _slot_style(SLOT_FILL, SLOT_BORDER, 1))
	button.add_theme_stylebox_override("hover", _slot_style(SLOT_HOVER_FILL, SLOT_HOVER_BORDER, 2))
	button.add_theme_stylebox_override("pressed", _slot_style(SLOT_HOVER_FILL, SLOT_HOVER_BORDER, 2))
	button.add_theme_stylebox_override("focus", _slot_style(Color(0.0, 0.0, 0.0, 0.0), SLOT_HOVER_BORDER, 2))
	button.add_theme_stylebox_override("disabled", _slot_style(Color(0.025, 0.035, 0.034, 0.86), Color(0.25, 0.25, 0.22, 0.8), 1))
	button.text = str(int(slot.get("count", 0))) if occupied else "·"
	button.tooltip_text = _slot_tooltip(slot, slot_index)
	if occupied:
		button.icon = _texture(String(slot.get("battle_icon", "")))
	button.set_meta("occupied", occupied)
	button.set_meta("holder_id", holder_id)
	button.set_meta("slot_index", slot_index)
	button.pressed.connect(_on_slot_pressed.bind(holder_id, slot_index, occupied))
	return button

func _slot_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style

func _slot_tooltip(slot: Dictionary, slot_index: int) -> String:
	if not bool(slot.get("occupied", false)):
		return "Empty army slot %d. Select a stack, then choose this slot to move or split it here." % (slot_index + 1)
	return "%s · Tier %d · %s · %d units\nSelect as the source or destination stack." % [
		String(slot.get("unit_name", slot.get("unit_id", "Unit"))),
		int(slot.get("tier", 1)),
		String(slot.get("role", "unit")).capitalize(),
		int(slot.get("count", 0)),
	]

func _on_slot_pressed(holder_id: String, slot_index: int, occupied: bool) -> void:
	if not _can_manage:
		return
	if _selected_holder_id == "":
		if not occupied:
			_status_label.text = "Choose an occupied source stack first."
			return
		_selected_holder_id = holder_id
		_selected_slot_index = slot_index
		_update_status()
		_update_slot_styles()
		selection_changed.emit(validation_snapshot())
		return
	if _selected_holder_id == holder_id and _selected_slot_index == slot_index:
		clear_selection()
		return
	operation_requested.emit(_selected_holder_id, _selected_slot_index, holder_id, slot_index, _amount_token)

func _on_amount_mode_pressed(token: String) -> void:
	_amount_token = token if token in ["all", "half", "1"] else "all"
	_update_mode_styles()
	_update_status()
	selection_changed.emit(validation_snapshot())

func _update_mode_styles() -> void:
	for token_value in _mode_buttons.keys():
		var token := String(token_value)
		var button: Button = _mode_buttons.get(token)
		if button == null:
			continue
		button.disabled = not _can_manage
		button.button_pressed = token == _amount_token
		button.modulate = SELECTED_MODULATE if token == _amount_token else OCCUPIED_MODULATE

func _update_status() -> void:
	if _status_label == null:
		return
	if _selected_holder_id == "":
		_status_label.text = "Choose stack → destination"
	else:
		_status_label.text = "Slot %d · %s → destination" % [
			_selected_slot_index + 1,
			_amount_label(),
		]

func _update_slot_styles() -> void:
	for key_value in _slot_buttons.keys():
		var key := String(key_value)
		var button: Button = _slot_buttons.get(key)
		if button == null:
			continue
		if key == _slot_key(_selected_holder_id, _selected_slot_index):
			button.modulate = SELECTED_MODULATE
		else:
			button.modulate = OCCUPIED_MODULATE if bool(button.get_meta("occupied", false)) else EMPTY_MODULATE

func _selected_slot_still_valid() -> bool:
	if _selected_holder_id == "" or _selected_slot_index < 0:
		return true
	for holder_value in _holders:
		if not (holder_value is Dictionary) or String(holder_value.get("holder_id", "")) != _selected_holder_id:
			continue
		if not bool(holder_value.get("capacity_valid", true)):
			return false
		var slots: Array = holder_value.get("slots", []) if holder_value.get("slots", []) is Array else []
		return _selected_slot_index < slots.size() and slots[_selected_slot_index] is Dictionary and bool(slots[_selected_slot_index].get("occupied", false))
	return false

func _amount_label() -> String:
	match _amount_token:
		"half":
			return "split half"
		"1":
			return "split one"
		_:
			return "move all"

func _slot_key(holder_id: String, slot_index: int) -> String:
	return "%s:%02d" % [holder_id, slot_index]

func _texture(path: String):
	var normalized := path.strip_edges()
	if normalized == "" or _missing_textures.has(normalized):
		return null
	if _texture_cache.has(normalized):
		return _texture_cache.get(normalized)
	if ResourceLoader.exists(normalized):
		var resource = load(normalized)
		if resource is Texture2D:
			_texture_cache[normalized] = resource
			return resource
	_missing_textures[normalized] = true
	return null
