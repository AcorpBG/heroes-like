extends Node

const REPORT_ID := "ACCESSIBILITY_SCREEN_READER_SEMANTICS_REPORT"
const OVERWORLD_LIVE_REGIONS: Array[Dictionary] = [
	{"path": "RouteCursorLive", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ShellMargin/Shell/ShellPad/Content/BodyRow/SidebarShell/SidebarPad/SidebarBox/EventPanel/EventPad/EventBox/Event", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ShellMargin/Shell/ShellPad/Content/CommandBand/CommandPad/CommandRow/StatusChip/StatusPad/Status", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ShellMargin/Shell/ShellPad/Content/CommandBand/CommandPad/CommandRow/SystemPanel/SystemPad/SystemBox/SaveStatus", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ActivePlaySettingsDialog/Center/DialogPanel/Margin/Content/Header/Status", "mode": DisplayServer.LIVE_POLITE},
]
const MAP_EDITOR_LIVE_REGIONS: Array[Dictionary] = [
	{"path": "EditorMapCursorLive", "mode": DisplayServer.LIVE_POLITE},
]
const BATTLE_LIVE_REGIONS: Array[Dictionary] = [
	{"path": "BattleBoardCursorLive", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ContentMargin/Content/Banner/BannerPad/BannerBox/Event", "mode": DisplayServer.LIVE_POLITE},
	{"path": "ActivePlaySettingsDialog/Center/DialogPanel/Margin/Content/Header/Status", "mode": DisplayServer.LIVE_POLITE},
]

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if int(ProjectSettings.get_setting("accessibility/general/accessibility_support", -1)) != 0:
		return _fail("Project accessibility support is not in automatic native mode.")

	var fixture := VBoxContainer.new()
	fixture.name = "AccessibilityFixture"
	add_child(fixture)

	var generated := Button.new()
	generated.name = "GeneratedCommand"
	generated.text = "Launch campaign"
	generated.tooltip_text = "Open the selected campaign chapter without changing saved expeditions."
	fixture.add_child(generated)

	var authored := Button.new()
	authored.name = "AuthoredCommand"
	authored.text = "Internal label"
	authored.accessibility_name = "Open campaign details"
	authored.accessibility_description = "Review the selected campaign before starting it."
	fixture.add_child(authored)

	var fallback := Button.new()
	fallback.name = "IconOnlyCommand"
	fixture.add_child(fallback)

	var entry := LineEdit.new()
	entry.name = "SaveNameInput"
	entry.placeholder_text = "Optional save name"
	fixture.add_child(entry)

	var option := OptionButton.new()
	option.name = "PresentationModePicker"
	option.tooltip_text = "Choose a display mode."
	option.add_item("Windowed")
	option.add_item("Fullscreen")
	option.select(0)
	fixture.add_child(option)

	var authored_option := OptionButton.new()
	authored_option.name = "AuthoredPicker"
	authored_option.add_item("Brief")
	authored_option.accessibility_name = "Battle detail level"
	authored_option.accessibility_description = "Choose how much tactical detail is announced."
	fixture.add_child(authored_option)

	var event := Label.new()
	event.name = "Event"
	event.text = "A frontier route opened."
	fixture.add_child(event)

	await _settle()
	var fixture_snapshot: Dictionary = UiAccessibility.validation_snapshot(fixture)
	if not bool(fixture_snapshot.get("ok", false)):
		return _fail("Fixture controls are missing semantics: %s" % fixture_snapshot)
	if generated.accessibility_name != "" or UiAccessibility.semantic_name(generated) != "Launch campaign":
		return _fail("Button text did not remain its effective native accessibility name: %s" % UiAccessibility.semantic_name(generated))
	if not generated.accessibility_description.contains("without changing saved expeditions"):
		return _fail("Button tooltip did not become its accessibility description.")
	if authored.accessibility_name != "Open campaign details" or authored.accessibility_description != "Review the selected campaign before starting it.":
		return _fail("Authored accessibility semantics were replaced.")
	if fallback.accessibility_name != "Icon Only Command" or fallback.accessibility_description != "Activate Icon Only Command.":
		return _fail("Icon-only command did not receive a readable node-name fallback: %s / %s" % [fallback.accessibility_name, fallback.accessibility_description])
	if entry.accessibility_name != "Save Name Input" or entry.accessibility_description != "Enter Save Name Input.":
		return _fail("Text entry did not receive a stable field identity: %s" % entry.accessibility_name)
	if option.accessibility_name != "Presentation Mode" or UiAccessibility.semantic_name(option) != "Presentation Mode":
		return _fail("Option control did not receive a stable field identity: %s / %s" % [option.accessibility_name, UiAccessibility.semantic_name(option)])
	if not option.accessibility_description.contains("Choose a display mode") or not option.accessibility_description.contains("Current value: Windowed"):
		return _fail("Option control did not expose its initial current value: %s" % option.accessibility_description)
	option.select(1)
	option.item_selected.emit(1)
	await _settle()
	if UiAccessibility.semantic_name(option) != "Presentation Mode" or not option.accessibility_description.contains("Current value: Fullscreen"):
		return _fail("Option semantics did not retain field identity and refresh the selected value: %s / %s" % [UiAccessibility.semantic_name(option), option.accessibility_description])
	if authored_option.accessibility_name != "Battle detail level" or authored_option.accessibility_description != "Choose how much tactical detail is announced.":
		return _fail("Authored option semantics were replaced: %s / %s" % [authored_option.accessibility_name, authored_option.accessibility_description])
	fixture.remove_child(option)
	await _settle()
	fixture.add_child(option)
	await _settle()
	UiAccessibility.configure_control(option)
	if (
		_connection_count(option.focus_entered, "_on_control_refresh_requested") != 1
		or _connection_count(option.visibility_changed, "_on_control_refresh_requested") != 1
		or _connection_count(option.item_selected, "_on_option_selected") != 1
	):
		return _fail("Re-entered controls received duplicate accessibility signal connections.")
	if event.accessibility_live != DisplayServer.LIVE_POLITE:
		return _fail("Event label is not a polite native live region.")
	if event.accessibility_name != "":
		return _fail("Live label text was replaced by a static accessibility name.")

	generated.text = "Resume campaign"
	generated.tooltip_text = "Resume the latest selected campaign checkpoint."
	generated.grab_focus()
	await _settle()
	if UiAccessibility.semantic_name(generated) != "Resume campaign" or not generated.accessibility_description.contains("latest selected campaign checkpoint"):
		return _fail("Derived semantics did not refresh with changed control text and tooltip.")

	var dynamic := Button.new()
	dynamic.name = "DynamicRecruitOrder"
	dynamic.text = "Recruit wardens"
	dynamic.tooltip_text = "Recruit the selected available stack."
	fixture.add_child(dynamic)
	if (
		UiAccessibility.semantic_name(dynamic) != "Recruit wardens"
		or dynamic.accessibility_description != "Recruit the selected available stack."
		or _connection_count(dynamic.focus_entered, "_on_control_refresh_requested") != 1
		or _connection_count(dynamic.visibility_changed, "_on_control_refresh_requested") != 1
	):
		return _fail("Dynamically inserted control did not receive synchronous first-pass semantics.")
	await _settle()
	if UiAccessibility.semantic_name(dynamic) != "Recruit wardens" or dynamic.accessibility_description == "":
		return _fail("Dynamically inserted control did not receive semantics.")

	var post_add := Button.new()
	post_add.name = "PostAddAction"
	fixture.add_child(post_add)
	if post_add.accessibility_description != "Activate Post Add Action.":
		return _fail("Post-add control did not receive synchronous fallback semantics: %s" % post_add.accessibility_description)
	post_add.text = "Inspect frontier"
	post_add.tooltip_text = "Inspect the selected frontier tile."
	await _settle()
	if UiAccessibility.semantic_name(post_add) != "Inspect frontier" or post_add.accessibility_description != "Inspect the selected frontier tile.":
		return _fail("Deferred semantics did not refresh values assigned after insertion: %s / %s" % [UiAccessibility.semantic_name(post_add), post_add.accessibility_description])

	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await _settle()
	var menu_snapshot: Dictionary = UiAccessibility.validation_snapshot(menu)
	if not bool(menu_snapshot.get("ok", false)):
		return _fail("Visible main-menu controls are missing native semantics: %s" % menu_snapshot)
	if int(menu_snapshot.get("focusable_control_count", 0)) < 20:
		return _fail("Main-menu semantic scan covered too few focusable controls: %s" % menu_snapshot)
	if int(menu_snapshot.get("live_region_count", 0)) != 5:
		return _fail("Main menu must expose exactly five shared polite live regions: %s" % menu_snapshot.get("live_regions", []))
	if _live_region_path_count(menu_snapshot, "/BindingStatus") != 1:
		return _fail("Main menu must expose exactly one BindingStatus live-region entry: %s" % menu_snapshot.get("live_regions", []))
	var binding_status_nodes: Array = menu.find_children("BindingStatus", "Label", true, false)
	if binding_status_nodes.size() != 1:
		return _fail("Main menu must own exactly one BindingStatus Label: %s" % [binding_status_nodes])
	var binding_status := binding_status_nodes[0] as Label
	if binding_status.accessibility_live != DisplayServer.LIVE_POLITE:
		return _fail("BindingStatus is not a polite native live region.")
	if binding_status.accessibility_description != "Reports hero movement keybinding capture prompts and results." or binding_status.accessibility_description.length() > HeroesUiAccessibility.MAX_DESCRIPTION_LENGTH:
		return _fail("BindingStatus does not expose the exact bounded shared description: %s" % binding_status.accessibility_description)
	var rescanned_menu_snapshot: Dictionary = UiAccessibility.validation_snapshot(menu)
	var keybindings_dialog := menu.get_node("HeroKeybindingsDialog") as HeroKeybindingsDialog
	menu.call("validation_open_hero_keybindings_dialog")
	await _settle()
	keybindings_dialog.close_dialog()
	await _settle()
	menu.call("validation_open_hero_keybindings_dialog")
	await _settle()
	var reentered_menu_snapshot: Dictionary = UiAccessibility.validation_snapshot(menu)
	if int(rescanned_menu_snapshot.get("live_region_count", 0)) != 5 or int(reentered_menu_snapshot.get("live_region_count", 0)) != 5:
		return _fail("Repeated menu scans duplicated or dropped shared live regions: %s / %s" % [rescanned_menu_snapshot.get("live_regions", []), reentered_menu_snapshot.get("live_regions", [])])
	if _live_region_path_count(reentered_menu_snapshot, "/BindingStatus") != 1 or menu.find_children("BindingStatus", "Label", true, false).size() != 1:
		return _fail("Repeated menu entry duplicated BindingStatus semantics or nodes.")
	var reentered_binding_status := menu.find_children("BindingStatus", "Label", true, false)[0] as Label
	if reentered_binding_status.accessibility_live != DisplayServer.LIVE_POLITE or reentered_binding_status.accessibility_description != "Reports hero movement keybinding capture prompts and results." or reentered_binding_status.accessibility_description.length() > HeroesUiAccessibility.MAX_DESCRIPTION_LENGTH:
		return _fail("Dialog re-entry or repeated scan replaced BindingStatus live semantics: %s / %s" % [reentered_binding_status.accessibility_live, reentered_binding_status.accessibility_description])
	keybindings_dialog.close_dialog()
	await _settle()
	var settings_transaction_before: Dictionary = _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot())
	var settings_session_before = SessionState.active_session
	var settings_save_cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var open_settings_button := menu.get_node("BackdropCommandHotspots/OpenSettings") as Button
	open_settings_button.pressed.emit()
	await _settle()
	var stage_dock_panel := menu.get_node("StageDockPanel") as PanelContainer
	var menu_tabs := menu.find_child("MenuTabs", true, false) as TabContainer
	var settings_scroll := menu.find_child("SettingsScroll", true, false) as ScrollContainer
	var presentation_mode_picker := menu.find_child("PresentationModePicker", true, false) as OptionButton
	var render_quality_picker := menu.find_child("RenderQualityPicker", true, false) as OptionButton
	var settings_scroll_rect := settings_scroll.get_global_rect()
	var presentation_mode_rect := presentation_mode_picker.get_global_rect()
	var render_quality_rect := render_quality_picker.get_global_rect()
	var settings_stage_checks := {
		"stage_visible": stage_dock_panel.visible and stage_dock_panel.is_visible_in_tree(),
		"settings_tab_active": menu_tabs.get_current_tab_control() != null and String(menu_tabs.get_current_tab_control().name) == "Settings",
		"presentation_visible": presentation_mode_picker.is_visible_in_tree(),
		"render_quality_visible": render_quality_picker.is_visible_in_tree(),
		"presentation_focus": get_viewport().gui_get_focus_owner() == presentation_mode_picker,
		"settings_scroll_at_entry": settings_scroll.scroll_vertical == 0,
		"presentation_inside_scroll": settings_scroll_rect.encloses(presentation_mode_rect),
		"render_quality_inside_scroll": settings_scroll_rect.encloses(render_quality_rect),
		"presentation_name": UiAccessibility.semantic_name(presentation_mode_picker) == "Presentation Mode",
		"presentation_current_value": presentation_mode_picker.accessibility_description.contains("Current value:"),
		"render_quality_name": UiAccessibility.semantic_name(render_quality_picker) == "Render Quality",
		"render_quality_current_value": render_quality_picker.accessibility_description.contains("Current value:"),
		"presentation_focus_connection": _connection_count(presentation_mode_picker.focus_entered, "_on_control_refresh_requested") == 1,
		"presentation_visibility_connection": _connection_count(presentation_mode_picker.visibility_changed, "_on_control_refresh_requested") == 1,
		"render_focus_connection": _connection_count(render_quality_picker.focus_entered, "_on_control_refresh_requested") == 1,
		"render_visibility_connection": _connection_count(render_quality_picker.visibility_changed, "_on_control_refresh_requested") == 1,
		"settings_authority": _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot()) == settings_transaction_before,
		"session_authority": SessionState.active_session == settings_session_before,
		"save_cache_authority": SaveService.validation_summary_cache_snapshot() == settings_save_cache_before,
	}
	if not _checks_exact(settings_stage_checks):
		return _fail("Main-menu Settings secondary board did not preserve exact focus, semantics, lifecycle, and authority: %s" % settings_stage_checks)
	for node_name in ["OpenCampaign", "OpenSkirmish", "OpenSaves", "OpenSettings", "OpenEditor", "Quit"]:
		var control := menu.get_node_or_null("BackdropCommandHotspots/%s" % node_name) as Control
		if control == null or UiAccessibility.semantic_name(control) == "" or control.accessibility_description == "":
			return _fail("Main-menu command lacks native semantics: %s" % node_name)
	for option_contract in [
		{"node": "PresentationModePicker", "name": "Presentation Mode"},
		{"node": "UIScalePicker", "name": "UI Scale"},
		{"node": "ColorCuePicker", "name": "Color Cue"},
	]:
		var shipped_option := menu.find_child(String(option_contract["node"]), true, false) as OptionButton
		if shipped_option == null:
			return _fail("Shipped option control is missing: %s" % option_contract["node"])
		if UiAccessibility.semantic_name(shipped_option) != String(option_contract["name"]):
			return _fail("Shipped option control lacks stable field identity: %s / %s" % [option_contract["node"], UiAccessibility.semantic_name(shipped_option)])
		if not shipped_option.accessibility_description.contains("Current value:"):
			return _fail("Shipped option control lacks current-value semantics: %s / %s" % [option_contract["node"], shipped_option.accessibility_description])

	var original_session = SessionState.active_session
	var original_summary_cache: Dictionary = SaveService.validation_summary_cache_snapshot()
	var overworld_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(overworld_session)
	SessionState.set_active_session(overworld_session)
	var overworld = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld)
	await _settle()
	var route_live_nodes: Array = overworld.find_children("RouteCursorLive", "Label", true, false)
	if route_live_nodes.size() != 1:
		overworld.queue_free()
		await get_tree().process_frame
		SessionState.active_session = original_session
		SaveService._slot_summary_cache = original_summary_cache.duplicate(true)
		return _fail("Overworld must expose exactly one RouteCursorLive Label: %s" % [route_live_nodes])
	var route_live := route_live_nodes[0] as Label
	var overworld_snapshot: Dictionary = UiAccessibility.validation_snapshot(overworld)
	var rescanned_overworld_snapshot: Dictionary = UiAccessibility.validation_snapshot(overworld)
	var overworld_live_regions: Array[Dictionary] = _relative_live_regions(overworld, overworld_snapshot)
	var rescanned_overworld_live_regions: Array[Dictionary] = _relative_live_regions(overworld, rescanned_overworld_snapshot)
	var route_live_relative_path := String(route_live.get_path()).trim_prefix("%s/" % String(overworld.get_path()))
	var shell_margin := overworld.get_node_or_null("ShellMargin") as Control
	var route_live_checks := {
		"snapshot_ok": bool(overworld_snapshot.get("ok", false)),
		"first_scan_exact_order": overworld_live_regions == OVERWORLD_LIVE_REGIONS,
		"second_scan_equals_first": rescanned_overworld_live_regions == overworld_live_regions,
		"total_five": int(overworld_snapshot.get("live_region_count", 0)) == 5 and overworld_live_regions.size() == 5,
		"one_route_context": overworld_live_regions.count(OVERWORLD_LIVE_REGIONS[0]) == 1,
		"existing_four": overworld_live_regions.slice(1).size() == 4,
		"unique_route_find": route_live_nodes.size() == 1,
		"route_relative_path": route_live_relative_path == String(OVERWORLD_LIVE_REGIONS[0].get("path", "")),
		"visible_tree": route_live.is_visible_in_tree(),
		"direct_overworld_parent": route_live.get_parent() == overworld,
		"layout_mode_zero": route_live.layout_mode == 0,
		"anchors_zero": is_zero_approx(route_live.anchor_left) and is_zero_approx(route_live.anchor_top) and is_zero_approx(route_live.anchor_right) and is_zero_approx(route_live.anchor_bottom),
		"position_zero": route_live.position == Vector2.ZERO,
		"one_pixel_width": is_equal_approx(route_live.size.x, 1.0),
		"finite_positive_height": is_finite(route_live.size.y) and route_live.size.y >= 1.0,
		"shell_margin_exists": shell_margin != null,
		"shell_margin_position_zero": shell_margin != null and shell_margin.position == Vector2.ZERO,
		"shell_margin_matches_root": shell_margin != null and shell_margin.size == overworld.size,
		"transparent": is_zero_approx(route_live.self_modulate.a),
		"mouse_ignored": route_live.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"authored_name": route_live.accessibility_name == "Route cursor",
		"authored_description": route_live.accessibility_description == "Announces the current right-stick route destination after navigation settles.",
		"polite": route_live.accessibility_live == DisplayServer.LIVE_POLITE,
		"loaded_inactive_empty": route_live.text == "",
	}
	if not _checks_exact(route_live_checks):
		overworld.queue_free()
		await get_tree().process_frame
		SessionState.active_session = original_session
		SaveService._slot_summary_cache = original_summary_cache.duplicate(true)
		return _fail("Overworld route-context live semantics were not exact: %s / %s" % [route_live_checks, overworld_snapshot.get("live_regions", [])])
	overworld.queue_free()
	await get_tree().process_frame
	SessionState.active_session = original_session
	SaveService._slot_summary_cache = original_summary_cache.duplicate(true)

	var map_editor = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	map_editor.set("validation_skip_initial_package_index", true)
	add_child(map_editor)
	await _settle()
	var editor_live_nodes: Array = map_editor.find_children("EditorMapCursorLive", "Label", true, false)
	var working_copy_status_nodes: Array = map_editor.find_children("WorkingCopyStatus", "Label", true, false)
	if editor_live_nodes.size() != 1 or working_copy_status_nodes.size() != 1:
		map_editor.queue_free()
		await get_tree().process_frame
		return _fail("Map Editor must expose exactly one cursor live region and one non-live working-copy status: %s / %s" % [editor_live_nodes, working_copy_status_nodes])
	var editor_live := editor_live_nodes[0] as Label
	var working_copy_status := working_copy_status_nodes[0] as Label
	var editor_snapshot: Dictionary = UiAccessibility.validation_snapshot(map_editor)
	var rescanned_editor_snapshot: Dictionary = UiAccessibility.validation_snapshot(map_editor)
	var editor_live_regions: Array[Dictionary] = _relative_live_regions(map_editor, editor_snapshot)
	var rescanned_editor_live_regions: Array[Dictionary] = _relative_live_regions(map_editor, rescanned_editor_snapshot)
	var editor_live_relative_path := String(editor_live.get_path()).trim_prefix("%s/" % String(map_editor.get_path()))
	var working_copy_relative_path := String(working_copy_status.get_path()).trim_prefix("%s/" % String(map_editor.get_path()))
	var editor_live_checks := {
		"snapshot_ok": bool(editor_snapshot.get("ok", false)),
		"first_scan_exact_order": editor_live_regions == MAP_EDITOR_LIVE_REGIONS,
		"second_scan_equals_first": rescanned_editor_live_regions == editor_live_regions,
		"total_one": int(editor_snapshot.get("live_region_count", 0)) == 1 and editor_live_regions.size() == 1,
		"one_cursor_context": editor_live_regions.count(MAP_EDITOR_LIVE_REGIONS[0]) == 1,
		"unique_cursor_find": editor_live_nodes.size() == 1,
		"cursor_relative_path": editor_live_relative_path == String(MAP_EDITOR_LIVE_REGIONS[0].get("path", "")),
		"visible_tree": editor_live.is_visible_in_tree(),
		"direct_editor_parent": editor_live.get_parent() == map_editor,
		"layout_mode_zero": editor_live.layout_mode == 0,
		"anchors_zero": is_zero_approx(editor_live.anchor_left) and is_zero_approx(editor_live.anchor_top) and is_zero_approx(editor_live.anchor_right) and is_zero_approx(editor_live.anchor_bottom),
		"position_zero": editor_live.position == Vector2.ZERO,
		"one_pixel_width": is_equal_approx(editor_live.size.x, 1.0),
		"finite_layout_height": is_finite(editor_live.size.y) and editor_live.size.y >= 1.0,
		"transparent": is_zero_approx(editor_live.self_modulate.a),
		"mouse_ignored": editor_live.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"authored_name": editor_live.accessibility_name == "Map editor cursor",
		"authored_description": editor_live.accessibility_description == "Announces the current map editor tile, material, tool, and available keyboard actions after canvas navigation settles.",
		"polite": editor_live.accessibility_live == DisplayServer.LIVE_POLITE,
		"loaded_inactive_empty": editor_live.text == "",
		"working_copy_unique": working_copy_status_nodes.size() == 1,
		"working_copy_exact_path": working_copy_relative_path == "RootMargin/Shell/ShellPad/ShellBox/BodyRow/ToolRail/ToolPad/ToolScroll/ToolBox/WorkingCopyStatus",
		"working_copy_visible": working_copy_status.is_visible_in_tree(),
		"working_copy_live_off": working_copy_status.accessibility_live == DisplayServer.LIVE_OFF,
	}
	if not _checks_exact(editor_live_checks):
		map_editor.queue_free()
		await get_tree().process_frame
		return _fail("Map Editor cursor and working-copy accessibility semantics were not exact: %s / %s" % [editor_live_checks, editor_snapshot.get("live_regions", [])])
	map_editor.queue_free()
	await get_tree().process_frame

	var battle_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var battle_encounter := _first_uncleared_encounter(battle_session)
	if battle_encounter.is_empty():
		return _fail("Battle accessibility fixture has no encounter.")
	battle_session.battle = BattleRules.create_battle_payload(battle_session, battle_encounter)
	SessionState.set_active_session(battle_session)
	var battle = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(battle)
	await _settle()
	var battle_live_nodes: Array = battle.find_children("BattleBoardCursorLive", "Label", true, false)
	if battle_live_nodes.size() != 1:
		battle.queue_free()
		await get_tree().process_frame
		SessionState.active_session = original_session
		SaveService._slot_summary_cache = original_summary_cache.duplicate(true)
		return _fail("Battle must expose exactly one BattleBoardCursorLive Label: %s" % [battle_live_nodes])
	var battle_live := battle_live_nodes[0] as Label
	var battle_snapshot: Dictionary = UiAccessibility.validation_snapshot(battle)
	var rescanned_battle_snapshot: Dictionary = UiAccessibility.validation_snapshot(battle)
	var battle_live_regions: Array[Dictionary] = _relative_live_regions(battle, battle_snapshot)
	var rescanned_battle_live_regions: Array[Dictionary] = _relative_live_regions(battle, rescanned_battle_snapshot)
	var battle_live_relative_path := String(battle_live.get_path()).trim_prefix("%s/" % String(battle.get_path()))
	var battle_backdrop := battle.get_node_or_null("Backdrop") as Control
	var battle_live_checks := {
		"snapshot_ok": bool(battle_snapshot.get("ok", false)),
		"first_scan_exact_order": battle_live_regions == BATTLE_LIVE_REGIONS,
		"second_scan_equals_first": rescanned_battle_live_regions == battle_live_regions,
		"total_four": int(battle_snapshot.get("live_region_count", 0)) == 4 and battle_live_regions.size() == 4,
		"one_battle_context": battle_live_regions.count(BATTLE_LIVE_REGIONS[0]) == 1,
		"existing_three": battle_live_regions.slice(1).size() == 3,
		"unique_cursor_find": battle_live_nodes.size() == 1,
		"cursor_relative_path": battle_live_relative_path == String(BATTLE_LIVE_REGIONS[0].get("path", "")),
		"visible_tree": battle_live.is_visible_in_tree(),
		"direct_battle_parent": battle_live.get_parent() == battle,
		"layout_mode_zero": battle_live.layout_mode == 0,
		"anchors_zero": is_zero_approx(battle_live.anchor_left) and is_zero_approx(battle_live.anchor_top) and is_zero_approx(battle_live.anchor_right) and is_zero_approx(battle_live.anchor_bottom),
		"position_zero": battle_live.position == Vector2.ZERO,
		"one_pixel_width": is_equal_approx(battle_live.size.x, 1.0),
		"finite_layout_height": is_finite(battle_live.size.y) and battle_live.size.y >= 1.0,
		"backdrop_exists": battle_backdrop != null,
		"backdrop_position_zero": battle_backdrop != null and battle_backdrop.position == Vector2.ZERO,
		"backdrop_matches_root": battle_backdrop != null and battle_backdrop.size == battle.size,
		"transparent": is_zero_approx(battle_live.self_modulate.a),
		"mouse_ignored": battle_live.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"authored_name": battle_live.accessibility_name == "Battle board cursor",
		"authored_description": battle_live.accessibility_description == "Announces the current keyboard or controller battle-board hex and available action after navigation settles.",
		"polite": battle_live.accessibility_live == DisplayServer.LIVE_POLITE,
		"loaded_inactive_empty": battle_live.text == "",
	}
	if not _checks_exact(battle_live_checks):
		battle.queue_free()
		await get_tree().process_frame
		SessionState.active_session = original_session
		SaveService._slot_summary_cache = original_summary_cache.duplicate(true)
		return _fail("Battle cursor accessibility semantics were not exact: %s / %s" % [battle_live_checks, battle_snapshot.get("live_regions", [])])
	battle.queue_free()
	await get_tree().process_frame
	SessionState.active_session = original_session
	SaveService._slot_summary_cache = original_summary_cache.duplicate(true)

	var result := {
		"schema": "accessibility_screen_reader_semantics_report_v1",
		"accessibility_support_mode": 0,
		"fixture_focusable_controls": int(fixture_snapshot.get("focusable_control_count", 0)),
		"menu_focusable_controls": int(menu_snapshot.get("focusable_control_count", 0)),
		"menu_live_regions": int(menu_snapshot.get("live_region_count", 0)),
		"dynamic_control_named": UiAccessibility.semantic_name(dynamic) != "",
		"authored_semantics_preserved": true,
		"option_field_semantics": true,
		"reentry_connections_deduplicated": true,
		"binding_status_polite": true,
		"binding_status_exact_count": 1,
		"settings_stage_accessibility_refresh_exact": true,
		"overworld_route_context_live_exact_count": 1,
		"overworld_existing_live_regions_unchanged": 4,
		"overworld_route_context_rescan_exact": true,
		"overworld_route_context_authored_semantics": true,
		"map_editor_cursor_live_exact_count": 1,
		"map_editor_cursor_rescan_exact": true,
		"map_editor_cursor_authored_semantics": true,
		"map_editor_working_copy_status_live_off": true,
		"battle_board_cursor_live_exact_count": 1,
		"battle_existing_live_regions_unchanged": 3,
		"battle_board_cursor_rescan_exact": true,
		"battle_board_cursor_authored_semantics": true,
	}
	print("%s PASS %s" % [REPORT_ID, JSON.stringify(result)])
	menu.queue_free()
	fixture.queue_free()
	get_tree().quit(0)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _connection_count(signal_value: Signal, method_name: String) -> int:
	var count := 0
	for connection in signal_value.get_connections():
		var callable: Callable = connection.get("callable", Callable())
		if callable.get_object() == UiAccessibility and callable.get_method() == method_name:
			count += 1
	return count


