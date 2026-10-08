class_name ResourceStockpileMenu
extends MenuButton

func _make_custom_tooltip(for_text: String) -> Object:
	return get_node("/root/ContextualHelp").make_hover_card(self, for_text)

const OverworldRules = preload("res://scripts/core/OverworldRules.gd")

const SNAPSHOT_SCHEMA := "resource_stockpile_icon_menu_v1"
const COMPACT_LABEL := "Stores"
const POPUP_ICON_WIDTH := 24
const INCOME_GAIN_COLOR := Color(0.62, 0.86, 0.50, 1.0)
const INCOME_LOSS_COLOR := Color(0.93, 0.52, 0.42, 1.0)
const INCOME_NONE_COLOR := Color(0.58, 0.64, 0.69, 0.80)

# Overworld's fixed-width footer may overflow even on a wide viewport. Other
# consumers retain their existing explicit compact/summary presentation.
@export var fit_summary_to_width := false:
	set(value):
		fit_summary_to_width = value
		if is_node_ready():
			_refresh_button_copy()

var _normal_summary := ""
var _full_summary := ""
var _compact_mode := false
var _return_focus_on_hide := false
var _resource_values: Dictionary = {}
var _resource_income: Dictionary = {}
var _inline_row: HBoxContainer
var _inline_cells: Dictionary = {}


func enable_inline_icons() -> void:
	if _inline_row != null: return
	_inline_row = HBoxContainer.new()
	_inline_row.name = "ResourceIconStrip"
	_inline_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inline_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inline_row.offset_left = 8
	_inline_row.offset_right = -8
	_inline_row.add_theme_constant_override("separation", 8)
	add_child(_inline_row)
	custom_minimum_size.y = 28
	_refresh_button_copy()
	_sync_inline_icons()


func _sync_inline_icons() -> void:
	if _inline_row == null: return
	var popup := get_popup()
	for index in range(popup.item_count):
		var data: Dictionary = popup.get_item_metadata(index)
		var id := String(data.resource_id)
		if not _inline_cells.has(id):
			var cell := HBoxContainer.new()
			cell.name = id
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			var glyph := TextureRect.new()
			glyph.custom_minimum_size = Vector2(28, 28)
			glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(glyph)
			var amount := Label.new()
			amount.add_theme_font_size_override("font_size", 14)
			amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(amount)
			var income := Label.new()
			income.name = "Income"
			income.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			income.clip_text = true
			income.add_theme_font_size_override("font_size", 13)
			income.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(income)
			_inline_row.add_child(cell)
			_inline_cells[id] = cell
		var cell: HBoxContainer = _inline_cells[id]
		cell.get_child(0).texture = popup.get_item_icon(index)
		cell.get_child(1).text = _inline_amount(int(data.amount))
		var daily := int(data.get("daily_income", 0))
		var income_label: Label = cell.get_child(2)
		income_label.text = _income_text(daily)
		income_label.add_theme_color_override("font_color", _income_color(daily))
		cell.tooltip_text = popup.get_item_tooltip(index)
		cell.accessibility_name = cell.tooltip_text
	accessibility_name = "Resources: " + _full_summary


func _inline_amount(value: int) -> String:
	# Exact quantities remain in each tooltip and the existing popup.
	if absi(value) >= 1000000000: return "%.1fB" % (float(value) / 1000000000.0)
	if absi(value) >= 1000000: return "%.1fM" % (float(value) / 1000000.0)
	if absi(value) >= 100000: return "%.0fk" % (float(value) / 1000.0)
	return str(value)


## Daily income beside the amount, signed: "+500", "-2", "+0".
func _income_text(value: int) -> String:
	return ("-" if value < 0 else "+") + _inline_amount(absi(value))


func _income_color(value: int) -> Color:
	if value > 0: return INCOME_GAIN_COLOR
	if value < 0: return INCOME_LOSS_COLOR
	return INCOME_NONE_COLOR


func _ready() -> void:
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	expand_icon = true
	add_theme_constant_override("icon_max_width", 20)
	var popup: PopupMenu = get_popup()
	popup.hide_on_item_selection = false
	popup.add_theme_constant_override("icon_max_width", POPUP_ICON_WIDTH)
	popup.about_to_popup.connect(_on_popup_about_to_show)
	popup.window_input.connect(_on_popup_window_input)
	popup.popup_hide.connect(_on_popup_hidden)
	resized.connect(_refresh_button_copy)
	_refresh_button_copy()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_refresh_button_copy()


func sync_stockpile(resources: Variant, normal_summary: String, full_summary: String, daily_income: Variant = {}) -> void:
	_resource_values.clear()
	_resource_income.clear()
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var amount := int((resources as Dictionary).get(resource_id, 0)) if resources is Dictionary else 0
		_resource_values[resource_id] = amount
		_resource_income[resource_id] = int((daily_income as Dictionary).get(resource_id, 0)) if daily_income is Dictionary else 0
	_normal_summary = normal_summary.strip_edges()
	_full_summary = full_summary.strip_edges()
	if _full_summary == "":
		_full_summary = _normal_summary
	_refresh_button_copy()
	_rebuild_popup()


func set_compact_mode(compact: bool) -> void:
	_compact_mode = compact
	_refresh_button_copy()


func full_summary_text() -> String:
	return _full_summary


