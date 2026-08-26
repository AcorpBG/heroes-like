extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "MAP_EDITOR_LOAD_MAP_PACKAGE_REPORT"
const WORKBENCH_WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]
const WORKBENCH_PANEL_PATHS := {
	"RootMargin/Shell": "res://art/ui/runtime/main_menu/stage_dock_cartography.png",
	"RootMargin/Shell/ShellPad/ShellBox/TopPanel": "res://art/ui/runtime/battle/battle_footer_panel.png",
	"RootMargin/Shell/ShellPad/ShellBox/BodyRow/MapPanel": "res://art/ui/runtime/battle/combat_log_panel.png",
	"RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail": "res://art/ui/runtime/overworld/sidebar_frame.png",
}
const WORKBENCH_PRIMARY_BUTTONS := ["LoadMap", "SaveCopy", "PlayWorkingCopy", "ApplyObjectProperties"]
const WORKBENCH_SECONDARY_BUTTONS := [
	"InspectTool",
	"TerrainTool",
	"TerrainLineTool",
	"TerrainRectangleTool",
	"RoadTool",
	"RoadPathTool",
	"HeroStartTool",
	"PlaceObjectTool",
	"RemoveObjectTool",
	"MoveObjectTool",
	"DuplicateObjectTool",
	"RethemeObjectTool",
	"FillTerrain",
	"RestoreSelectedTile",
	"Menu",
]
const WORKBENCH_PICKERS := [
	"MapPackagePicker",
	"TerrainPicker",
	"ObjectFamilyPicker",
	"ObjectContentPicker",
	"SelectedObjectPicker",
	"PropertyOwnerPicker",
	"PropertyDifficultyPicker",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	ContentService.clear_generated_scenario_drafts()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup(
		ScenarioSelectRulesScript.build_random_map_player_config(
			"1",
			"",
			"",
			3,
			"land",
			false,
			"homm3_small",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		),
		"normal"
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated package setup failed: %s" % JSON.stringify(setup))
		return
	var startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var map_path := String(startup.get("map_path", ""))
	var scenario_path := String(startup.get("scenario_path", ""))
	var package_stem := String(startup.get("package_stem", ""))
	var package_id := ScenarioSelectRulesScript.maps_folder_package_id_for_stem(package_stem)
	if package_id == "" or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
		_fail("Generated package setup did not write paired map packages: %s" % JSON.stringify(startup))
		return

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_load_maps_folder_package"):
		_cleanup(map_path, scenario_path)
		_fail("Map editor did not expose Load Map validation hooks.")
		return
	var initial: Dictionary = shell.call("validation_snapshot")
	if bool(initial.get("working_copy", true)):
		_cleanup(map_path, scenario_path)
		_fail("Map editor should wait for Load Map instead of auto-loading an authored scenario: %s" % JSON.stringify(initial))
		return
	if not bool(initial.get("load_map_flow_active", false)) or bool(initial.get("legacy_scenario_dropdown_active", true)):
		_cleanup(map_path, scenario_path)
		_fail("Map editor did not expose the active Load Map package flow: %s" % JSON.stringify(initial))
		return
	if bool(initial.get("authored_json_scenarios_used", true)):
		_cleanup(map_path, scenario_path)
		_fail("Initial Load Map snapshot reported authored JSON scenario usage.")
		return
	var labels: Array = initial.get("map_package_picker_labels", [])
	var metadata: Array = initial.get("map_package_picker_metadata", [])
	if package_id not in metadata:
		_cleanup(map_path, scenario_path)
		_fail("Load Map picker did not include the generated maps/ package id: %s" % JSON.stringify(initial))
		return
	if not _any_label_contains(labels, "Map Package |"):
		_cleanup(map_path, scenario_path)
		_fail("Load Map picker did not use map package copy: %s" % JSON.stringify(labels))
		return
	if _active_copy_mentions_legacy_scenario_dropdown(initial):
		_cleanup(map_path, scenario_path)
		_fail("Load Map UI still exposed old scenario dropdown copy: %s" % JSON.stringify(initial))
		return

	var loaded: Dictionary = shell.call("validation_load_maps_folder_package", package_id)
	if not bool(loaded.get("ok", false)):
		_cleanup(map_path, scenario_path)
		_fail("Load Map could not open the generated package: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_kind", "")) != "maps_folder_package":
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy did not record package source kind: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_package_id", "")) != package_id:
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy did not record the selected package id: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_map_path", "")) != map_path or String(loaded.get("editor_source_scenario_path", "")) != scenario_path:
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy used the wrong package paths: %s" % JSON.stringify(loaded))
		return
	if not bool(loaded.get("maps_folder_package_browser", false)) or not bool(loaded.get("working_copy", false)):
		_cleanup(map_path, scenario_path)
		_fail("Loaded map package did not create a package-backed editor working copy: %s" % JSON.stringify(loaded))
		return
	if bool(loaded.get("authored_json_scenarios_used", true)):
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor snapshot reported authored JSON scenario usage.")
		return
	if ContentService.has_authored_scenario(String(loaded.get("scenario_id", ""))) or ContentService.has_generated_scenario_draft(String(loaded.get("scenario_id", ""))):
		_cleanup(map_path, scenario_path)
		_fail("Loaded package leaked into authored scenarios or generated draft registry: %s" % String(loaded.get("scenario_id", "")))
		return
	var map_ref: Dictionary = loaded.get("map_package_ref", {}) if loaded.get("map_package_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = loaded.get("scenario_package_ref", {}) if loaded.get("scenario_package_ref", {}) is Dictionary else {}
	if map_ref.is_empty() or scenario_ref.is_empty():
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy missed package refs: %s" % JSON.stringify(loaded))
		return
	var index_status: Dictionary = loaded.get("map_package_index_status", {}) if loaded.get("map_package_index_status", {}) is Dictionary else {}
	if int(index_status.get("entry_count", 0)) <= 0:
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor snapshot did not preserve package index visibility: %s" % JSON.stringify(loaded))
		return
	if _active_copy_mentions_legacy_scenario_dropdown(loaded):
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor UI still exposed old scenario dropdown copy: %s" % JSON.stringify(loaded))
		return
	if not await _assert_cartographic_workbench_skin(shell, package_id):
		_cleanup(map_path, scenario_path)
		return
	var initial_overlay: Dictionary = shell.call("validation_placement_debug_overlay_snapshot") if shell.has_method("validation_placement_debug_overlay_snapshot") else {}
	if bool(initial_overlay.get("enabled", true)):
		_cleanup(map_path, scenario_path)
		_fail("Editor F4 blocker overlay should start disabled: %s" % JSON.stringify(initial_overlay))
		return
	shell._unhandled_input(_f4_event())
	await get_tree().process_frame
	var enabled_overlay: Dictionary = shell.call("validation_placement_debug_overlay_snapshot")
	var enabled_map_overlay: Dictionary = enabled_overlay.get("map_view", {}) if enabled_overlay.get("map_view", {}) is Dictionary else {}
	if not bool(enabled_overlay.get("enabled", false)) or not bool(enabled_map_overlay.get("enabled", false)):
		_cleanup(map_path, scenario_path)
		_fail("Editor F4 did not enable the blocker overlay: %s" % JSON.stringify(enabled_overlay))
		return
	if not _has_map_object_blocker_overlay(enabled_overlay):
		_cleanup(map_path, scenario_path)
		_fail("Editor F4 overlay did not expose generated package map object blockers: %s" % JSON.stringify(enabled_overlay))
		return
	shell._unhandled_input(_f4_event())
	await get_tree().process_frame
	var disabled_overlay: Dictionary = shell.call("validation_placement_debug_overlay_snapshot")
	var disabled_map_overlay: Dictionary = disabled_overlay.get("map_view", {}) if disabled_overlay.get("map_view", {}) is Dictionary else {}
	if bool(disabled_overlay.get("enabled", true)) or bool(disabled_map_overlay.get("enabled", true)):
		_cleanup(map_path, scenario_path)
		_fail("Editor F4 did not disable the blocker overlay: %s" % JSON.stringify(disabled_overlay))
		return

	_cleanup(map_path, scenario_path)
	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"package_id": package_id,
		"package_stem": package_stem,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"scenario_id": String(loaded.get("scenario_id", "")),
		"load_map_flow_active": true,
		"authored_json_scenarios_used": false,
	})])
	get_tree().quit(0)