func _canonical_settings_transaction(transaction: Dictionary) -> Dictionary:
	var canonical: Dictionary = transaction.duplicate(true)
	var canonical_input_map := {}
	var input_map: Dictionary = transaction.get("input_map", {}) if transaction.get("input_map", {}) is Dictionary else {}
	for action_value in input_map.keys():
		var action := String(action_value)
		var action_state: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var canonical_events: Array = []
		var events: Array = action_state.get("events", []) if action_state.get("events", []) is Array else []
		for event_value in events:
			if event_value is InputEvent:
				canonical_events.append(_canonical_stored_input_event(event_value as InputEvent))
			else:
				canonical_events.append({"class": "", "as_text": var_to_str(event_value), "stored_properties": []})
		canonical_input_map[action] = {
			"action": action,
			"exists": bool(action_state.get("exists", false)),
			"deadzone": float(action_state.get("deadzone", 0.5)),
			"events": canonical_events,
		}
	canonical["input_map"] = canonical_input_map
	return canonical


func _canonical_stored_input_event(event: InputEvent) -> Dictionary:
	var stored_properties: Array = []
	for property_value in event.get_property_list():
		if not (property_value is Dictionary):
			continue
		var property: Dictionary = property_value
		var property_name := String(property.get("name", ""))
		var property_usage := int(property.get("usage", 0))
		if property_name == "script" or (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		stored_properties.append({"name": property_name, "value": var_to_str(event.get(property_name))})
	return {"class": event.get_class(), "as_text": event.as_text(), "stored_properties": stored_properties}


func _first_uncleared_encounter(session) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and not bool(encounter_value.get("cleared", false)):
			return (encounter_value as Dictionary).duplicate(true)
	return {}


func _live_region_path_count(snapshot: Dictionary, suffix: String) -> int:
	var count := 0
	for entry_value in snapshot.get("live_regions", []):
		var entry: Dictionary = entry_value
		if String(entry.get("path", "")).ends_with(suffix) and int(entry.get("mode", DisplayServer.LIVE_OFF)) == DisplayServer.LIVE_POLITE:
			count += 1
	return count


func _relative_live_regions(root: Node, snapshot: Dictionary) -> Array[Dictionary]:
	var relative_rows: Array[Dictionary] = []
	var absolute_prefix := "%s/" % String(root.get_path())
	for entry_value in snapshot.get("live_regions", []):
		if not (entry_value is Dictionary):
			continue
		var detached: Dictionary = (entry_value as Dictionary).duplicate(true)
		detached["path"] = String(detached.get("path", "")).trim_prefix(absolute_prefix)
		relative_rows.append(detached)
	return relative_rows


func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
