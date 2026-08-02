extends Node

const OUTPUT_DIR := "res://.artifacts/generated_map_setup_visual_smoke"
const VIEWPORT_SIZE := Vector2i(1280, 720)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	ContentService.clear_generated_scenario_drafts()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
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
	shell.call("validation_open_skirmish_stage")
	shell.call("validation_set_generated_seed", "")
	await _settle()
	if not _assert_inside(shell.find_child("GeneratedMapPanel", true, false) as Control, "generated map panel"):
		return
	if not _assert_inside(shell.get_node("%StartGeneratedSkirmish"), "Build & Play button"):
		return
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var visible_copy := "\n".join([
		String(snapshot.get("status_full", "")),
		String(snapshot.get("provenance_full", "")),
		String(snapshot.get("start_tooltip", "")),
	])
	for forbidden in ["internal", "provenance", "template", "profile", "bounded retry", "validation"]:
		if visible_copy.to_lower().contains(forbidden):
			_fail("Generated map setup exposed internal term %s: %s" % [forbidden, visible_copy])
			return
	if String(snapshot.get("start_text", "")) != "Build & Play":
		_fail("Generated map setup did not expose Build & Play: %s" % JSON.stringify(snapshot))
		return
	if OS.get_environment("GENERATED_MAP_SETUP_VISUAL_CAPTURE") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var result := image.save_png(ProjectSettings.globalize_path("%s/generated_map_setup_1280x720.png" % OUTPUT_DIR))
		if result != OK:
			_fail("Could not save generated map setup capture: %s" % result)
			return
	print("GENERATED_MAP_SETUP_VISUAL_SMOKE PASS")
	get_tree().quit(0)

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _assert_inside(target: Control, label: String) -> bool:
	if target == null:
		_fail("%s is missing." % label)
		return false
	var rect := target.get_global_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	if rect.position.x < bounds.position.x - 1.0 or rect.position.y < bounds.position.y - 1.0 \
			or rect.end.x > bounds.end.x + 1.0 or rect.end.y > bounds.end.y + 1.0:
		_fail("%s overflows 1280x720: %s" % [label, rect])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
