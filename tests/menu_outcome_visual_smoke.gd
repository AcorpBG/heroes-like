extends Node

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")
const OutcomeScenicBackdropViewScript = preload("res://scenes/results/OutcomeScenicBackdropView.gd")
const OutcomeBannerViewScript = preload("res://scenes/results/OutcomeBannerView.gd")
const CAMPAIGN_SMOKE_ID := "campaign_reedfall"
const OUTCOME_SCENIC_BACKDROP_PATHS := {
	"victory": "res://art/results/runtime/backdrops/outcome_victory.png",
	"defeat": "res://art/results/runtime/backdrops/outcome_defeat.png",
}
const OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME := {
	"Banner": 0.78,
	"BannerArtPanel": 0.66,
	"ActionStatusPanel": 0.68,
	"HeroPanel": 0.72,
	"ArmyPanel": 0.72,
	"ResourcePanel": 0.72,
	"ActionsPanel": 0.70,
	"SidebarShell": 0.82,
	"ProgressionPanel": 0.78,
	"AftermathPanel": 0.78,
	"CampaignArcPanel": 0.78,
	"CarryoverPanel": 0.78,
	"JournalPanel": 0.78,
	"SavePanel": 0.80,
}
const OUTCOME_SCENIC_STAGE_SIZES := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]
const OUTCOME_STATUS_EMBLEM_PATHS := {
	"victory": "res://art/results/runtime/emblems/outcome_victory_emblem.png",
	"defeat": "res://art/results/runtime/emblems/outcome_defeat_emblem.png",
}
const OUTCOME_STATUS_EMBLEM_STAGE_SIZES := [Vector2(260.0, 104.0), Vector2(300.0, 176.0)]
const MAIN_MENU_STAGE_DOCK_ASSET_PATH := "res://art/ui/runtime/main_menu/stage_dock_cartography.png"
const MAIN_MENU_STAGE_DOCK_TEXTURE_SIZE := Vector2(1024.0, 1024.0)
const MAIN_MENU_STAGE_DOCK_TEXTURE_MARGINS := Vector4(56.0, 56.0, 56.0, 56.0)
const MAIN_MENU_STAGE_DOCK_TEXTURE_MODULATE := Color(0.86, 0.88, 0.88, 0.98)
const MAIN_MENU_POCKET_FRAME_MODEL := "shared_stage_cartography_quiet_pocket_frame"
const MAIN_MENU_POCKET_TEXTURE_MARGINS := Vector4(56.0, 56.0, 56.0, 56.0)
const MAIN_MENU_POCKET_TEXTURE_MODULATE := Color(0.72, 0.76, 0.78, 0.88)
const MAIN_MENU_LOGO_POCKET_ANCHORS := Rect2(0.032, 0.028, 0.330, 0.200)
const MAIN_MENU_FOOTER_POCKET_ANCHORS := Rect2(0.032, 0.895, 0.340, 0.080)
const MAIN_MENU_STAGE_DOCK_WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]
const MAIN_MENU_STAGE_DOCK_COMPACT_ANCHORS := Rect2(0.032, 0.258, 0.528, 0.440)
const MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS := Rect2(0.032, 0.258, 0.733, 0.620)
const MAIN_MENU_CAMPAIGN_DOCK_FIRST_VIEW_MIN_HEIGHT := 460.0
const MAIN_MENU_CAMPAIGN_DOCK_MAX_HEIGHT_RATIO := 0.640
const MAIN_MENU_SKIRMISH_DOCK_FIRST_VIEW_MIN_HEIGHT := 520.0
const MAIN_MENU_SKIRMISH_DOCK_MAX_HEIGHT_RATIO := 0.720
const MAIN_MENU_GUIDE_DOCK_MAX_SIZE := Vector2(1024.0, 460.0)
const MAIN_MENU_ITEM_LISTS_BY_BOARD := {
	"Campaign": ["CampaignList", "ChapterList"],
	"Skirmish": ["SkirmishList"],
	"Saves": ["SaveList"],
	"Guide": ["HelpList"],
}

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
	var frontier_crest = shell.get_node_or_null("LogoPocketPanel/LogoPocketPad/LogoPocketBox/LogoHeader/WarGlyph")
	if not (frontier_crest is TextureRect) or not _assert_frontier_crest_asset(frontier_crest as TextureRect):
		get_tree().quit(1)
		return false
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
	for button in [campaign_button, skirmish_button, load_button, settings_button, quit_button]:
		if not _assert_text_only_plaque_style(button as Button, String((button as Button).text)):
			get_tree().quit(1)
			return false
	if not await _assert_editor_utility_frame_at_supported_widths(
		shell,
		logo_panel,
		public_title as Label,
		frontier_crest as TextureRect,
		settings_button as Button,
		editor_button as Button,
		quit_button as Button
	):
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
	var editor_utility_frame: Dictionary = first_view_snapshot.get("editor_utility_frame", {}) if first_view_snapshot.get("editor_utility_frame", {}) is Dictionary else {}
	if String(editor_utility_frame.get("style_class", "")) != "StyleBoxTexture" \
			or String(editor_utility_frame.get("normal_texture_path", "")) != "res://art/ui/runtime/shared/button_secondary_normal.png" \
			or not is_equal_approx(float(editor_utility_frame.get("anchor_top", 0.0)), 0.681) \
			or not is_equal_approx(float(editor_utility_frame.get("anchor_bottom", 0.0)), 0.729) \
			or String(editor_utility_frame.get("tooltip_text", "")) != (editor_button as Button).tooltip_text:
		push_error("Main menu smoke: Editor utility frame snapshot is not exact: %s." % [editor_utility_frame])
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
	if skirmish_list == null:
		push_error("Main menu smoke: skirmish browser node is missing.")
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
	if int(skirmish_list.get_item_count()) <= 0:
		push_error("Main menu smoke: skirmish browser did not populate after its public stage opened.")
		get_tree().quit(1)
		return false
	var initial_skirmish_snapshot: Dictionary = shell.call("validation_snapshot")
	var initial_skirmish_forge: Dictionary = initial_skirmish_snapshot.get("generated_map_forge", {}) if initial_skirmish_snapshot.get("generated_map_forge", {}) is Dictionary else {}
	if bool(initial_skirmish_forge.get("expanded", true)) \
			or bool(initial_skirmish_forge.get("controls_visible", true)) \
			or bool(initial_skirmish_forge.get("provenance_visible", true)) \
			or String(initial_skirmish_forge.get("toggle_text", "")) != "Open Forge" \
			or String(initial_skirmish_forge.get("eyebrow_text", "")) != "MAP FORGE":
		push_error("Main menu smoke: Skirmish first view did not keep the Map Forge compact: %s." % [initial_skirmish_forge])
		get_tree().quit(1)
		return false
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
	if not await _assert_main_menu_stage_dock_surface(shell, session):
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
	if not await _assert_battle_shake_picker_theme_parity(
		shell as Control,
		ui_scale_picker as OptionButton,
		battle_camera_shake_picker as OptionButton,
		color_cue_picker as OptionButton,
		original_ui_scale,
		original_high_contrast
	):
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
	if not await _focus_settings_scroll_control(shell, &"ReduceRepetitiveSoundsToggle"):
		push_error("Main menu smoke: Reduce Repetitive Sounds could not receive focus in the max-scale settings scroll.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("reduce_repetitive_sounds_visible_in_scroll", false)):
		push_error("Main menu smoke: Reduce Repetitive Sounds is not reachable in the max-scale settings scroll: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if not await _focus_settings_scroll_control(shell, &"ReduceFlashesToggle"):
		push_error("Main menu smoke: Reduce Flashes could not receive focus in the max-scale settings scroll.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("reduce_flashes_visible_in_scroll", false)):
		push_error("Main menu smoke: Reduce Flashes is not reachable in the max-scale settings scroll: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if not await _focus_settings_scroll_control(shell, &"ExportSupportBundle"):
		push_error("Main menu smoke: support bundle could not receive focus in the max-scale settings scroll.")
		get_tree().quit(1)
		return false
	settings_snapshot = shell.call("validation_snapshot")
	if not bool(settings_snapshot.get("support_bundle_visible_in_scroll", false)):
		push_error("Main menu smoke: support bundle remains clipped after settings scrolling: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if not await _focus_settings_scroll_control(shell, &"RestoreSettingsDefaults"):
		push_error("Main menu smoke: Restore Defaults could not receive focus in the max-scale settings scroll.")
		get_tree().quit(1)
		return false
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
	if not await _focus_settings_scroll_control(shell, &"ReduceFlashesToggle"):
		push_error("Main menu smoke: Reduce Flashes could not regain focus after cancelling Restore Defaults.")
		get_tree().quit(1)
		return false

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
	var contrast_menu_tabs := shell.get_node_or_null("%MenuTabs") as TabContainer
	if not bool(settings_snapshot.get("high_contrast_enabled", false)) or not String(settings_snapshot.get("settings_summary_full", "")).contains("High contrast On") or not (contrast_normal is StyleBoxFlat) or not (contrast_focus is StyleBoxFlat) or (contrast_normal as StyleBoxFlat).bg_color.get_luminance() > 0.08 or (contrast_normal as StyleBoxFlat).border_color.get_luminance() < 0.80 or (contrast_focus as StyleBoxFlat).border_width_left < 4:
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: high-contrast mode did not apply solid dark controls, bright borders, and a strong focus ring: %s." % settings_snapshot)
		get_tree().quit(1)
		return false
	if contrast_menu_tabs == null or not _shared_tab_plaque_high_contrast_exact(contrast_menu_tabs):
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: high-contrast tabs did not use exact texture-free plaque fallbacks.")
		get_tree().quit(1)
		return false
	var contrast_stage_surface: Dictionary = shell.call("validation_stage_dock_surface_summary")
	if String(contrast_stage_surface.get("style_class", "")) != "StyleBoxFlat" \
			or String(contrast_stage_surface.get("rendering_mode", "")) != "smoke_fallback" \
			or String(contrast_stage_surface.get("texture_path", "")) != "" \
			or not bool(contrast_stage_surface.get("high_contrast", false)) \
			or not bool(contrast_stage_surface.get("fallbacks_texture_free", false)):
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: high-contrast mode did not replace the cartographic Stage Dock with the exact smoke fallback: %s." % [contrast_stage_surface])
		get_tree().quit(1)
		return false
	var contrast_pocket_surface: Dictionary = shell.call("validation_main_menu_pocket_surface_summary")
	if String(contrast_pocket_surface.get("rendering_mode", "")) != "smoke_fallback" \
			or String(contrast_pocket_surface.get("logo_style_class", "")) != "StyleBoxFlat" \
			or String(contrast_pocket_surface.get("footer_style_class", "")) != "StyleBoxFlat" \
			or String(contrast_pocket_surface.get("logo_texture_path", "")) != "" \
			or String(contrast_pocket_surface.get("footer_texture_path", "")) != "" \
			or not bool(contrast_pocket_surface.get("high_contrast", false)) \
			or not bool(contrast_pocket_surface.get("fallbacks_texture_free", false)):
		if not original_high_contrast:
			shell.call("validation_set_high_contrast", false)
		push_error("Main menu smoke: high-contrast mode did not replace both cartographic first-view pockets with exact smoke fallbacks: %s." % [contrast_pocket_surface])
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
	var restored_stage_surface: Dictionary = shell.call("validation_stage_dock_surface_summary")
	var restored_pocket_surface: Dictionary = shell.call("validation_main_menu_pocket_surface_summary")
	var expected_restored_mode := "smoke_fallback" if original_high_contrast else "authored_cartography_surface"
	var expected_restored_class := "StyleBoxFlat" if original_high_contrast else "StyleBoxTexture"
	if String(restored_stage_surface.get("rendering_mode", "")) != expected_restored_mode \
			or String(restored_stage_surface.get("style_class", "")) != expected_restored_class \
			or (not original_high_contrast and String(restored_stage_surface.get("texture_path", "")) != MAIN_MENU_STAGE_DOCK_ASSET_PATH):
		push_error("Main menu smoke: Stage Dock surface did not restore its original contrast-dependent rendering mode: %s." % [restored_stage_surface])
		get_tree().quit(1)
		return false
	var expected_restored_pocket_mode := "smoke_fallback" if original_high_contrast else "authored_cartography_pockets"
	if String(restored_pocket_surface.get("rendering_mode", "")) != expected_restored_pocket_mode \
			or String(restored_pocket_surface.get("logo_style_class", "")) != expected_restored_class \
			or String(restored_pocket_surface.get("footer_style_class", "")) != expected_restored_class \
			or (not original_high_contrast and String(restored_pocket_surface.get("logo_texture_path", "")) != MAIN_MENU_STAGE_DOCK_ASSET_PATH) \
			or (not original_high_contrast and String(restored_pocket_surface.get("footer_texture_path", "")) != MAIN_MENU_STAGE_DOCK_ASSET_PATH):
		push_error("Main menu smoke: first-view pocket surfaces did not restore their original contrast-dependent rendering mode: %s." % [restored_pocket_surface])
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

	(close_stage_button as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var returned_first_view_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(returned_first_view_snapshot.get("footer_pocket_visible", false)) \
			or String(returned_first_view_snapshot.get("active_expedition", "")) != String(first_view_snapshot.get("active_expedition", "")) \
			or String(returned_first_view_snapshot.get("active_expedition_full", "")) != String(first_view_snapshot.get("active_expedition_full", "")) \
			or not _assert_footer_pocket_containment(shell, shell.size, "returned first view"):
		push_error("Main menu smoke: Frontier Log did not return with its exact first-view content and containment: %s." % [returned_first_view_snapshot])
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_main_menu_stage_dock_surface(shell: Control, session) -> bool:
	if not shell.has_method("validation_stage_dock_surface_summary"):
		push_error("Main menu smoke: Stage Dock surface validation summary is missing.")
		get_tree().quit(1)
		return false
	var original_window_size: Vector2i = get_window().size
	var original_high_contrast := SettingsService.high_contrast_ui_enabled()
	var session_before: Dictionary = session.to_dict()
	var compact_contracts: Dictionary = {}
	var compact_item_list_payloads: Dictionary = {}
	var failure := ""
	if original_high_contrast and not bool(shell.call("validation_set_high_contrast", false)):
		failure = "could not establish the authored standard-contrast surface"
	for width_index in range(MAIN_MENU_STAGE_DOCK_WINDOW_SIZES.size()):
		if failure != "":
			break
		var requested_size: Vector2i = MAIN_MENU_STAGE_DOCK_WINDOW_SIZES[width_index]
		SettingsService.call("_set_runtime_window_size", requested_size)
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != requested_size or get_tree().root.size != requested_size:
			failure = "window/root did not reach %s" % [requested_size]
			break
		var campaign_anchors := _main_menu_campaign_dock_anchors(requested_size)
		var skirmish_anchors := _main_menu_skirmish_dock_anchors(requested_size)
		var guide_anchors := _main_menu_guide_dock_anchors(requested_size)
		for board in [
			{"label": "Campaign", "tab": 0, "anchors": campaign_anchors},
			{"label": "Skirmish", "tab": 1, "anchors": skirmish_anchors},
			{"label": "Saves", "tab": 2, "anchors": MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS},
			{"label": "Settings", "tab": 4, "anchors": MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS},
			{"label": "Guide", "tab": 3, "anchors": guide_anchors},
		]:
			match String(board.get("label", "")):
				"Campaign":
					shell.call("validation_open_campaign_stage")
				"Skirmish":
					shell.call("validation_open_skirmish_stage")
				"Saves":
					shell.call("validation_open_saves_stage")
				"Settings":
					shell.call("validation_open_settings_stage")
				"Guide":
					shell.call("validation_open_contextual_guide_stage")
			await get_tree().process_frame
			await get_tree().process_frame
			var summary: Dictionary = shell.call("validation_stage_dock_surface_summary")
			var anchors: Rect2 = board.get("anchors", Rect2())
			if String(board.get("label", "")) == "Saves" and (
				bool(summary.get("save_empty_state", true))
				or bool(summary.get("save_empty_panel_visible", true))
				or not bool(summary.get("save_split_visible", false))
			):
				failure = "Populated Saves board did not retain its exact two-column surface at %s: %s" % [requested_size, summary]
				break
			var anchored_rect := Rect2(
				Vector2(shell.size.x * anchors.position.x, shell.size.y * anchors.position.y),
				Vector2(shell.size.x * anchors.size.x, shell.size.y * anchors.size.y)
			)
			if not _main_menu_stage_dock_summary_exact(summary, int(board.get("tab", -1)), anchors, anchored_rect, shell.size):
				failure = "%s surface contract failed at %s: %s" % [board.get("label", ""), requested_size, summary]
				break
			for item_list_name_value in MAIN_MENU_ITEM_LISTS_BY_BOARD.get(String(board.get("label", "")), []):
				var item_list_name := String(item_list_name_value)
				var item_list := shell.get_node_or_null("%%%s" % item_list_name) as ItemList
				var dock_rect: Rect2 = summary.get("dock_rect", Rect2())
				if not _main_menu_item_list_inlay_exact(item_list, dock_rect):
					failure = "%s list %s lost its enamel-and-gold inlay or containment at %s" % [board.get("label", ""), item_list_name, requested_size]
					break
			if failure != "":
				break
			var contract_key := String(board.get("label", ""))
			var board_item_list_payloads: Dictionary = {}
			var all_item_list_payloads := _main_menu_item_list_payloads(shell)
			for item_list_name_value in MAIN_MENU_ITEM_LISTS_BY_BOARD.get(contract_key, []):
				var payload_item_list_name := String(item_list_name_value)
				board_item_list_payloads[payload_item_list_name] = all_item_list_payloads.get(payload_item_list_name, {}).duplicate(true)
			if width_index == 0:
				compact_contracts[contract_key] = summary.duplicate(true)
				compact_item_list_payloads[contract_key] = board_item_list_payloads
			elif width_index == MAIN_MENU_STAGE_DOCK_WINDOW_SIZES.size() - 1 and summary != compact_contracts.get(contract_key, {}):
				failure = "%s surface did not restore exactly after compact-wide-compact: before=%s after=%s" % [contract_key, compact_contracts.get(contract_key, {}), summary]
				break
			elif width_index == MAIN_MENU_STAGE_DOCK_WINDOW_SIZES.size() - 1 and board_item_list_payloads != compact_item_list_payloads.get(contract_key, {}):
				failure = "%s item text, metadata, tooltip, or selection did not restore exactly after compact-wide-compact" % contract_key
				break
	SettingsService.call("_set_runtime_window_size", original_window_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if SettingsService.high_contrast_ui_enabled() != original_high_contrast:
		if not bool(shell.call("validation_set_high_contrast", original_high_contrast)) and failure == "":
			failure = "could not restore the original high-contrast setting"
	if session.to_dict() != session_before and failure == "":
		failure = "session authority changed during the Stage Dock width/tab round trip"
	if failure != "":
		push_error("Main menu smoke: Stage Dock cartography surface validation failed: %s." % failure)
		get_tree().quit(1)
		return false
	return true

func _main_menu_item_list_inlay_exact(item_list: ItemList, dock_rect: Rect2) -> bool:
	if item_list == null or not item_list.is_visible_in_tree() or item_list.get_item_count() <= 0:
		return false
	if not _main_menu_item_list_visible_containment_exact(item_list, dock_rect) or item_list.get_selected_items().size() != 1:
		return false
	var selected := item_list.get_theme_stylebox("selected")
	var selected_focus := item_list.get_theme_stylebox("selected_focus")
	var hovered := item_list.get_theme_stylebox("hovered")
	var hovered_selected := item_list.get_theme_stylebox("hovered_selected")
	var hovered_selected_focus := item_list.get_theme_stylebox("hovered_selected_focus")
	var cursor := item_list.get_theme_stylebox("cursor")
	var cursor_unfocused := item_list.get_theme_stylebox("cursor_unfocused")
	var focus := item_list.get_theme_stylebox("focus")
	if not (
		selected is StyleBoxFlat
		and selected_focus is StyleBoxFlat
		and hovered is StyleBoxFlat
		and hovered_selected is StyleBoxFlat
		and hovered_selected_focus is StyleBoxFlat
		and cursor is StyleBoxFlat
		and cursor_unfocused is StyleBoxFlat
		and focus is StyleBoxFlat
	):
		return false
	var selected_flat := selected as StyleBoxFlat
	var selected_focus_flat := selected_focus as StyleBoxFlat
	var hovered_flat := hovered as StyleBoxFlat
	var cursor_flat := cursor as StyleBoxFlat
	var cursor_unfocused_flat := cursor_unfocused as StyleBoxFlat
	var focus_flat := focus as StyleBoxFlat
	return (
		selected_flat.bg_color.is_equal_approx(Color(0.24, 0.18, 0.10, 0.96))
		and selected_flat.border_color.is_equal_approx(Color(0.86, 0.70, 0.39, 0.94))
		and selected_flat.border_width_left == 4
		and selected_flat.border_width_top == 1
		and selected_flat.border_width_right == 1
		and selected_flat.border_width_bottom == 1
		and selected_flat.corner_radius_top_left == 4
		and selected_flat.corner_radius_top_right == 4
		and selected_flat.corner_radius_bottom_left == 4
		and selected_flat.corner_radius_bottom_right == 4
		and is_equal_approx(selected_flat.content_margin_left, 8.0)
		and is_equal_approx(selected_flat.content_margin_top, 2.0)
		and is_equal_approx(selected_flat.content_margin_right, 6.0)
		and is_equal_approx(selected_flat.content_margin_bottom, 2.0)
		and selected_focus_flat.border_color.is_equal_approx(Color(0.97, 0.88, 0.61, 1.0))
		and selected_focus_flat.border_width_left == 4
		and selected_focus_flat.shadow_size == 3
		and hovered_flat.bg_color.is_equal_approx(Color(0.10, 0.16, 0.18, 0.88))
		and hovered_flat.border_color.is_equal_approx(Color(0.43, 0.66, 0.70, 0.78))
		and hovered_flat.border_width_left == 2
		and cursor_flat.border_width_left == 2
		and cursor_unfocused_flat.border_width_left == 1
		and focus_flat.bg_color.a <= 0.001
		and focus_flat.border_color.is_equal_approx(Color(0.97, 0.88, 0.61, 1.0))
		and focus_flat.border_width_left == 1
		and focus_flat.corner_radius_top_left == 8
		and item_list.get_theme_constant("line_separation") == 3
		and item_list.get_theme_color("font_color").is_equal_approx(Color(0.86, 0.90, 0.93, 1.0))
		and item_list.get_theme_color("font_selected_color").is_equal_approx(Color(0.98, 0.96, 0.90, 1.0))
	)

func _main_menu_item_list_visible_containment_exact(item_list: ItemList, dock_rect: Rect2) -> bool:
	var list_rect := item_list.get_global_rect()
	var ancestor := item_list.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			var scroll_rect := (ancestor as ScrollContainer).get_global_rect()
			return _rect_is_contained(dock_rect, scroll_rect) and scroll_rect.intersects(list_rect)
		ancestor = ancestor.get_parent()
	return _rect_is_contained(dock_rect, list_rect)

func _main_menu_item_list_payloads(shell: Control) -> Dictionary:
	var result := {}
	for list_name in ["CampaignList", "ChapterList", "SkirmishList", "SaveList", "HelpList"]:
		var item_list := shell.get_node_or_null("%%%s" % list_name) as ItemList
		if item_list == null:
			result[list_name] = {"missing": true}
			continue
		var items: Array = []
		for item_index in range(item_list.get_item_count()):
			var metadata = item_list.get_item_metadata(item_index)
			items.append({
				"text": item_list.get_item_text(item_index),
				"tooltip": item_list.get_item_tooltip(item_index),
				"metadata": metadata.duplicate(true) if metadata is Dictionary or metadata is Array else metadata,
			})
		result[list_name] = {
			"items": items,
			"selected": Array(item_list.get_selected_items()),
		}
	return result

func _main_menu_campaign_dock_anchors(viewport_size: Vector2i) -> Rect2:
	var first_view_height_ratio := minf(
		MAIN_MENU_CAMPAIGN_DOCK_FIRST_VIEW_MIN_HEIGHT / float(viewport_size.y),
		MAIN_MENU_CAMPAIGN_DOCK_MAX_HEIGHT_RATIO
	)
	return Rect2(
		MAIN_MENU_STAGE_DOCK_COMPACT_ANCHORS.position,
		Vector2(
			MAIN_MENU_STAGE_DOCK_COMPACT_ANCHORS.size.x,
			maxf(MAIN_MENU_STAGE_DOCK_COMPACT_ANCHORS.size.y, first_view_height_ratio)
		)
	)

func _main_menu_skirmish_dock_anchors(viewport_size: Vector2i) -> Rect2:
	var first_view_height_ratio := minf(
		MAIN_MENU_SKIRMISH_DOCK_FIRST_VIEW_MIN_HEIGHT / float(viewport_size.y),
		MAIN_MENU_SKIRMISH_DOCK_MAX_HEIGHT_RATIO
	)
	return Rect2(
		MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.position,
		Vector2(
			MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.size.x,
			maxf(MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.size.y, first_view_height_ratio)
		)
	)

func _main_menu_guide_dock_anchors(viewport_size: Vector2i) -> Rect2:
	if viewport_size.x <= 1280 or viewport_size.y <= 720:
		return MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS
	return Rect2(
		MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.position,
		Vector2(
			minf(MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.size.x, MAIN_MENU_GUIDE_DOCK_MAX_SIZE.x / float(viewport_size.x)),
			minf(MAIN_MENU_STAGE_DOCK_STANDARD_ANCHORS.size.y, MAIN_MENU_GUIDE_DOCK_MAX_SIZE.y / float(viewport_size.y))
		)
	)

func _main_menu_stage_dock_summary_exact(summary: Dictionary, expected_tab: int, expected_anchors: Rect2, anchored_rect: Rect2, viewport_size: Vector2) -> bool:
	var dock_rect: Rect2 = summary.get("dock_rect", Rect2())
	var actual_anchors: Rect2 = summary.get("dock_anchors", Rect2())
	var combined_minimum: Vector2 = summary.get("dock_combined_minimum_size", Vector2.ZERO)
	var expected_rect := Rect2(anchored_rect.position, Vector2(
		maxf(anchored_rect.size.x, combined_minimum.x),
		maxf(anchored_rect.size.y, combined_minimum.y)
	))
	var checks := {
		"asset_path": String(summary.get("asset_path", "")) == MAIN_MENU_STAGE_DOCK_ASSET_PATH,
		"asset_exists": bool(summary.get("asset_exists", false)),
		"style_class": String(summary.get("style_class", "")) == "StyleBoxTexture",
		"texture_path": String(summary.get("texture_path", "")) == MAIN_MENU_STAGE_DOCK_ASSET_PATH,
		"texture_size": summary.get("texture_size", Vector2.ZERO) == MAIN_MENU_STAGE_DOCK_TEXTURE_SIZE,
		"texture_margins": summary.get("texture_margins", Vector4.ZERO) == MAIN_MENU_STAGE_DOCK_TEXTURE_MARGINS,
		"content_margins": summary.get("content_margins", Vector4.ONE) == Vector4.ZERO,
		"modulate": summary.get("modulate", Color.WHITE) == MAIN_MENU_STAGE_DOCK_TEXTURE_MODULATE,
		"dock_visible": bool(summary.get("dock_visible", false)),
		"current_tab": int(summary.get("current_tab", -1)) == expected_tab,
		"standard_contrast": not bool(summary.get("high_contrast", true)),
		"rendering_mode": String(summary.get("rendering_mode", "")) == "authored_cartography_surface",
		"high_contrast_fallback": String(summary.get("high_contrast_fallback_class", "")) == "StyleBoxFlat",
		"missing_asset_fallback": String(summary.get("missing_asset_fallback_class", "")) == "StyleBoxFlat",
		"fallbacks_texture_free": bool(summary.get("fallbacks_texture_free", false)),
		"anchors": actual_anchors.position.distance_to(expected_anchors.position) <= 0.0001 and actual_anchors.size.distance_to(expected_anchors.size) <= 0.0001,
		"minimum_positive": combined_minimum.x > 0.0 and combined_minimum.y > 0.0,
		"position": dock_rect.position.distance_to(expected_rect.position) <= 1.0,
		"size": dock_rect.size.distance_to(expected_rect.size) <= 1.0,
		"contained": _rect_is_contained(Rect2(Vector2.ZERO, viewport_size), dock_rect, 1.0),
	}
	return not checks.values().has(false)

func _focus_settings_scroll_control(shell: Node, control_name: StringName) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var control := shell.get_node_or_null("%%%s" % String(control_name)) as Control
	if control == null or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	control.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return get_viewport().gui_get_focus_owner() == control

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

func _assert_frontier_crest_asset(frontier_crest: TextureRect) -> bool:
	if frontier_crest.custom_minimum_size != Vector2(56.0, 52.0) \
			or frontier_crest.expand_mode != TextureRect.EXPAND_IGNORE_SIZE \
			or frontier_crest.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED \
			or frontier_crest.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("Main menu smoke: Aurelion Reach crest layout contract drifted.")
		return false
	var crest_texture := frontier_crest.texture
	if crest_texture == null or crest_texture.resource_path != "res://art/ui/branding/aurelion_reach_frontier_crest.png":
		push_error("Main menu smoke: Aurelion Reach crest texture is missing or incorrect.")
		return false
	var crest_image: Image = crest_texture.get_image()
	if crest_image == null or crest_image.is_empty() or crest_image.get_width() != 1254 or crest_image.get_height() != 1254:
		push_error("Main menu smoke: Aurelion Reach crest did not import as the authored 1254x1254 image.")
		return false
	var corner_pixels := [
		crest_image.get_pixel(0, 0),
		crest_image.get_pixel(crest_image.get_width() - 1, 0),
		crest_image.get_pixel(0, crest_image.get_height() - 1),
		crest_image.get_pixel(crest_image.get_width() - 1, crest_image.get_height() - 1),
	]
	for corner: Color in corner_pixels:
		if corner.a > 0.01:
			push_error("Main menu smoke: Aurelion Reach crest corners are not transparent.")
			return false
	var visible_pixel_count := 0
	var chroma_green_pixel_count := 0
	for y in range(crest_image.get_height()):
		for x in range(crest_image.get_width()):
			var pixel := crest_image.get_pixel(x, y)
			if pixel.a <= 0.01:
				continue
			visible_pixel_count += 1
			if pixel.g > 0.65 and pixel.g > pixel.r * 1.35 and pixel.g > pixel.b * 1.25:
				chroma_green_pixel_count += 1
	var pixel_count := crest_image.get_width() * crest_image.get_height()
	var visible_coverage := float(visible_pixel_count) / float(pixel_count)
	var chroma_green_ratio := float(chroma_green_pixel_count) / float(maxi(visible_pixel_count, 1))
	if visible_coverage < 0.25 or visible_coverage > 0.55 or chroma_green_ratio > 0.002:
		push_error("Main menu smoke: Aurelion Reach crest alpha/chroma contract failed: coverage %.4f green %.6f." % [visible_coverage, chroma_green_ratio])
		return false
	return true

func _assert_editor_utility_frame_at_supported_widths(shell: Control, logo_panel: Control, public_title: Label, frontier_crest: TextureRect, settings_button: Button, editor_button: Button, quit_button: Button) -> bool:
	var original_size := get_window().size
	for requested_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		SettingsService.call("_set_runtime_window_size", requested_size)
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != requested_size:
			push_error("Main menu smoke: Editor frame fixture did not reach requested size %s." % [requested_size])
			return false
		var viewport_size := shell.size
		var physical_size := DisplayServer.window_get_size()
		var physical_size_exact: bool = physical_size == requested_size \
			or (DisplayServer.get_name() == "headless" and physical_size == Vector2i.ZERO)
		var root_size := get_tree().root.size
		var content_scale_size := get_tree().root.content_scale_size
		var settings_rect := settings_button.get_global_rect()
		var editor_rect := editor_button.get_global_rect()
		var quit_rect := quit_button.get_global_rect()
		var logo_rect := logo_panel.get_global_rect()
		var title_rect := public_title.get_global_rect()
		var crest_rect := frontier_crest.get_global_rect()
		if not physical_size_exact \
				or get_window().size != requested_size \
				or root_size != requested_size \
				or content_scale_size != requested_size \
				or Vector2i(int(viewport_size.x), int(viewport_size.y)) != requested_size:
			push_error("Main menu smoke: native/root/canvas size authority diverged at %s: physical=%s window=%s root=%s content_scale=%s viewport=%s." % [requested_size, physical_size, get_window().size, root_size, content_scale_size, viewport_size])
			return false
		var first_view_rect := Rect2(Vector2.ZERO, viewport_size)
		var pocket_summary: Dictionary = shell.call("validation_main_menu_pocket_surface_summary")
		if not _main_menu_pocket_summary_exact(pocket_summary, viewport_size):
			push_error("Main menu smoke: cartographic first-view pocket contract failed at %s: %s." % [requested_size, pocket_summary])
			return false
		if not _assert_footer_pocket_containment(shell, viewport_size, "%s first view" % requested_size):
			return false
		for command_name in ["OpenCampaign", "OpenSkirmish", "OpenSaves", "OpenSettings", "OpenEditor", "Quit"]:
			var command := shell.get_node_or_null("%%%s" % command_name) as Button
			if command == null \
					or not command.visible \
					or command.get_global_rect().position.x < -0.5 \
					or command.get_global_rect().position.y < -0.5 \
					or command.get_global_rect().end.x > first_view_rect.end.x + 0.5 \
					or command.get_global_rect().end.y > first_view_rect.end.y + 0.5:
				push_error("Main menu smoke: first-view command %s is not visible and contained at %s: %s / %s." % [command_name, requested_size, command.get_global_rect() if command != null else Rect2(), first_view_rect])
				return false
		if crest_rect.position.x < logo_rect.position.x - 0.5 \
				or crest_rect.position.y < logo_rect.position.y - 0.5 \
				or crest_rect.end.x > logo_rect.end.x + 0.5 \
				or crest_rect.end.y > logo_rect.end.y + 0.5 \
				or crest_rect.size.x < 56.0 \
				or crest_rect.size.y < 52.0 \
				or crest_rect.intersects(title_rect):
			push_error("Main menu smoke: Aurelion Reach crest escaped or overlapped the logo lockup at %s: %s / %s / %s." % [requested_size, logo_rect, crest_rect, title_rect])
			return false
		if editor_rect.position.x < viewport_size.x * 0.82 \
				or editor_rect.end.x > viewport_size.x + 0.5 \
				or editor_rect.position.y < settings_rect.end.y - 0.5 \
				or editor_rect.end.y > quit_rect.position.y + 0.5 \
				or editor_rect.intersects(settings_rect) \
				or editor_rect.intersects(quit_rect):
			push_error("Main menu smoke: Editor utility frame escaped or overlapped the right rail at %s: %s / %s / %s." % [requested_size, settings_rect, editor_rect, quit_rect])
			return false
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := editor_button.get_theme_stylebox(state)
			if not (style is StyleBoxTexture):
				push_error("Main menu smoke: Editor utility %s state is not asset-backed at %s." % [state, requested_size])
				return false
			var texture := (style as StyleBoxTexture).texture
			var expected_path := "res://art/ui/runtime/shared/button_secondary_%s.png" % state
			if texture == null or texture.resource_path != expected_path:
				push_error("Main menu smoke: Editor utility %s state does not use %s at %s." % [state, expected_path, requested_size])
				return false
	SettingsService.call("_set_runtime_window_size", original_size)
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func _main_menu_pocket_summary_exact(summary: Dictionary, viewport_size: Vector2) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var logo_rect: Rect2 = summary.get("logo_rect", Rect2())
	var footer_rect: Rect2 = summary.get("footer_rect", Rect2())
	var checks := {
		"model": String(summary.get("model", "")) == MAIN_MENU_POCKET_FRAME_MODEL,
		"asset_path": String(summary.get("asset_path", "")) == MAIN_MENU_STAGE_DOCK_ASSET_PATH,
		"asset_exists": bool(summary.get("asset_exists", false)),
		"logo_style": String(summary.get("logo_style_class", "")) == "StyleBoxTexture",
		"footer_style": String(summary.get("footer_style_class", "")) == "StyleBoxTexture",
		"logo_texture": String(summary.get("logo_texture_path", "")) == MAIN_MENU_STAGE_DOCK_ASSET_PATH,
		"footer_texture": String(summary.get("footer_texture_path", "")) == MAIN_MENU_STAGE_DOCK_ASSET_PATH,
		"logo_margins": summary.get("logo_texture_margins", Vector4.ZERO) == MAIN_MENU_POCKET_TEXTURE_MARGINS,
		"footer_margins": summary.get("footer_texture_margins", Vector4.ZERO) == MAIN_MENU_POCKET_TEXTURE_MARGINS,
		"logo_modulate": summary.get("logo_modulate", Color.WHITE) == MAIN_MENU_POCKET_TEXTURE_MODULATE,
		"footer_modulate": summary.get("footer_modulate", Color.WHITE) == MAIN_MENU_POCKET_TEXTURE_MODULATE,
		"logo_anchors": (summary.get("logo_anchors", Rect2()) as Rect2).position.distance_to(MAIN_MENU_LOGO_POCKET_ANCHORS.position) <= 0.0001 \
			and (summary.get("logo_anchors", Rect2()) as Rect2).size.distance_to(MAIN_MENU_LOGO_POCKET_ANCHORS.size) <= 0.0001,
		"footer_anchors": (summary.get("footer_anchors", Rect2()) as Rect2).position.distance_to(MAIN_MENU_FOOTER_POCKET_ANCHORS.position) <= 0.0001 \
			and (summary.get("footer_anchors", Rect2()) as Rect2).size.distance_to(MAIN_MENU_FOOTER_POCKET_ANCHORS.size) <= 0.0001,
		"logo_visible": bool(summary.get("logo_visible", false)),
		"footer_visible": bool(summary.get("footer_visible", false)),
		"title": String(summary.get("title_text", "")) == "AURELION REACH",
		"footer_copy_exact": String(summary.get("active_expedition_text", "")) == String(summary.get("active_expedition_tooltip", "")),
		"load_copy": String(summary.get("active_expedition_text", "")).contains("Load: choose a saved expedition."),
		"quit_copy": String(summary.get("active_expedition_text", "")).contains("Quit check: save first automatically, then closes client."),
		"standard_contrast": not bool(summary.get("high_contrast", true)),
		"rendering_mode": String(summary.get("rendering_mode", "")) == "authored_cartography_pockets",
		"high_contrast_fallback": String(summary.get("high_contrast_fallback_class", "")) == "StyleBoxFlat",
		"missing_asset_fallback": String(summary.get("missing_asset_fallback_class", "")) == "StyleBoxFlat",
		"fallbacks_texture_free": bool(summary.get("fallbacks_texture_free", false)),
		"logo_contained": _rect_is_contained(viewport_rect, logo_rect, 1.0),
		"footer_contained": _rect_is_contained(viewport_rect, footer_rect, 1.0),
		"pockets_disjoint": not logo_rect.intersects(footer_rect),
	}
	var failures := []
	for check_name in checks:
		if not bool(checks[check_name]):
			failures.append(check_name)
	if not failures.is_empty():
		push_error("Main menu smoke: failed named cartographic pocket checks: %s." % [failures])
	return failures.is_empty()

func _assert_battle_shake_picker_theme_parity(
		shell: Control,
		ui_scale_picker: OptionButton,
		battle_shake_picker: OptionButton,
		color_cue_picker: OptionButton,
		original_ui_scale: int,
		original_high_contrast: bool
	) -> bool:
	var original_size: Vector2i = get_window().size
	var settings_before: Dictionary = SettingsService.ensure_settings().duplicate(true)
	var ui_scale_before: Dictionary = _option_button_behavior_contract(ui_scale_picker)
	var battle_shake_before: Dictionary = _option_button_behavior_contract(battle_shake_picker)
	var color_cue_before: Dictionary = _option_button_behavior_contract(color_cue_picker)
	var failure := ""
	if original_high_contrast and not bool(shell.call("validation_set_high_contrast", false)):
		failure = "could not establish the standard asset-backed theme"
	for requested_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		if failure != "":
			break
		for requested_scale in [100, 130]:
			if not bool(shell.call("validation_select_ui_scale", requested_scale)):
				failure = "could not select UI scale %d at %s" % [requested_scale, requested_size]
				break
			SettingsService.call("_set_runtime_window_size", requested_size)
			await get_tree().process_frame
			await get_tree().process_frame
			var physical_size: Vector2i = DisplayServer.window_get_size()
			var physical_size_exact: bool = physical_size == requested_size \
				or (DisplayServer.get_name() == "headless" and physical_size == Vector2i.ZERO)
			var expected_shell_size := Vector2(requested_size) * (100.0 / float(requested_scale))
			if not physical_size_exact \
					or get_window().size != requested_size \
					or get_tree().root.size != requested_size \
					or get_tree().root.content_scale_size != requested_size \
					or shell.size.distance_to(expected_shell_size) > 0.1:
				failure = "window/root/canvas authority diverged at %s and %d%%: physical=%s window=%s root=%s content_scale=%s shell=%s expected_shell=%s" % [requested_size, requested_scale, physical_size, get_window().size, get_tree().root.size, get_tree().root.content_scale_size, shell.size, expected_shell_size]
				break
			var expected_style_paths := {
				"normal": "res://art/ui/runtime/shared/button_secondary_normal.png",
				"hover": "res://art/ui/runtime/shared/button_secondary_hover.png",
				"pressed": "res://art/ui/runtime/shared/button_secondary_pressed.png",
				"disabled": "res://art/ui/runtime/shared/button_secondary_disabled.png",
			}
			var ui_scale_style: Dictionary = _option_button_style_contract(ui_scale_picker)
			var battle_shake_style: Dictionary = _option_button_style_contract(battle_shake_picker)
			var color_cue_style: Dictionary = _option_button_style_contract(color_cue_picker)
			if ui_scale_style.is_empty() \
					or battle_shake_style != ui_scale_style \
					or color_cue_style != ui_scale_style \
					or ui_scale_style.get("style_paths", {}) != expected_style_paths \
					or ui_scale_style.get("custom_minimum_size", Vector2.ZERO) != Vector2(176.0, 34.0) \
					or int(ui_scale_style.get("font_size", 0)) != 13 \
					or int(ui_scale_style.get("focus_mode", -1)) != Control.FOCUS_ALL:
				failure = "secondary style contract diverged at %s and %d%%: ui=%s battle=%s color=%s" % [requested_size, requested_scale, ui_scale_style, battle_shake_style, color_cue_style]
				break
			var scale_row := ui_scale_picker.get_parent() as Control
			var assist_row := color_cue_picker.get_parent() as Control
			if scale_row == null \
					or assist_row == null \
					or battle_shake_picker.get_parent() != scale_row \
					or not _rect_is_contained(scale_row.get_global_rect(), ui_scale_picker.get_global_rect()) \
					or not _rect_is_contained(scale_row.get_global_rect(), battle_shake_picker.get_global_rect()) \
					or not _rect_is_contained(assist_row.get_global_rect(), color_cue_picker.get_global_rect()) \
					or ui_scale_picker.get_global_rect().intersects(battle_shake_picker.get_global_rect()):
				failure = "picker row containment or non-overlap failed at %s and %d%%" % [requested_size, requested_scale]
				break
	if SettingsService.ui_scale_percent() != original_ui_scale:
		if not bool(shell.call("validation_select_ui_scale", original_ui_scale)) and failure == "":
			failure = "could not restore the original UI scale"
	if SettingsService.high_contrast_ui_enabled() != original_high_contrast:
		if not bool(shell.call("validation_set_high_contrast", original_high_contrast)) and failure == "":
			failure = "could not restore the original high-contrast setting"
	SettingsService.call("_set_runtime_window_size", original_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if SettingsService.ensure_settings() != settings_before and failure == "":
		failure = "settings authority changed after the width/scale round trip"
	if (
		_option_button_behavior_contract(ui_scale_picker) != ui_scale_before
		or _option_button_behavior_contract(battle_shake_picker) != battle_shake_before
		or _option_button_behavior_contract(color_cue_picker) != color_cue_before
	) and failure == "":
		failure = "picker items, selection, tooltip, focus, or parent authority changed after the round trip"
	if failure != "":
		push_error("Main menu smoke: Battle Shake picker theme parity failed: %s." % failure)
		get_tree().quit(1)
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

func _assert_footer_pocket_containment(shell: Control, viewport_size: Vector2, context: String) -> bool:
	var footer_panel := shell.get_node_or_null("FooterPocketPanel") as PanelContainer
	var footer_title := shell.get_node_or_null("FooterPocketPanel/FooterPocketPad/FooterPocketBox/FooterTitle") as Label
	var footer_body := shell.get_node_or_null("%ActiveExpedition") as Label
	if footer_panel == null or footer_title == null or footer_body == null:
		push_error("Main menu smoke: Frontier Log nodes are missing at %s." % context)
		return false
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var footer_rect := footer_panel.get_global_rect()
	var title_rect := footer_title.get_global_rect()
	var body_rect := footer_body.get_global_rect()
	var body_lines := footer_body.text.split("\n", false)
	var tooltip_lines := footer_body.tooltip_text.split("\n", false)
	if not footer_panel.is_visible_in_tree() \
			or footer_panel.grow_vertical != Control.GROW_DIRECTION_BEGIN \
			or not is_equal_approx(footer_panel.anchor_left, 0.032) \
			or not is_equal_approx(footer_panel.anchor_top, 0.895) \
			or not is_equal_approx(footer_panel.anchor_right, 0.372) \
			or not is_equal_approx(footer_panel.anchor_bottom, 0.975) \
			or footer_rect.size.y + 0.5 < footer_panel.get_combined_minimum_size().y \
			or body_rect.size.y + 0.5 < footer_body.get_combined_minimum_size().y \
			or not _rect_is_contained(viewport_rect, footer_rect) \
			or not _rect_is_contained(footer_rect, title_rect) \
			or not _rect_is_contained(footer_rect, body_rect) \
			or footer_title.text != "Frontier Log" \
			or body_lines != tooltip_lines \
			or body_lines.size() < 3 \
			or not footer_body.text.contains("Load: choose a saved expedition.") \
			or not footer_body.text.contains("Quit check: save first automatically, then closes client."):
		push_error("Main menu smoke: Frontier Log is clipped or changed at %s: viewport=%s footer=%s title=%s body=%s min=%s text=%s tooltip=%s." % [context, viewport_rect, footer_rect, title_rect, body_rect, footer_panel.get_combined_minimum_size(), footer_body.text, footer_body.tooltip_text])
		return false
	return true

func _rect_is_contained(outer: Rect2, inner: Rect2, tolerance: float = 0.5) -> bool:
	return inner.position.x >= outer.position.x - tolerance \
		and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance \
		and inner.end.y <= outer.end.y + tolerance

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

func _shared_tab_plaque_standard_exact(tabs: TabContainer, expected_titles: Array) -> bool:
	var current_tab_before := tabs.current_tab
	var tab_bar := tabs.get_tab_bar()
	if tab_bar == null or tabs.get_tab_count() != expected_titles.size():
		return false
	var titles: Array[String] = []
	var prior_rect := Rect2()
	for index in range(tabs.get_tab_count()):
		titles.append(tabs.get_tab_title(index))
		var tab_rect: Rect2 = tab_bar.get_tab_rect(index)
		if tab_rect.size.x <= 0.0 \
				or tab_rect.size.y <= 0.0 \
				or tab_rect.position.x < -0.5 \
				or tab_rect.position.y < -0.5 \
				or tab_rect.end.x > tab_bar.size.x + 0.5 \
				or tab_rect.end.y > tab_bar.size.y + 0.5 \
				or (index > 0 and prior_rect.end.x > tab_rect.position.x + 0.5):
			return false
		prior_rect = tab_rect
	var expected_paths := {
		"tab_selected": "res://art/ui/runtime/shared/button_primary_pressed.png",
		"tab_hovered": "res://art/ui/runtime/shared/button_secondary_hover.png",
		"tab_unselected": "res://art/ui/runtime/shared/button_secondary_normal.png",
		"tab_disabled": "res://art/ui/runtime/shared/button_secondary_disabled.png",
	}
	for style_name_value in expected_paths:
		var style_name := String(style_name_value)
		var style := tabs.get_theme_stylebox(style_name)
		if not (style is StyleBoxTexture):
			return false
		var texture_style := style as StyleBoxTexture
		var texture := texture_style.texture
		if texture == null \
				or texture.resource_path != String(expected_paths[style_name]) \
				or not is_equal_approx(texture_style.texture_margin_left, 6.0) \
				or not is_equal_approx(texture_style.texture_margin_top, 6.0) \
				or not is_equal_approx(texture_style.texture_margin_right, 6.0) \
				or not is_equal_approx(texture_style.texture_margin_bottom, 6.0) \
				or not is_equal_approx(texture_style.content_margin_left, 1.0) \
				or not is_equal_approx(texture_style.content_margin_top, 2.0) \
				or not is_equal_approx(texture_style.content_margin_right, 1.0) \
				or not is_equal_approx(texture_style.content_margin_bottom, 2.0):
			return false
		if style_name == "tab_disabled" and not texture_style.modulate_color.is_equal_approx(Color(0.72, 0.72, 0.72, 0.76)):
			return false
	var focus := tabs.get_theme_stylebox("tab_focus")
	if not (focus is StyleBoxFlat):
		return false
	var focus_flat := focus as StyleBoxFlat
	return titles == expected_titles \
		and tabs.current_tab == current_tab_before \
		and focus_flat.bg_color.a <= 0.001 \
		and focus_flat.border_color.is_equal_approx(Color(0.97, 0.88, 0.61, 1.0)) \
		and focus_flat.border_width_left == 2 \
		and focus_flat.border_width_top == 2 \
		and focus_flat.border_width_right == 2 \
		and focus_flat.border_width_bottom == 2 \
		and focus_flat.corner_radius_top_left == 6 \
		and focus_flat.corner_radius_top_right == 6 \
		and focus_flat.corner_radius_bottom_left == 6 \
		and focus_flat.corner_radius_bottom_right == 6

func _shared_tab_plaque_high_contrast_exact(tabs: TabContainer) -> bool:
	var current_tab_before := tabs.current_tab
	for style_name in ["tab_selected", "tab_hovered", "tab_unselected", "tab_disabled"]:
		var style := tabs.get_theme_stylebox(style_name)
		if not (style is StyleBoxFlat):
			return false
		var flat := style as StyleBoxFlat
		if flat.bg_color.get_luminance() > 0.08 \
				or flat.border_color.get_luminance() < 0.70 \
				or flat.border_width_left != 2 \
				or flat.border_width_top != 2 \
				or flat.border_width_right != 2 \
				or flat.border_width_bottom != 2 \
				or flat.corner_radius_top_left != 6 \
				or not is_equal_approx(flat.content_margin_left, 1.0) \
				or not is_equal_approx(flat.content_margin_top, 2.0) \
				or not is_equal_approx(flat.content_margin_right, 1.0) \
				or not is_equal_approx(flat.content_margin_bottom, 2.0):
			return false
	var focus := tabs.get_theme_stylebox("tab_focus")
	if not (focus is StyleBoxFlat):
		return false
	var focus_flat := focus as StyleBoxFlat
	return tabs.current_tab == current_tab_before \
		and focus_flat.bg_color.a <= 0.001 \
		and focus_flat.border_color.is_equal_approx(Color(1.0, 0.91, 0.32, 1.0)) \
		and focus_flat.border_width_left == 2 \
		and focus_flat.border_width_top == 2 \
		and focus_flat.border_width_right == 2 \
		and focus_flat.border_width_bottom == 2 \
		and focus_flat.corner_radius_top_left == 6


func _assert_outcome_scenic_epilogue_contract(shell: Control, session) -> bool:
	if not shell.has_method("validation_scenic_epilogue_summary"):
		push_error("Outcome smoke: shell does not expose scenic epilogue validation.")
		get_tree().quit(1)
		return false
	var authority_before: Dictionary = session.to_dict()
	var recap_tabs := shell.get_node_or_null("%RecapTabs") as TabContainer
	if recap_tabs == null or not _shared_tab_plaque_standard_exact(recap_tabs, ["Progress", "Arc", "Carry", "After", "Journal"]):
		push_error("Outcome smoke: recap tabs did not retain exact compact shared plaques, titles, order, current page, and fit.")
		get_tree().quit(1)
		return false
	var live_banner = shell.get_node_or_null("%OutcomeBanner")
	if live_banner == null or not live_banner.has_method("validation_summary"):
		push_error("Outcome smoke: live result banner does not expose authored-emblem validation.")
		get_tree().quit(1)
		return false
	var live_emblem_summary: Dictionary = live_banner.call("validation_summary")
	if not _outcome_status_emblem_geometry_exact(live_emblem_summary, "victory"):
		push_error("Outcome smoke: live victory result emblem contract failed: %s." % live_emblem_summary)
		get_tree().quit(1)
		return false
	var fresh_live_emblem_summary := live_emblem_summary.duplicate(true)
	live_emblem_summary["destination_rect"] = Rect2()
	if session.to_dict() != authority_before or live_banner.call("validation_summary") != fresh_live_emblem_summary:
		push_error("Outcome smoke: detached result-emblem validation changed live session or banner authority.")
		get_tree().quit(1)
		return false
	var live_summary: Dictionary = shell.call("validation_scenic_epilogue_summary")
	if (
		String(live_summary.get("status", "")) != "victory"
		or String(live_summary.get("expected_path", "")) != String(OUTCOME_SCENIC_BACKDROP_PATHS["victory"])
		or not _outcome_scenic_geometry_exact(live_summary)
		or bool(live_summary.get("actions_panel_vertical_expand", true))
		or not bool(live_summary.get("scenic_window_positive", false))
		or not bool(live_summary.get("content_above_backdrop", false))
		or live_summary.get("draw_order", []) != ["scenic_backdrop", "scenic_veil", "outcome_content"]
		or not _outcome_panel_alphas_exact(live_summary.get("panel_alphas", {}), OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME)
		or live_summary.get("panel_alpha_contract", {}) != OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME
		or not _outcome_compact_ribbon_contract_exact(live_summary)
	):
		push_error("Outcome smoke: live victory scenic epilogue contract failed: %s." % live_summary)
		get_tree().quit(1)
		return false
	var viewport_size: Vector2 = live_summary.get("viewport_size", Vector2.ZERO)
	var scenic_window: Rect2 = live_summary.get("scenic_window_rect", Rect2())
	var action_rect: Rect2 = live_summary.get("actions_panel_rect", Rect2())
	if (
		viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
		or scenic_window.size.y < viewport_size.y * 0.38
		or float(live_summary.get("scenic_window_area_fraction", 0.0)) < 0.31
		or float(live_summary.get("content_overlay_bottom_fraction", 1.0)) > 0.61
		or action_rect.end.y > viewport_size.y * 0.61
	):
		push_error("Outcome smoke: compact action dock did not preserve the dominant scenic stage: %s." % live_summary)
		get_tree().quit(1)
		return false

	var fixture = OutcomeScenicBackdropViewScript.new()
	add_child(fixture)
	await get_tree().process_frame
	for stage_size in OUTCOME_SCENIC_STAGE_SIZES:
		fixture.size = stage_size
		for status in OUTCOME_SCENIC_BACKDROP_PATHS:
			fixture.set_outcome(String(status))
			var summary: Dictionary = fixture.validation_summary()
			if (
				String(summary.get("status", "")) != String(status)
				or String(summary.get("expected_path", "")) != String(OUTCOME_SCENIC_BACKDROP_PATHS[status])
				or String(summary.get("texture_path", "")) != String(OUTCOME_SCENIC_BACKDROP_PATHS[status])
				or not _outcome_scenic_geometry_exact(summary)
			):
				push_error("Outcome smoke: %s scenic epilogue contract failed at %s: %s." % [status, stage_size, summary])
				fixture.queue_free()
				get_tree().quit(1)
				return false
	fixture.set_outcome("unmapped_outcome")
	var fallback_summary: Dictionary = fixture.validation_summary()
	if (
		bool(fallback_summary.get("texture_loaded", true))
		or not bool(fallback_summary.get("fallback", false))
		or String(fallback_summary.get("rendering_mode", "")) != "flat_palette_fallback"
		or String(fallback_summary.get("expected_path", "")) != ""
	):
		push_error("Outcome smoke: unmapped status did not retain the flat palette fallback: %s." % fallback_summary)
		fixture.queue_free()
		get_tree().quit(1)
		return false
	fixture.queue_free()
	await get_tree().process_frame

	var emblem_fixture = OutcomeBannerViewScript.new()
	add_child(emblem_fixture)
	await get_tree().process_frame
	var compact_initial: Dictionary = {}
	for stage_size in OUTCOME_STATUS_EMBLEM_STAGE_SIZES:
		emblem_fixture.size = stage_size
		for status in OUTCOME_STATUS_EMBLEM_PATHS:
			emblem_fixture.set_outcome(String(status))
			var summary: Dictionary = emblem_fixture.validation_summary()
			if not _outcome_status_emblem_geometry_exact(summary, String(status)):
				push_error("Outcome smoke: %s authored status emblem contract failed at %s: %s." % [status, stage_size, summary])
				emblem_fixture.queue_free()
				get_tree().quit(1)
				return false
			if not _outcome_status_emblem_alpha_exact(String(OUTCOME_STATUS_EMBLEM_PATHS[status])):
				push_error("Outcome smoke: %s authored status emblem lost transparent-corner authority." % status)
				emblem_fixture.queue_free()
				get_tree().quit(1)
				return false
			if stage_size == OUTCOME_STATUS_EMBLEM_STAGE_SIZES[0] and String(status) == "victory":
				compact_initial = summary.duplicate(true)
	emblem_fixture.size = OUTCOME_STATUS_EMBLEM_STAGE_SIZES[0]
	emblem_fixture.set_outcome("victory")
	if emblem_fixture.validation_summary() != compact_initial:
		push_error("Outcome smoke: authored status emblem did not restore exact compact geometry after the wide layout.")
		emblem_fixture.queue_free()
		get_tree().quit(1)
		return false
	emblem_fixture.set_outcome("unmapped_outcome")
	var emblem_fallback: Dictionary = emblem_fixture.validation_summary()
	if (
		bool(emblem_fallback.get("texture_loaded", true))
		or not bool(emblem_fallback.get("fallback", false))
		or String(emblem_fallback.get("rendering_mode", "")) != "procedural_status_fallback"
		or String(emblem_fallback.get("expected_path", "")) != ""
	):
		push_error("Outcome smoke: unmapped result status did not retain the procedural banner fallback: %s." % emblem_fallback)
		emblem_fixture.queue_free()
		get_tree().quit(1)
		return false
	emblem_fixture.queue_free()
	await get_tree().process_frame
	if FileAccess.get_file_as_bytes(OUTCOME_STATUS_EMBLEM_PATHS["victory"]) == FileAccess.get_file_as_bytes(OUTCOME_STATUS_EMBLEM_PATHS["defeat"]):
		push_error("Outcome smoke: victory and defeat authored status emblems are not byte-distinct.")
		get_tree().quit(1)
		return false
	if session.to_dict() != authority_before:
		push_error("Outcome smoke: scenic epilogue or authored status-emblem selection changed live session authority.")
		get_tree().quit(1)
		return false
	return true


func _outcome_panel_alphas_exact(actual_value, expected: Dictionary) -> bool:
	if not (actual_value is Dictionary):
		return false
	var actual: Dictionary = actual_value
	if actual.keys() != expected.keys():
		return false
	for panel_name in expected:
		if not actual.has(panel_name) or not is_equal_approx(float(actual[panel_name]), float(expected[panel_name])):
			return false
	return true


func _outcome_compact_ribbon_contract_exact(summary: Dictionary) -> bool:
	var viewport_size: Vector2 = summary.get("viewport_size", Vector2.ZERO)
	var compact := viewport_size.x < 1360.0 or viewport_size.y < 760.0
	var expected_banner_width := 260.0 if compact else 300.0
	var expected_emblem_height := 104.0 if compact else 176.0
	var action_status_tooltip := String(summary.get("action_status_tooltip", ""))
	var actions_hint_tooltip := String(summary.get("actions_hint_tooltip", ""))
	return (
		String(summary.get("presentation_model", "")) == "scenery_first_compact_command_ribbons"
		and is_equal_approx(float(summary.get("banner_art_width", 0.0)), expected_banner_width)
		and is_equal_approx(float(summary.get("emblem_height", 0.0)), expected_emblem_height)
		and int(summary.get("action_status_visible_line_count", 0)) == 1
		and int(summary.get("actions_hint_visible_line_count", 0)) == 1
		and action_status_tooltip.contains("Next step:")
		and action_status_tooltip.contains("Follow-up check:")
		and action_status_tooltip.contains("Retry check:")
		and actions_hint_tooltip.contains("Action cue:")
		and actions_hint_tooltip.contains("Outcome Follow-up Check")
		and actions_hint_tooltip.contains("Outcome Retry Check")
	)


func _outcome_scenic_geometry_exact(summary: Dictionary) -> bool:
	var texture_size: Vector2 = summary.get("texture_size", Vector2.ZERO)
	var destination_rect: Rect2 = summary.get("destination_rect", Rect2())
	var source_rect: Rect2 = summary.get("source_rect", Rect2())
	return (
		bool(summary.get("texture_loaded", false))
		and String(summary.get("rendering_mode", "")) == "cover_crop_scenic_epilogue"
		and bool(summary.get("cover_crop", false))
		and not bool(summary.get("stretched", true))
		and not bool(summary.get("fallback", true))
		and bool(summary.get("mouse_filter_ignore", false))
		and bool(summary.get("source_contained", false))
		and bool(summary.get("destination_contained", false))
		and texture_size == Vector2(1600.0, 900.0)
		and destination_rect.position == Vector2.ZERO
		and destination_rect.size.x > 0.0
		and destination_rect.size.y > 0.0
		and source_rect.size.x > 0.0
		and source_rect.size.y > 0.0
		and is_equal_approx(source_rect.size.x / source_rect.size.y, destination_rect.size.x / destination_rect.size.y)
	)


func _outcome_status_emblem_geometry_exact(summary: Dictionary, status: String) -> bool:
	var destination_rect: Rect2 = summary.get("destination_rect", Rect2()) if summary.get("destination_rect", Rect2()) is Rect2 else Rect2()
	var texture_size: Vector2 = summary.get("texture_size", Vector2.ZERO) if summary.get("texture_size", Vector2.ZERO) is Vector2 else Vector2.ZERO
	return (
		String(summary.get("status", "")) == status
		and String(summary.get("expected_path", "")) == String(OUTCOME_STATUS_EMBLEM_PATHS[status])
		and String(summary.get("texture_path", "")) == String(OUTCOME_STATUS_EMBLEM_PATHS[status])
		and bool(summary.get("texture_loaded", false))
		and texture_size == Vector2(1024.0, 896.0)
		and destination_rect.size.x > 0.0
		and destination_rect.size.y > 0.0
		and String(summary.get("rendering_mode", "")) == "contained_authored_status_emblem"
		and bool(summary.get("aspect_preserved", false))
		and bool(summary.get("destination_contained", false))
		and bool(summary.get("centered", false))
		and is_equal_approx(float(summary.get("inset", 0.0)), 8.0)
		and not bool(summary.get("fallback", true))
	)


func _outcome_status_emblem_alpha_exact(path: String) -> bool:
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK \
			or image.is_empty() \
			or image.get_width() != 1024 \
			or image.get_height() != 896:
		return false
	return (
		is_zero_approx(image.get_pixel(0, 0).a)
		and is_zero_approx(image.get_pixel(image.get_width() - 1, 0).a)
		and is_zero_approx(image.get_pixel(0, image.get_height() - 1).a)
		and is_zero_approx(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
	)

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
	if not await _assert_outcome_scenic_epilogue_contract(shell, session):
		return false
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
