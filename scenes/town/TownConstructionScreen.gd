class_name TownConstructionScreen
extends Control

## Full-screen Town construction board. Presents the fixed slot board from
## TownConstructionBoard and emits intents; TownShell owns every rule call,
## construction commit, market hand-off and scenic preview.

signal build_requested(building_id: String)
signal trade_requested(building_id: String)
signal view_in_town_requested(building_id: String)
signal close_requested
signal selection_changed(building_id: String)

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const BLUR_SHADER := preload("res://scenes/town/construction_backdrop_blur.gdshader")

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
# Below this logical size the board keeps its approved proportions and is
# scaled down as a whole instead of squeezing tiles until labels clip.
const MIN_LAYOUT_SIZE := Vector2(1600.0, 900.0)
const COMPACT_HEADER_WIDTH := 1800.0
const HEADER_HEIGHT := 56.0
const GAP := 12.0
const ROW_GAP := 8.0
const LABEL_HEIGHT := 22.0
const TILE_BG := Color(0.055, 0.075, 0.09, 0.93)
const TILE_BORDER := Color(0.47, 0.70, 0.75, 0.34)
const TILE_HOVER := Color(0.94, 0.78, 0.43, 0.85)
const TILE_SELECTED := Color(0.94, 0.78, 0.43, 1.0)
const GOLD_TEXT := Color(0.97, 0.88, 0.61, 1.0)
const TITLE_TEXT := Color(0.98, 0.96, 0.90, 1.0)
const BODY_TEXT := Color(0.86, 0.90, 0.93, 1.0)
const MUTED_TEXT := Color(0.58, 0.64, 0.69, 1.0)
const TEAL_TEXT := Color(0.62, 0.82, 0.84, 1.0)
const PANEL_BG := Color(0.043, 0.059, 0.071, 0.95)
const PANEL_BORDER := Color(0.88, 0.72, 0.40, 0.5)
const CARD_BG := Color(0.078, 0.106, 0.125, 0.92)
const STATUS_PALETTE := {
	"ready": [Color(0.133, 0.204, 0.122), Color(0.57, 0.74, 0.44), Color(0.84, 0.92, 0.78)],
	"short": [Color(0.22, 0.125, 0.11), Color(0.86, 0.45, 0.37), Color(0.95, 0.78, 0.72)],
	"trade": [Color(0.086, 0.157, 0.169), Color(0.44, 0.76, 0.79), Color(0.77, 0.93, 0.94)],
	"locked": [Color(0.11, 0.125, 0.15), Color(0.35, 0.39, 0.44), Color(0.66, 0.71, 0.75)],
	"complete": [Color(0.204, 0.165, 0.086), Color(0.88, 0.72, 0.40), Color(0.97, 0.88, 0.61)],
	"tomorrow": [Color(0.125, 0.145, 0.169), Color(0.49, 0.54, 0.59), Color(0.78, 0.82, 0.87)],
}
const ASSISTED_STATUS_PALETTE := {
	"ready": [Color(0.078, 0.141, 0.188), Color(0.30, 0.72, 0.96), Color(0.75, 0.90, 1.0)],
	"short": [Color(0.20, 0.13, 0.06), Color(0.94, 0.58, 0.20), Color(1.0, 0.85, 0.66)],
}
const STATUS_LEGEND := [["ready", "Can build"], ["trade", "Market can cover"], ["short", "Short of resources"], ["locked", "Locked"], ["complete", "Fully built"]]
const STAT_BETTER_KEYS := ["Attack", "Defense", "Damage", "Health", "Speed", "Initiative", "Growth"]
const BETTER_STAT := Color(0.62, 0.90, 0.45)
const ASSISTED_BETTER_STAT := Color(0.45, 0.80, 1.0)

var _board: Dictionary = {}
var _resources: Dictionary = {}
var _faction_id := ""
var _selected_slot_id := ""
var _selected_option_index := -1
var _peek := false
var _tiles: Dictionary = {}
var _texture_cache: Dictionary = {}

var _backdrop: TextureRect
var _shade: ColorRect
var _frame: Control
var _crest: TextureRect
var _town_label: Label
var _town_subtitle: Label
var _header_divider: ColorRect
var _today_chip: PanelContainer
var _today_label: Label
var _resource_row: HBoxContainer
var _close_button: Button
var _board_column: VBoxContainer
var _row_boxes: Dictionary = {}
var _row_labels: Dictionary = {}
var _legend_row: HBoxContainer
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
var _detail_kicker: Label
var _detail_title: Label
var _detail_desc: Label
var _detail_content: VBoxContainer
var _note_panel: PanelContainer
var _note_label: Label
var _cost_title: Label
var _cost_flow: HFlowContainer
var _req_flow: HFlowContainer
var _primary_button: Button
var _trade_button: Button
var _view_button: Button
var _peek_bar: PanelContainer
var _peek_label: Label
var _peek_back_button: Button

func _init() -> void:
	name = "TownConstructionScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visible = false
	_build_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

# --- public API -------------------------------------------------------------------

func configure(board: Dictionary, resources: Dictionary, backdrop_path: String) -> void:
	_board = board
	_resources = resources.duplicate(true)
	_faction_id = String(board.get("faction_id", ""))
	_backdrop.texture = _texture(backdrop_path)
	_crest.texture = _texture(TownRulesScript.faction_crest_icon_path(_faction_id))
	_town_label.text = String(board.get("town_name", "Town"))
	_town_subtitle.text = String(board.get("faction_name", ""))
	_refresh_today_chip(_frame.size.x > 0.0 and _frame.size.x < COMPACT_HEADER_WIDTH)
	_rebuild_resources()
	_rebuild_board()
	if Board.slot_by_id(_board, _selected_slot_id).is_empty():
		_selected_slot_id = _default_slot_id()
		_selected_option_index = -1
	_refresh_selection()
	_layout()

func board() -> Dictionary:
	return _board

func select_slot(slot_id: String, option_index: int = -1) -> bool:
	if Board.slot_by_id(_board, slot_id).is_empty():
		return false
	_selected_slot_id = slot_id
	_selected_option_index = option_index
	_refresh_selection()
	return true

## Selects the slot that owns building_id; for an open exclusive choice also
## selects the matching option.
func select_building(building_id: String) -> bool:
	var slot := Board.slot_for_building(_board, building_id)
	if slot.is_empty():
		return false
	var option_index := -1
	var options: Array = slot.get("options", [])
	for index in range(options.size()):
		if String(options[index].get("building_id", "")) == building_id:
			option_index = index
	return select_slot(String(slot.get("id", "")), option_index)

func selected_slot_id() -> String:
	return _selected_slot_id

func selected_slot() -> Dictionary:
	return Board.slot_by_id(_board, _selected_slot_id)

## The building the primary action would construct, or "" when nothing can be
## ordered from the current selection.
func selected_building_id() -> String:
	var slot := selected_slot()
	if slot.is_empty():
		return ""
	if String(slot.get("kind", "")) == "choice":
		var options: Array = slot.get("options", [])
		if _selected_option_index >= 0 and _selected_option_index < options.size():
			return String(options[_selected_option_index].get("building_id", ""))
		return ""
	return String(slot.get("next_id", ""))

func focus_initial() -> void:
	if _peek:
		_peek_back_button.grab_focus()
		return
	var tile: Button = _tiles.get(_selected_slot_id)
	if tile != null and tile.is_visible_in_tree():
		tile.grab_focus()
	elif _close_button.is_visible_in_tree():
		_close_button.grab_focus()

func focus_surfaces() -> Array:
	return [_peek_bar] if _peek else [_frame]

func set_peek(enabled: bool) -> void:
	_peek = enabled
	_frame.visible = not enabled
	_backdrop.visible = not enabled
	_shade.visible = not enabled
	_peek_bar.visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP
	var slot := selected_slot()
	_peek_label.text = "Previewing %s in %s" % [_building_name(_peek_building_id(slot)), String(_board.get("town_name", "town"))]
	_layout()

