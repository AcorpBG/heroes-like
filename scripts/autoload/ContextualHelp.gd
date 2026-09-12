extends Node

const TooltipControl = preload("res://scripts/ui/BoundedTooltipControl.gd")
const MAX_SUMMARY_CHARACTERS := 240
const MAX_SUMMARY_LINES := 3
var _hover_owner: WeakRef
var _hover_card: WeakRef
var _hover_layer: CanvasLayer
var _hover_text := ""
var _hover_revision: Variant = null
var _hover_pointer := Vector2.ZERO
var _detail: ConfirmationDialog
var _detail_owner: WeakRef
var _detail_text: RichTextLabel
var _detail_revision: Variant = null
var _keyboard_context := false
var _hover_placed := false

func _ready() -> void:
	get_tree().node_added.connect(_install)
	get_tree().node_removed.connect(_node_removed)
	get_tree().scene_changed.connect(dismiss)
	_install_tree(get_tree().root)
	set_process(false)

func _install_tree(node: Node) -> void:
	_install(node)
	for child in node.get_children(): _install_tree(child)

func _install(node: Node) -> void:
	if node is Control and node.get_script() == null: node.set_script(TooltipControl)
	if node is Control and not node.visibility_changed.is_connected(_owner_visibility_changed.bind(node)):
		node.visibility_changed.connect(_owner_visibility_changed.bind(node))
	if node is Window and node != get_tree().root:
		if not node.about_to_popup.is_connected(_on_popup.bind(node)):
			node.about_to_popup.connect(_on_popup.bind(node))
		if not node.window_input.is_connected(_on_window_input.bind(node)):
			node.window_input.connect(_on_window_input.bind(node))

func _on_window_input(event: InputEvent, window: Window) -> void:
	if window != _detail: _handle_help_input(event, window)

func _owner_visibility_changed(control: Control) -> void:
	if control.is_visible_in_tree(): return
	if _hover_owner != null and _hover_owner.get_ref() == control: dismiss_hover()
	if _detail_owner != null and _detail_owner.get_ref() == control: dismiss_details()

func _on_popup(window: Window) -> void:
	dismiss_hover()
	if window != _detail: dismiss_details()

func _node_removed(node: Node) -> void:
	if _hover_owner != null and _hover_owner.get_ref() == node: dismiss_hover()
	if _detail_owner != null and _detail_owner.get_ref() == node: dismiss_details()

func make_hover_card(control: Control, full_text: String) -> Control:
	# Godot calls the custom hook before checking for empty tooltip text.
	if full_text.strip_edges() == "": return null
	dismiss_hover()
	var card := PanelContainer.new()
	card.name = "BoundedContextHover"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := minf(360.0, control.get_viewport_rect().size.x * 0.32)
	card.custom_minimum_size.x = width
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182021")
	style.border_color = Color("b59c60")
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var label := Label.new()
	label.name = "Summary"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.x = width - 20
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = MAX_SUMMARY_LINES
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 14)
	label.text = summary_text(full_text)
	column.add_child(label)
	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "F1 / controller View: inspect • Esc: dismiss"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("d4bd83"))
	column.add_child(hint)
	return adopt_hover_card(control, card, full_text)

func adopt_hover_card(control: Control, card: Control, full_text: String) -> Control:
	dismiss_hover()
	# Use Godot's tooltip delay/query, but not its native PopupPanel lifecycle.
	# Native release templates can emit invalid disconnects when those close.
	_hover_layer = CanvasLayer.new()
	_hover_layer.layer = 100
	control.get_viewport().add_child(_hover_layer)
	_hover_layer.add_child(card)
	card.position = control.get_global_mouse_position() + Vector2(18, 22)
	_hover_owner = weakref(control)
	_hover_card = weakref(card)
	_hover_text = full_text.strip_edges()
	_hover_revision = _revision(control)
	_hover_pointer = control.get_local_mouse_position()
	_hover_placed = false
	set_process(true)
	var suppress_native := Control.new()
	suppress_native.hide()
	return suppress_native

