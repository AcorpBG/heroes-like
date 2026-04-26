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
	SaveService.save_runtime_autosave_session(session)

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var hero_stage = shell.get_node_or_null("%HeroStage")
	if hero_stage == null:
		push_error("Main menu smoke: hero landing art did not load.")
		get_tree().quit(1)
		return false

	if shell.get_node_or_null("TopShade") != null or shell.get_node_or_null("BottomShade") != null:
		push_error("Main menu smoke: broad top/bottom backdrop shade layers returned.")
		get_tree().quit(1)
		return false
	if _hero_view_draws_backdrop_washes():
		push_error("Main menu smoke: hero backdrop view is still drawing broad wash overlays.")
		get_tree().quit(1)
		return false
	if shell.get_node_or_null("RightShade") != null:
		push_error("Main menu smoke: separate right-side shade returned over the painted command door.")
		get_tree().quit(1)
		return false

	var hotspot_surface = shell.get_node_or_null("%BackdropCommandHotspots")
	if hotspot_surface == null:
		push_error("Main menu smoke: painted backdrop command hotspot surface is missing.")
		get_tree().quit(1)
		return false

	for removed_node in ["CommandSpinePanel", "SpineStatusPanel", "CommandBlockPanel", "Continue", "OpenGuide", "Menu"]:
		if shell.get_node_or_null(removed_node) != null or shell.find_child(removed_node, true, false) != null:
			push_error("Main menu smoke: removed first-view shell node returned: %s." % removed_node)
			get_tree().quit(1)
			return false

	var quit_button = shell.get_node_or_null("%Quit")
	var campaign_button = shell.get_node_or_null("%OpenCampaign")
	var skirmish_button = shell.get_node_or_null("%OpenSkirmish")
	var load_button = shell.get_node_or_null("%OpenSaves")
	var settings_button = shell.get_node_or_null("%OpenSettings")
	var editor_button = shell.get_node_or_null("%OpenEditor")
	if quit_button == null or campaign_button == null or skirmish_button == null or load_button == null or settings_button == null or editor_button == null:
		push_error("Main menu smoke: one or more painted-plaque command buttons are missing.")
		get_tree().quit(1)
		return false
	for button in [campaign_button, skirmish_button, load_button, settings_button, editor_button, quit_button]:
		if not (button is Button) or button.get_parent() != hotspot_surface:
			push_error("Main menu smoke: first-view command is not a direct painted-backdrop hotspot.")
			get_tree().quit(1)
			return false
		if not _assert_text_only_plaque_style(button as Button, String((button as Button).text)):
			get_tree().quit(1)
			return false
	var first_view_labels := [
		String((campaign_button as Button).text),
		String((skirmish_button as Button).text),
		String((load_button as Button).text),
		String((settings_button as Button).text),
		String((editor_button as Button).text),
		String((quit_button as Button).text),
	]
	if first_view_labels != ["Campaign", "Skirmish", "Load", "Settings", "Editor", "Quit"]:
		push_error("Main menu smoke: first-view command labels are not the approved plaque commands: %s." % [first_view_labels])
		get_tree().quit(1)
		return false
	var load_rect := (load_button as Button).get_global_rect()
	if load_rect.position.x < shell.get_viewport_rect().size.x * 0.82:
		push_error("Main menu smoke: Load hotspot is not mapped onto the painted right-side plaque column.")
		get_tree().quit(1)
		return false
	if not _assert_plaque_anchor(load_button as Button, "Load", 0.473, 0.523):
		get_tree().quit(1)
		return false
	if not _assert_plaque_anchor(settings_button as Button, "Settings", 0.611, 0.66):
		get_tree().quit(1)
		return false
	if not _assert_plaque_anchor(editor_button as Button, "Editor", 0.681, 0.729):
		get_tree().quit(1)
		return false
	if not _assert_plaque_anchor(quit_button as Button, "Quit", 0.749, 0.798):
		get_tree().quit(1)
		return false

	var first_view_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(first_view_snapshot.get("first_view_command_surface", "")) != "painted_backdrop_hotspots":
		push_error("Main menu smoke: validation snapshot does not report painted backdrop hotspots.")
		get_tree().quit(1)
		return false
	if bool(first_view_snapshot.get("has_generated_command_spine", true)) or bool(first_view_snapshot.get("has_first_view_status_box", true)):
		push_error("Main menu smoke: validation snapshot still sees generated command spine or status box.")
		get_tree().quit(1)
		return false
	if first_view_snapshot.get("first_view_commands", []) != ["Campaign", "Skirmish", "Load", "Settings", "Editor", "Quit"]:
		push_error("Main menu smoke: validation snapshot first-view commands are wrong: %s." % [first_view_snapshot])
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Main menu latest save pulse",
		[String(first_view_snapshot.get("save_pulse_full", first_view_snapshot.get("save_pulse", "")))],
		["Skirmish", "River Pass", "Day", "Overworld"]
	):
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

	if not shell.has_method("validation_open_saves_stage"):
		push_error("Main menu smoke: save board validation hook is missing.")
		get_tree().quit(1)
		return false
	shell.call("validation_open_saves_stage")
	var save_snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"Main menu selected save details",
		[
			String(save_snapshot.get("save_details_full", save_snapshot.get("save_details", ""))),
			String(save_snapshot.get("load_selected_tooltip", "")),
		],
		["Skirmish", "River Pass", "Day", "Resume target:", "Overworld"]
	):
		return false

	var inactive_settings_text_color := (settings_button as Button).get_theme_color("font_color")
	shell.call("validation_open_settings_stage")
	var active_settings_text_color := (settings_button as Button).get_theme_color("font_color")
	if _colors_close(inactive_settings_text_color, active_settings_text_color):
		push_error("Main menu smoke: active painted-plaque feedback no longer changes the command text color.")
		get_tree().quit(1)
		return false
	if not _assert_text_only_plaque_style(settings_button as Button, "Settings active"):
		get_tree().quit(1)
		return false
	var close_stage_button = shell.get_node_or_null("%CloseStageDock")
	if not (close_stage_button is Button) or (close_stage_button as Button).disabled:
		push_error("Main menu smoke: secondary board close command is unavailable after opening settings.")
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