func is_peeking() -> bool:
	return _peek

func handle_cancel() -> void:
	if _peek:
		set_peek(false)
		view_in_town_requested.emit("")
		focus_initial()
	else:
		close_requested.emit()

func validation_snapshot() -> Dictionary:
	var rows := []
	for row in _board.get("rows", []):
		var slots := []
		for slot in row.get("slots", []):
			var tile: Button = _tiles.get(String(slot.get("id", "")))
			slots.append({
				"id": String(slot.get("id", "")),
				"kind": String(slot.get("kind", "")),
				"status": String(slot.get("status", "")),
				"status_text": String(slot.get("status_text", "")),
				"title": String(slot.get("title", "")),
				"next_id": String(slot.get("next_id", "")),
				"done_count": int(slot.get("done_count", 0)),
				"stage_count": int(slot.get("stage_count", 0)),
				"building_ids": slot.get("building_ids", []).duplicate(),
				"tile_rect": _visual_rect(tile),
				"tile_visible": tile != null and tile.is_visible_in_tree(),
				"tile_has_art": tile != null and _tile_has_art(tile),
			})
		rows.append({"id": String(row.get("id", "")), "title": String(row.get("title", "")), "slots": slots})
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return {
		"schema": "town_construction_screen_v1",
		"open": visible,
		"peek": _peek,
		"town_id": String(_board.get("town_id", "")),
		"faction_id": _faction_id,
		"row_order": rows.map(func(row): return String(row.id)),
		"rows": rows,
		"slot_count": int(_board.get("slot_count", 0)),
		"unassigned_building_ids": _board.get("unassigned_building_ids", []).duplicate(),
		"selected_slot_id": _selected_slot_id,
		"selected_building_id": selected_building_id(),
		"detail_title": _detail_title.text,
		"detail_kicker": _detail_kicker.text,
		"primary_text": _primary_button.text,
		"primary_visible": _primary_button.visible,
		"primary_disabled": _primary_button.disabled,
		"trade_visible": _trade_button.visible,
		"today_text": _today_label.text,
		"built_today": bool(_board.get("built_today", false)),
		"screen_rect": get_global_rect(),
		"detail_rect": _visual_rect(_detail_panel),
		"board_rect": _visual_rect(_board_column),
		"layout_scale": _frame.scale.x,
		"focus_inside": focus_owner != null and is_ancestor_of(focus_owner),
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
	}

func _visual_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var transform := control.get_global_transform()
	return Rect2(transform.origin, control.size * transform.get_scale())

func validation_press_primary() -> bool:
	if not _primary_button.visible or _primary_button.disabled:
		return false
	_primary_button.emit_signal("pressed")
	return true

func validation_press_option(index: int) -> bool:
	var slot := selected_slot()
	if String(slot.get("kind", "")) != "choice":
		return false
	select_slot(_selected_slot_id, index)
	return validation_press_primary()

# --- construction ---------------------------------------------------------------------

func _build_controls() -> void:
	_backdrop = TextureRect.new()
	_backdrop.name = "ConstructionBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BLUR_SHADER
	_backdrop.material = material
	add_child(_backdrop)
	_shade = ColorRect.new()
	_shade.name = "ConstructionShade"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.02, 0.03, 0.04, 0.35)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	_frame = Control.new()
	_frame.name = "ConstructionFrame"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_build_header()
	_build_body()
	_build_peek_bar()

