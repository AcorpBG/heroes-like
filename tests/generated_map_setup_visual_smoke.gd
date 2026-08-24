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
	if not await _assert_generated_size_picker_theme_parity(viewport, shell as Control):
		return
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

func _assert_generated_size_picker_theme_parity(viewport: SubViewport, shell: Control) -> bool:
	var size_picker := shell.get_node_or_null("%GeneratedSizePicker") as OptionButton
	var player_count_picker := shell.get_node_or_null("%GeneratedPlayerCountPicker") as OptionButton
	var water_picker := shell.get_node_or_null("%GeneratedWaterPicker") as OptionButton
	var generated_panel := shell.find_child("GeneratedMapPanel", true, false) as Control
	if size_picker == null or player_count_picker == null or water_picker == null or generated_panel == null:
		_fail("Generated Size theme-parity dependencies are missing.")
		return false
	var setup_before: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var size_before: Dictionary = _option_button_behavior_contract(size_picker)
	var player_count_before: Dictionary = _option_button_behavior_contract(player_count_picker)
	var water_before: Dictionary = _option_button_behavior_contract(water_picker)
	for requested_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = requested_size
		await _settle()
		var expected_style_paths := {
			"normal": "res://art/ui/runtime/shared/button_secondary_normal.png",
			"hover": "res://art/ui/runtime/shared/button_secondary_hover.png",
			"pressed": "res://art/ui/runtime/shared/button_secondary_pressed.png",
			"disabled": "res://art/ui/runtime/shared/button_secondary_disabled.png",
		}
		var size_style: Dictionary = _option_button_style_contract(size_picker)
		var player_count_style: Dictionary = _option_button_style_contract(player_count_picker)
		var water_style: Dictionary = _option_button_style_contract(water_picker)
		if size_style.is_empty() \
				or size_style != player_count_style \
				or size_style != water_style \
				or size_style.get("style_paths", {}) != expected_style_paths \
				or size_style.get("custom_minimum_size", Vector2.ZERO) != Vector2(176.0, 34.0) \
				or int(size_style.get("font_size", 0)) != 13 \
				or int(size_style.get("focus_mode", -1)) != Control.FOCUS_ALL:
			_fail("Generated Size picker shared theme diverged at %s: size=%s player=%s water=%s" % [requested_size, size_style, player_count_style, water_style])
			return false
		if not _rect_contains(generated_panel.get_global_rect(), size_picker.get_global_rect()) \
				or not _rect_contains(generated_panel.get_global_rect(), player_count_picker.get_global_rect()) \
				or not _rect_contains(generated_panel.get_global_rect(), water_picker.get_global_rect()) \
				or size_picker.get_global_rect().intersects(player_count_picker.get_global_rect()) \
				or size_picker.get_global_rect().intersects(water_picker.get_global_rect()):
			_fail("Generated Size picker containment or non-overlap failed at %s." % requested_size)
			return false
	viewport.size = VIEWPORT_SIZE
	await _settle()
	if shell.call("validation_generated_random_map_snapshot") != setup_before \
			or _option_button_behavior_contract(size_picker) != size_before \
			or _option_button_behavior_contract(player_count_picker) != player_count_before \
			or _option_button_behavior_contract(water_picker) != water_before:
		_fail("Generated Size theme validation changed generated setup, picker items, metadata, selection, tooltip, focus, or parent authority.")
		return false
	return true

func _option_button_style_contract(picker: OptionButton) -> Dictionary:
	var style_paths := {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := picker.get_theme_stylebox(state)
		if not (style is StyleBoxTexture):
			return {}
		var texture := (style as StyleBoxTexture).texture
		if texture == null:
			return {}
		style_paths[state] = texture.resource_path
	return {
		"style_paths": style_paths,
		"custom_minimum_size": picker.custom_minimum_size,
		"font_size": picker.get_theme_font_size("font_size"),
		"focus_mode": picker.focus_mode,
	}

func _option_button_behavior_contract(picker: OptionButton) -> Dictionary:
	var items := []
	for index in range(picker.get_item_count()):
		items.append({
			"text": picker.get_item_text(index),
			"metadata": picker.get_item_metadata(index),
			"disabled": picker.is_item_disabled(index),
		})
	return {
		"items": items,
		"selected": picker.selected,
		"tooltip": picker.tooltip_text,
		"parent": picker.get_parent().get_path(),
		"size_flags_horizontal": picker.size_flags_horizontal,
		"focus_neighbor_top": picker.focus_neighbor_top,
		"focus_neighbor_bottom": picker.focus_neighbor_bottom,
		"focus_previous": picker.focus_previous,
		"focus_next": picker.focus_next,
	}

func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1.0 \
		and inner.position.y >= outer.position.y - 1.0 \
		and inner.end.x <= outer.end.x + 1.0 \
		and inner.end.y <= outer.end.y + 1.0

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