func _assert_plaque_anchor(button: Button, label: String, expected_top: float, expected_bottom: float) -> bool:
	if not is_equal_approx(button.anchor_top, expected_top) or not is_equal_approx(button.anchor_bottom, expected_bottom):
		push_error(
			"Main menu smoke: %s plaque anchors drifted from art-centered bounds: top %.3f bottom %.3f." % [
				label,
				button.anchor_top,
				button.anchor_bottom,
			]
		)
		return false
	return true

func _assert_text_only_plaque_style(button: Button, label: String) -> bool:
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(style_name)
		if not (style is StyleBoxFlat):
			push_error("Main menu smoke: %s plaque %s style is not a StyleBoxFlat override." % [label, style_name])
			return false
		var flat_style := style as StyleBoxFlat
		var border_width := (
			flat_style.get_border_width(SIDE_LEFT)
			+ flat_style.get_border_width(SIDE_TOP)
			+ flat_style.get_border_width(SIDE_RIGHT)
			+ flat_style.get_border_width(SIDE_BOTTOM)
		)
		if flat_style.bg_color.a > 0.01 or border_width > 0:
			push_error(
				"Main menu smoke: %s plaque %s style draws a hotspot box instead of text-only feedback." % [
					label,
					style_name,
				]
			)
			return false
	return true

func _colors_close(first: Color, second: Color, tolerance: float = 0.01) -> bool:
	return (
		absf(first.r - second.r) <= tolerance
		and absf(first.g - second.g) <= tolerance
		and absf(first.b - second.b) <= tolerance
		and absf(first.a - second.a) <= tolerance
	)

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

func _assert_text_contains_all(label: String, texts: Array, needles: Array) -> bool:
	var joined := "\n".join(texts)
	for needle in needles:
		if joined.find(String(needle)) < 0:
			push_error("%s missing '%s'. text=%s" % [label, String(needle), joined])
			get_tree().quit(1)
			return false
	return true

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
