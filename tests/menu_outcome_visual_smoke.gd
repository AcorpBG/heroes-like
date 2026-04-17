extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_main_menu_smoke():
		return
	if not await _run_outcome_smoke():
		return
	get_tree().quit(0)

func _run_main_menu_smoke() -> bool:
	var original_resolution := SettingsService.presentation_resolution_id()
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var hero_stage = shell.get_node_or_null("%HeroStage")
	if hero_stage == null:
		push_error("Main menu smoke: hero landing art did not load.")
		get_tree().quit(1)
		return false

	var right_shade = shell.get_node_or_null("RightShade")
	if shell.get_node_or_null("TopShade") != null or shell.get_node_or_null("BottomShade") != null:
		push_error("Main menu smoke: broad top/bottom backdrop shade layers returned.")
		get_tree().quit(1)
		return false
	if _hero_view_draws_backdrop_washes():
		push_error("Main menu smoke: hero backdrop view is still drawing broad wash overlays.")
		get_tree().quit(1)
		return false
	if not (right_shade is ColorRect):
		push_error("Main menu smoke: right command gutter shade is missing.")
		get_tree().quit(1)
		return false
	var right_shade_rect := right_shade as ColorRect
	if right_shade_rect.anchor_left < 0.78 or right_shade_rect.color.a < 0.28:
		push_error("Main menu smoke: right command gutter is not a narrow darkened stage edge.")
		get_tree().quit(1)
		return false

	var command_block = shell.get_node_or_null("%CommandBlockPanel")
	var command_title = shell.get_node_or_null("%CommandBlockTitle")
	var menu_button = shell.get_node_or_null("%Menu")
	var quit_button = shell.get_node_or_null("%Quit")
	var campaign_button = shell.get_node_or_null("%OpenCampaign")
	var spine_header = shell.get_node_or_null("CommandSpinePanel/CommandSpinePad/CommandSpineBox/SpineHeaderRow/SpineHeader")
	if command_block == null or command_title == null or menu_button == null or quit_button == null or campaign_button == null or spine_header == null:
		push_error("Main menu smoke: command block grouping nodes are missing.")
		get_tree().quit(1)
		return false
	if not (command_title is Label) or not (menu_button is Button) or not (quit_button is Button) or not (campaign_button is Button) or not (spine_header is Label):
		push_error("Main menu smoke: command block grouping nodes have unexpected types.")
		get_tree().quit(1)
		return false
	var command_title_label := command_title as Label
	var menu_command_button := menu_button as Button
	var quit_command_button := quit_button as Button
	var campaign_nav_button := campaign_button as Button
	var spine_header_label := spine_header as Label
	if String(spine_header_label.text) != "Menu" or String(command_title_label.text) != "Command":
		push_error("Main menu smoke: command spine titles do not match the wireframe grouping.")
		get_tree().quit(1)
		return false
	if not command_block.is_ancestor_of(menu_command_button) or not command_block.is_ancestor_of(quit_command_button) or command_block.is_ancestor_of(campaign_nav_button):
		push_error("Main menu smoke: Menu/Quit are not isolated from the main navigation spine.")
		get_tree().quit(1)
		return false

	var campaign_list = shell.get_node_or_null("%CampaignList")
	if campaign_list == null or int(campaign_list.get_item_count()) <= 0:
		push_error("Main menu smoke: campaign browser did not populate.")
		get_tree().quit(1)
		return false

	var skirmish_list = shell.get_node_or_null("%SkirmishList")
	if skirmish_list == null or int(skirmish_list.get_item_count()) <= 0:
		push_error("Main menu smoke: skirmish browser did not populate.")
		get_tree().quit(1)
		return false

	if not shell.has_method("validation_open_settings_stage") or not shell.has_method("validation_select_resolution"):
		push_error("Main menu smoke: settings resolution validation hooks are missing.")
		get_tree().quit(1)
		return false

	shell.call("validation_open_settings_stage")
	if menu_command_button.disabled:
		push_error("Main menu smoke: Menu command did not become available after opening a secondary board.")
		get_tree().quit(1)
		return false

	var settings_snapshot: Dictionary = shell.call("validation_snapshot")
	var resolution_ids := _resolution_ids_from_snapshot(settings_snapshot)
	for expected_id in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
		if not resolution_ids.has(expected_id):
			push_error("Main menu smoke: settings resolution picker omitted %s: %s." % [expected_id, resolution_ids])
			get_tree().quit(1)
			return false

	if not bool(shell.call("validation_select_resolution", "1600x900")):
		push_error("Main menu smoke: settings resolution picker could not select 1600x900.")
		get_tree().quit(1)
		return false

	settings_snapshot = shell.call("validation_snapshot")
	var settings_summary := String(settings_snapshot.get("settings_summary_full", settings_snapshot.get("settings_summary", "")))
	if String(settings_snapshot.get("presentation_resolution", "")) != "1600x900" or not settings_summary.contains("1600 x 900"):
		if original_resolution != "1600x900":
			shell.call("validation_select_resolution", original_resolution)
		push_error("Main menu smoke: settings summary did not reflect selected 1600x900 resolution: %s." % settings_snapshot)
		get_tree().quit(1)
		return false

	if original_resolution != "1600x900" and not bool(shell.call("validation_select_resolution", original_resolution)):
		push_error("Main menu smoke: settings resolution picker could not restore %s." % original_resolution)
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _resolution_ids_from_snapshot(snapshot: Dictionary) -> Array:
	var ids := []
	var options: Array = snapshot.get("presentation_resolution_options", [])
	for option in options:
		if option is Dictionary:
			ids.append(String(option.get("id", "")))
	return ids

func _hero_view_draws_backdrop_washes() -> bool:
	var source_file := FileAccess.open("res://scenes/menus/MainMenuHeroView.gd", FileAccess.READ)
	if source_file == null:
		return true
	var source := source_file.get_as_text()
	return source.contains("draw_rect(") or source.contains("TOP_WASH") or source.contains("LOWER_SHADE")

func _run_outcome_smoke() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session.scenario_status = "victory"
	session.scenario_summary = "Smoke victory outcome."
	SessionState.set_active_session(session)

	var shell = load("res://scenes/results/ScenarioOutcomeShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var banner = shell.get_node_or_null("%OutcomeBanner")
	if banner == null:
		push_error("Outcome smoke: result banner did not load.")
		get_tree().quit(1)
		return false

	var actions = shell.get_node_or_null("%Actions")
	if actions == null or actions.get_child_count() <= 0:
		push_error("Outcome smoke: follow-up action row did not populate.")
		get_tree().quit(1)
		return false

	var save_slot = shell.get_node_or_null("%SaveSlot")
	if save_slot == null or int(save_slot.get_item_count()) <= 0:
		push_error("Outcome smoke: save slot picker did not populate.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true