func _assert_cartographic_workbench_skin(shell: Control, package_id: String) -> bool:
	var editor_session = shell.get("_session")
	if editor_session == null or not editor_session.has_method("to_dict"):
		_fail("Map Editor workbench skin proof could not capture the loaded editor session authority.")
		return false
	var editor_authority_before: Dictionary = editor_session.to_dict()
	var active_authority_before: Dictionary = SessionState.ensure_active_session().to_dict()
	var control_contract_before := _workbench_control_contract(shell)
	if control_contract_before.is_empty():
		_fail("Map Editor workbench skin proof could not capture its native control contract.")
		return false
	var first_layout: Dictionary = {}
	for index in range(WORKBENCH_WINDOW_SIZES.size()):
		var requested_size: Vector2i = WORKBENCH_WINDOW_SIZES[index]
		get_window().size = requested_size
		shell.size = Vector2(requested_size)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var layout := _workbench_layout_contract(shell, requested_size)
		if not bool(layout.get("ok", false)):
			_fail("Map Editor cartographic workbench did not retain authored frame/control containment at %s: %s" % [requested_size, layout])
			return false
		var control_contract_now := _workbench_control_contract(shell)
		if control_contract_now != control_contract_before:
			_fail("Map Editor cartographic skin changed native text, items, metadata, selection, state, font, focusability, or minimum-size authority at %s: before=%s now=%s" % [requested_size, control_contract_before, control_contract_now])
			return false
		if index == 0:
			first_layout = layout.duplicate(true)
		elif index == WORKBENCH_WINDOW_SIZES.size() - 1 and layout != first_layout:
			_fail("Map Editor cartographic workbench did not restore exact 1280 layout after the wide pass: first=%s restored=%s" % [first_layout, layout])
			return false
	var picker := shell.get_node_or_null("%MapPackagePicker") as OptionButton
	if picker == null or package_id not in _option_metadata(picker):
		_fail("Map Editor cartographic skin lost the loaded package picker item/metadata authority.")
		return false
	if editor_session.to_dict() != editor_authority_before or SessionState.ensure_active_session().to_dict() != active_authority_before:
		_fail("Map Editor cartographic skin changed the loaded editor or active playable session authority.")
		return false
	return true


