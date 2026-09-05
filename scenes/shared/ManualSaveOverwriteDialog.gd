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
var _file_mode := false
var _file_box: VBoxContainer
var _file_list: ItemList
var _file_name: LineEdit
var _file_status: Label
var _file_rows: Array = []
var _file_commit: Callable
var _file_overwrite := {}


func _ready() -> void:
	FrontierVisualKit.apply_confirmation_dialog(self, "danger")
	get_cancel_button().text = "Keep Save"
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	get_cancel_button().shortcut = cancel_shortcut
	confirmed.connect(_confirm_file_save)
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if (
		not visible
		or (_pending_slot <= 0 and not _file_mode)
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
	if not visible or (_pending_slot <= 0 and not _file_mode) or _forwarding_root_physical_input:
		return
	_forwarding_root_physical_input = true
	push_input(event)
	_forwarding_root_physical_input = false

func open_action(action: Dictionary) -> bool:
	_file_mode = false
	dialog_hide_on_ok = true
	get_cancel_button().text = "Keep Save"
	if _file_box != null:
		_file_box.hide()
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
	if _file_mode:
		return 0
	var slot := _pending_slot
	if slot > 0:
		_confirm_count += 1
	_clear_pending(false)
	return slot

func clear_pending() -> void:
	var had_pending := _pending_slot > 0 or _file_mode
	if had_pending:
		_cancel_count += 1
	_clear_pending(had_pending)


func _clear_pending(restore_focus: bool) -> void:
	var return_focus := _return_focus
	# Drop the file browser's exclusive focus claim before removing its embedded
	# window; otherwise focus restoration can reselect the closing subwindow.
	if _file_mode:
		exclusive = false
	hide()
	exclusive = true
	_pending_slot = 0
	_pending_action = {}
	_file_mode = false
	_file_overwrite = {}
	_file_commit = Callable()
	_return_focus = null
	if restore_focus and is_instance_valid(return_focus):
		_restore_origin_focus.call_deferred(return_focus)


func open_file_browser(session, commit: Callable) -> bool:
	if session == null or session.scenario_id == "" or not commit.is_valid():
		return false
	_return_focus = get_tree().root.gui_get_focus_owner() as Control
	_pending_slot = 0
	_pending_action = {}
	_file_mode = true
	FrontierVisualKit.apply_confirmation_dialog(self, "primary")
	_file_commit = commit
	_file_overwrite = {}
	dialog_hide_on_ok = false
	title = "Save expedition"
	dialog_text = ""
	get_label().custom_minimum_size = Vector2.ZERO
	get_ok_button().text = "Save"
	get_cancel_button().text = "Cancel"
	if _file_box == null:
		_file_box = VBoxContainer.new()
		_file_box.add_theme_constant_override("separation", 10)
		add_child(_file_box)
		var heading := Label.new()
		heading.text = "Create a new file, or select an existing file to replace."
		_file_box.add_child(heading)
		_file_name = LineEdit.new()
		_file_name.name = "SaveFileName"
		_file_name.placeholder_text = "Save name"
		_file_name.tooltip_text = "Name of the expedition save file (up to 64 characters)."
		_file_name.max_length = 64
		_file_name.custom_minimum_size.y = 36
		_file_box.add_child(_file_name)
		_file_name.text_changed.connect(func(_text: String):
			_file_overwrite = {}
			_file_status.text = ""
			get_ok_button().text = "Save"
		)
		_file_name.text_submitted.connect(func(_text: String): _confirm_file_save())
		_file_list = ItemList.new()
		_file_list.name = "SaveFiles"
		_file_list.custom_minimum_size = Vector2(440, 210)
		_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_file_box.add_child(_file_list)
		_file_list.item_selected.connect(func(index: int):
			_file_name.text = String(_file_rows[index].slot_id)
			_file_name.text_changed.emit(_file_name.text)
		)
		_file_status = Label.new()
		_file_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_file_status.custom_minimum_size = Vector2(440, 48)
		_file_box.add_child(_file_status)
		var directory := Label.new()
		directory.text = "Files: " + ProjectSettings.globalize_path(SaveService.SAVE_DIR)
		directory.tooltip_text = directory.text
		directory.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_file_box.add_child(directory)
	_file_box.show()
	_file_rows = SaveService.list_save_files()
	_file_list.clear()
	for summary in _file_rows:
		_file_list.add_item("%s  ·  Day %d  ·  %s" % [String(summary.slot_id), int(summary.get("day", 1)), String(summary.get("hero_name", ""))])
		_file_list.set_item_tooltip(_file_list.item_count - 1, SaveService.describe_slot_details(summary))
	_file_name.text = "%s — Day %d" % [String(session.hero_id).trim_prefix("hero_").capitalize().left(36), int(session.day)]
	_file_status.text = "No manual files yet. Choose a name for your first save." if _file_rows.is_empty() else "Existing files are only replaced after confirmation."
	popup_centered(Vector2i(600, 420))
	_file_name.grab_focus()
	_file_name.select_all()
	return true


func _confirm_file_save() -> void:
	if not _file_mode or not visible or not _file_commit.is_valid():
		return
	var action := SaveService.build_file_save_action(_file_name.text)
	if not bool(action.get("ok", false)):
		_file_status.text = String(action.get("message", "Choose a valid name."))
		return
	if bool(action.get("requires_confirmation", false)) and (
		String(_file_overwrite.get("path", "")) != String(action.path)
		or String(_file_overwrite.get("expected_sha256", "")) != String(action.expected_sha256)
	):
		_file_overwrite = action
		_file_status.text = "Replace “%s”? Its previous expedition will be overwritten. Cancel keeps it unchanged." % String(action.name)
		get_ok_button().text = "Replace file"
		_focus_file_cancel_after_submit.call_deferred()
		return
	var commit := _file_commit
	var result: Dictionary = commit.call(String(action.name), String(action.expected_sha256))
	if bool(result.get("ok", false)):
		_clear_pending(true)
	else:
		_file_status.text = String(result.get("message", "Save failed. Your previous file was preserved."))
		_file_overwrite = {}
		get_ok_button().text = "Save"


func _focus_file_cancel_after_submit() -> void:
	# Enter in the name field requests confirmation. Moving focus to Cancel
	# while that same key is held lets its release activate Cancel immediately.
	while visible and _file_mode and Input.is_action_pressed("ui_accept"):
		await get_tree().process_frame
	if visible and _file_mode and not _file_overwrite.is_empty():
		get_cancel_button().grab_focus()


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