func validation_snapshot() -> Dictionary:
	var popup: PopupMenu = get_popup()
	var items: Array = []
	for index in range(popup.item_count):
		var metadata: Variant = popup.get_item_metadata(index)
		var row: Dictionary = metadata.duplicate(true) if metadata is Dictionary else {}
		var item_icon: Texture2D = popup.get_item_icon(index)
		row["text"] = popup.get_item_text(index)
		row["tooltip"] = popup.get_item_tooltip(index)
		row["disabled"] = popup.is_item_disabled(index)
		row["icon_loaded"] = item_icon is Texture2D
		row["icon_resource_path"] = item_icon.resource_path if item_icon is Texture2D else ""
		items.append(row)
	return {
		"schema": SNAPSHOT_SCHEMA,
		"resource_ids": OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.duplicate(),
		"resources": _resource_values.duplicate(true),
		"daily_income": _resource_income.duplicate(true),
		"normal_summary": _normal_summary,
		"full_summary": _full_summary,
		"compact": _compact_mode,
		"visible_text": text,
		"tooltip_text": tooltip_text,
		"popup_visible": popup.visible,
		"popup_item_count": popup.item_count,
		"popup_items": items,
		"has_focus": has_focus(),
		"visible": visible,
		"rect": {
			"x": get_global_rect().position.x,
			"y": get_global_rect().position.y,
			"width": get_global_rect().size.x,
			"height": get_global_rect().size.y,
		},
		"popup_rect": {
			"x": popup.position.x,
			"y": popup.position.y,
			"width": popup.size.x,
			"height": popup.size.y,
		},
	}


func _refresh_button_copy() -> void:
	var compact := _compact_mode or (fit_summary_to_width and _summary_exceeds_width())
	text = COMPACT_LABEL if compact else (_normal_summary if _normal_summary != "" else COMPACT_LABEL)
	if _inline_row != null: text = ""
	tooltip_text = _full_summary


func _summary_exceeds_width() -> bool:
	if _normal_summary == "" or size.x <= 0.0:
		return false
	if _normal_summary.contains("\n"):
		return true
	var padding := get_theme_stylebox("normal").get_minimum_size()
	var required := get_theme_font("font").get_string_size(
		_normal_summary, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")
	).x + padding.x
	if icon != null:
		var icon_width := float(icon.get_width())
		if expand_icon and icon.get_height() > 0:
			icon_width = minf(icon_width, maxf(0.0, size.y - padding.y) * icon.get_width() / icon.get_height())
		var maximum_icon_width := get_theme_constant("icon_max_width")
		if maximum_icon_width > 0:
			icon_width = minf(icon_width, maximum_icon_width)
		required += icon_width + get_theme_constant("h_separation")
	return required > size.x


func _rebuild_popup() -> void:
	var popup: PopupMenu = get_popup()
	# Rebuilding the popup re-lays out its window. While it lists the same
	# resources with the same icons, only the amounts change: update in place.
	var in_place := _popup_lists_current_resources(popup)
	if not in_place:
		popup.clear()
	var row := 0
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var definition := OverworldRules.resource_definition(resource_id)
		if definition.is_empty():
			continue
		var display_name := String(definition.get("display_name", "")).strip_edges()
		if display_name == "":
			continue
		var amount := int(_resource_values.get(resource_id, 0))
		var daily := int(_resource_income.get(resource_id, 0))
		var item_text := "%s  %d  %+d" % [display_name, amount, daily]
		var icon_path := OverworldRules.resource_icon_path(resource_id)
		var icon_texture: Texture2D = null
		if icon_path != "":
			var loaded_icon = load(icon_path)
			if loaded_icon is Texture2D:
				icon_texture = loaded_icon
		var index := row if in_place else popup.item_count
		row += 1
		if not in_place:
			if icon_texture != null:
				popup.add_icon_item(icon_texture, item_text, index)
			else:
				popup.add_item(item_text, index)
			popup.set_item_disabled(index, true)
		elif popup.get_item_text(index) != item_text:
			popup.set_item_text(index, item_text)
		popup.set_item_tooltip(index, "%s: %d (%+d per day)" % [display_name, amount, daily])
		popup.set_item_metadata(index, {
			"resource_id": resource_id,
			"display_name": display_name,
			"amount": amount,
			"daily_income": daily,
			"icon_path": icon_path if icon_texture != null else "",
		})
	_sync_inline_icons()


## True when the popup already lists exactly the resources a rebuild would
## list, in order and with the same icons.
func _popup_lists_current_resources(popup: PopupMenu) -> bool:
	var index := 0
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var definition := OverworldRules.resource_definition(resource_id)
		if definition.is_empty() or String(definition.get("display_name", "")).strip_edges() == "":
			continue
		if index >= popup.item_count:
			return false
		var metadata: Variant = popup.get_item_metadata(index)
		var icon_path := OverworldRules.resource_icon_path(resource_id)
		var icon: Texture2D = load(icon_path) as Texture2D if icon_path != "" else null
		if not (metadata is Dictionary) or String(metadata.get("resource_id", "")) != resource_id or popup.get_item_icon(index) != icon:
			return false
		index += 1
	return index == popup.item_count


func _on_popup_about_to_show() -> void:
	_return_focus_on_hide = false


func _on_popup_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_focus_on_hide = true


func _on_popup_hidden() -> void:
	if _return_focus_on_hide and is_inside_tree() and is_visible_in_tree():
		call_deferred("grab_focus")
	_return_focus_on_hide = false