func _workbench_layout_contract(shell: Control, expected_size: Vector2i) -> Dictionary:
	var failures: Array[String] = []
	var shell_rect := shell.get_global_rect()
	var top_panel := shell.get_node("RootMargin/Shell/ShellPad/ShellBox/TopPanel") as PanelContainer
	var map_panel := shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/MapPanel") as PanelContainer
	var tool_rail := shell.get_node("RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail") as PanelContainer
	var map_rect := map_panel.get_global_rect()
	var rail_rect := tool_rail.get_global_rect()
	if get_window().size != expected_size or shell.size != Vector2(expected_size):
		failures.append("requested_window")
	if not shell_rect.encloses(top_panel.get_global_rect()) or not shell_rect.encloses(map_rect) or not shell_rect.encloses(rail_rect):
		failures.append("shell_containment")
	if map_rect.end.x > rail_rect.position.x + 0.01 or map_rect.position.y < top_panel.get_global_rect().end.y - 0.01:
		failures.append("body_order")
	if map_rect.size.x < 820.0 or rail_rect.size.x < 340.0 or map_rect.size.x / maxf(shell_rect.size.x, 1.0) < 0.64:
		failures.append("map_dominance")
	for panel_path in WORKBENCH_PANEL_PATHS:
		var panel := shell.get_node(String(panel_path)) as PanelContainer
		if not _style_box_texture_exact(panel.get_theme_stylebox("panel"), String(WORKBENCH_PANEL_PATHS[panel_path])):
			failures.append("panel:%s" % panel_path)
	for button_name in WORKBENCH_PRIMARY_BUTTONS:
		if not _button_art_states_exact(shell.get_node("%%%s" % button_name) as BaseButton, "primary"):
			failures.append("primary:%s" % button_name)
	for button_name in WORKBENCH_SECONDARY_BUTTONS:
		if not _button_art_states_exact(shell.get_node("%%%s" % button_name) as BaseButton, "secondary"):
			failures.append("secondary:%s" % button_name)
	for picker_name in WORKBENCH_PICKERS:
		if not _button_art_states_exact(shell.get_node("%%%s" % picker_name) as OptionButton, "secondary"):
			failures.append("picker:%s" % picker_name)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"window_size": get_window().size,
		"shell_rect": shell_rect,
		"top_rect": top_panel.get_global_rect(),
		"map_rect": map_rect,
		"tool_rail_rect": rail_rect,
	}


func _style_box_texture_exact(style: StyleBox, expected_path: String) -> bool:
	if not (style is StyleBoxTexture):
		return false
	var textured := style as StyleBoxTexture
	return textured.texture != null \
		and textured.texture.resource_path == expected_path \
		and is_equal_approx(textured.texture_margin_left, 24.0) \
		and is_equal_approx(textured.texture_margin_top, 24.0) \
		and is_equal_approx(textured.texture_margin_right, 24.0) \
		and is_equal_approx(textured.texture_margin_bottom, 24.0) \
		and is_equal_approx(textured.content_margin_left, 8.0) \
		and is_equal_approx(textured.content_margin_top, 8.0) \
		and is_equal_approx(textured.content_margin_right, 8.0) \
		and is_equal_approx(textured.content_margin_bottom, 8.0)