func _build_header() -> void:
	var header := PanelContainer.new()
	header.name = "ConstructionHeader"
	header.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.047, 0.059, 0.95), Color(0.88, 0.72, 0.40, 0.5), 0, [0, 0, 0, 1]))
	_frame.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)
	_crest = TextureRect.new()
	_crest.name = "FactionCrest"
	_crest.custom_minimum_size = Vector2(40, 40)
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_crest)
	_town_label = _label("Town", TITLE_TEXT, 22)
	_town_label.name = "TownName"
	row.add_child(_town_label)
	_town_subtitle = _label("", MUTED_TEXT, 13)
	row.add_child(_town_subtitle)
	_header_divider = ColorRect.new()
	_header_divider.custom_minimum_size = Vector2(1, 28)
	_header_divider.color = Color(0.88, 0.72, 0.40, 0.35)
	_header_divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_header_divider)
	var title := _label("CONSTRUCTION", GOLD_TEXT, 16)
	title.name = "ConstructionTitle"
	row.add_child(title)
	_today_chip = PanelContainer.new()
	_today_chip.name = "ConstructionTodayChip"
	_today_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_today_chip)
	_today_label = _label("", BODY_TEXT, 13)
	_today_label.name = "ConstructionToday"
	_today_chip.add_child(_today_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_resource_row = HBoxContainer.new()
	_resource_row.name = "ConstructionResources"
	_resource_row.add_theme_constant_override("separation", 14)
	row.add_child(_resource_row)
	_close_button = Button.new()
	_close_button.name = "ConstructionClose"
	_close_button.text = "Close  (Esc)"
	_close_button.tooltip_text = "Return to the town without building."
	_close_button.accessibility_name = "Close construction and return to town"
	FrontierVisualKit.apply_button(_close_button, "secondary", 128, 36, 13)
	_close_button.pressed.connect(func(): close_requested.emit())
	row.add_child(_close_button)
	header.set_meta("layout_role", "header")

func _build_body() -> void:
	_board_column = VBoxContainer.new()
	_board_column.name = "ConstructionBoard"
	_board_column.add_theme_constant_override("separation", int(ROW_GAP))
	_board_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_board_column)
	for row_id in ["town", "army", "growth_training", "signature"]:
		if row_id == "growth_training":
			var label_row := HBoxContainer.new()
			label_row.name = "GrowthTrainingLabels"
			label_row.add_theme_constant_override("separation", int(GAP))
			_board_column.add_child(label_row)
			_row_labels["growth"] = _row_header(label_row, "growth")
			var gap_label := Control.new()
			gap_label.name = "GrowthTrainingLabelGap"
			label_row.add_child(gap_label)
			_row_labels["training"] = _row_header(label_row, "training")
			var tiles_row := HBoxContainer.new()
			tiles_row.name = "GrowthTrainingTiles"
			tiles_row.add_theme_constant_override("separation", int(GAP))
			_board_column.add_child(tiles_row)
			var growth_box := HBoxContainer.new()
			growth_box.name = "GrowthTiles"
			growth_box.add_theme_constant_override("separation", int(GAP))
			tiles_row.add_child(growth_box)
			var divider_holder := CenterContainer.new()
			divider_holder.name = "GrowthTrainingDivider"
			tiles_row.add_child(divider_holder)
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(1, 120)
			divider.color = Color(0.88, 0.72, 0.40, 0.25)
			divider_holder.add_child(divider)
			var training_box := HBoxContainer.new()
			training_box.name = "TrainingTiles"
			training_box.add_theme_constant_override("separation", int(GAP))
			tiles_row.add_child(training_box)
			_row_boxes["growth"] = growth_box
			_row_boxes["training"] = training_box
			continue
		var header_row := HBoxContainer.new()
		header_row.name = "%sLabel" % row_id.capitalize()
		_board_column.add_child(header_row)
		_row_labels[row_id] = _row_header(header_row, row_id)
		var box := HBoxContainer.new()
		box.name = "%sTiles" % row_id.capitalize()
		box.add_theme_constant_override("separation", int(GAP))
		_board_column.add_child(box)
		_row_boxes[row_id] = box
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_column.add_child(filler)
	_legend_row = HBoxContainer.new()
	_legend_row.name = "ConstructionLegend"
	_legend_row.add_theme_constant_override("separation", 20)
	_board_column.add_child(_legend_row)
	for entry in STATUS_LEGEND:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 7)
		var swatch := PanelContainer.new()
		swatch.custom_minimum_size = Vector2(18, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.set_meta("status", String(entry[0]))
		cell.add_child(swatch)
		cell.add_child(_label(String(entry[1]), MUTED_TEXT, 12))
		_legend_row.add_child(cell)
	var legend_spacer := Control.new()
	legend_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend_row.add_child(legend_spacer)
	_legend_row.add_child(_label("Arrows move · Enter selects · B builds · V views in town · Esc closes", MUTED_TEXT, 12))

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "ConstructionDetail"
	_detail_panel.add_theme_stylebox_override("panel", _flat(PANEL_BG, PANEL_BORDER, 10, [1, 1, 1, 1], 24))
	_frame.add_child(_detail_panel)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(detail_column)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "ConstructionDetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(_detail_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail_body)
	_detail_kicker = _label("", TEAL_TEXT, 12)
	_detail_kicker.name = "DetailKicker"
	_detail_body.add_child(_detail_kicker)
	_detail_title = _label("", TITLE_TEXT, 26)
	_detail_title.name = "DetailTitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(_detail_title)
	_detail_desc = _label("", BODY_TEXT, 14)
	_detail_desc.name = "DetailDescription"
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(_detail_desc)
	_detail_content = VBoxContainer.new()
	_detail_content.name = "DetailContent"
	_detail_content.add_theme_constant_override("separation", 12)
	_detail_body.add_child(_detail_content)

	var footer := VBoxContainer.new()
	footer.name = "ConstructionDecision"
	footer.add_theme_constant_override("separation", 10)
	detail_column.add_child(footer)
	_note_panel = PanelContainer.new()
	_note_panel.name = "ConstructionNote"
	_note_panel.add_theme_stylebox_override("panel", _flat(Color(0.204, 0.165, 0.086, 0.45), Color(0.88, 0.72, 0.40, 0.4), 6, [1, 1, 1, 1], 10))
	footer.add_child(_note_panel)
	_note_label = _label("", Color(0.95, 0.90, 0.77), 13)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_panel.add_child(_note_label)
	_cost_title = _label("COST · NEED / HAVE", MUTED_TEXT, 11)
	footer.add_child(_cost_title)
	_cost_flow = HFlowContainer.new()
	_cost_flow.name = "ConstructionCost"
	_cost_flow.add_theme_constant_override("h_separation", 8)
	_cost_flow.add_theme_constant_override("v_separation", 8)
	footer.add_child(_cost_flow)
	_req_flow = HFlowContainer.new()
	_req_flow.name = "ConstructionRequirements"
	_req_flow.add_theme_constant_override("h_separation", 8)
	_req_flow.add_theme_constant_override("v_separation", 6)
	footer.add_child(_req_flow)
	var buttons := HBoxContainer.new()
	buttons.name = "ConstructionButtons"
	buttons.add_theme_constant_override("separation", 10)
	footer.add_child(buttons)
	_primary_button = Button.new()
	_primary_button.name = "ConstructionBuild"
	_primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FrontierVisualKit.apply_button(_primary_button, "primary", 200, 48, 15)
	_primary_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_primary_button.clip_text = true
	_primary_button.pressed.connect(_on_primary_pressed)
	buttons.add_child(_primary_button)
	_trade_button = Button.new()
	_trade_button.name = "ConstructionTrade"
	_trade_button.text = "Trade"
	_trade_button.tooltip_text = "Open the town market to cover the missing resources. Nothing is spent until you trade."
	FrontierVisualKit.apply_button(_trade_button, "secondary", 96, 48, 13)
	_trade_button.pressed.connect(func(): trade_requested.emit(selected_building_id()))
	buttons.add_child(_trade_button)
	_view_button = Button.new()
	_view_button.name = "ConstructionViewInTown"
	_view_button.text = "View in town"
	_view_button.tooltip_text = "Fold the board away and see where this building stands in the town. Nothing is built."
	FrontierVisualKit.apply_button(_view_button, "secondary", 136, 48, 13)
	_view_button.pressed.connect(_on_view_pressed)
	buttons.add_child(_view_button)

func _build_peek_bar() -> void:
	_peek_bar = PanelContainer.new()
	_peek_bar.name = "ConstructionPeekBar"
	_peek_bar.visible = false
	_peek_bar.add_theme_stylebox_override("panel", _flat(PANEL_BG, PANEL_BORDER, 10, [1, 1, 1, 1], 14))
	add_child(_peek_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_peek_bar.add_child(row)
	_peek_label = _label("", BODY_TEXT, 14)
	_peek_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_peek_label)
	_peek_back_button = Button.new()
	_peek_back_button.name = "ConstructionPeekBack"
	_peek_back_button.text = "Back to construction  (Esc)"
	FrontierVisualKit.apply_button(_peek_back_button, "primary", 230, 40, 13)
	_peek_back_button.pressed.connect(handle_cancel)
	row.add_child(_peek_back_button)

func _row_header(parent: HBoxContainer, row_id: String) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = "%sHeader" % row_id.capitalize()
	header.add_theme_constant_override("separation", 12)
	header.custom_minimum_size.y = LABEL_HEIGHT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)
	var title := _label("", GOLD_TEXT, 15)
	title.name = "Title"
	header.add_child(title)
	var subtitle := _label("", MUTED_TEXT, 12)
	subtitle.name = "Subtitle"
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.clip_text = true
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(subtitle)
	return header

# --- board -------------------------------------------------------------------------

func _rebuild_board() -> void:
	for box in _row_boxes.values():
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_tiles.clear()
	for row in _board.get("rows", []):
		var row_id := String(row.get("id", ""))
		var header: HBoxContainer = _row_labels.get(row_id)
		if header != null:
			(header.get_node("Title") as Label).text = String(row.get("title", "")).to_upper()
			(header.get_node("Subtitle") as Label).text = String(row.get("subtitle", ""))
		var box: HBoxContainer = _row_boxes.get(row_id)
		if box == null:
			continue
		for slot in row.get("slots", []):
			var tile := _make_tile(slot, row_id == "signature")
			box.add_child(tile)
			_tiles[String(slot.get("id", ""))] = tile
	for cell in _legend_row.get_children():
		for swatch in cell.get_children():
			if swatch is PanelContainer and swatch.has_meta("status"):
				var colors := _status_colors(String(swatch.get_meta("status")))
				swatch.add_theme_stylebox_override("panel", _flat(colors[0], colors[1], 2, [0, 2, 0, 0]))