func summary_text(full_text: String) -> String:
	var lines := full_text.strip_edges().split("\n", false)
	var text := "\n".join(lines.slice(0, 3))
	if text.length() > MAX_SUMMARY_CHARACTERS: text = text.left(MAX_SUMMARY_CHARACTERS - 1) + "…"
	elif lines.size() > 3: text += "…"
	return text

func dismiss_hover() -> void:
	var card = _hover_card.get_ref() if _hover_card != null else null
	if is_instance_valid(card) and card.is_inside_tree():
		card.hide()
	if is_instance_valid(_hover_layer): _hover_layer.queue_free()
	_hover_layer = null
	_hover_card = null
	_hover_owner = null
	_hover_text = ""
	if _detail_owner == null: set_process(false)

func dismiss_details() -> void:
	_detail_owner = null
	if is_instance_valid(_detail): _detail.hide()
	if _hover_owner == null: set_process(false)

func dismiss() -> void:
	dismiss_hover()
	dismiss_details()

func _process(_delta: float) -> void:
	if _hover_card != null and not is_instance_valid(_hover_card.get_ref()): dismiss_hover()
	if _hover_owner != null:
		var control = _hover_owner.get_ref()
		if not is_instance_valid(control) or not control.is_visible_in_tree(): dismiss_hover()
		elif _hover_text_changed(control): dismiss_hover()
		elif not _hover_matches(control): dismiss_hover()
		elif not _hover_placed: _place_hover(control)
	if _detail_owner != null:
		var control = _detail_owner.get_ref()
		if not is_instance_valid(control) or not control.is_visible_in_tree() or not control.get_window().visible or _revision(control) != _detail_revision: dismiss_details()

func _revision(control: Control) -> Variant:
	return control.get_meta("contextual_help_revision") if control.has_meta("contextual_help_revision") else null

func _hover_text_changed(control: Control) -> bool:
	var revision: Variant = _revision(control)
	if revision != _hover_revision: return true
	# Tactical descriptions may calculate approach paths. Their owner supplies
	# a presentation revision so stationary hover never repeats those queries.
	if revision != null: return control.get_local_mouse_position() != _hover_pointer
	return control.get_tooltip(control.get_local_mouse_position()).strip_edges() != _hover_text

func _hover_matches(control: Control) -> bool:
	var hovered := control.get_viewport().gui_get_hovered_control()
	return hovered != null and (hovered == control or control.is_ancestor_of(hovered))

func _button_rects(node: Node, viewport: Viewport, result: Array) -> void:
	if node is Control and node.is_visible_in_tree() and node.get_viewport() == viewport:
		if node is BaseButton or node.has_meta("contextual_help_exclusion"):
			result.append(node.get_global_rect())
		if node.has_method("contextual_help_exclusion_rects"):
			for rect in node.contextual_help_exclusion_rects():
				result.append(node.get_global_transform_with_canvas() * rect)
	for child in node.get_children(): _button_rects(child, viewport, result)

func _place_hover(control: Control) -> void:
	var card = _hover_card.get_ref() if _hover_card != null else null
	if not is_instance_valid(card) or not card.is_inside_tree(): return
	_hover_placed = true
	var bounds := control.get_viewport_rect().grow(-8)
	var footprint: Vector2 = card.size
	var target := control.get_global_rect()
	# Scenic boards are not one giant target: protect the pointed-at object.
	if target.size.x > bounds.size.x * 0.5 or target.size.y > bounds.size.y * 0.5:
		target = Rect2(control.get_global_mouse_position() - Vector2(32, 32), Vector2(64, 64))
	var obstacles: Array = []
	if get_tree().current_scene != null: _button_rects(get_tree().current_scene, control.get_viewport(), obstacles)
	obstacles.append(target)
	var initial: Vector2 = card.position
	var best := initial
	var best_score := INF
	for x in [initial.x, target.end.x + 12, target.position.x - footprint.x - 12]:
		for y in [initial.y, initial.y - footprint.y - 12, initial.y + footprint.y + 12, target.position.y - footprint.y - 12, target.end.y + 12, bounds.position.y + 12, bounds.end.y - footprint.y - 12]:
			var point := Vector2(clampf(x, bounds.position.x, bounds.end.x - footprint.x), clampf(y, bounds.position.y, bounds.end.y - footprint.y))
			var candidate := Rect2(point, footprint)
			var score := point.distance_squared_to(initial) * 0.0001
			for obstacle in obstacles:
				var rect: Rect2 = obstacle
				score += candidate.intersection(rect.grow(4)).get_area()
			if score < best_score:
				best_score = score
				best = point
	card.position = best