func _button_art_states_exact(button: BaseButton, role: String) -> bool:
	if button == null or button.focus_mode != Control.FOCUS_ALL or not (button.get_theme_stylebox("focus") is StyleBoxFlat):
		return false
	for state in ["normal", "hover", "pressed", "disabled"]:
		var expected_path := "res://art/ui/runtime/shared/button_%s_%s.png" % [role, state]
		var style := button.get_theme_stylebox(state)
		if not (style is StyleBoxTexture):
			return false
		var textured := style as StyleBoxTexture
		if textured.texture == null or textured.texture.resource_path != expected_path:
			return false
	return true


func _workbench_control_contract(shell: Control) -> Dictionary:
	var contract := {}
	for button_name in WORKBENCH_PRIMARY_BUTTONS + WORKBENCH_SECONDARY_BUTTONS:
		var button := shell.get_node_or_null("%%%s" % button_name) as BaseButton
		if button == null:
			return {}
		contract[button_name] = {
			"text": button.text,
			"disabled": button.disabled,
			"pressed": button.button_pressed,
			"focus_mode": button.focus_mode,
			"custom_minimum_size": button.custom_minimum_size,
			"font_size": button.get_theme_font_size("font_size"),
		}
	for picker_name in WORKBENCH_PICKERS:
		var picker := shell.get_node_or_null("%%%s" % picker_name) as OptionButton
		if picker == null:
			return {}
		contract[picker_name] = {
			"items": _option_items(picker),
			"popup_items": _popup_items(picker),
			"metadata": _option_metadata(picker),
			"selected": picker.selected,
			"text": picker.text,
			"disabled": picker.disabled,
			"focus_mode": picker.focus_mode,
			"font_size": picker.get_theme_font_size("font_size"),
			"fit_to_longest_item": picker.fit_to_longest_item,
			"clip_text": picker.clip_text,
		}
	return contract


func _option_items(picker: OptionButton) -> Array:
	var items := []
	for index in range(picker.item_count):
		items.append(picker.get_item_text(index))
	return items


func _option_metadata(picker: OptionButton) -> Array:
	var metadata := []
	for index in range(picker.item_count):
		metadata.append(picker.get_item_metadata(index))
	return metadata


func _popup_items(picker: OptionButton) -> Array:
	var items := []
	var popup := picker.get_popup()
	for index in range(popup.item_count):
		items.append(popup.get_item_text(index))
	return items

func _f4_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F4
	event.physical_keycode = KEY_F4
	event.pressed = true
	return event

func _has_map_object_blocker_overlay(snapshot: Dictionary) -> bool:
	var map_view: Dictionary = snapshot.get("map_view", {}) if snapshot.get("map_view", {}) is Dictionary else {}
	var blocker_tiles: Array = map_view.get("blocker_tiles", []) if map_view.get("blocker_tiles", []) is Array else []
	for tile_value in blocker_tiles:
		if not (tile_value is Dictionary):
			continue
		var tile: Dictionary = tile_value
		var kinds: Array = tile.get("kinds", []) if tile.get("kinds", []) is Array else []
		var placement_ids: Array = tile.get("placement_ids", []) if tile.get("placement_ids", []) is Array else []
		if "map_object_body" in kinds and not placement_ids.is_empty():
			return true
	return false

func _any_label_contains(labels: Array, needle: String) -> bool:
	for label in labels:
		if String(label).contains(needle):
			return true
	return false

func _active_copy_mentions_legacy_scenario_dropdown(snapshot: Dictionary) -> bool:
	var combined := " ".join([
		String(snapshot.get("visible_status_text", "")),
		String(snapshot.get("map_load_handoff_text", "")),
		String(snapshot.get("map_load_handoff_tooltip", "")),
		String(snapshot.get("map_package_picker_tooltip", "")),
		String(snapshot.get("load_map_button_text", "")),
		String(snapshot.get("status_text", "")),
	])
	for forbidden in [
		"Scenario switch:",
		"Scenario Switch",
		"scenario dropdown",
		"choosing another scenario",
		"authored baseline",
		"Loaded authored scenario",
		"Ninefold Confluence",
	]:
		if combined.contains(forbidden):
			return true
	return false

func _cleanup(map_path: String, scenario_path: String) -> void:
	if map_path != "" and FileAccess.file_exists(map_path):
		DirAccess.remove_absolute(map_path)
	if scenario_path != "" and FileAccess.file_exists(scenario_path):
		DirAccess.remove_absolute(scenario_path)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