func _make_tile(slot: Dictionary, wide: bool) -> Button:
	var tile := Button.new()
	tile.name = "Slot_%s" % String(slot.get("id", ""))
	tile.focus_mode = Control.FOCUS_ALL
	tile.clip_contents = true
	tile.set_meta("slot_id", String(slot.get("id", "")))
	tile.set_meta("wide", wide)
	tile.tooltip_text = _tile_tooltip(slot)
	tile.accessibility_name = "%s: %s" % [String(slot.get("title", "")), String(slot.get("status_text", ""))]
	tile.accessibility_description = String(slot.get("status_detail", ""))
	tile.pressed.connect(_on_tile_pressed.bind(String(slot.get("id", ""))))
	tile.focus_entered.connect(_on_tile_focused.bind(String(slot.get("id", ""))))
	var column := VBoxContainer.new()
	column.name = "Content"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var dim := not bool(slot.get("built", false))
	if wide:
		var wide_row := HBoxContainer.new()
		wide_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wide_row.add_theme_constant_override("separation", 14)
		wide_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(wide_row)
		var art := _art_rect(String(slot.get("art_building_id", "")), dim)
		art.custom_minimum_size = Vector2(110, 0)
		wide_row.add_child(art)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.alignment = BoxContainer.ALIGNMENT_CENTER
		text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wide_row.add_child(text_column)
		var name_label := _label(String(slot.get("title", "")), TITLE_TEXT, 15)
		name_label.name = "Name"
		text_column.add_child(name_label)
		var blurb := _label(String(slot.get("blurb", "")), TEAL_TEXT, 12)
		blurb.name = "Blurb"
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.max_lines_visible = 2
		text_column.add_child(blurb)
	elif String(slot.get("kind", "")) == "choice":
		var halves := HBoxContainer.new()
		halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
		halves.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halves.add_theme_constant_override("separation", 2)
		column.add_child(halves)
		for option in slot.get("options", []):
			var half := VBoxContainer.new()
			half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			half.mouse_filter = Control.MOUSE_FILTER_IGNORE
			halves.add_child(half)
			var art := _art_rect(String(option.get("building_id", "")), true)
			art.size_flags_vertical = Control.SIZE_EXPAND_FILL
			half.add_child(art)
			var option_label := _label(String(option.get("unit_name", "")), Color(0.90, 0.93, 0.95), 10)
			option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			option_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			option_label.max_lines_visible = 2
			option_label.custom_minimum_size.y = 30
			half.add_child(option_label)
		var or_badge := PanelContainer.new()
		or_badge.name = "OrBadge"
		or_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		or_badge.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.07, 0.08), Color(0.88, 0.72, 0.40, 0.75), 13, [1, 1, 1, 1], 4))
		var or_label := _label("or", GOLD_TEXT, 11)
		or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		or_badge.add_child(or_label)
		tile.add_child(or_badge)
	else:
		var art := _art_rect(String(slot.get("art_building_id", "")), dim)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(art)
		var name_label := _label(String(slot.get("title", "")), TITLE_TEXT, 13)
		name_label.name = "Name"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.custom_minimum_size.y = 34
		column.add_child(name_label)
		if String(slot.get("blurb", "")) != "":
			var blurb := _label(String(slot.get("blurb", "")), TEAL_TEXT, 12)
			blurb.name = "Blurb"
			blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blurb.custom_minimum_size.y = 20
			column.add_child(blurb)
	var status := _status_strip(slot)
	column.add_child(status)
	if int(slot.get("tier", 0)) > 0:
		var badge := PanelContainer.new()
		badge.name = "TierBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(7, 7)
		badge.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.047, 0.059, 0.86), Color(0.88, 0.72, 0.40, 0.6), 4, [1, 1, 1, 1], 4))
		badge.add_child(_label(String(slot.get("tier_label", "")), GOLD_TEXT, 13))
		tile.add_child(badge)
	if int(slot.get("stage_count", 1)) > 1:
		var pips := ConstructionPips.new()
		pips.name = "StagePips"
		pips.done = int(slot.get("done_count", 0))
		pips.total = int(slot.get("stage_count", 1))
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pips)
	_style_tile(tile, false)
	return tile

func _status_strip(slot: Dictionary) -> PanelContainer:
	var status_id := String(slot.get("status", "locked"))
	var colors := _status_colors(status_id)
	var strip := PanelContainer.new()
	strip.name = "Status"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.custom_minimum_size.y = 30
	strip.add_theme_stylebox_override("panel", _flat(colors[0], colors[1], 0, [0, 2, 0, 0], 4))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	var glyph := ConstructionStatusGlyph.new()
	glyph.status = status_id
	glyph.color = colors[2]
	glyph.custom_minimum_size = Vector2(14, 14)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var status_text := String(slot.get("status_text", ""))
	var text := _label(status_text, colors[2], 12 if status_text.length() <= 16 else (11 if status_text.length() <= 19 else 10))
	text.name = "StatusText"
	row.add_child(text)
	return strip

func _art_rect(building_id: String, dim: bool) -> TextureRect:
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = _texture(TownRulesScript.building_icon_path(building_id, _faction_id))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if dim:
		art.modulate = Color(0.48, 0.48, 0.50, 0.92)
	return art

func _tile_has_art(tile: Button) -> bool:
	for node in tile.find_children("Art", "TextureRect", true, false):
		if (node as TextureRect).texture != null:
			return true
	return false

func _style_tile(tile: Button, selected: bool) -> void:
	var border := TILE_SELECTED if selected else TILE_BORDER
	var width := 2 if selected else 1
	var normal := _flat(TILE_BG, border, 7, [width, width, width, width])
	if selected:
		normal.shadow_color = Color(0.94, 0.78, 0.43, 0.22)
		normal.shadow_size = 10
	var hover := _flat(TILE_BG.lightened(0.04), TILE_SELECTED if selected else TILE_HOVER, 7, [width, width, width, width])
	var focus := _flat(Color(0, 0, 0, 0), Color(0.97, 0.88, 0.61), 8, [2, 2, 2, 2])
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	focus.draw_center = false
	tile.add_theme_stylebox_override("normal", normal)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", hover)
	tile.add_theme_stylebox_override("hover_pressed", hover)
	tile.add_theme_stylebox_override("focus", focus)
	tile.add_theme_stylebox_override("disabled", normal)

func _tile_tooltip(slot: Dictionary) -> String:
	var lines := [String(slot.get("title", ""))]
	lines.append(String(slot.get("status_text", "")))
	if String(slot.get("status_detail", "")) != "":
		lines.append(String(slot.get("status_detail", "")))
	return "\n".join(lines)

# --- selection and detail ---------------------------------------------------------

func _default_slot_id() -> String:
	var first := ""
	for slot in Board.ordered_slots(_board):
		if first == "":
			first = String(slot.get("id", ""))
		if String(slot.get("status", "")) == Board.STATUS_READY:
			return String(slot.get("id", ""))
	return first

func _on_tile_pressed(slot_id: String) -> void:
	if slot_id != _selected_slot_id:
		_selected_option_index = -1
	_selected_slot_id = slot_id
	_refresh_selection()

func _on_tile_focused(slot_id: String) -> void:
	if slot_id == _selected_slot_id:
		return
	_selected_slot_id = slot_id
	_selected_option_index = -1
	_refresh_selection()

func _refresh_selection() -> void:
	for slot_id in _tiles.keys():
		_style_tile(_tiles[slot_id], slot_id == _selected_slot_id)
	_rebuild_detail()
	_wire_focus()
	selection_changed.emit(_peek_building_id(selected_slot()))

func _rebuild_detail() -> void:
	for child in _detail_content.get_children():
		_detail_content.remove_child(child)
		child.queue_free()
	for child in _cost_flow.get_children():
		_cost_flow.remove_child(child)
		child.queue_free()
	for child in _req_flow.get_children():
		_req_flow.remove_child(child)
		child.queue_free()
	var slot := selected_slot()
	if slot.is_empty():
		_detail_title.text = "No construction"
		_detail_kicker.text = ""
		_detail_desc.text = ""
		_primary_button.visible = false
		_trade_button.visible = false
		_note_panel.visible = false
		_cost_title.visible = false
		return
	var kind := String(slot.get("kind", ""))
	var focus_id := String(slot.get("next_id", "")) if String(slot.get("next_id", "")) != "" else String(slot.get("current_id", ""))
	var focus_building := ContentService.get_building(focus_id)
	_detail_kicker.text = _kicker_for(slot).to_upper()
	_detail_title.text = String(focus_building.get("name", slot.get("title", "")))
	_detail_desc.text = String(focus_building.get("description", ""))
	var note := ""
	match kind:
		"choice":
			_detail_title.text = "Tier %s: choose a line" % String(slot.get("tier_label", ""))
			_detail_desc.text = ""
			_detail_content.add_child(_choice_view(slot))
			note = "Permanent choice: building one dwelling removes the other from this town."
		"line":
			_detail_content.add_child(_stage_strip(slot))
			_detail_content.add_child(_now_next_view(slot))
		"dwelling":
			_detail_content.add_child(_dwelling_view(slot))
			var forgone: Array = slot.get("forgone_unit_names", [])
			if not forgone.is_empty():
				note = "Forgone in this town: %s." % ", ".join(forgone)
			var rare := _rare_cost_resource(String(slot.get("next_id", slot.get("current_id", ""))))
			if rare != "":
				note = "Needs %s to build and to recruit." % Board.resource_name(rare)
		_:
			_detail_content.add_child(_single_view(slot))
	if String(slot.get("status", "")) == Board.STATUS_LOCKED and note == "":
		note = String(slot.get("status_detail", ""))
	_note_label.text = note
	_note_panel.visible = note != ""
	var has_next := String(slot.get("next_id", "")) != ""
	_cost_title.visible = has_next
	_cost_title.text = "COST · EITHER DWELLING · NEED / HAVE" if kind == "choice" else "COST · NEED / HAVE"
	if has_next:
		_fill_cost(slot.get("cost", {}))
		_fill_requirements(String(slot.get("next_id", "")))
	_refresh_buttons(slot)

