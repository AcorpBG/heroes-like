class_name ResourceStockpileMenu
extends MenuButton

const OverworldRules = preload("res://scripts/core/OverworldRules.gd")

const SNAPSHOT_SCHEMA := "resource_stockpile_icon_menu_v1"
const COMPACT_LABEL := "Stores"
const POPUP_ICON_WIDTH := 24

var _normal_summary := ""
var _full_summary := ""
var _compact_mode := false
var _return_focus_on_hide := false
var _resource_values: Dictionary = {}


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


func sync_stockpile(resources: Variant, normal_summary: String, full_summary: String) -> void:
	_resource_values.clear()
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var amount := int((resources as Dictionary).get(resource_id, 0)) if resources is Dictionary else 0
		_resource_values[resource_id] = amount
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
	text = COMPACT_LABEL if _compact_mode else (_normal_summary if _normal_summary != "" else COMPACT_LABEL)
	tooltip_text = _full_summary


func _rebuild_popup() -> void:
	var popup: PopupMenu = get_popup()
	popup.clear()
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var definition := OverworldRules.resource_definition(resource_id)
		if definition.is_empty():
			continue
		var display_name := String(definition.get("display_name", "")).strip_edges()
		if display_name == "":
			continue
		var amount := int(_resource_values.get(resource_id, 0))
		var item_text := "%s  %d" % [display_name, amount]
		var icon_path := OverworldRules.resource_icon_path(resource_id)
		var icon_texture: Texture2D = null
		if icon_path != "":
			var loaded_icon = load(icon_path)
			if loaded_icon is Texture2D:
				icon_texture = loaded_icon
		var index := popup.item_count
		if icon_texture != null:
			popup.add_icon_item(icon_texture, item_text, index)
		else:
			popup.add_item(item_text, index)
		popup.set_item_disabled(index, true)
		popup.set_item_tooltip(index, "%s: %d" % [display_name, amount])
		popup.set_item_metadata(index, {
			"resource_id": resource_id,
			"display_name": display_name,
			"amount": amount,
			"icon_path": icon_path if icon_texture != null else "",
		})


func _on_popup_about_to_show() -> void:
	_return_focus_on_hide = false


func _on_popup_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_focus_on_hide = true


func _on_popup_hidden() -> void:
	if _return_focus_on_hide and is_inside_tree() and is_visible_in_tree():
		call_deferred("grab_focus")
	_return_focus_on_hide = false
