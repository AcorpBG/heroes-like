extends Node

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")
const CAMPAIGN_SMOKE_ID := "campaign_reedfall"

var _original_campaign_profile := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_seed_clean_campaign_smoke_profile()
	var main_menu_ok := await _run_main_menu_smoke()
	_restore_campaign_smoke_profile()
	if not main_menu_ok:
		return
	if not await _run_outcome_smoke():
		return
	get_tree().quit(0)

func _seed_clean_campaign_smoke_profile() -> void:
	_original_campaign_profile = CampaignProgression.ensure_profile().duplicate(true)
	var clean_profile := CampaignRules.normalize_profile(_original_campaign_profile)
	clean_profile["campaign_states"][CAMPAIGN_SMOKE_ID] = {}
	clean_profile["last_campaign_id"] = CAMPAIGN_SMOKE_ID
	clean_profile["last_scenario_id"] = ""
	CampaignProgression.profile = CampaignRules.normalize_profile(clean_profile)
	CampaignProgression.save_profile()

func _restore_campaign_smoke_profile() -> void:
	if _original_campaign_profile.is_empty():
		return
	CampaignProgression.profile = CampaignRules.normalize_profile(_original_campaign_profile)
	CampaignProgression.save_profile()

func _run_main_menu_smoke() -> bool:
	var original_resolution := SettingsService.presentation_resolution_id()
	var original_render_quality := SettingsService.render_quality_id()
	var original_ui_scale := SettingsService.ui_scale_percent()
	var original_battle_camera_shake := SettingsService.battle_camera_shake_mode_id()
	var original_reduce_flashes := SettingsService.reduced_flashes_enabled()
	var original_reduce_repetitive_sounds := SettingsService.reduced_repetitive_sounds_enabled()
	var original_high_contrast := SettingsService.high_contrast_ui_enabled()
	var original_color_cue_mode := SettingsService.color_cue_mode_id()
	var original_keyboard_navigation_layout := SettingsService.keyboard_navigation_layout_id()
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
	var public_title = shell.get_node_or_null("%Title")
	if not (public_title is Label) or String((public_title as Label).text) != "AURELION REACH":
		push_error("Main menu smoke: the first-view public title is not AURELION REACH.")
		get_tree().quit(1)
		return false
	var title_rect: Rect2 = (public_title as Label).get_global_rect()
	var logo_panel: Control = shell.get_node("LogoPocketPanel") as Control
	var logo_rect: Rect2 = logo_panel.get_global_rect()
	var title_minimum_size: Vector2 = (public_title as Label).get_combined_minimum_size()
	if (
		title_rect.end.x > logo_rect.end.x + 0.5
		or title_rect.end.y > logo_rect.end.y + 0.5
		or title_minimum_size.x > title_rect.size.x + 0.5
		or title_minimum_size.y > title_rect.size.y + 0.5
	):
		push_error("Main menu smoke: the AURELION REACH title overflows the compact logo pocket.")
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
	var first_view_tooltips: Dictionary = first_view_snapshot.get("first_view_command_tooltips", {}) if first_view_snapshot.get("first_view_command_tooltips", {}) is Dictionary else {}
	if not _assert_text_contains_all(
		"Main menu first-view command tooltip cues",
		[
			String(first_view_tooltips.get("Campaign", "")),
			String(first_view_tooltips.get("Skirmish", "")),
			String(first_view_tooltips.get("Load", "")),
			String(first_view_tooltips.get("Settings", "")),
			String(first_view_tooltips.get("Editor", "")),
			String(first_view_tooltips.get("Quit", "")),
		],
		["Command cue:", "Campaign opens", "Skirmish opens", "Open saved expeditions", "does not overwrite any saved slot", "Settings opens", "device config", "Editor opens", "Play Copy", "Quit closes", "Quit Check", "Resume point:"]
	):
		return false
	var continue_check: Dictionary = first_view_snapshot.get("continue_check", {}) if first_view_snapshot.get("continue_check", {}) is Dictionary else {}
	if not _assert_text_contains_all(
		"Main menu Load cue",
		[
			String(first_view_snapshot.get("continue_check_text", "")),
			String(first_view_snapshot.get("continue_check_tooltip", "")),
			String(continue_check.get("visible_text", "")),
			String(continue_check.get("tooltip_text", "")),
			String(first_view_tooltips.get("Load", "")),
			String(first_view_snapshot.get("active_expedition", "")),
			String(first_view_snapshot.get("active_expedition_full", "")),
		],
		["Load: choose a saved expedition", "Open saved expeditions", "Previewing", "does not change it", "does not overwrite any saved slot"]
	):
		return false
	var quit_check: Dictionary = first_view_snapshot.get("quit_check", {}) if first_view_snapshot.get("quit_check", {}) is Dictionary else {}
	if not _assert_text_contains_all(
		"Main menu Quit check cue",
		[
			String(first_view_snapshot.get("quit_check_text", "")),
			String(first_view_snapshot.get("quit_check_tooltip", "")),
			String(quit_check.get("visible_text", "")),
			String(quit_check.get("tooltip_text", "")),
			String((quit_button as Button).tooltip_text),
			String(first_view_snapshot.get("active_expedition", "")),
			String(first_view_snapshot.get("active_expedition_full", "")),
		],
		["Quit check:", "closes client", "save first", "Quit Check", "Resume point:", "Not changed:", "campaign progress", "expedition saves", "device settings"]
	):
		return false
	if not _assert_text_contains_all(
		"Main menu lazy save pulse",
		[String(first_view_snapshot.get("save_pulse_full", first_view_snapshot.get("save_pulse", "")))],
		["Open Load", "choose a saved expedition"]
	):
		return false
	if not _assert_text_contains_all(
		"Main menu footer lazy save target",
		[String(first_view_snapshot.get("active_expedition_full", first_view_snapshot.get("active_expedition", "")))],
		["Load: choose a saved expedition", "Quit check:", "save first"]
	):
		return false
	if not _assert_no_score_leak(
		"Main menu first-view play check",
		[
			String(first_view_snapshot.get("save_pulse_full", first_view_snapshot.get("save_pulse", ""))),
			String(first_view_snapshot.get("active_expedition_full", first_view_snapshot.get("active_expedition", ""))),
			String(first_view_snapshot.get("latest_play_check", "")),
			String(first_view_snapshot.get("latest_resume_handoff", "")),
			String(first_view_snapshot.get("continue_check_text", "")),
			String(first_view_snapshot.get("continue_check_tooltip", "")),
			String(first_view_snapshot.get("quit_check_text", "")),
			String(first_view_snapshot.get("quit_check_tooltip", "")),
			"\n".join(first_view_tooltips.values()),
		]
	):
		return false

	var campaign_list = shell.get_node_or_null("%CampaignList")
	if campaign_list == null:
		push_error("Main menu smoke: campaign browser node is missing.")
		get_tree().quit(1)
		return false

	var skirmish_list = shell.get_node_or_null("%SkirmishList")
	if skirmish_list == null or int(skirmish_list.get_item_count()) <= 0:
		push_error("Main menu smoke: skirmish browser did not populate.")
		get_tree().quit(1)
		return false

	if not shell.has_method("validation_open_campaign_stage"):
		push_error("Main menu smoke: campaign launch preview validation hook is missing.")
		get_tree().quit(1)
		return false
	shell.call("validation_open_campaign_stage")
	var campaign_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(campaign_snapshot.get("campaign_board_status", "")) == "archived_empty":
		if int(campaign_snapshot.get("campaign_count", -1)) != 0 or int(campaign_list.get_item_count()) != 0:
			push_error("Main menu smoke: archived campaign board exposed campaign entries: %s." % campaign_snapshot)
			get_tree().quit(1)
			return false
		if not _assert_text_contains_all(
			"Main menu archived campaign empty state",
			[
				String(campaign_snapshot.get("campaign_empty_state_tooltip", campaign_snapshot.get("campaign_empty_state_text", ""))),
				String(campaign_snapshot.get("campaign_arc_status_full", campaign_snapshot.get("campaign_arc_status", ""))),
				String(campaign_snapshot.get("chapter_details_full", campaign_snapshot.get("chapter_details", ""))),
				String(campaign_snapshot.get("campaign_commander_preview_full", campaign_snapshot.get("campaign_commander_preview", ""))),
				String(campaign_snapshot.get("campaign_operational_board_full", campaign_snapshot.get("campaign_operational_board", ""))),
				String(campaign_snapshot.get("campaign_primary_tooltip", "")),
				String(campaign_snapshot.get("start_chapter_tooltip", "")),
			],
			["Campaign board:", "archived campaign", "no player-facing campaign", "No campaign chapters", "Skirmish fronts remain available", "Use Skirmish", "intentionally disabled", "No campaign chapter"]
		):
			return false
		if String(campaign_snapshot.get("campaign_primary_text", "")) != "No Campaign" or not bool(campaign_snapshot.get("campaign_primary_disabled", false)):
			push_error("Main menu smoke: archived campaign primary action is not disabled: %s." % campaign_snapshot)
			get_tree().quit(1)
			return false
	else:
		if int(campaign_list.get_item_count()) <= 0:
			push_error("Main menu smoke: active campaign browser did not populate.")
			get_tree().quit(1)
			return false
		var selected_chapter_action: Dictionary = campaign_snapshot.get("selected_chapter_action", {}) if campaign_snapshot.get("selected_chapter_action", {}) is Dictionary else {}
		var campaign_chapter_check: Dictionary = campaign_snapshot.get("campaign_chapter_check", {}) if campaign_snapshot.get("campaign_chapter_check", {}) is Dictionary else {}
		if not _assert_text_contains_all(
			"Main menu campaign launch preview",
			[
				String(campaign_snapshot.get("chapter_details_full", campaign_snapshot.get("chapter_details", ""))),
				String(selected_chapter_action.get("summary", "")),
				String(campaign_chapter_check.get("text", "")),
				String(campaign_chapter_check.get("tooltip_text", "")),
				String(campaign_snapshot.get("campaign_chapter_check_text", "")),
				String(campaign_snapshot.get("campaign_chapter_check_tooltip", "")),
				String(selected_chapter_action.get("launch_handoff", "")),
				String(campaign_snapshot.get("start_chapter_tooltip", "")),
				String(campaign_snapshot.get("campaign_commander_preview_full", campaign_snapshot.get("campaign_commander_preview", ""))),
				String(campaign_snapshot.get("campaign_operational_board_full", campaign_snapshot.get("campaign_operational_board", ""))),
			],
			["Campaign check:", "Campaign Chapter Check", "selected chapter matches the primary campaign action", "victory can advance the campaign path", "Chapter position:", "Campaign framing:", "Continuity:", "Readiness watch:", "Launch handoff:", "starts Day 1 in Campaign mode", "Action consequence:", "Launch Preview", "Campaign", "Captain", "Objective:", "Stakes:", "Current progress:", "Next step:", "Action:", "Faction Identity", "Embercourt League", "Economy:", "Pressure:", "Spellbook", "Gear impact:", "Collection:", "Field Route", "Battle Strike", "Cost", "Use:"]
		):
			return false
		if not _assert_text_contains_all(
			"Main menu visible campaign launch handoff",
			[String(campaign_snapshot.get("chapter_details", ""))],
			["Campaign check:", "Launch handoff:", "starts Day 1 in Campaign mode"]
		):
			return false
		if not _assert_no_score_leak(
			"Main menu campaign launch handoff",
			[
				String(selected_chapter_action.get("launch_handoff", "")),
				String(campaign_chapter_check.get("text", "")),
				String(campaign_chapter_check.get("tooltip_text", "")),
				String(campaign_snapshot.get("chapter_details_full", campaign_snapshot.get("chapter_details", ""))),
				String(campaign_snapshot.get("start_chapter_tooltip", "")),
			]
		):
			return false
	if not shell.has_method("validation_open_contextual_guide_stage") or not shell.has_method("validation_return_from_contextual_guide"):
		push_error("Main menu smoke: contextual Field Manual validation hooks are missing.")
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Main menu campaign contextual guide control",
		[String(campaign_snapshot.get("stage_help_tooltip", ""))],
		["Open the Field Manual", "Campaign", "does not start, load, save, or change settings", "Help handoff:", "reference only"]
	):
		return false
	shell.call("validation_open_contextual_guide_stage")
	var campaign_guide_snapshot: Dictionary = shell.call("validation_snapshot")
	var campaign_help_item_tooltips := []
	for item_tooltip in (campaign_guide_snapshot.get("help_item_tooltips", []) if campaign_guide_snapshot.get("help_item_tooltips", []) is Array else []):
		campaign_help_item_tooltips.append(String(item_tooltip))
	if not _assert_text_contains_all(
		"Main menu campaign contextual Field Manual",
		[
			String(campaign_guide_snapshot.get("stage_help_text", "")),
			String(campaign_guide_snapshot.get("stage_help_tooltip", "")),
			String(campaign_guide_snapshot.get("help_topic_id", "")),
			String(campaign_guide_snapshot.get("help_handoff_text", "")),
			String(campaign_guide_snapshot.get("help_handoff_tooltip", "")),
			String(campaign_guide_snapshot.get("help_intro_full", campaign_guide_snapshot.get("help_intro", ""))),
			String(campaign_guide_snapshot.get("help_details_full", campaign_guide_snapshot.get("help_details", ""))),
			"\n".join(campaign_help_item_tooltips),
		],
		["Back", "Return to campaign board", "campaign", "Campaigns are the authored progression path", "carryover", "Help handoff:", "reference only", "Topic cue:", "Selection:", "no campaign progress", "expedition save", "device setting"]
	):
		return false
	if not _assert_no_score_leak(
		"Main menu campaign contextual Field Manual",
		[
			String(campaign_guide_snapshot.get("stage_help_tooltip", "")),
			String(campaign_guide_snapshot.get("help_handoff_text", "")),
			String(campaign_guide_snapshot.get("help_handoff_tooltip", "")),
			String(campaign_guide_snapshot.get("help_intro_full", campaign_guide_snapshot.get("help_intro", ""))),
			String(campaign_guide_snapshot.get("help_details_full", campaign_guide_snapshot.get("help_details", ""))),
			"\n".join(campaign_help_item_tooltips),
		]
	):
		return false
	shell.call("validation_return_from_contextual_guide")
	campaign_snapshot = shell.call("validation_snapshot")
	if int(campaign_snapshot.get("current_tab", -1)) != 0 or String(campaign_snapshot.get("stage_help_text", "")) != "Guide":
		push_error("Main menu smoke: contextual Field Manual did not return to the campaign board: %s." % [campaign_snapshot])
		get_tree().quit(1)
		return false

	if not shell.has_method("validation_open_settings_stage") or not shell.has_method("validation_select_resolution"):
		push_error("Main menu smoke: settings resolution validation hooks are missing.")
		get_tree().quit(1)
		return false

	if not shell.has_method("validation_open_skirmish_stage") or not shell.has_method("validation_select_skirmish") or not shell.has_method("validation_set_difficulty"):
		push_error("Main menu smoke: skirmish launch preview validation hooks are missing.")
		get_tree().quit(1)
		return false
	shell.call("validation_open_skirmish_stage")
	var initial_skirmish_snapshot: Dictionary = shell.call("validation_snapshot")
	var selected_skirmish_id := String(initial_skirmish_snapshot.get("selected_skirmish_id", ""))
	if selected_skirmish_id == "":
		push_error("Main menu smoke: skirmish stage has no selected launchable front: %s." % [initial_skirmish_snapshot])
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_skirmish", selected_skirmish_id)):
		push_error("Main menu smoke: could not reselect current skirmish front %s for launch preview." % selected_skirmish_id)
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_set_difficulty", "hard")):
		push_error("Main menu smoke: could not set Warlord difficulty for skirmish launch preview.")
		get_tree().quit(1)
		return false
	var skirmish_snapshot: Dictionary = shell.call("validation_snapshot")
	var selected_skirmish_setup: Dictionary = skirmish_snapshot.get("selected_skirmish_setup", {}) if skirmish_snapshot.get("selected_skirmish_setup", {}) is Dictionary else {}
	var skirmish_front_check: Dictionary = skirmish_snapshot.get("skirmish_front_check", {}) if skirmish_snapshot.get("skirmish_front_check", {}) is Dictionary else {}
	var skirmish_browser_tooltips := []
	for item_tooltip in (skirmish_snapshot.get("skirmish_browser_item_tooltips", []) if skirmish_snapshot.get("skirmish_browser_item_tooltips", []) is Array else []):
		skirmish_browser_tooltips.append(String(item_tooltip))
	if not _assert_text_contains_all(
		"Main menu skirmish launch preview",
		[
			String(skirmish_snapshot.get("skirmish_setup_full", skirmish_snapshot.get("skirmish_setup", ""))),
			String(skirmish_front_check.get("visible_text", "")),
			String(skirmish_front_check.get("tooltip_text", "")),
			String(skirmish_snapshot.get("skirmish_front_check_text", "")),
			String(skirmish_snapshot.get("skirmish_front_check_tooltip", "")),
			String(skirmish_snapshot.get("difficulty_summary_full", skirmish_snapshot.get("difficulty_summary", ""))),
			String(skirmish_snapshot.get("start_skirmish_tooltip", "")),
			String(skirmish_snapshot.get("skirmish_commander_preview_full", skirmish_snapshot.get("skirmish_commander_preview", ""))),
			String(selected_skirmish_setup.get("launch_handoff", "")),
			String(selected_skirmish_setup.get("briefing_check", "")),
			String(selected_skirmish_setup.get("front_context", "")),
			String(selected_skirmish_setup.get("objective_stakes", "")),
			String(selected_skirmish_setup.get("readiness_summary", "")),
			String(selected_skirmish_setup.get("difficulty_check", "")),
			String(selected_skirmish_setup.get("difficulty_consequence", "")),
			String(selected_skirmish_setup.get("action_consequence", "")),
			"\n".join(skirmish_browser_tooltips),
		],
		["Skirmish front check:", "Skirmish Front Check", "Launch Skirmish target", "selection changes preview only", "Selected front:", "changing front rows updates", "campaign progress", "latest save", "manual save slots", "Launch handoff:", "fresh Skirmish expedition on Day 1", "Opening briefing:", "First decision:", "Skirmish", "Warlord", "Generated package", "Front context:", "Difficulty check:", "Warlord differs from recommended Captain", "Difficulty consequence:", "Action boundary:"]
	):
		return false
	if not _assert_text_contains_all(
		"Main menu visible skirmish launch handoff",
		[String(skirmish_snapshot.get("skirmish_setup", ""))],
		["Skirmish front check:", "Launch Skirmish target", "Launch handoff:", "Skirmish", "Warlord", "River Pass"]
	):
		return false
	if not _assert_no_score_leak(
		"Main menu skirmish launch handoff",
		[
			String(skirmish_front_check.get("visible_text", "")),
			String(skirmish_front_check.get("tooltip_text", "")),
			String(selected_skirmish_setup.get("launch_handoff", "")),
			String(selected_skirmish_setup.get("difficulty_check", "")),
			String(skirmish_snapshot.get("difficulty_summary_full", skirmish_snapshot.get("difficulty_summary", ""))),
			String(skirmish_snapshot.get("skirmish_setup_full", skirmish_snapshot.get("skirmish_setup", ""))),
			String(skirmish_snapshot.get("start_skirmish_tooltip", "")),
			"\n".join(skirmish_browser_tooltips),
		]
	):
		return false

	if not shell.has_method("validation_open_saves_stage"):
		push_error("Main menu smoke: save board validation hook is missing.")
		get_tree().quit(1)
		return false
	shell.call("validation_open_saves_stage")
	var save_snapshot: Dictionary = shell.call("validation_snapshot")
	var selected_save_summary: Dictionary = save_snapshot.get("selected_save_summary", {}) if save_snapshot.get("selected_save_summary", {}) is Dictionary else {}
	if String(selected_save_summary.get("slot_type", "")) == SaveService.SLOT_TYPE_AUTOSAVE \
			and (bool(save_snapshot.get("save_name_edit_visible", false)) or bool(save_snapshot.get("apply_save_name_visible", false))):
		push_error("Main menu smoke: autosave incorrectly exposed manual-slot naming controls: %s." % save_snapshot)
		get_tree().quit(1)
		return false
	var save_browser_item_texts := []
	for item_label in (save_snapshot.get("save_browser_items", []) if save_snapshot.get("save_browser_items", []) is Array else []):
		save_browser_item_texts.append(String(item_label))
	var save_browser_item_tooltips := []
	for item_tooltip in (save_snapshot.get("save_browser_item_tooltips", []) if save_snapshot.get("save_browser_item_tooltips", []) is Array else []):
		save_browser_item_tooltips.append(String(item_tooltip))
	if not _assert_text_contains_all(
		"Main menu selected save details",
		[
			String(save_snapshot.get("save_details_full", save_snapshot.get("save_details", ""))),
			String(save_snapshot.get("load_selected_text", "")),
			String(save_snapshot.get("load_selected_tooltip", "")),
			String(save_snapshot.get("selected_save_command_tooltip", "")),
			"\n".join(save_browser_item_texts),
			"\n".join(save_browser_item_tooltips),
		],
		["Skirmish", "River Pass", "Day", "Commander:", "Saved:", "Returns to: Adventure Map", "Next:", "Resume Expedition", "Loading does not change any saved slot"]
	):
		return false
	var save_visible_copy := "\n".join([
		String(save_snapshot.get("save_details_full", save_snapshot.get("save_details", ""))),
		String(save_snapshot.get("load_selected_tooltip", "")),
		String(save_snapshot.get("selected_save_command_tooltip", "")),
		"\n".join(save_browser_item_texts),
		"\n".join(save_browser_item_tooltips),
	]).to_lower()
	for forbidden in ["play check", "resume handoff", "command cue", "integrity:", "resume target:", "load state:", "cue:", "river-pass", "overworld 0,0"]:
		if save_visible_copy.contains(forbidden):
			push_error("Main menu save workflow exposes diagnostic copy %s: %s" % [forbidden, save_visible_copy])
			get_tree().quit(1)
			return false
	if not _assert_no_score_leak(
		"Main menu save play check",
		[
			String(save_snapshot.get("save_details_full", save_snapshot.get("save_details", ""))),
			String(save_snapshot.get("load_selected_tooltip", "")),
			String(save_snapshot.get("selected_save_command_tooltip", "")),
			String(save_snapshot.get("selected_save_play_check", "")),
			String(save_snapshot.get("selected_save_browser_cue", "")),
			"\n".join(save_browser_item_texts),
			"\n".join(save_browser_item_tooltips),
			String(save_snapshot.get("selected_save_resume_handoff", "")),
		]
	):
		return false
	if not _assert_text_contains_all(
		"Main menu save contextual guide control",
		[String(save_snapshot.get("stage_help_tooltip", ""))],
		["Open the Field Manual", "Save Flow", "does not start, load, save, or change settings", "Help handoff:", "reference only"]
	):
		return false
	shell.call("validation_open_contextual_guide_stage")
	var save_guide_snapshot: Dictionary = shell.call("validation_snapshot")
	var save_help_item_tooltips := []
	for item_tooltip in (save_guide_snapshot.get("help_item_tooltips", []) if save_guide_snapshot.get("help_item_tooltips", []) is Array else []):
		save_help_item_tooltips.append(String(item_tooltip))
	if not _assert_text_contains_all(
		"Main menu save contextual Field Manual",
		[
			String(save_guide_snapshot.get("stage_help_text", "")),
			String(save_guide_snapshot.get("stage_help_tooltip", "")),
			String(save_guide_snapshot.get("help_topic_id", "")),
			String(save_guide_snapshot.get("help_handoff_text", "")),
			String(save_guide_snapshot.get("help_handoff_tooltip", "")),
			String(save_guide_snapshot.get("help_intro_full", save_guide_snapshot.get("help_intro", ""))),
			String(save_guide_snapshot.get("help_details_full", save_guide_snapshot.get("help_details", ""))),
			"\n".join(save_help_item_tooltips),
		],
		["Back", "Return to load expedition", "saves", "Campaign unlocks and carryover live in progression data", "manual slots plus autosave", "Help handoff:", "reference only", "Topic cue:", "Selection:", "no campaign progress", "expedition save", "device setting"]
	):
		return false
	if not _assert_no_score_leak(
		"Main menu save contextual Field Manual",
		[
			String(save_guide_snapshot.get("stage_help_tooltip", "")),
			String(save_guide_snapshot.get("help_handoff_text", "")),
			String(save_guide_snapshot.get("help_handoff_tooltip", "")),
			String(save_guide_snapshot.get("help_intro_full", save_guide_snapshot.get("help_intro", ""))),
			String(save_guide_snapshot.get("help_details_full", save_guide_snapshot.get("help_details", ""))),
			"\n".join(save_help_item_tooltips),
		]
	):
		return false
	shell.call("validation_return_from_contextual_guide")
	save_snapshot = shell.call("validation_snapshot")
	if int(save_snapshot.get("current_tab", -1)) != 2 or String(save_snapshot.get("stage_help_text", "")) != "Guide":
		push_error("Main menu smoke: contextual Field Manual did not return to the save board: %s." % [save_snapshot])
		get_tree().quit(1)
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
	if bool(settings_snapshot.get("footer_pocket_visible", true)):
		push_error("Main menu smoke: footer pocket must collapse while the settings board is open.")
		get_tree().quit(1)
		return false
	var effects_slider = shell.get_node_or_null("%EffectsVolumeSlider")
	if not (effects_slider is HSlider):
		push_error("Main menu smoke: settings board is missing the Effects volume slider.")
		get_tree().quit(1)
		return false
	var vsync_toggle = shell.get_node_or_null("%VSyncToggle")
	var frame_rate_picker = shell.get_node_or_null("%FrameRatePicker")
	var render_quality_picker = shell.get_node_or_null("%RenderQualityPicker")
	var ui_scale_picker = shell.get_node_or_null("%UIScalePicker")
	var battle_camera_shake_picker = shell.get_node_or_null("%BattleCameraShakePicker")
	var high_contrast_toggle = shell.get_node_or_null("%HighContrastToggle")
	var color_cue_picker = shell.get_node_or_null("%ColorCuePicker")
	var reduce_flashes_toggle = shell.get_node_or_null("%ReduceFlashesToggle")
	var reduce_repetitive_sounds_toggle = shell.get_node_or_null("%ReduceRepetitiveSoundsToggle")
	var keyboard_navigation_layout_picker = shell.get_node_or_null("%KeyboardNavigationLayoutPicker")
	var support_bundle_button = shell.get_node_or_null("%ExportSupportBundle")
	var support_bundle_status = shell.get_node_or_null("%SupportBundleStatus")
	if not (vsync_toggle is CheckButton) or not (frame_rate_picker is OptionButton) or not (render_quality_picker is OptionButton) or not (ui_scale_picker is OptionButton) or not (battle_camera_shake_picker is OptionButton) or not (high_contrast_toggle is CheckButton) or not (color_cue_picker is OptionButton) or not (reduce_flashes_toggle is CheckButton) or not (reduce_repetitive_sounds_toggle is CheckButton) or not (keyboard_navigation_layout_picker is OptionButton) or not (support_bundle_button is Button) or not (support_bundle_status is Label):
		push_error("Main menu smoke: settings board is missing quality, pacing, or UI-scale controls.")
		get_tree().quit(1)
		return false
	var render_quality_items: Array = settings_snapshot.get("render_quality_picker_items", []) if settings_snapshot.get("render_quality_picker_items", []) is Array else []
	for expected_label in ["Low", "Balanced", "High"]:
		if not render_quality_items.has(expected_label):
			push_error("Main menu smoke: renderer-quality picker omitted %s: %s." % [expected_label, render_quality_items])
			get_tree().quit(1)
			return false
	var keyboard_layout_items: Array = settings_snapshot.get("keyboard_navigation_layout_picker_items", []) if settings_snapshot.get("keyboard_navigation_layout_picker_items", []) is Array else []
	for expected_label in ["WASD + Arrows", "IJKL + Arrows", "Arrows Only"]:
		if not keyboard_layout_items.has(expected_label):
			push_error("Main menu smoke: keyboard-navigation picker omitted %s: %s." % [expected_label, keyboard_layout_items])
			get_tree().quit(1)
			return false
	var ui_scale_items: Array = settings_snapshot.get("ui_scale_picker_items", []) if settings_snapshot.get("ui_scale_picker_items", []) is Array else []
	for expected_label in ["100%", "115%", "130%"]:
		if not ui_scale_items.has(expected_label):
			push_error("Main menu smoke: UI-scale picker omitted %s: %s." % [expected_label, ui_scale_items])
			get_tree().quit(1)
			return false
	var color_cue_items: Array = settings_snapshot.get("color_cue_picker_items", []) if settings_snapshot.get("color_cue_picker_items", []) is Array else []
	for expected_label in ["Standard", "Shape + Palette"]:
		if not color_cue_items.has(expected_label):
			push_error("Main menu smoke: color-cue picker omitted %s: %s." % [expected_label, color_cue_items])
			get_tree().quit(1)
			return false
	var battle_shake_items: Array = settings_snapshot.get("battle_camera_shake_picker_items", []) if settings_snapshot.get("battle_camera_shake_picker_items", []) is Array else []
	for expected_label in ["Full", "Reduced", "Off"]:
		if not battle_shake_items.has(expected_label):
			push_error("Main menu smoke: battle-shake picker omitted %s: %s." % [expected_label, battle_shake_items])
			get_tree().quit(1)
			return false
	var frame_rate_items: Array = settings_snapshot.get("frame_rate_picker_items", []) if settings_snapshot.get("frame_rate_picker_items", []) is Array else []
	for expected_label in ["Unlimited", "30 FPS", "60 FPS", "120 FPS"]:
		if not frame_rate_items.has(expected_label):
			push_error("Main menu smoke: frame-limit picker omitted %s: %s." % [expected_label, frame_rate_items])
			get_tree().quit(1)
			return false
	var resolution_ids := _resolution_ids_from_snapshot(settings_snapshot)
	if not _assert_text_contains_all(
		"Main menu settings handoff cue",
		[
			String(settings_snapshot.get("settings_handoff_text", "")),
			String(settings_snapshot.get("settings_handoff_tooltip", "")),
			String(settings_snapshot.get("close_stage_dock_tooltip", "")),
		],
		["Settings handoff:", "changes apply now", "Settings Handoff", "presentation, sound, gameplay, and readability", "device config", "campaign progress", "expedition saves", "Close:", "scenic first view"]
	):
		return false
	var support_bundle_result: Dictionary = shell.call("validation_export_support_bundle")
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(support_bundle_result.get("ok", false)) \
			or String(settings_snapshot.get("support_bundle_button_text", "")) != "Export Support Bundle" \
			or not String(settings_snapshot.get("support_bundle_status", "")).contains("Support bundle ready") \
			or not String(settings_snapshot.get("support_bundle_button_tooltip", "")).contains("No saves or telemetry"):
		push_error("Main menu smoke: support bundle command did not export with clear local-only feedback: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	var support_bundle: Dictionary = RuntimeIssueLog.support_bundle_snapshot()
	if String(support_bundle.get("schema", "")) != RuntimeIssueLog.SUPPORT_BUNDLE_SCHEMA \
			or not bool(support_bundle.get("privacy", {}).get("local_only", false)) \
			or bool(support_bundle.get("privacy", {}).get("telemetry_uploaded", true)):
		push_error("Main menu smoke: exported support bundle did not preserve its privacy contract: %s." % support_bundle)
		get_tree().quit(1)
		return false
	for expected_id in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
		if not resolution_ids.has(expected_id):
			push_error("Main menu smoke: settings resolution picker omitted %s: %s." % [expected_id, resolution_ids])
			get_tree().quit(1)
			return false
	if not bool(shell.call("validation_select_keyboard_navigation_layout", "ijkl")):
		push_error("Main menu smoke: keyboard-navigation picker could not select IJKL + Arrows.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	if String(settings_snapshot.get("keyboard_navigation_layout", "")) != "ijkl" or not String(settings_snapshot.get("settings_summary_full", "")).contains("Navigation IJKL + Arrows"):
		push_error("Main menu smoke: settings summary did not reflect the selected keyboard-navigation layout: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if original_keyboard_navigation_layout != "ijkl" and not bool(shell.call("validation_select_keyboard_navigation_layout", original_keyboard_navigation_layout)):
		push_error("Main menu smoke: keyboard-navigation picker could not restore %s." % original_keyboard_navigation_layout)
		get_tree().quit(1)
		return false

	if not bool(shell.call("validation_select_resolution", "1600x900")):
		push_error("Main menu smoke: settings resolution picker could not select 1600x900.")
		get_tree().quit(1)
		return false
	var display_preview_snapshot: Dictionary = shell.call("validation_snapshot")
	var display_preview: Dictionary = display_preview_snapshot.get("display_change_snapshot", {}) if display_preview_snapshot.get("display_change_snapshot", {}) is Dictionary else {}
	if original_resolution != "1600x900" and (
		not bool(display_preview.get("pending", false))
		or String(display_preview.get("resolution", "")) != "1600x900"
		or SettingsService.presentation_resolution_id() != original_resolution
		or not bool(display_preview_snapshot.get("display_change_dialog_visible", false))
	):
		push_error("Main menu smoke: resolution selection did not remain an uncommitted preview: %s." % display_preview_snapshot)
		get_tree().quit(1)
		return false
	var display_keep: Dictionary = shell.call("validation_confirm_display_change")
	if SettingsService.display_change_pending() or SettingsService.presentation_resolution_id() != "1600x900" or bool(display_keep.get("dialog_visible", true)):
		push_error("Main menu smoke: Keep did not commit and close the resolution preview: %s." % display_keep)
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_render_quality", "high")):
		if original_resolution != "1600x900":
			_keep_resolution(shell, original_resolution)
		push_error("Main menu smoke: renderer-quality picker could not select High.")
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_ui_scale", 130)):
		if original_resolution != "1600x900":
			_keep_resolution(shell, original_resolution)
		if original_render_quality != "high":
			shell.call("validation_select_render_quality", original_render_quality)
		push_error("Main menu smoke: UI-scale picker could not select 130%.")
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_battle_camera_shake", "reduced")):
		push_error("Main menu smoke: battle-shake picker could not select Reduced.")
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_set_reduced_flashes", true)):
		push_error("Main menu smoke: Reduce Flashes could not be enabled independently.")
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_set_reduced_repetitive_sounds", true)):
		push_error("Main menu smoke: Reduce Repetitive Sounds could not be enabled independently.")
		get_tree().quit(1)
		return false
	shell.call("validation_reveal_reduced_repetitive_sounds")
	await get_tree().process_frame
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("reduce_repetitive_sounds_visible_in_scroll", false)):
		push_error("Main menu smoke: Reduce Repetitive Sounds is not reachable in the max-scale settings scroll: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	shell.call("validation_reveal_reduced_flashes")
	await get_tree().process_frame
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("reduce_flashes_visible_in_scroll", false)):
		push_error("Main menu smoke: Reduce Flashes is not reachable in the max-scale settings scroll: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	shell.call("validation_reveal_support_bundle")
	await get_tree().process_frame
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("support_bundle_visible_in_scroll", false)):
		push_error("Main menu smoke: support bundle remains clipped after settings scrolling: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	shell.call("validation_reveal_restore_settings_defaults")
	await get_tree().process_frame
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("restore_settings_defaults_visible_in_scroll", false)) \
			or String(settings_snapshot.get("restore_settings_defaults_button_text", "")) != "Restore Defaults" \
			or not String(settings_snapshot.get("restore_settings_defaults_button_tooltip", "")).contains("Campaign progress and expedition saves stay unchanged"):
		push_error("Main menu smoke: Restore Defaults is not reachable with its preservation contract: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	var restore_request: Dictionary = shell.call("validation_request_settings_restore_defaults")
	if not bool(restore_request.get("dialog_visible", false)) or not String(restore_request.get("text", "")).contains("custom movement keys"):
		push_error("Main menu smoke: Restore Defaults omitted its confirmation or settings scope: %s." % restore_request)
		get_tree().quit(1)
		return false
	shell.call("validation_cancel_settings_restore_defaults")
	shell.call("validation_reveal_reduced_flashes")
	await get_tree().process_frame

	settings_snapshot = shell.call("validation_snapshot")
	var settings_summary := String(settings_snapshot.get("settings_summary_full", settings_snapshot.get("settings_summary", "")))
	if String(settings_snapshot.get("presentation_resolution", "")) != "1600x900" or String(settings_snapshot.get("render_quality", "")) != "high" or int(settings_snapshot.get("ui_scale_percent", 0)) != 130 or String(settings_snapshot.get("battle_camera_shake", "")) != "reduced" or not is_equal_approx(float(settings_snapshot.get("battle_camera_shake_scale", -1.0)), 0.35) or not bool(settings_snapshot.get("reduce_flashes_enabled", false)) or not bool(settings_snapshot.get("reduce_repetitive_sounds_enabled", false)) or not settings_summary.contains("1600 x 900") or not settings_summary.contains("High quality") or not settings_summary.contains("UI scale 130%") or not settings_summary.contains("Battle shake Reduced") or not settings_summary.contains("Reduced flashes On") or not settings_summary.contains("Reduced repetitive sounds On") or not settings_summary.contains("VSync") or not settings_summary.contains("Effects"):
		if original_resolution != "1600x900":
			_keep_resolution(shell, original_resolution)
		if original_render_quality != "high":
			shell.call("validation_select_render_quality", original_render_quality)
		if original_ui_scale != 130:
			shell.call("validation_select_ui_scale", original_ui_scale)
		push_error("Main menu smoke: settings summary did not reflect selected resolution and quality: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Main menu settings persistence check",
		[
			settings_summary,
			String(settings_snapshot.get("settings_persistence_check", "")),
			String(settings_snapshot.get("settings_handoff_text", "")),
			String(settings_snapshot.get("settings_handoff_tooltip", "")),
			String(settings_snapshot.get("close_stage_dock_tooltip", "")),
			String(settings_snapshot.get("presentation_resolution_tooltip", "")),
			String(settings_snapshot.get("render_quality_tooltip", "")),
			String(settings_snapshot.get("vsync_tooltip", "")),
			String(settings_snapshot.get("frame_rate_tooltip", "")),
			String(settings_snapshot.get("master_volume_tooltip", "")),
			String(settings_snapshot.get("effects_volume_tooltip", "")),
			String(settings_snapshot.get("ui_scale_tooltip", "")),
			String(settings_snapshot.get("battle_camera_shake_tooltip", "")),
			String(settings_snapshot.get("high_contrast_tooltip", "")),
			String(settings_snapshot.get("color_cue_tooltip", "")),
			String(settings_snapshot.get("reduce_flashes_tooltip", "")),
			String(settings_snapshot.get("reduce_repetitive_sounds_tooltip", "")),
			String(settings_snapshot.get("keyboard_navigation_layout_tooltip", "")),
		],
		["Settings check:", "applies immediately", "stored in device config", "campaign progress", "expedition saves stay unchanged", "Settings handoff:", "Settings Handoff", "Close:"]
	):
		if original_resolution != "1600x900":
			_keep_resolution(shell, original_resolution)
		if original_render_quality != "high":
			shell.call("validation_select_render_quality", original_render_quality)
		if original_ui_scale != 130:
			shell.call("validation_select_ui_scale", original_ui_scale)
		return false
	if not _assert_no_score_leak(
		"Main menu settings persistence check",
		[
			settings_summary,
			String(settings_snapshot.get("settings_persistence_check", "")),
			String(settings_snapshot.get("settings_handoff_text", "")),
			String(settings_snapshot.get("settings_handoff_tooltip", "")),
			String(settings_snapshot.get("close_stage_dock_tooltip", "")),
			String(settings_snapshot.get("presentation_resolution_tooltip", "")),
			String(settings_snapshot.get("render_quality_tooltip", "")),
			String(settings_snapshot.get("vsync_tooltip", "")),
			String(settings_snapshot.get("frame_rate_tooltip", "")),
			String(settings_snapshot.get("master_volume_tooltip", "")),
			String(settings_snapshot.get("effects_volume_tooltip", "")),
			String(settings_snapshot.get("ui_scale_tooltip", "")),
			String(settings_snapshot.get("battle_camera_shake_tooltip", "")),
			String(settings_snapshot.get("high_contrast_tooltip", "")),
			String(settings_snapshot.get("color_cue_tooltip", "")),
			String(settings_snapshot.get("reduce_flashes_tooltip", "")),
			String(settings_snapshot.get("reduce_repetitive_sounds_tooltip", "")),
			String(settings_snapshot.get("keyboard_navigation_layout_tooltip", "")),
		]
	):
		if original_resolution != "1600x900":
			_keep_resolution(shell, original_resolution)
		if original_render_quality != "high":
			shell.call("validation_select_render_quality", original_render_quality)
		if original_ui_scale != 130:
			shell.call("validation_select_ui_scale", original_ui_scale)
		return false

	if not bool(shell.call("validation_set_high_contrast", true)):
		push_error("Main menu smoke: high-contrast toggle could not enable the shared palette.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	var contrast_normal = (close_stage_button as Button).get_theme_stylebox("normal")
	var contrast_focus = (close_stage_button as Button).get_theme_stylebox("focus")
	if not bool(settings_snapshot.get("high_contrast_enabled", false)) or not String(settings_snapshot.get("settings_summary_full", "")).contains("High contrast On") or not (contrast_normal is StyleBoxFlat) or not (contrast_focus is StyleBoxFlat) or (contrast_normal as StyleBoxFlat).bg_color.get_luminance() > 0.08 or (contrast_normal as StyleBoxFlat).border_color.get_luminance() < 0.80 or (contrast_focus as StyleBoxFlat).border_width_left < 4:
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: high-contrast mode did not apply solid dark controls, bright borders, and a strong focus ring: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_color_cue_mode", "assisted")):
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: color-cue picker could not enable shape and palette assistance.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	var assisted_green: Color = FrontierVisualKitScript.text_color("green")
	var assisted_red: Color = FrontierVisualKitScript.text_color("red")
	if String(settings_snapshot.get("color_cue_mode", "")) != "assisted" or not String(settings_snapshot.get("settings_summary_full", "")).contains("Color cues Shape + Palette") or assisted_green.b <= assisted_green.r or assisted_red.r <= assisted_red.g or assisted_red.g <= assisted_red.b:
		if original_color_cue_mode != "assisted":
			shell.call("validation_select_color_cue_mode", original_color_cue_mode)
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: assisted color cues did not apply blue/cyan success and orange danger styling: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if original_color_cue_mode != "assisted" and not bool(shell.call("validation_select_color_cue_mode", original_color_cue_mode)):
		push_error("Main menu smoke: color-cue picker could not restore %s." % original_color_cue_mode)
		get_tree().quit(1)
		return false
	if not original_high_contrast and not bool(shell.call("validation_set_high_contrast", false)):
		push_error("Main menu smoke: high-contrast toggle could not restore the original setting.")
		get_tree().quit(1)
		return false

	if original_resolution != "1600x900" and not _keep_resolution(shell, original_resolution):
		push_error("Main menu smoke: settings resolution picker could not restore %s." % original_resolution)
		get_tree().quit(1)
		return false
	if original_render_quality != "high" and not bool(shell.call("validation_select_render_quality", original_render_quality)):
		push_error("Main menu smoke: renderer-quality picker could not restore %s." % original_render_quality)
		get_tree().quit(1)
		return false
	if original_ui_scale != 130 and not bool(shell.call("validation_select_ui_scale", original_ui_scale)):
		push_error("Main menu smoke: UI-scale picker could not restore %d%%." % original_ui_scale)
		get_tree().quit(1)
		return false
	if original_battle_camera_shake != "reduced" and not bool(shell.call("validation_select_battle_camera_shake", original_battle_camera_shake)):
		push_error("Main menu smoke: battle-shake picker could not restore %s." % original_battle_camera_shake)
		get_tree().quit(1)
		return false
	if original_reduce_flashes != true and not bool(shell.call("validation_set_reduced_flashes", original_reduce_flashes)):
		push_error("Main menu smoke: Reduce Flashes could not restore the original setting.")
		get_tree().quit(1)
		return false
	if original_reduce_repetitive_sounds != true and not bool(shell.call("validation_set_reduced_repetitive_sounds", original_reduce_repetitive_sounds)):
		push_error("Main menu smoke: Reduce Repetitive Sounds could not restore the original setting.")
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

func _assert_no_score_leak(label: String, texts: Array) -> bool:
	var joined := "\n".join(texts).to_lower()
	for token in [
		"final_priority",
		"base_value",
		"assignment_penalty",
		"final_score",
		"income_value",
		"growth_value",
		"pressure_value",
		"category_bonus",
		"raid_score",
		"debug_reason",
		"raid_target_weights",
		"ai_score",
		"weight",
	]:
		if joined.find(token) >= 0:
			push_error("%s leaked internal score field '%s'. text=%s" % [label, token, joined])
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

	var snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_outcome_field_manual_contract(shell, "Outcome skirmish Field Manual"):
		return false
	var follow_up_check: Dictionary = snapshot.get("outcome_follow_up_check", {}) if snapshot.get("outcome_follow_up_check", {}) is Dictionary else {}
	var retry_check: Dictionary = snapshot.get("outcome_retry_check", {}) if snapshot.get("outcome_retry_check", {}) is Dictionary else {}
	var carryover_check: Dictionary = snapshot.get("outcome_carryover_check", {}) if snapshot.get("outcome_carryover_check", {}) is Dictionary else {}
	var slot_check: Dictionary = snapshot.get("outcome_slot_check", {}) if snapshot.get("outcome_slot_check", {}) is Dictionary else {}
	var save_check: Dictionary = snapshot.get("outcome_save_check", {}) if snapshot.get("outcome_save_check", {}) is Dictionary else {}
	var action_payload_text := _joined_action_payload_text(snapshot)
	var action_tooltip_text := _joined_action_tooltip_text(snapshot)
	if not _assert_text_contains_all(
		"Outcome progress and next-step recap",
		[
			String(follow_up_check.get("visible_text", "")),
			String(follow_up_check.get("tooltip_text", "")),
			String(retry_check.get("visible_text", "")),
			String(retry_check.get("tooltip_text", "")),
			String(snapshot.get("outcome_retry_check_text", "")),
			String(snapshot.get("outcome_retry_check_tooltip", "")),
			String(carryover_check.get("visible_text", "")),
			String(carryover_check.get("tooltip_text", "")),
			String(snapshot.get("outcome_carryover_check_text", "")),
			String(snapshot.get("outcome_carryover_check_tooltip", "")),
			String(snapshot.get("carryover_label", "")),
			String(snapshot.get("carryover_tooltip", "")),
			String(slot_check.get("visible_text", "")),
			String(slot_check.get("tooltip_text", "")),
			String(snapshot.get("outcome_slot_check_text", "")),
			String(snapshot.get("outcome_slot_check_tooltip", "")),
			String(save_check.get("visible_text", "")),
			String(save_check.get("tooltip_text", "")),
			String(snapshot.get("outcome_save_check_text", "")),
			String(snapshot.get("outcome_save_check_tooltip", "")),
			String(snapshot.get("progression_summary", "")),
			String(snapshot.get("next_step_summary", "")),
			String(snapshot.get("outcome_resolution_handoff", "")),
			String(snapshot.get("continuity_choice_summary", "")),
			String(snapshot.get("post_result_handoff_summary", "")),
			String(snapshot.get("next_play_action_summary", "")),
			String(snapshot.get("action_cue_summary", "")),
			String(snapshot.get("actions_hint", "")),
			String(snapshot.get("actions_hint_tooltip", "")),
			action_payload_text,
			action_tooltip_text,
			String(snapshot.get("action_status", "")),
			String(snapshot.get("save_status", "")),
			String(snapshot.get("save_status_tooltip", "")),
			String(snapshot.get("save_button_tooltip", "")),
			String(snapshot.get("return_cue", "")),
			String(snapshot.get("return_cue_tooltip", "")),
			String(snapshot.get("save_check", "")),
			String(snapshot.get("play_check", "")),
			String(snapshot.get("return_handoff", "")),
			String(snapshot.get("current_save_recap", "")),
		],
		["Progress Recap", "Current progress:", "Recently resolved:", "Next step:", "Follow-up check:", "Outcome Follow-up Check", "Primary follow-up:", "Retry Skirmish starts a fresh skirmish expedition", "Save first:", "Return keeps review", "Retry check:", "Outcome Retry Check", "starts this skirmish from Day 1", "save keeps review", "campaign progression stays unchanged", "Carryover check:", "Outcome Carryover Check", "Skirmish result", "retry starts fresh", "Skirmish runs do not import or export campaign carryover", "Replay/new run:", "Manual save:", "Slot check:", "Outcome Slot Check", "Selected slot:", "Saving now:", "Outcome save check:", "Outcome Save Check", "Save target:", "Save action:", "Follow-up boundary:", "review preserved", "Manual", "Continue Latest and Load Selected can review this outcome", "State change:", "Inspection:", "does not save, route, or change campaign progression", "Outcome handoff:", "Victory recorded", "primary follow-up", "Continuity choice:", "self-contained", "retry starts fresh", "Post-result handoff:", "review-only", "Save Outcome", "campaign progression stays unchanged", "Next play action:", "Action cue:", "save first", "Return to Menu", "Retry Skirmish", "starts fresh", "resumable", "Return cue:", "Menu autosaves this outcome", "Continue Latest reviews it later", "Save check:", "Play check:", "Return handoff:", "Saved state:", "What changed:", "Resume state:", "Watch:", "Next decision:"]
	):
		return false
	if not _assert_no_score_leak(
		"Outcome skirmish continuity choice",
		[
			String(follow_up_check.get("visible_text", "")),
			String(follow_up_check.get("tooltip_text", "")),
			String(retry_check.get("visible_text", "")),
			String(retry_check.get("tooltip_text", "")),
			String(carryover_check.get("visible_text", "")),
			String(carryover_check.get("tooltip_text", "")),
			String(snapshot.get("carryover_label", "")),
			String(snapshot.get("carryover_tooltip", "")),
			String(slot_check.get("visible_text", "")),
			String(slot_check.get("tooltip_text", "")),
			String(save_check.get("visible_text", "")),
			String(save_check.get("tooltip_text", "")),
			String(snapshot.get("outcome_resolution_handoff", "")),
			String(snapshot.get("continuity_choice_summary", "")),
			String(snapshot.get("post_result_handoff_summary", "")),
			String(snapshot.get("action_cue_summary", "")),
			String(snapshot.get("actions_hint", "")),
			String(snapshot.get("actions_hint_tooltip", "")),
			action_payload_text,
			action_tooltip_text,
			String(snapshot.get("action_status", "")),
			String(snapshot.get("save_status", "")),
			String(snapshot.get("save_status_tooltip", "")),
			String(snapshot.get("save_button_tooltip", "")),
			String(snapshot.get("return_cue", "")),
			String(snapshot.get("return_cue_tooltip", "")),
		]
	):
		return false

	shell.queue_free()
	await get_tree().process_frame

	var profile := CampaignRules.normalize_profile({})
	var campaign_session = CampaignRules.build_session_bridge(
		profile,
		"river-pass",
		"normal",
		"campaign_reedfall"
	)
	campaign_session.scenario_status = "victory"
	campaign_session.scenario_summary = "Smoke campaign victory outcome."
	profile = CampaignRules.record_session_completion_bridge(profile, campaign_session)
	CampaignProgression.profile = profile
	SessionState.set_active_session(campaign_session)

	var campaign_shell = load("res://scenes/results/ScenarioOutcomeShell.tscn").instantiate()
	add_child(campaign_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var campaign_snapshot: Dictionary = campaign_shell.call("validation_snapshot")
	if not _assert_outcome_field_manual_contract(campaign_shell, "Outcome campaign Field Manual"):
		return false
	var campaign_follow_up_check: Dictionary = campaign_snapshot.get("outcome_follow_up_check", {}) if campaign_snapshot.get("outcome_follow_up_check", {}) is Dictionary else {}
	var campaign_retry_check: Dictionary = campaign_snapshot.get("outcome_retry_check", {}) if campaign_snapshot.get("outcome_retry_check", {}) is Dictionary else {}
	var campaign_carryover_check: Dictionary = campaign_snapshot.get("outcome_carryover_check", {}) if campaign_snapshot.get("outcome_carryover_check", {}) is Dictionary else {}
	var campaign_slot_check: Dictionary = campaign_snapshot.get("outcome_slot_check", {}) if campaign_snapshot.get("outcome_slot_check", {}) is Dictionary else {}
	var campaign_save_check: Dictionary = campaign_snapshot.get("outcome_save_check", {}) if campaign_snapshot.get("outcome_save_check", {}) is Dictionary else {}
	var campaign_action_payload_text := _joined_action_payload_text(campaign_snapshot)
	var campaign_action_tooltip_text := _joined_action_tooltip_text(campaign_snapshot)
	if not _assert_text_contains_all(
		"Outcome campaign continuity choice",
		[
			String(campaign_follow_up_check.get("visible_text", "")),
			String(campaign_follow_up_check.get("tooltip_text", "")),
			String(campaign_retry_check.get("visible_text", "")),
			String(campaign_retry_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("outcome_retry_check_text", "")),
			String(campaign_snapshot.get("outcome_retry_check_tooltip", "")),
			String(campaign_carryover_check.get("visible_text", "")),
			String(campaign_carryover_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("outcome_carryover_check_text", "")),
			String(campaign_snapshot.get("outcome_carryover_check_tooltip", "")),
			String(campaign_snapshot.get("carryover_label", "")),
			String(campaign_snapshot.get("carryover_tooltip", "")),
			String(campaign_slot_check.get("visible_text", "")),
			String(campaign_slot_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("outcome_slot_check_text", "")),
			String(campaign_snapshot.get("outcome_slot_check_tooltip", "")),
			String(campaign_save_check.get("visible_text", "")),
			String(campaign_save_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("outcome_save_check_text", "")),
			String(campaign_snapshot.get("outcome_save_check_tooltip", "")),
			String(campaign_snapshot.get("progression_summary", "")),
			String(campaign_snapshot.get("campaign_arc_summary", "")),
			String(campaign_snapshot.get("carryover_summary", "")),
			String(campaign_snapshot.get("outcome_resolution_handoff", "")),
			String(campaign_snapshot.get("continuity_choice_summary", "")),
			String(campaign_snapshot.get("post_result_handoff_summary", "")),
			String(campaign_snapshot.get("action_cue_summary", "")),
			String(campaign_snapshot.get("actions_hint", "")),
			String(campaign_snapshot.get("actions_hint_tooltip", "")),
			campaign_action_payload_text,
			campaign_action_tooltip_text,
			String(campaign_snapshot.get("action_status", "")),
			String(campaign_snapshot.get("save_status", "")),
			String(campaign_snapshot.get("save_status_tooltip", "")),
			String(campaign_snapshot.get("save_button_tooltip", "")),
			String(campaign_snapshot.get("return_cue", "")),
			String(campaign_snapshot.get("return_cue_tooltip", "")),
			String(campaign_snapshot.get("save_check", "")),
			String(campaign_snapshot.get("play_check", "")),
			String(campaign_snapshot.get("return_handoff", "")),
		],
		["Campaign progress", "Next chapter import ready:", "This victory exports:", "Follow-up check:", "Outcome Follow-up Check", "Primary follow-up:", "starts a fresh campaign chapter from recorded campaign progress", "Save first:", "Return keeps review", "Retry check:", "Outcome Retry Check", "replays this chapter from its authored opening state", "save keeps review", "current campaign record stays as recorded", "Carryover check:", "Outcome Carryover Check", "Campaign export", "next chapter ready", "Replay/new run:", "recorded campaign progress", "Manual save:", "Slot check:", "Outcome Slot Check", "Selected slot:", "Saving now:", "Outcome save check:", "Outcome Save Check", "Save target:", "Save action:", "Follow-up boundary:", "review preserved", "Manual", "Continue Latest and Load Selected can review this outcome", "State change:", "Inspection:", "Outcome handoff:", "Victory recorded", "primary follow-up", "Continuity choice:", "carry forward", "Chapter 2", "replay keeps", "return to menu", "Post-result handoff:", "campaign progression is already recorded", "Save Outcome", "fresh campaign chapter", "Action cue:", "save first", "campaign board", "Replays this chapter fresh", "Start Chapter 2", "Return cue:", "Menu autosaves this outcome", "Continue Latest reviews it later", "Save check:", "Play check:", "Return handoff:"]
	):
		return false
	if not _assert_no_score_leak(
		"Outcome campaign continuity choice",
		[
			String(campaign_follow_up_check.get("visible_text", "")),
			String(campaign_follow_up_check.get("tooltip_text", "")),
			String(campaign_retry_check.get("visible_text", "")),
			String(campaign_retry_check.get("tooltip_text", "")),
			String(campaign_carryover_check.get("visible_text", "")),
			String(campaign_carryover_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("carryover_label", "")),
			String(campaign_snapshot.get("carryover_tooltip", "")),
			String(campaign_slot_check.get("visible_text", "")),
			String(campaign_slot_check.get("tooltip_text", "")),
			String(campaign_save_check.get("visible_text", "")),
			String(campaign_save_check.get("tooltip_text", "")),
			String(campaign_snapshot.get("outcome_resolution_handoff", "")),
			String(campaign_snapshot.get("continuity_choice_summary", "")),
			String(campaign_snapshot.get("post_result_handoff_summary", "")),
			String(campaign_snapshot.get("action_cue_summary", "")),
			String(campaign_snapshot.get("actions_hint", "")),
			String(campaign_snapshot.get("actions_hint_tooltip", "")),
			campaign_action_payload_text,
			campaign_action_tooltip_text,
			String(campaign_snapshot.get("action_status", "")),
			String(campaign_snapshot.get("carryover_summary", "")),
			String(campaign_snapshot.get("save_status", "")),
			String(campaign_snapshot.get("save_status_tooltip", "")),
			String(campaign_snapshot.get("save_button_tooltip", "")),
			String(campaign_snapshot.get("return_cue", "")),
			String(campaign_snapshot.get("return_cue_tooltip", "")),
		]
	):
		return false

	campaign_shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_outcome_field_manual_contract(shell: Node, label: String) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_open_outcome_guide") or not shell.has_method("validation_close_outcome_guide"):
		push_error("%s: outcome shell is missing Field Manual validation hooks." % label)
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(snapshot.get("outcome_guide_visible", true)):
		push_error("%s: outcome Field Manual should stay collapsed until requested: %s." % [label, snapshot])
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		label + " control",
		[
			String(snapshot.get("outcome_guide_button", "")),
			String(snapshot.get("outcome_guide_tooltip", "")),
		],
		["Guide", "Open the outcome Field Manual", "does not save, load, route, or change campaign progression"]
	):
		return false
	shell.call("validation_open_outcome_guide")
	var guide_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(guide_snapshot.get("outcome_guide_visible", false)):
		push_error("%s: outcome Field Manual did not open: %s." % [label, guide_snapshot])
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		label,
		[
			String(guide_snapshot.get("outcome_guide_button", "")),
			String(guide_snapshot.get("outcome_guide_tooltip", "")),
			String(guide_snapshot.get("outcome_guide_full", guide_snapshot.get("outcome_guide", ""))),
		],
		["Hide Guide", "Hide the outcome Field Manual", "Outcome", "resolved expedition checkpoint", "Outcome Retry Check", "Outcome Carryover Check", "Outcome Slot Check", "Outcome Save Check", "Post-result handoff:", "Save check:", "Play check:", "Return handoff:", "Guide handoff:", "same outcome actions"]
	):
		return false
	if not _assert_no_score_leak(
		label,
		[
			String(guide_snapshot.get("outcome_guide_tooltip", "")),
			String(guide_snapshot.get("outcome_guide_full", guide_snapshot.get("outcome_guide", ""))),
		]
	):
		return false
	shell.call("validation_close_outcome_guide")
	var closed_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(closed_snapshot.get("outcome_guide_visible", true)):
		push_error("%s: outcome Field Manual did not close: %s." % [label, closed_snapshot])
		get_tree().quit(1)
		return false
	return true

func _joined_action_payload_text(snapshot: Dictionary) -> String:
	var lines := []
	var actions = snapshot.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				lines.append(String(action.get("label", "")))
				lines.append(String(action.get("summary", "")))
				lines.append(String(action.get("action_cue", "")))
	return "\n".join(lines)

func _keep_resolution(shell: Node, resolution_id: String) -> bool:
	if not bool(shell.call("validation_select_resolution", resolution_id)):
		return false
	if SettingsService.display_change_pending():
		var result: Dictionary = shell.call("validation_confirm_display_change")
		if bool(result.get("pending", true)) or bool(result.get("dialog_visible", true)):
			return false
	return SettingsService.presentation_resolution_id() == resolution_id

func _joined_action_tooltip_text(snapshot: Dictionary) -> String:
	var lines := []
	var tooltips = snapshot.get("action_tooltips", [])
	if tooltips is Array:
		for tooltip in tooltips:
			if tooltip is Dictionary:
				lines.append(String(tooltip.get("label", "")))
				lines.append(String(tooltip.get("tooltip", "")))
	return "\n".join(lines)