func _kicker_for(slot: Dictionary) -> String:
	var row_id := String(slot.get("row_id", ""))
	match String(slot.get("kind", "")):
		"choice":
			return "Tier %s dwelling · choose one" % String(slot.get("tier_label", ""))
		"dwelling":
			return "Tier %s dwelling%s" % [String(slot.get("tier_label", "")), " · chosen" if not slot.get("forgone_unit_names", []).is_empty() else ""]
		"line":
			var line_title := String(slot.get("line_title", "")) if String(slot.get("line_title", "")) != "" else String(slot.get("title", ""))
			return "%s line · stage %d of %d" % [line_title, mini(int(slot.get("done_count", 0)) + 1, int(slot.get("stage_count", 1))), int(slot.get("stage_count", 1))]
	for row in _board.get("rows", []):
		if String(row.get("id", "")) == row_id:
			return String(row.get("title", ""))
	return ""

func _refresh_buttons(slot: Dictionary) -> void:
	var kind := String(slot.get("kind", ""))
	var status_id := String(slot.get("status", ""))
	var next_name := _building_name(String(slot.get("next_id", "")))
	_trade_button.visible = status_id == Board.STATUS_TRADE
	_view_button.visible = _peek_building_id(slot) != ""
	if String(slot.get("next_id", "")) == "":
		_primary_button.visible = true
		_primary_button.disabled = true
		_primary_button.text = "Fully built"
		_primary_button.tooltip_text = "Every stage of this slot stands in this town."
		return
	_primary_button.visible = true
	var building_id := selected_building_id()
	var verb := String(slot.get("verb", "Build"))
	match status_id:
		Board.STATUS_READY:
			if kind == "choice":
				_primary_button.disabled = building_id == ""
				var option_name := ""
				for option in slot.get("options", []):
					if String(option.get("building_id", "")) == building_id:
						option_name = String(option.get("unit_name", ""))
				_primary_button.text = "Build %s" % option_name if building_id != "" else "Pick one of the two lines above"
			else:
				_primary_button.disabled = false
				_primary_button.text = ("Upgrade to %s" if verb == "Upgrade" else "Build %s") % next_name
			_primary_button.tooltip_text = "%s. Spends the cost shown and uses this town's construction for today." % _primary_button.text
		Board.STATUS_TRADE:
			_primary_button.disabled = false
			_primary_button.text = "Open market to cover the cost"
			_primary_button.tooltip_text = String(slot.get("status_detail", ""))
		Board.STATUS_TOMORROW:
			_primary_button.disabled = true
			_primary_button.text = "Next build tomorrow"
			_primary_button.tooltip_text = String(slot.get("status_detail", ""))
		Board.STATUS_LOCKED:
			_primary_button.disabled = true
			_primary_button.text = "Locked · %s" % String(slot.get("status_text", "")).replace("Needs ", "needs ")
			_primary_button.tooltip_text = String(slot.get("status_detail", ""))
		_:
			_primary_button.disabled = true
			_primary_button.text = String(slot.get("status_text", "Resources missing"))
			_primary_button.tooltip_text = String(slot.get("status_detail", ""))

func _on_primary_pressed() -> void:
	var slot := selected_slot()
	var status_id := String(slot.get("status", ""))
	var building_id := selected_building_id()
	if status_id == Board.STATUS_TRADE:
		trade_requested.emit(String(slot.get("next_id", "")))
		return
	if status_id != Board.STATUS_READY or building_id == "":
		return
	build_requested.emit(building_id)

func _on_view_pressed() -> void:
	var building_id := _peek_building_id(selected_slot())
	if building_id == "":
		return
	set_peek(true)
	view_in_town_requested.emit(building_id)
	_peek_back_button.call_deferred("grab_focus")

func _peek_building_id(slot: Dictionary) -> String:
	if slot.is_empty():
		return ""
	if String(slot.get("kind", "")) == "choice":
		var chosen := selected_building_id()
		return chosen if chosen != "" else String(slot.get("next_id", ""))
	return String(slot.get("next_id", ""))

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_B:
			if not _peek and _primary_button.visible and not _primary_button.disabled:
				get_viewport().set_input_as_handled()
				_on_primary_pressed()
		KEY_V:
			if not _peek and _view_button.visible:
				get_viewport().set_input_as_handled()
				_on_view_pressed()
		KEY_1, KEY_2:
			var slot := selected_slot()
			if not _peek and String(slot.get("kind", "")) == "choice":
				get_viewport().set_input_as_handled()
				select_slot(_selected_slot_id, 0 if (event as InputEventKey).keycode == KEY_1 else 1)

# --- keyboard and controller focus ----------------------------------------------------

## Explicit neighbours keep arrow navigation on the visual grid and inside this
## screen; Tab cycles tiles, the decision controls and Close.
func _wire_focus() -> void:
	var grid_rows := []
	for row_ids in [["town"], ["army"], ["growth", "training"], ["signature"]]:
		var row := []
		for row_id in row_ids:
			row.append_array(_row_tiles(row_id))
		if not row.is_empty():
			grid_rows.append(row)
	var detail_controls := []
	_collect_focusables(_detail_panel, detail_controls)
	var detail_entry: Control = detail_controls[0] if not detail_controls.is_empty() else _close_button
	for row_index in range(grid_rows.size()):
		var row: Array = grid_rows[row_index]
		for index in range(row.size()):
			var tile: Control = row[index]
			tile.focus_neighbor_left = tile.get_path_to(row[index - 1]) if index > 0 else NodePath("")
			tile.focus_neighbor_right = tile.get_path_to(row[index + 1]) if index < row.size() - 1 else tile.get_path_to(detail_entry)
			tile.focus_neighbor_top = tile.get_path_to(_nearest_tile(grid_rows[row_index - 1], tile)) if row_index > 0 else tile.get_path_to(_close_button)
			tile.focus_neighbor_bottom = tile.get_path_to(_nearest_tile(grid_rows[row_index + 1], tile)) if row_index < grid_rows.size() - 1 else tile.get_path_to(detail_entry)
	var selected_tile: Control = _tiles.get(_selected_slot_id)
	for control in detail_controls:
		if selected_tile != null:
			control.focus_neighbor_left = control.get_path_to(selected_tile)
	var cycle := []
	for row in grid_rows:
		cycle.append_array(row)
	cycle.append_array(detail_controls)
	cycle.append(_close_button)
	for index in range(cycle.size()):
		var control: Control = cycle[index]
		control.focus_next = control.get_path_to(cycle[(index + 1) % cycle.size()])
		control.focus_previous = control.get_path_to(cycle[(index - 1 + cycle.size()) % cycle.size()])
	if selected_tile != null:
		_close_button.focus_neighbor_bottom = _close_button.get_path_to(selected_tile)

func _row_tiles(row_id: String) -> Array:
	var box: HBoxContainer = _row_boxes.get(row_id)
	return box.get_children().filter(func(child): return child is Button and not child.is_queued_for_deletion()) if box != null else []

func _column_center(tile: Control) -> float:
	var row_id := ""
	for key in _row_boxes.keys():
		if _row_boxes[key] == tile.get_parent():
			row_id = String(key)
	var index := tile.get_index()
	match row_id:
		"signature":
			return (float(index) + 0.5) * 7.0 / 3.0
		"training":
			return float(index) + 4.5
		_:
			return float(index) + 0.5

