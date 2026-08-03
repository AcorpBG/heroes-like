class_name ManualSaveOverwriteDialog
extends ConfirmationDialog

var _pending_slot := 0
var _pending_action := {}

func open_action(action: Dictionary) -> bool:
	if bool(action.get("disabled", true)) or not bool(action.get("requires_confirmation", false)):
		clear_pending()
		return false
	var slot := int(action.get("slot", 0))
	if not SaveService.get_manual_slot_ids().has(slot):
		clear_pending()
		return false
	_pending_slot = slot
	_pending_action = action.duplicate(true)
	title = "Overwrite %s?" % String(action.get("slot_label", "manual save"))
	dialog_text = String(action.get("summary", "Replace this manual save?"))
	var dialog_label := get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(520.0, 112.0)
	get_ok_button().text = "Overwrite Save"
	popup_centered(Vector2i(640, 270))
	return true

func consume_pending_slot() -> int:
	var slot := _pending_slot
	clear_pending()
	return slot

func clear_pending() -> void:
	hide()
	_pending_slot = 0
	_pending_action = {}

func validation_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"pending_slot": _pending_slot,
		"title": title,
		"text": dialog_text,
		"action": _pending_action.duplicate(true),
	}
