class_name ManualSaveOverwriteDialog
extends ConfirmationDialog

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

var _pending_slot := 0
var _pending_action := {}
var _return_focus: Control
var _request_count := 0
var _cancel_count := 0
var _confirm_count := 0
var _forwarding_root_physical_input := false


func _ready() -> void:
	FrontierVisualKit.apply_confirmation_dialog(self, "danger")
	get_cancel_button().text = "Keep Save"
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	get_cancel_button().shortcut = cancel_shortcut
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if (
		not visible
		or _pending_slot <= 0
		or _forwarding_root_physical_input
		or not (event is InputEventKey or event is InputEventJoypadButton)
	):
		return
	get_tree().root.set_input_as_handled()
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred("_forward_root_physical_input", detached_event)


func _forward_root_physical_input(event: InputEvent) -> void:
	if not visible or _pending_slot <= 0 or _forwarding_root_physical_input:
		return
	_forwarding_root_physical_input = true
	push_input(event)
	_forwarding_root_physical_input = false

func open_action(action: Dictionary) -> bool:
	if bool(action.get("disabled", true)) or not bool(action.get("requires_confirmation", false)):
		_clear_pending(false)
		return false
	var slot := int(action.get("slot", 0))
	if not SaveService.get_manual_slot_ids().has(slot):
		_clear_pending(false)
		return false
	_return_focus = get_tree().root.gui_get_focus_owner() as Control
	_pending_slot = slot
	_pending_action = action.duplicate(true)
	_request_count += 1
	title = "Overwrite %s?" % String(action.get("slot_label", "manual save"))
	dialog_text = String(action.get("summary", "Replace this manual save?"))
	var dialog_label := get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(520.0, 112.0)
	get_ok_button().text = "Overwrite Save"
	popup_centered(Vector2i(640, 270))
	call_deferred("_focus_safe_cancel")
	return true

func consume_pending_slot() -> int:
	var slot := _pending_slot
	if slot > 0:
		_confirm_count += 1
	_clear_pending(false)
	return slot

func clear_pending() -> void:
	var had_pending := _pending_slot > 0
	if had_pending:
		_cancel_count += 1
	_clear_pending(had_pending)


func _clear_pending(restore_focus: bool) -> void:
	var return_focus := _return_focus
	hide()
	_pending_slot = 0
	_pending_action = {}
	_return_focus = null
	if restore_focus and is_instance_valid(return_focus):
		_restore_origin_focus.call_deferred(return_focus)


func _focus_safe_cancel() -> void:
	if not visible or _pending_slot <= 0:
		return
	get_cancel_button().grab_focus()
	await get_tree().process_frame
	if visible and _pending_slot > 0:
		get_cancel_button().grab_focus()


func _restore_origin_focus(target: Control) -> void:
	await get_tree().process_frame
	if (
		is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	):
		target.grab_focus()


func _focus_owner_name(viewport: Viewport) -> String:
	if viewport == null:
		return ""
	var focus_owner := viewport.gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func validation_snapshot() -> Dictionary:
	var cancel_button := get_cancel_button()
	return {
		"visible": visible,
		"dialog_visible": visible,
		"pending_slot": _pending_slot,
		"title": title,
		"text": dialog_text,
		"action": _pending_action.duplicate(true),
		"cancel_text": cancel_button.text,
		"focus_owner": _focus_owner_name(cancel_button.get_viewport()),
		"return_focus_name": String(_return_focus.name) if is_instance_valid(_return_focus) else "",
		"origin_focus_owner": _focus_owner_name(get_tree().root),
		"request_count": _request_count,
		"cancel_count": _cancel_count,
		"confirm_count": _confirm_count,
	}