func _nearest_tile(candidates: Array, from: Control) -> Control:
	var best: Control = candidates[0]
	var best_distance := INF
	var center := _column_center(from)
	for candidate in candidates:
		var distance := absf(_column_center(candidate) - center)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _collect_focusables(node: Node, controls: Array) -> void:
	if node is Control and node != _detail_panel and (node as Control).focus_mode != Control.FOCUS_NONE and (node as Control).visible and not (node is BaseButton and (node as BaseButton).disabled) and not node.is_queued_for_deletion():
		controls.append(node)
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		_collect_focusables(child, controls)

# --- detail views -------------------------------------------------------------------

func _stage_strip(slot: Dictionary) -> Control:
	var card := _card()
	card.name = "StageStrip"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	for stage in slot.get("stages", []):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_next := bool(stage.get("next", false))
		cell.add_theme_stylebox_override("panel", _flat(Color(0.204, 0.165, 0.086, 0.55) if is_next else Color(0, 0, 0, 0), Color(0.88, 0.72, 0.40, 0.6) if is_next else Color(0, 0, 0, 0), 6, [1, 1, 1, 1], 4))
		row.add_child(cell)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 4)
		cell.add_child(column)
		var art := _art_rect(String(stage.get("building_id", "")), not bool(stage.get("done", false)))
		art.custom_minimum_size = Vector2(0, 66)
		column.add_child(art)
		var stage_name := _label(String(stage.get("name", "")), Color(0.90, 0.93, 0.95), 12)
		stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(stage_name)
		var tag_text := "BUILT" if bool(stage.get("done", false)) else ("NEXT" if is_next else "—")
		var tag_color: Color = GOLD_TEXT if bool(stage.get("done", false)) else (_status_colors("ready")[2] if is_next else MUTED_TEXT)
		var tag := _label(tag_text, tag_color, 11)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(tag)
	return card

