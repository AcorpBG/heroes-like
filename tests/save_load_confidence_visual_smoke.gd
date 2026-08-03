extends Node

const OUTPUT_DIR := "res://.artifacts/save_load_confidence_visual_smoke"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1024, 600)]

var _autosave_path := ""
var _previous_autosave := PackedByteArray()
var _had_autosave := false
var _previous_session = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_previous_session = SessionState.active_session
	_autosave_path = ProjectSettings.globalize_path("%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE])
	_had_autosave = FileAccess.file_exists(_autosave_path)
	if _had_autosave:
		_previous_autosave = FileAccess.get_file_as_bytes(_autosave_path)

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = 4
	SessionState.set_active_session(session)
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(save_result.get("ok", false)):
		_fail("Could not create the save preview fixture: %s" % JSON.stringify(save_result))
		return

	for viewport_size in VIEWPORT_SIZES:
		if not await _validate_viewport(viewport_size):
			return

	_cleanup()
	print("SAVE_LOAD_CONFIDENCE_VISUAL_SMOKE PASS")
	get_tree().quit(0)

func _validate_viewport(viewport_size: Vector2i) -> bool:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	viewport.add_child(shell)
	if shell is Control:
		shell.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell.offset_left = 0.0
		shell.offset_top = 0.0
		shell.offset_right = 0.0
		shell.offset_bottom = 0.0
	await _settle()
	shell.call("validation_open_saves_stage")
	if not shell.call("validation_select_save_summary", SaveService.SLOT_TYPE_AUTOSAVE, SaveService.SLOT_TYPE_AUTOSAVE):
		_fail("Autosave was not selectable at %s." % viewport_size)
		return false
	await _settle()

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var details := String(snapshot.get("save_details_full", ""))
	var button_text := String(snapshot.get("load_selected_text", ""))
	var button_tooltip := String(snapshot.get("load_selected_tooltip", ""))
	var delete_text := String(snapshot.get("save_delete_action", {}).get("label", ""))
	var delete_tooltip := String(snapshot.get("save_delete_tooltip", ""))
	var rows := "\n".join(snapshot.get("save_browser_items", []))
	var visible_copy := "\n".join([details, button_text, button_tooltip, delete_text, delete_tooltip, rows])
	for expected in ["River Pass", "Skirmish", "Captain", "Day 4", "Commander:", "Saved:", "Returns to: Adventure Map", "Next:"]:
		if not visible_copy.contains(expected):
			_fail("Load preview at %s is missing %s: %s" % [viewport_size, expected, visible_copy])
			return false
	for forbidden in ["play check", "resume handoff", "command cue", "integrity:", "scenario id", "resume target:", "load state:", "cue:", "river-pass", "overworld 0,0"]:
		if visible_copy.to_lower().contains(forbidden):
			_fail("Load preview at %s exposes diagnostic copy %s: %s" % [viewport_size, forbidden, visible_copy])
			return false
	if button_text != "Resume Expedition":
		_fail("Load action at %s is not destination-specific: %s" % [viewport_size, button_text])
		return false
	if not button_tooltip.contains("Loading does not change any saved slot"):
		_fail("Load action at %s does not state the save-preservation boundary." % viewport_size)
		return false
	if delete_text != "Delete Save" or not bool(snapshot.get("save_delete_enabled", false)):
		_fail("Occupied autosave does not expose Delete Save at %s: %s" % [viewport_size, JSON.stringify(snapshot)])
		return false
	if not delete_tooltip.contains("permanently removes only this expedition save"):
		_fail("Delete action at %s does not state its single-slot boundary." % viewport_size)
		return false
	for control_name in ["StageDockPanel", "SaveList", "SaveDetails", "DeleteSelectedSave", "LoadSelected"]:
		var control = shell.find_child(control_name, true, false)
		if not _inside_viewport(control as Control, viewport_size, control_name):
			return false

	if OS.get_environment("SAVE_LOAD_CONFIDENCE_VISUAL_CAPTURE") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var output_path := "%s/load_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
		var result := image.save_png(ProjectSettings.globalize_path(output_path))
		if result != OK:
			_fail("Could not save %s: %s" % [output_path, result])
			return false

	if viewport_size == VIEWPORT_SIZES.back():
		var remove_result := DirAccess.remove_absolute(_autosave_path)
		if remove_result != OK or FileAccess.file_exists(_autosave_path):
			_fail("Could not remove the selected autosave fixture: %s" % remove_result)
			return false
		shell.call("validation_resume_selected_save")
		var stale_snapshot: Dictionary = shell.call("validation_snapshot")
		var stale_details := String(stale_snapshot.get("save_details_full", stale_snapshot.get("save_details", "")))
		if not stale_details.contains("This save is no longer available"):
			_fail("A removed selected save did not explain the live-file change: %s" % stale_details)
			return false
		if bool(stale_snapshot.get("load_selected_enabled", true)):
			_fail("A removed selected save left the load action enabled.")
			return false
		if bool(stale_snapshot.get("save_delete_visible", true)) or bool(stale_snapshot.get("save_delete_enabled", true)):
			_fail("A removed selected save left the delete action available.")
			return false

	viewport.queue_free()
	await get_tree().process_frame
	return true

func _inside_viewport(control: Control, viewport_size: Vector2i, label: String) -> bool:
	if control == null:
		_fail("%s is missing." % label)
		return false
	var rect := control.get_global_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > bounds.end.x + 1.0 or rect.end.y > bounds.end.y + 1.0:
		_fail("%s overflows %s: %s" % [label, viewport_size, rect])
		return false
	return true

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _cleanup() -> void:
	if _had_autosave:
		var file := FileAccess.open(_autosave_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_previous_autosave)
	else:
		DirAccess.remove_absolute(_autosave_path)
	SessionState.active_session = _previous_session

func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	get_tree().quit(1)