func _input(event: InputEvent) -> void:
	_handle_help_input(event, get_viewport())

func _handle_help_input(event: InputEvent, viewport: Viewport) -> void:
	if event is InputEventMouseMotion: _keyboard_context = false
	var inspect: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK)
	if inspect:
		var focused := _keyboard_context or event is InputEventJoypadButton
		var control: Control = viewport.gui_get_focus_owner() if focused else viewport.gui_get_hovered_control()
		if control == null: control = viewport.gui_get_focus_owner()
		if inspect_control(control, focused): viewport.set_input_as_handled()
		return
	if event is InputEventKey or event is InputEventJoypadButton: _keyboard_context = true
	if event.is_action_pressed("ui_cancel"):
		var had_detail := is_instance_valid(_detail) and _detail.visible
		var had_hover := _hover_card != null
		dismiss()
		if had_detail or had_hover: viewport.set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton: dismiss_hover()

func inspect_control(control: Control, focused: bool = false) -> bool:
	if control == null or not control.is_visible_in_tree(): return false
	var text: String = control.contextual_inspection_text() if focused and control.has_method("contextual_inspection_text") else control.get_tooltip(control.get_local_mouse_position())
	if focused and control is ItemList and not control.get_selected_items().is_empty():
		var selected: int = control.get_selected_items()[0]
		text = control.get_item_tooltip(selected)
		if text.strip_edges() == "": text = control.get_item_text(selected)
	while text.strip_edges() == "" and control.get_parent() is Control:
		control = control.get_parent()
		text = control.get_tooltip(control.get_local_mouse_position())
	if text.strip_edges() == "": return false
	var parent_window := control.get_window()
	if is_instance_valid(_detail) and _detail.get_parent() != parent_window:
		dismiss_details()
		_detail.reparent(parent_window)
	if not is_instance_valid(_detail):
		_detail = ConfirmationDialog.new()
		_detail.name = "ContextInspection"
		_detail.title = "Inspect"
		_detail.exclusive = true
		_detail_text = RichTextLabel.new()
		_detail_text.bbcode_enabled = false
		_detail_text.scroll_active = true
		_detail_text.selection_enabled = true
		_detail_text.focus_mode = Control.FOCUS_ALL
		_detail.add_child(_detail_text)
		parent_window.add_child(_detail)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("182021")
		frame.border_color = Color("b59c60")
		frame.set_border_width_all(1)
		frame.set_content_margin_all(12)
		_detail.add_theme_stylebox_override("panel", frame)
		_detail.add_theme_color_override("title_color", Color("e0c98f"))
		_detail.get_cancel_button().hide()
		_detail.confirmed.connect(dismiss_details)
		_detail.canceled.connect(dismiss_details)
		_detail.close_requested.connect(dismiss_details)
		_detail.window_input.connect(_detail_input)
	dismiss_hover()
	_detail_text.text = text
	_detail_text.scroll_to_line(0)
	var viewport_size := control.get_viewport_rect().size
	_detail_text.custom_minimum_size = Vector2(minf(520, viewport_size.x - 64), minf(360, viewport_size.y - 140))
	_detail_owner = weakref(control)
	_detail_revision = _revision(control)
	_detail.popup_centered()
	_detail_text.grab_focus()
	set_process(true)
	return true

func _detail_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		dismiss_details()
		_detail.set_input_as_handled()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		var direction := 1 if event.is_action_pressed("ui_down", true) else -1
		_detail_text.get_v_scroll_bar().value += 36 * direction
		_detail.set_input_as_handled()