func _now_next_view(slot: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "NowNext"
	row.add_theme_constant_override("separation", 12)
	var current_id := String(slot.get("current_id", ""))
	var next_id := String(slot.get("next_id", ""))
	row.add_child(_effect_box("NOW", _building_name(current_id) if current_id != "" else "Not built", _effect_line(current_id) if current_id != "" else "—", false))
	if next_id != "":
		row.add_child(_effect_box("NEXT", _building_name(next_id), _effect_line(next_id), true))
	return row

func _effect_box(caption: String, title: String, body: String, highlight: bool) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _flat(Color(0.204, 0.165, 0.086, 0.55) if highlight else CARD_BG, Color(0.88, 0.72, 0.40, 0.55) if highlight else Color(0.47, 0.70, 0.75, 0.25), 8, [1, 1, 1, 1], 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	box.add_child(column)
	column.add_child(_label(caption, GOLD_TEXT if highlight else MUTED_TEXT, 11))
	column.add_child(_label(title, TITLE_TEXT, 14))
	var body_label := _label(body, Color(0.95, 0.90, 0.77) if highlight else BODY_TEXT, 13)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body_label)
	return box

func _effect_line(building_id: String) -> String:
	var sentences := []
	for sentence in String(ContentService.get_building(building_id).get("description", "")).split(". ", false):
		var text := String(sentence).strip_edges()
		if text != "" and not text.begins_with("Replaces the previous"):
			sentences.append(text.trim_suffix("."))
	return ". ".join(sentences) + ("." if not sentences.is_empty() else "")

func _choice_view(slot: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "ChoiceOptions"
	row.add_theme_constant_override("separation", 12)
	var options: Array = slot.get("options", [])
	var stats := []
	for option in options:
		stats.append(_unit_stats(String(option.get("unit_id", ""))))
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var selected := index == _selected_option_index
		var card := PanelContainer.new()
		card.name = "Option%d" % (index + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _flat(Color(0.204, 0.165, 0.086, 0.5) if selected else CARD_BG, TILE_SELECTED if selected else Color(0.47, 0.70, 0.75, 0.3), 8, [2 if selected else 1, 2 if selected else 1, 2 if selected else 1, 2 if selected else 1], 12))
		row.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		card.add_child(column)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		column.add_child(head)
		var building_art := _art_rect(String(option.get("building_id", "")), false)
		building_art.custom_minimum_size = Vector2(44, 40)
		head.add_child(building_art)
		var building_label := _label(String(option.get("building_name", "")), BODY_TEXT, 12)
		building_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		building_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(building_label)
		var portrait := _portrait(String(option.get("unit_id", "")), false)
		portrait.custom_minimum_size = Vector2(0, 168)
		column.add_child(portrait)
		var role := _label(_unit_role(String(option.get("unit_id", ""))), TEAL_TEXT, 12)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(role)
		var other: Array = stats[1 - index] if options.size() == 2 else []
		column.add_child(_stat_grid(stats[index], other))
		var abilities := _label(_unit_abilities(String(option.get("unit_id", ""))), BODY_TEXT, 12)
		abilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(abilities)
		column.add_child(_label("Upgrades to %s" % String(option.get("upgrade_unit_name", "")), MUTED_TEXT, 12))
		var pick := Button.new()
		pick.name = "PickOption%d" % (index + 1)
		pick.text = "Selected" if selected else "Pick this line"
		pick.tooltip_text = "Select this line, then confirm with the Build button below. Press %d to pick it from the keyboard." % (index + 1)
		pick.accessibility_name = "Pick %s for tier %s" % [String(option.get("unit_name", "")), String(slot.get("tier_label", ""))]
		FrontierVisualKit.apply_button(pick, "primary" if selected else "secondary", 120, 40, 13)
		pick.pressed.connect(_on_pick_option.bind(String(slot.get("id", "")), index))
		column.add_child(pick)
	return row

func _on_pick_option(slot_id: String, index: int) -> void:
	select_slot(slot_id, index)
	if _primary_button.is_visible_in_tree() and not _primary_button.disabled:
		_primary_button.call_deferred("grab_focus")

func _dwelling_view(slot: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.name = "DwellingUpgrade"
	column.add_theme_constant_override("separation", 10)
	var stages: Array = slot.get("stages", [])
	if stages.size() < 2:
		column.add_child(_single_view(slot))
		return column
	var card := _card()
	column.add_child(card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		if index > 0:
			row.add_child(_label("→", GOLD_TEXT, 26))
		var stage_column := VBoxContainer.new()
		stage_column.add_theme_constant_override("separation", 4)
		row.add_child(stage_column)
		var portrait := _portrait(String(stage.get("unit_id", "")), not bool(stage.get("done", false)))
		portrait.custom_minimum_size = Vector2(150, 200)
		stage_column.add_child(portrait)
		var tag := "RECRUITING" if bool(stage.get("done", false)) else ("DWELLING" if index == 0 else "LODGE UPGRADE")
		var tag_label := _label(tag, GOLD_TEXT if bool(stage.get("done", false)) else MUTED_TEXT, 11)
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage_column.add_child(tag_label)
	var base_stats := _unit_stats(String(stages[0].get("unit_id", "")))
	var upgrade_stats := _unit_stats(String(stages[1].get("unit_id", "")))
	var grid := GridContainer.new()
	grid.name = "UpgradeCompare"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	grid.add_child(_label("STAT", MUTED_TEXT, 11))
	grid.add_child(_label(_unit_name(String(stages[0].get("unit_id", ""))).to_upper(), MUTED_TEXT, 11))
	grid.add_child(_label(_unit_name(String(stages[1].get("unit_id", ""))).to_upper(), GOLD_TEXT, 11))
	for index in range(base_stats.size()):
		var key := String(base_stats[index][0])
		grid.add_child(_label(key, MUTED_TEXT, 13))
		grid.add_child(_label(String(base_stats[index][1]), BODY_TEXT, 13))
		var better := key in STAT_BETTER_KEYS and _stat_number(upgrade_stats[index][1]) > _stat_number(base_stats[index][1])
		grid.add_child(_label(String(upgrade_stats[index][1]), _better_color() if better else BODY_TEXT, 13))
	for child in grid.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column

func _single_view(slot: Dictionary) -> Control:
	var card := _card()
	card.name = "BuildingPainting"
	var focus_id := String(slot.get("next_id", "")) if String(slot.get("next_id", "")) != "" else String(slot.get("current_id", ""))
	var art := _art_rect(focus_id, not bool(slot.get("built", false)))
	art.custom_minimum_size = Vector2(0, 260)
	card.add_child(art)
	return card

func _stat_grid(stats: Array, other: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	for index in range(stats.size()):
		var key := String(stats[index][0])
		var value := String(stats[index][1])
		var key_label := _label(key, MUTED_TEXT, 13)
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(key_label)
		var better := not other.is_empty() and key in STAT_BETTER_KEYS and _stat_number(value) > _stat_number(other[index][1])
		var value_label := _label(value, _better_color() if better else BODY_TEXT, 13)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
	return grid

func _fill_cost(cost: Dictionary) -> void:
	for resource_id in Board.RESOURCE_ORDER:
		if not cost.has(resource_id):
			continue
		var need := int(cost[resource_id])
		var have := int(_resources.get(resource_id, 0))
		var short := have < need
		var colors := _status_colors("short") if short else [CARD_BG, Color(0.47, 0.70, 0.75, 0.35), TITLE_TEXT]
		var chip := PanelContainer.new()
		chip.name = "Cost_%s" % resource_id
		chip.tooltip_text = "%s: need %s, have %s" % [Board.resource_name(resource_id).capitalize(), Board.format_amount(need), Board.format_amount(have)]
		chip.add_theme_stylebox_override("panel", _flat(colors[0], colors[1], 6, [1, 1, 1, 1], 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _texture(OverworldRulesScript.resource_icon_path(resource_id))
		row.add_child(icon)
		row.add_child(_label(Board.format_amount(need), colors[2], 15))
		row.add_child(_label("/ %s" % Board.format_amount(have), Color(colors[2], 0.8), 12))
		_cost_flow.add_child(chip)

func _fill_requirements(building_id: String) -> void:
	var building := ContentService.get_building(building_id)
	var ids := []
	for requirement_value in building.get("requires", []):
		var requirement := String(requirement_value)
		if requirement != "" and requirement != building_id and requirement not in ids:
			ids.append(requirement)
	if ids.is_empty():
		return
	_req_flow.add_child(_label("REQUIRES", MUTED_TEXT, 11))
	var missing: Array = selected_slot().get("missing_requirements", [])
	for requirement in ids:
		var requirement_name := _building_name(requirement)
		var met := requirement_name not in missing
		var colors := _status_colors("ready") if met else _status_colors("locked")
		var chip := Button.new()
		chip.name = "Requirement_%s" % requirement
		chip.text = requirement_name if met else "%s · needed" % requirement_name
		chip.tooltip_text = "%s stands in this town. Select to view its slot." % requirement_name if met else "%s is not built yet. Select to view its slot; nothing is built." % requirement_name
		chip.accessibility_name = "Requirement %s, %s" % [requirement_name, "built" if met else "not built"]
		chip.focus_mode = Control.FOCUS_ALL
		chip.add_theme_font_size_override("font_size", 12)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			chip.add_theme_color_override(state, colors[2])
		var normal := _flat(colors[0], colors[1], 13, [1, 1, 1, 1], 10)
		normal.content_margin_top = 4
		normal.content_margin_bottom = 4
		var hover := _flat(colors[0].lightened(0.08), TILE_HOVER, 13, [1, 1, 1, 1], 10)
		hover.content_margin_top = 4
		hover.content_margin_bottom = 4
		chip.add_theme_stylebox_override("normal", normal)
		chip.add_theme_stylebox_override("hover", hover)
		chip.add_theme_stylebox_override("pressed", hover)
		chip.add_theme_stylebox_override("focus", hover)
		chip.pressed.connect(_on_requirement_pressed.bind(requirement))
		_req_flow.add_child(chip)

func _on_requirement_pressed(building_id: String) -> void:
	if not select_building(building_id):
		return
	var tile: Button = _tiles.get(_selected_slot_id)
	if tile != null:
		tile.call_deferred("grab_focus")

# --- header ------------------------------------------------------------------------

func _refresh_today_chip(compact: bool = false) -> void:
	var used := bool(_board.get("built_today", false))
	var colors := _status_colors("tomorrow" if used else "ready")
	_today_chip.add_theme_stylebox_override("panel", _flat(colors[0], colors[1], 16, [1, 1, 1, 1], 6))
	_today_label.add_theme_color_override("font_color", colors[2])
	if compact:
		_today_label.text = "Day %d · %s" % [int(_board.get("day", 0)), "next build tomorrow" if used else "build available"]
	else:
		_today_label.text = "Day %d · %s" % [int(_board.get("day", 0)), "built today, next construction tomorrow" if used else "1 construction available today"]

func _rebuild_resources() -> void:
	for child in _resource_row.get_children():
		_resource_row.remove_child(child)
		child.queue_free()
	for resource_id in Board.RESOURCE_ORDER:
		var cell := HBoxContainer.new()
		cell.name = resource_id
		cell.add_theme_constant_override("separation", 5)
		cell.tooltip_text = Board.resource_name(resource_id).capitalize()
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = _texture(OverworldRulesScript.resource_icon_path(resource_id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var amount := _label(Board.format_amount(int(_resources.get(resource_id, 0))), TITLE_TEXT, 15)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(amount)
		_resource_row.add_child(cell)

# --- layout ------------------------------------------------------------------------

func _layout() -> void:
	if _detail_panel == null:
		return
	var actual := size if size.x > 0.0 and size.y > 0.0 else DESIGN_SIZE
	var fit := minf(1.0, minf(actual.x / MIN_LAYOUT_SIZE.x, actual.y / MIN_LAYOUT_SIZE.y))
	var view := actual / fit
	_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.position = Vector2.ZERO
	_frame.size = view
	_frame.scale = Vector2(fit, fit)
	var compact_header := view.x < COMPACT_HEADER_WIDTH
	_town_subtitle.visible = not compact_header
	_header_divider.visible = not compact_header
	_refresh_today_chip(compact_header)
	var header: Control = _frame.get_child(0)
	header.position = Vector2.ZERO
	header.size = Vector2(view.x, HEADER_HEIGHT)
	var margin_x := clampf(view.x * 0.0167, 16.0, 40.0)
	var top := HEADER_HEIGHT + 20.0
	var bottom_margin := 18.0
	var detail_width := clampf(view.x * 0.30, 420.0, 600.0)
	var board_width := maxf(560.0, view.x - margin_x * 2.0 - 28.0 - detail_width)
	var body_height := view.y - top - bottom_margin
	_detail_panel.position = Vector2(view.x - margin_x - detail_width, top)
	_detail_panel.size = Vector2(detail_width, body_height)
	_board_column.position = Vector2(margin_x, top)
	_board_column.size = Vector2(board_width, body_height)
	var tile_width := floorf((board_width - GAP * 6.0) / 7.0)
	# Rows share the height that labels, gaps and the legend leave free.
	var fixed := LABEL_HEIGHT * 4.0 + ROW_GAP * 9.0 + 24.0
	var scale := clampf((body_height - fixed) / 752.0, 0.62, 1.18)
	var heights := {"town": 200.0 * scale, "army": 230.0 * scale, "growth": 200.0 * scale, "training": 200.0 * scale, "signature": 122.0 * scale}
	for row_id in _row_boxes.keys():
		var box: HBoxContainer = _row_boxes[row_id]
		for tile in box.get_children():
			var wide := bool(tile.get_meta("wide", false))
			var width := floorf((board_width - GAP * 2.0) / 3.0) if wide else tile_width
			tile.custom_minimum_size = Vector2(width, heights.get(row_id, 200.0))
			_layout_tile_overlays(tile)
	var divider_holder := _board_column.find_child("GrowthTrainingDivider", true, false) as Control
	if divider_holder != null:
		divider_holder.custom_minimum_size = Vector2(tile_width, heights.growth)
	var label_gap := _board_column.find_child("GrowthTrainingLabelGap", true, false) as Control
	if label_gap != null:
		label_gap.custom_minimum_size.x = tile_width
	for row_id in ["growth", "training"]:
		var header_row: Control = _row_labels.get(row_id)
		if header_row != null:
			header_row.custom_minimum_size.x = tile_width * 3.0 + GAP * 2.0
	_peek_bar.reset_size()
	_peek_bar.scale = Vector2(fit, fit)
	var peek_size := _peek_bar.get_combined_minimum_size() * fit
	_peek_bar.position = Vector2((actual.x - peek_size.x) * 0.5, actual.y - peek_size.y - 150.0 * fit)

func _layout_tile_overlays(tile: Control) -> void:
	var pips := tile.get_node_or_null("StagePips") as Control
	if pips != null:
		pips.size = Vector2(16.0 * float((pips as ConstructionPips).total), 12.0)
		pips.position = Vector2(tile.custom_minimum_size.x - pips.size.x - 6.0, 9.0)
	var or_badge := tile.get_node_or_null("OrBadge") as Control
	if or_badge != null:
		or_badge.reset_size()
		var badge_size := or_badge.get_combined_minimum_size()
		or_badge.size = badge_size
		or_badge.position = Vector2((tile.custom_minimum_size.x - badge_size.x) * 0.5, (tile.custom_minimum_size.y - 64.0) * 0.45)

# --- helpers -----------------------------------------------------------------------

func _status_colors(status_id: String) -> Array:
	if FrontierVisualKit.color_cue_assist_enabled() and ASSISTED_STATUS_PALETTE.has(status_id):
		return ASSISTED_STATUS_PALETTE[status_id]
	return STATUS_PALETTE.get(status_id, STATUS_PALETTE.locked)

func _better_color() -> Color:
	return ASSISTED_BETTER_STAT if FrontierVisualKit.color_cue_assist_enabled() else BETTER_STAT

func _flat(bg: Color, border: Color, radius: int, borders: Array, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = int(borders[0])
	style.border_width_top = int(borders[1])
	style.border_width_right = int(borders[2])
	style.border_width_bottom = int(borders[3])
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.5 if margin > 0.0 and margin < 8.0 else margin
	style.content_margin_bottom = margin * 0.5 if margin > 0.0 and margin < 8.0 else margin
	return style

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(CARD_BG, Color(0.47, 0.70, 0.75, 0.3), 8, [1, 1, 1, 1], 12))
	return card

func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	_texture_cache[path] = texture
	return texture

func _portrait(unit_id: String, dim: bool) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _texture(String(ContentService.get_unit_art(unit_id).get("portrait", "")))
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if dim:
		portrait.modulate = Color(0.55, 0.55, 0.57, 0.95)
	return portrait

func _building_name(building_id: String) -> String:
	return String(ContentService.get_building(building_id).get("name", building_id)) if building_id != "" else ""

func _unit_name(unit_id: String) -> String:
	return String(ContentService.get_unit(unit_id).get("name", unit_id))

func _unit_role(unit_id: String) -> String:
	var unit := ContentService.get_unit(unit_id)
	var role := String(unit.get("role", "")).replace("_", " ").capitalize()
	if bool(unit.get("ranged", false)):
		role += " · %d shots" % int(unit.get("shots", 0))
	return role

func _unit_abilities(unit_id: String) -> String:
	var names := []
	for ability in ContentService.get_unit(unit_id).get("abilities", []):
		if ability is Dictionary:
			names.append(String(ability.get("name", "")))
	return " · ".join(names)

func _unit_stats(unit_id: String) -> Array:
	var unit := ContentService.get_unit(unit_id)
	var cost_parts := []
	var cost: Dictionary = unit.get("cost", {}) if unit.get("cost", {}) is Dictionary else {}
	for resource_id in Board.RESOURCE_ORDER:
		if cost.has(resource_id):
			cost_parts.append("%s %s" % [Board.format_amount(int(cost[resource_id])), Board.resource_name(resource_id)])
	return [
		["Attack", str(int(unit.get("attack", 0)))],
		["Defense", str(int(unit.get("defense", 0)))],
		["Damage", "%d–%d" % [int(unit.get("min_damage", 0)), int(unit.get("max_damage", 0))]],
		["Health", str(int(unit.get("hp", 0)))],
		["Speed", str(int(unit.get("speed", 0)))],
		["Initiative", str(int(unit.get("initiative", 0)))],
		["Growth", "%d / week" % int(unit.get("growth", 0))],
		["Cost", " + ".join(cost_parts)],
	]

func _stat_number(value: Variant) -> float:
	var total := 0.0
	var regex := RegEx.new()
	regex.compile("\\d+(\\.\\d+)?")
	for match_result in regex.search_all(String(value)):
		total += float(match_result.get_string())
	return total

func _rare_cost_resource(building_id: String) -> String:
	var cost: Dictionary = ContentService.get_building(building_id).get("cost", {})
	for resource_id in cost.keys():
		if String(resource_id) not in ["gold", "wood", "ore"]:
			return String(resource_id)
	return ""


class ConstructionPips:
	extends Control
	var done := 0
	var total := 1

	func _draw() -> void:
		for index in range(total):
			var center := Vector2(6.0 + index * 16.0, size.y * 0.5)
			var points := PackedVector2Array([center + Vector2(0, -4.5), center + Vector2(4.5, 0), center + Vector2(0, 4.5), center + Vector2(-4.5, 0)])
			if index < done:
				draw_colored_polygon(points, Color(0.91, 0.77, 0.43))
			else:
				var outline := points.duplicate()
				outline.append(points[0])
				draw_polyline(outline, Color(0.91, 0.77, 0.43, 0.6), 1.2, true)


class ConstructionStatusGlyph:
	extends Control
	var status := "locked"
	var color := Color.WHITE

	func _draw() -> void:
		var s := minf(size.x, size.y) / 16.0
		var w := 1.7 * s
		match status:
			"ready":
				draw_colored_polygon(PackedVector2Array([Vector2(9.5, 2.5) * s, Vector2(13.5, 6.5) * s, Vector2(11.5, 8.5) * s, Vector2(7.5, 4.5) * s]), color)
				draw_line(Vector2(9.5, 6.5) * s, Vector2(3.0, 13.0) * s, color, w, true)
			"short":
				draw_arc(Vector2(8, 8) * s, 6.2 * s, 0.0, TAU, 24, color, w, true)
				draw_line(Vector2(8, 4.8) * s, Vector2(8, 8.8) * s, color, w, true)
				draw_circle(Vector2(8, 11.4) * s, 1.0 * s, color)
			"trade":
				draw_polyline(PackedVector2Array([Vector2(2.5, 5.5) * s, Vector2(12.5, 5.5) * s, Vector2(10.0, 3.0) * s]), color, w, true)
				draw_polyline(PackedVector2Array([Vector2(13.5, 10.5) * s, Vector2(3.5, 10.5) * s, Vector2(6.0, 13.0) * s]), color, w, true)
			"complete":
				draw_polyline(PackedVector2Array([Vector2(3, 8.5) * s, Vector2(6, 11.5) * s, Vector2(13, 4.5) * s]), color, 2.0 * s, true)
			"tomorrow":
				draw_arc(Vector2(8, 8) * s, 6.2 * s, 0.0, TAU, 24, color, w, true)
				draw_polyline(PackedVector2Array([Vector2(8, 4.8) * s, Vector2(8, 8.3) * s, Vector2(10.3, 9.8) * s]), color, w, true)
			_:
				draw_rect(Rect2(Vector2(3, 7) * s, Vector2(10, 7) * s), color, false, w)
				draw_arc(Vector2(8, 7) * s, 2.6 * s, PI, TAU, 12, color, w, true)
