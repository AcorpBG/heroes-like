extends ConfirmationDialog
## The maps built earlier, to play one again (docs/skirmish-setup-screen.md). A
## view only: the main menu fills it and acts on its signals.

signal map_selected(scenario_id: String)
signal play_requested(scenario_id: String)

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
const CARD_WIDTH := 560

var _list: ItemList
var _details: Label
var _ids: Array = []

func _ready() -> void:
	title = ""
	borderless = true
	exclusive = true
	dialog_hide_on_ok = false
	add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	add_theme_constant_override("buttons_min_width", 120)
	add_theme_constant_override("buttons_min_height", 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var heading := Label.new()
	heading.text = "Built maps"
	VisualKit.apply_label(heading, "gold", 20)
	box.add_child(heading)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(CARD_WIDTH - 60, 220)
	VisualKit.apply_item_list(_list)
	_list.item_selected.connect(func(index: int): map_selected.emit(String(_ids[index])))
	_list.item_activated.connect(func(index: int): play_requested.emit(String(_ids[index])))
	box.add_child(_list)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(CARD_WIDTH - 60, 60)
	VisualKit.apply_label(_details, "body", 13)
	box.add_child(_details)
	get_ok_button().text = "Play"
	get_cancel_button().text = "Close"
	confirmed.connect(func():
		var chosen := _list.get_selected_items()
		if not chosen.is_empty():
			play_requested.emit(String(_ids[chosen[0]])))
	canceled.connect(func(): VisualKit.hide_exclusive_dialog(self))

## entries: [{scenario_id, label}]; selected_id is the one shown as chosen.
func open_maps(entries: Array, selected_id: String) -> void:
	add_theme_stylebox_override("panel", VisualKit.info_card_style())
	VisualKit.apply_button(get_ok_button(), "primary", 120, 32)
	VisualKit.apply_button(get_cancel_button(), "secondary", 120, 32)
	_list.clear()
	_ids.clear()
	for entry in entries:
		_ids.append(String(entry.get("scenario_id", "")))
		_list.add_item(String(entry.get("label", entry.get("scenario_id", "Map"))))
		if String(entry.get("scenario_id", "")) == selected_id:
			_list.select(_list.item_count - 1)
	reset_size()
	popup_centered(Vector2i(CARD_WIDTH, 0))
	_list.grab_focus()

## What the main menu says about the chosen map, and whether it can be played.
func show_details(text: String, playable: bool) -> void:
	_details.text = text
	get_ok_button().disabled = not playable
