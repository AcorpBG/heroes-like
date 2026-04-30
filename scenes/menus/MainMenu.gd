extends Control

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

const TAB_CAMPAIGN := 0
const TAB_SKIRMISH := 1
const TAB_SAVES := 2
const TAB_GUIDE := 3
const TAB_SETTINGS := 4
const TAB_STAGE_COPY := {
	TAB_CAMPAIGN: {
		"title": "Campaign board",
		"hint": "Inspect arcs, chapters, and the next campaign push from this summoned board.",
	},
	TAB_SKIRMISH: {
		"title": "Skirmish charter",
		"hint": "Review a single-front plan, set difficulty, and launch a fresh expedition.",
	},
	TAB_SAVES: {
		"title": "War ledger",
		"hint": "Manual slots and autosave stay in this compact load board.",
	},
	TAB_GUIDE: {
		"title": "Field manual",
		"hint": "Open help pages in a reference tray only when the player asks for them.",
	},
	TAB_SETTINGS: {
		"title": "Cabinet",
		"hint": "Presentation, sound, and readability controls live in a secondary board.",
	},
}
const TAB_HELP_TOPIC := {
	TAB_CAMPAIGN: "campaign",
	TAB_SKIRMISH: "skirmish",
	TAB_SAVES: "saves",
	TAB_SETTINGS: "saves",
}

@onready var _menu_tabs: TabContainer = %MenuTabs
@onready var _stage_dock_panel: PanelContainer = $StageDockPanel
@onready var _stage_dock_title_label: Label = %ActionLead
@onready var _stage_dock_hint_label: Label = %ActionHint
@onready var _stage_help_button: Button = %StageHelp
@onready var _close_stage_dock_button: Button = %CloseStageDock
@onready var _eyebrow_label: Label = %Eyebrow
@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _summary_label: Label = %Summary
@onready var _active_expedition_label: Label = %ActiveExpedition
@onready var _quit_button: Button = %Quit
@onready var _open_campaign_button: Button = %OpenCampaign
@onready var _open_skirmish_button: Button = %OpenSkirmish
@onready var _open_saves_button: Button = %OpenSaves
@onready var _open_settings_button: Button = %OpenSettings
@onready var _open_editor_button: Button = %OpenEditor
@onready var _campaign_list: ItemList = %CampaignList
@onready var _campaign_details_label: Label = %CampaignDetails
@onready var _campaign_arc_status_label: Label = %CampaignArcStatus
@onready var _chapter_list: ItemList = %ChapterList
@onready var _chapter_details_label: Label = %ChapterDetails
@onready var _campaign_commander_preview_label: Label = %CampaignCommanderPreview
@onready var _campaign_operational_board_label: Label = %CampaignOperationalBoard
@onready var _campaign_journal_label: Label = %CampaignJournal
@onready var _campaign_primary_button: Button = %CampaignPrimaryAction
@onready var _start_chapter_button: Button = %StartChapter
@onready var _skirmish_list: ItemList = %SkirmishList
@onready var _skirmish_details_label: Label = %SkirmishDetails
@onready var _difficulty_picker: OptionButton = %DifficultyPicker
@onready var _difficulty_summary_label: Label = %DifficultySummary
@onready var _setup_summary_label: Label = %SetupSummary
@onready var _generated_seed_edit: LineEdit = %GeneratedSeed
@onready var _generated_size_picker: OptionButton = %GeneratedSizePicker
@onready var _generated_template_picker: OptionButton = %GeneratedTemplatePicker
@onready var _generated_profile_picker: OptionButton = %GeneratedProfilePicker
@onready var _generated_player_count_picker: OptionButton = %GeneratedPlayerCountPicker
@onready var _generated_water_picker: OptionButton = %GeneratedWaterPicker
@onready var _generated_underground_toggle: CheckButton = %GeneratedUndergroundToggle
@onready var _generated_status_label: Label = %GeneratedMapStatus
@onready var _generated_progress_bar: ProgressBar = %GeneratedMapProgress
@onready var _generated_provenance_label: Label = %GeneratedMapProvenance
@onready var _start_generated_skirmish_button: Button = %StartGeneratedSkirmish
@onready var _skirmish_commander_preview_label: Label = %SkirmishCommanderPreview
@onready var _skirmish_operational_board_label: Label = %SkirmishOperationalBoard
@onready var _start_skirmish_button: Button = %StartSkirmish
@onready var _help_intro_label: Label = %HelpIntro
@onready var _help_list: ItemList = %HelpList
@onready var _help_details_label: Label = %HelpDetails
@onready var _settings_summary_label: Label = %SettingsSummary
@onready var _settings_handoff_label: Label = %SettingsHandoff
@onready var _presentation_mode_picker: OptionButton = %PresentationModePicker
@onready var _resolution_picker: OptionButton = %ResolutionPicker
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _master_volume_value: Label = %MasterVolumeValue
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _music_volume_value: Label = %MusicVolumeValue
@onready var _large_text_toggle: CheckButton = %LargeTextToggle
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _save_list: ItemList = %SaveList
@onready var _save_details_label: Label = %SaveDetails
@onready var _load_selected_button: Button = %LoadSelected

var _save_summaries: Array = []
var _selected_save_key := ""
var _save_browser_loaded := false
var _campaign_entries: Array = []
var _selected_campaign_id := ""
var _campaign_chapter_entries: Array = []
var _selected_campaign_scenario_id := ""
var _skirmish_entries: Array = []
var _selected_skirmish_id := ""
var _selected_difficulty: String = ScenarioSelectRulesScript.default_difficulty_id()
var _generated_seed := ""
var _generated_size_class_id := ""
var _generated_template_id := ""
var _generated_profile_id := ""
var _generated_player_count := 3
var _generated_water_mode := "land"
var _generated_underground := false
var _generated_last_setup := {}
var _generated_generation_in_progress := false
var _generated_generation_yield_count := 0
var _generated_generation_stage := {}
var _generated_generation_snapshots := []
var _help_entries: Array = []
var _selected_help_topic_id := ""
var _last_context_tab := TAB_CAMPAIGN
var _syncing_settings_ui := false
var _menu_notice := ""

func _ready() -> void:
	CampaignProgression.ensure_profile()
	SettingsService.ensure_settings()
	_apply_visual_theme()
	_select_menu_tab(TAB_CAMPAIGN)
	_hide_stage_dock()
	_refresh_menu()

func _refresh_menu() -> void:
	_menu_notice = AppRouter.consume_menu_notice()
	if _stage_dock_panel.visible and _menu_tabs.current_tab == TAB_SAVES:
		_rebuild_save_browser()
	else:
		_reset_save_browser_placeholder()
	_rebuild_campaign_browser()
	_configure_difficulty_picker()
	_configure_generated_random_map_controls()
	_rebuild_skirmish_browser()
	_refresh_skirmish_setup()
	_refresh_generated_random_map_setup()
	_rebuild_help_browser()
	_refresh_settings_panel()
	_refresh_stage_dock_header()
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()
	_sync_first_view_command_tooltips()

func _latest_continue_surface() -> Dictionary:
	var latest_summary := _active_save_board_latest_summary()
	if latest_summary.is_empty():
		return {
			"text": "Continue Latest",
			"enabled": false,
			"tooltip": "Open Load to inspect saved expeditions. Continue Latest resolves save metadata only when a resume action is chosen.",
		}
	return {
		"text": SaveService.continue_action_label(latest_summary),
		"enabled": SaveService.can_load_summary(latest_summary),
		"tooltip": SaveService.load_action_tooltip(latest_summary),
	}

func _refresh_summary() -> void:
	var lead := _menu_notice
	_summary_label.visible = lead != ""
	_set_compact_label(_summary_label, lead, 3, 84)
	_set_compact_label(
		_active_expedition_label,
		_build_footer_expedition_summary(),
		5,
		84
	)

func _on_campaign_selected(index: int) -> void:
	if index < 0 or index >= _campaign_entries.size():
		return
	_selected_campaign_id = String(_campaign_entries[index].get("campaign_id", ""))
	_selected_campaign_scenario_id = ""
	CampaignProgression.select_campaign(_selected_campaign_id)
	_rebuild_campaign_chapter_browser()
	_refresh_campaign_browser()

func _on_chapter_selected(index: int) -> void:
	if index < 0 or index >= _campaign_chapter_entries.size():
		return
	_selected_campaign_scenario_id = String(_campaign_chapter_entries[index].get("scenario_id", ""))
	CampaignProgression.select_scenario(_selected_campaign_id, _selected_campaign_scenario_id)
	_refresh_campaign_browser()

func _on_campaign_primary_pressed() -> void:
	_launch_campaign_action(CampaignProgression.primary_campaign_action(_selected_campaign_id))

func _on_start_chapter_pressed() -> void:
	_launch_campaign_action(CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id))

func _launch_campaign_action(action: Dictionary) -> void:
	if bool(action.get("disabled", false)):
		return
	var scenario_id := String(action.get("scenario_id", ""))
	var campaign_id := String(action.get("campaign_id", _selected_campaign_id))
	var session := CampaignProgression.start_scenario(
		scenario_id,
		ScenarioSelectRulesScript.default_difficulty_id(),
		campaign_id
	)
	if session.scenario_id == "":
		_refresh_menu()
		return
	_refresh_menu()
	AppRouter.go_to_overworld()

func _on_continue_pressed() -> void:
	if not AppRouter.resume_latest_session():
		_refresh_menu()

func _on_open_campaign_pressed() -> void:
	_toggle_stage_dock(TAB_CAMPAIGN)

func _on_open_skirmish_pressed() -> void:
	_toggle_stage_dock(TAB_SKIRMISH)

func _on_open_saves_pressed() -> void:
	_toggle_stage_dock(TAB_SAVES)
	if _stage_dock_panel.visible and _menu_tabs.current_tab == TAB_SAVES:
		_ensure_save_browser_loaded()

func _on_open_guide_pressed() -> void:
	_select_help_topic(SettingsService.default_help_topic_id())
	_toggle_stage_dock(TAB_GUIDE)

func _on_open_settings_pressed() -> void:
	_toggle_stage_dock(TAB_SETTINGS)

func _on_stage_help_pressed() -> void:
	if _menu_tabs.current_tab == TAB_GUIDE:
		_select_menu_tab(_last_context_tab)
		_show_stage_dock()
		return
	_last_context_tab = _menu_tabs.current_tab
	_select_help_topic(_help_topic_for_tab(_menu_tabs.current_tab))
	_select_menu_tab(TAB_GUIDE)
	_show_stage_dock()

func _on_open_editor_pressed() -> void:
	AppRouter.go_to_map_editor()

func _on_close_stage_dock_pressed() -> void:
	_hide_stage_dock()

func _on_menu_pressed() -> void:
	_hide_stage_dock()

func _on_save_selected(index: int) -> void:
	if index < 0 or index >= _save_summaries.size():
		return
	_selected_save_key = _summary_key(_save_summaries[index])
	_refresh_selected_save()

func _on_load_selected_pressed() -> void:
	if not AppRouter.resume_summary(_selected_summary()):
		_refresh_menu()

func _on_skirmish_selected(index: int) -> void:
	if index < 0 or index >= _skirmish_entries.size():
		return
	_selected_skirmish_id = String(_skirmish_entries[index].get("scenario_id", ""))
	_refresh_skirmish_setup()

func _on_difficulty_selected(index: int) -> void:
	if index < 0 or index >= _difficulty_picker.get_item_count():
		return
	var metadata = _difficulty_picker.get_item_metadata(index)
	_selected_difficulty = ScenarioSelectRulesScript.normalize_difficulty(metadata)
	_refresh_skirmish_setup()
	_refresh_generated_random_map_setup()

func _on_start_skirmish_pressed() -> void:
	if _start_skirmish_button.disabled:
		return
	var session := ScenarioSelectRulesScript.start_skirmish_session(_selected_skirmish_id, _selected_difficulty)
	if session.scenario_id == "":
		_refresh_menu()
		return
	_refresh_menu()
	AppRouter.go_to_overworld()

func _on_generated_seed_changed(new_text: String) -> void:
	_generated_seed = new_text.strip_edges()
	_refresh_generated_random_map_setup()

func _on_generated_size_selected(index: int) -> void:
	if index < 0 or index >= _generated_size_picker.get_item_count():
		return
	_generated_size_class_id = String(_generated_size_picker.get_item_metadata(index))
	var size_defaults := ScenarioSelectRulesScript.random_map_size_class_default(_generated_size_class_id)
	_generated_template_id = String(size_defaults.get("template_id", _generated_template_id))
	_generated_profile_id = String(size_defaults.get("profile_id", _generated_profile_id))
	_generated_player_count = int(size_defaults.get("player_count", _generated_player_count))
	_select_generated_picker_metadata(_generated_template_picker, _generated_template_id)
	_select_generated_picker_metadata(_generated_profile_picker, _generated_profile_id)
	_clamp_generated_player_count_to_template()
	_rebuild_generated_player_count_picker()
	_select_generated_player_count_picker(_generated_player_count)
	_refresh_generated_random_map_setup()

func _on_generated_template_selected(index: int) -> void:
	if index < 0 or index >= _generated_template_picker.get_item_count():
		return
	_generated_template_id = String(_generated_template_picker.get_item_metadata(index))
	for option in ScenarioSelectRulesScript.random_map_player_setup_options().get("templates", []):
		if option is Dictionary and String(option.get("id", "")) == _generated_template_id:
			_generated_profile_id = String(option.get("profile_id", _generated_profile_id))
			_select_generated_picker_metadata(_generated_profile_picker, _generated_profile_id)
			break
	_clamp_generated_player_count_to_template()
	_rebuild_generated_player_count_picker()
	_select_generated_player_count_picker(_generated_player_count)
	_refresh_generated_random_map_setup()

func _on_generated_profile_selected(index: int) -> void:
	if index < 0 or index >= _generated_profile_picker.get_item_count():
		return
	_generated_profile_id = String(_generated_profile_picker.get_item_metadata(index))
	_refresh_generated_random_map_setup()

func _on_generated_player_count_selected(index: int) -> void:
	if index < 0 or index >= _generated_player_count_picker.get_item_count():
		return
	_generated_player_count = int(_generated_player_count_picker.get_item_metadata(index))
	_refresh_generated_random_map_setup()

func _on_generated_water_selected(index: int) -> void:
	if index < 0 or index >= _generated_water_picker.get_item_count():
		return
	_generated_water_mode = String(_generated_water_picker.get_item_metadata(index))
	if _generated_water_mode == "islands" and _generated_underground:
		_generated_underground = false
		_generated_underground_toggle.button_pressed = false
	_refresh_generated_random_map_setup()

func _on_generated_underground_toggled(enabled: bool) -> void:
	_generated_underground = enabled
	if _generated_underground and _generated_water_mode == "islands":
		_generated_water_mode = "land"
		_select_generated_picker_metadata(_generated_water_picker, _generated_water_mode)
	_refresh_generated_random_map_setup()

func _on_start_generated_skirmish_pressed() -> void:
	await _start_generated_skirmish_staged(true)

func _on_help_selected(index: int) -> void:
	if index < 0 or index >= _help_entries.size():
		return
	_selected_help_topic_id = String(_help_entries[index].get("id", ""))
	_refresh_help_browser()

func _on_presentation_mode_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _presentation_mode_picker.get_item_count():
		return
	var mode_id := String(_presentation_mode_picker.get_item_metadata(index))
	SettingsService.set_presentation_mode(mode_id)
	_refresh_settings_panel()

func _on_resolution_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _resolution_picker.get_item_count():
		return
	var resolution_id := String(_resolution_picker.get_item_metadata(index))
	SettingsService.set_presentation_resolution(resolution_id)
	_refresh_settings_panel()

func _on_master_volume_changed(value: float) -> void:
	if _syncing_settings_ui:
		return
	SettingsService.set_master_volume_percent(int(round(value)))
	_refresh_settings_panel()

func _on_music_volume_changed(value: float) -> void:
	if _syncing_settings_ui:
		return
	SettingsService.set_music_volume_percent(int(round(value)))
	_refresh_settings_panel()

func _on_large_text_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	SettingsService.set_large_ui_text_enabled(enabled)
	_refresh_settings_panel()

func _on_reduce_motion_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	SettingsService.set_reduced_motion_enabled(enabled)
	_refresh_settings_panel()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _rebuild_campaign_browser() -> void:
	_campaign_entries = CampaignProgression.campaign_browser_entries()
	_campaign_list.clear()

	var preferred_campaign_id := _selected_campaign_id
	if preferred_campaign_id == "":
		preferred_campaign_id = CampaignProgression.selected_campaign_id()

	var selected_index := -1
	for index in range(_campaign_entries.size()):
		var entry = _campaign_entries[index]
		_campaign_list.add_item(String(entry.get("label", entry.get("campaign_id", "Campaign"))))
		if String(entry.get("campaign_id", "")) == preferred_campaign_id:
			selected_index = index

	if selected_index < 0 and not _campaign_entries.is_empty():
		selected_index = 0

	if selected_index >= 0 and selected_index < _campaign_entries.size():
		_campaign_list.select(selected_index)
		_selected_campaign_id = String(_campaign_entries[selected_index].get("campaign_id", ""))
	else:
		_selected_campaign_id = ""

	_rebuild_campaign_chapter_browser()
	_refresh_campaign_browser()

func _rebuild_campaign_chapter_browser() -> void:
	_campaign_chapter_entries = CampaignProgression.campaign_chapter_entries(_selected_campaign_id)
	_chapter_list.clear()

	var preferred_scenario_id := _selected_campaign_scenario_id
	if preferred_scenario_id == "":
		preferred_scenario_id = CampaignProgression.selected_scenario_id(_selected_campaign_id)

	var selected_index := -1
	for index in range(_campaign_chapter_entries.size()):
		var entry = _campaign_chapter_entries[index]
		_chapter_list.add_item(String(entry.get("label", entry.get("scenario_id", "Chapter"))))
		if String(entry.get("scenario_id", "")) == preferred_scenario_id:
			selected_index = index

	if selected_index < 0:
		var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
		var primary_scenario_id := String(primary_action.get("scenario_id", ""))
		for index in range(_campaign_chapter_entries.size()):
			if String(_campaign_chapter_entries[index].get("scenario_id", "")) == primary_scenario_id:
				selected_index = index
				break

	if selected_index < 0 and not _campaign_chapter_entries.is_empty():
		selected_index = 0

	if selected_index >= 0 and selected_index < _campaign_chapter_entries.size():
		_chapter_list.select(selected_index)
		_selected_campaign_scenario_id = String(_campaign_chapter_entries[selected_index].get("scenario_id", ""))
	else:
		_selected_campaign_scenario_id = ""

func _refresh_campaign_browser() -> void:
	if _campaign_entries.is_empty():
		_set_compact_label(_campaign_details_label, "No campaign arcs are authored.", 2, 82)
		_set_compact_label(_campaign_arc_status_label, "Arc status appears here.", 2, 82)
		_set_compact_label(_chapter_details_label, "No chapters are ready.", 2, 82)
		_set_compact_label(_campaign_commander_preview_label, "Select a chapter to review the commander and opening force.", 3, 82)
		_set_compact_label(_campaign_operational_board_label, "Select a chapter to review terrain, pressure, and first contact.", 3, 82)
		_set_compact_label(_campaign_journal_label, "Campaign journal entries appear here.", 3, 82)
		_campaign_primary_button.text = "No Campaign"
		_campaign_primary_button.disabled = true
		_campaign_primary_button.tooltip_text = "Author a campaign arc to launch it from the main menu."
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or replay it."
		return

	_set_compact_label(_campaign_details_label, CampaignProgression.campaign_details(_selected_campaign_id), 4, 86)
	_set_compact_label(_campaign_arc_status_label, CampaignProgression.campaign_arc_status(_selected_campaign_id), 3, 86)
	_set_compact_label(_campaign_journal_label, CampaignProgression.campaign_journal(_selected_campaign_id), 3, 86)

	var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
	_campaign_primary_button.text = String(primary_action.get("label", "Advance Campaign"))
	_campaign_primary_button.disabled = bool(primary_action.get("disabled", false))
	_campaign_primary_button.tooltip_text = String(primary_action.get("summary", ""))

	if _selected_campaign_scenario_id == "":
		_set_compact_label(_chapter_details_label, "Select a chapter to inspect carryover and the latest result.", 3, 86)
		_set_compact_label(_campaign_commander_preview_label, "Select a chapter to review the commander and opening force.", 3, 86)
		_set_compact_label(_campaign_operational_board_label, "Select a chapter to review terrain, pressure, and first contact.", 3, 86)
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or replay it."
		return

	var chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	var chapter_check := _campaign_chapter_check_payload(chapter_action, primary_action)
	_set_compact_label(
		_chapter_details_label,
		_chapter_details_with_campaign_check(
			CampaignProgression.chapter_details(_selected_campaign_id, _selected_campaign_scenario_id),
			chapter_check
		),
		4,
		86
	)
	_set_compact_label(
		_campaign_commander_preview_label,
		CampaignProgression.chapter_commander_preview(_selected_campaign_id, _selected_campaign_scenario_id),
		4,
		86
	)
	_set_compact_label(
		_campaign_operational_board_label,
		CampaignProgression.chapter_operational_board(_selected_campaign_id, _selected_campaign_scenario_id),
		4,
		86
	)

	_start_chapter_button.text = String(chapter_action.get("label", "Start Chapter"))
	_start_chapter_button.disabled = bool(chapter_action.get("disabled", false))
	_start_chapter_button.tooltip_text = _join_nonempty_lines([
		String(chapter_check.get("tooltip_text", "")),
		String(chapter_action.get("summary", "")),
	])

func _campaign_chapter_check_payload(chapter_action: Dictionary, primary_action: Dictionary) -> Dictionary:
	if chapter_action.is_empty():
		return {
			"text": "Campaign check: select a chapter before starting a campaign expedition.",
			"tooltip_text": "Campaign Chapter Check\n- Selection: none.\n- Next: select an authored chapter before starting a campaign expedition.\n- Scope: campaign board only; no expedition save or campaign progress changes.",
		}

	var chapter_label := String(chapter_action.get("label", "Chapter"))
	var primary_label := String(primary_action.get("label", "primary campaign action"))
	var selected_scenario_id := String(chapter_action.get("scenario_id", ""))
	var primary_scenario_id := String(primary_action.get("scenario_id", ""))
	var disabled := bool(chapter_action.get("disabled", false))
	var relation := "selected chapter is separate from the primary campaign action"
	if disabled:
		relation = "selected chapter is locked or unavailable"
	elif selected_scenario_id != "" and selected_scenario_id == primary_scenario_id:
		relation = "selected chapter matches the primary campaign action"
	elif chapter_label.begins_with("Replay"):
		relation = "selected chapter is a replay of recorded campaign progress"
	elif chapter_label.begins_with("Retry"):
		relation = "selected chapter retries a recorded setback"

	var action_note := "starting stays unavailable"
	if not disabled:
		if chapter_label.begins_with("Replay"):
			action_note = "replay starts fresh and keeps recorded progress"
		elif chapter_label.begins_with("Retry"):
			action_note = "retry starts fresh until victory updates progress"
		elif selected_scenario_id != "" and selected_scenario_id == primary_scenario_id:
			action_note = "victory can advance the campaign path"
		else:
			action_note = "starts with campaign context without loading a save"

	var launch_handoff := String(chapter_action.get("launch_handoff", "")).strip_edges()
	var action_consequence := String(chapter_action.get("action_consequence", "")).strip_edges()
	return {
		"text": "Campaign check: %s; %s." % [relation, action_note],
		"tooltip_text": _join_nonempty_lines([
			"Campaign Chapter Check",
			"- Selection: %s." % chapter_label,
			"- Primary action: %s." % primary_label,
			"- State: %s." % relation,
			"- Next: %s." % action_note,
			"- Handoff: %s" % launch_handoff if launch_handoff != "" else "",
			"- Consequence: %s" % action_consequence if action_consequence != "" else "",
			"- Scope: campaign board only; pressing a start action creates a fresh Campaign expedition and does not load or overwrite an expedition save.",
		]),
		"relation": relation,
		"action_note": action_note,
	}

func _chapter_details_with_campaign_check(details: String, chapter_check: Dictionary) -> String:
	var check_text := String(chapter_check.get("text", "")).strip_edges()
	if check_text == "":
		return details
	var lines := details.split("\n", false)
	if lines.is_empty():
		return check_text
	var merged := [String(lines[0]), check_text]
	for index in range(1, lines.size()):
		merged.append(String(lines[index]))
	return "\n".join(merged)

func _rebuild_help_browser() -> void:
	_help_entries = SettingsService.build_help_topics()
	_help_list.clear()

	var preferred_help_topic_id := _selected_help_topic_id
	if preferred_help_topic_id == "":
		preferred_help_topic_id = SettingsService.default_help_topic_id()

	var selected_index := -1
	for index in range(_help_entries.size()):
		var entry = _help_entries[index]
		_help_list.add_item(String(entry.get("label", entry.get("id", "Topic"))))
		_help_list.set_item_tooltip(index, _help_topic_row_tooltip(entry))
		if String(entry.get("id", "")) == preferred_help_topic_id:
			selected_index = index

	if selected_index < 0 and not _help_entries.is_empty():
		selected_index = 0

	if selected_index >= 0 and selected_index < _help_entries.size():
		_help_list.select(selected_index)
		_selected_help_topic_id = String(_help_entries[selected_index].get("id", ""))
	else:
		_selected_help_topic_id = ""

	_refresh_help_intro()
	_refresh_help_browser()

func _refresh_help_browser() -> void:
	if _help_entries.is_empty():
		_set_compact_label(_help_details_label, "No guide entries are available.", 2, 84)
		return

	if _selected_help_topic_id == "":
		_selected_help_topic_id = String(_help_entries[0].get("id", ""))
		_help_list.select(0)

	var handoff := _help_handoff_surface()
	_set_compact_label(
		_help_details_label,
		"%s\n%s" % [String(handoff.get("text", "")), SettingsService.describe_help_topic(_selected_help_topic_id)],
		7,
		88
	)
	_help_details_label.tooltip_text = "%s\n%s" % [
		String(handoff.get("tooltip_text", "")),
		SettingsService.describe_help_topic(_selected_help_topic_id),
	]

func _refresh_help_intro() -> void:
	_refresh_help_topic_tooltips()
	var handoff := _help_handoff_surface()
	_set_compact_label(
		_help_intro_label,
		"%s\n%s" % [SettingsService.help_browser_summary(), String(handoff.get("text", ""))],
		3,
		84
	)
	_help_intro_label.tooltip_text = "%s\n%s" % [
		SettingsService.help_browser_summary(),
		String(handoff.get("tooltip_text", "")),
	]

func _help_handoff_surface(topic_id_override: String = "") -> Dictionary:
	var topic_id := topic_id_override
	if topic_id == "":
		topic_id = _selected_help_topic_id
	if topic_id == "":
		topic_id = SettingsService.default_help_topic_id()
	var topic_label := SettingsService.help_topic_label(topic_id)
	var return_copy: Dictionary = TAB_STAGE_COPY.get(_last_context_tab, TAB_STAGE_COPY[TAB_CAMPAIGN])
	var return_label := String(return_copy.get("title", "the previous board")).to_lower()
	return {
		"text": "Help handoff: %s is reference only; Back returns to %s; Close returns to scenic first view." % [topic_label, return_label],
		"tooltip_text": "Help Handoff\n- Topic: %s.\n- Selection: changes the visible Field Manual page only.\n- Back: returns to %s without launching, loading, saving, or changing settings.\n- Close: dismisses the secondary board and returns to the scenic first view.\n- State change: no campaign progress, expedition save, or device setting changes." % [topic_label, return_label],
		"topic_id": topic_id,
		"topic_label": topic_label,
		"return_board": return_label,
	}

func _help_topic_row_tooltip(entry: Dictionary) -> String:
	var topic_id := String(entry.get("id", ""))
	var topic_label := String(entry.get("label", entry.get("id", "Topic")))
	return "Topic cue: selecting %s changes the visible Field Manual reference only.\n%s" % [
		topic_label,
		String(_help_handoff_surface(topic_id).get("tooltip_text", "")),
	]

func _refresh_help_topic_tooltips() -> void:
	for index in range(mini(_help_list.get_item_count(), _help_entries.size())):
		var entry: Dictionary = _help_entries[index]
		_help_list.set_item_tooltip(index, _help_topic_row_tooltip(entry))

func _select_help_topic(topic_id: String) -> void:
	if topic_id == "":
		return
	_selected_help_topic_id = topic_id
	for index in range(_help_entries.size()):
		if String(_help_entries[index].get("id", "")) != topic_id:
			continue
		_help_list.select(index)
		break
	_refresh_help_intro()
	_refresh_help_browser()

func _refresh_settings_panel() -> void:
	_set_compact_label(_settings_summary_label, SettingsService.describe_settings(), 4, 84)
	var settings_check := SettingsService.describe_settings_persistence_check()
	var settings_handoff := _settings_handoff_surface()
	_set_compact_label(_settings_handoff_label, String(settings_handoff.get("visible_text", "")), 2, 96)
	_settings_handoff_label.tooltip_text = String(settings_handoff.get("tooltip_text", ""))

	_syncing_settings_ui = true
	_presentation_mode_picker.clear()
	var options := SettingsService.build_presentation_options()
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		var label := String(option.get("label", option.get("id", "Window Mode")))
		_presentation_mode_picker.add_item(label, index)
		_presentation_mode_picker.set_item_metadata(index, String(option.get("id", "")))
		if bool(option.get("selected", false)):
			selected_index = index
	if selected_index >= 0:
		_presentation_mode_picker.select(selected_index)
		_presentation_mode_picker.tooltip_text = "%s\n%s" % [String(options[selected_index].get("summary", "")), settings_check]

	_resolution_picker.clear()
	var resolution_options := SettingsService.build_resolution_options()
	var selected_resolution_index := -1
	for index in range(resolution_options.size()):
		var option = resolution_options[index]
		var label := String(option.get("label", option.get("id", "Resolution")))
		_resolution_picker.add_item(label, index)
		_resolution_picker.set_item_metadata(index, String(option.get("id", "")))
		if bool(option.get("selected", false)):
			selected_resolution_index = index
	if selected_resolution_index >= 0:
		_resolution_picker.select(selected_resolution_index)
		_resolution_picker.tooltip_text = "%s\n%s" % [String(resolution_options[selected_resolution_index].get("summary", "")), settings_check]

	_master_volume_slider.value = SettingsService.master_volume_percent()
	_master_volume_slider.tooltip_text = "Master volume applies immediately.\n%s" % settings_check
	_master_volume_value.text = "%d%%" % SettingsService.master_volume_percent()
	_music_volume_slider.value = SettingsService.music_volume_percent()
	_music_volume_slider.tooltip_text = "Music volume applies immediately.\n%s" % settings_check
	_music_volume_value.text = "%d%%" % SettingsService.music_volume_percent()
	_large_text_toggle.button_pressed = SettingsService.large_ui_text_enabled()
	_large_text_toggle.tooltip_text = "Large UI text applies immediately.\n%s" % settings_check
	_reduce_motion_toggle.button_pressed = SettingsService.reduced_motion_enabled()
	_reduce_motion_toggle.tooltip_text = "Reduced motion preference applies immediately.\n%s" % settings_check
	_syncing_settings_ui = false

func _rebuild_save_browser() -> void:
	_save_summaries = SaveService.list_session_summaries()
	_save_browser_loaded = true
	_save_list.clear()

	var latest_key := _summary_key(_latest_loaded_save_summary())
	var selected_index := -1
	for index in range(_save_summaries.size()):
		var summary: Dictionary = _save_summaries[index]
		var label := SaveService.describe_slot_browser_row(summary)
		if _summary_key(summary) == latest_key and SaveService.can_load_summary(summary):
			label = "%s | Latest" % label
		_save_list.add_item(label)
		_save_list.set_item_tooltip(index, _save_browser_row_tooltip(summary))
		if _summary_key(summary) == _selected_save_key:
			selected_index = index

	if selected_index < 0:
		selected_index = _default_selected_save_index()

	if selected_index >= 0 and selected_index < _save_summaries.size():
		_save_list.select(selected_index)
		_selected_save_key = _summary_key(_save_summaries[selected_index])
	else:
		_selected_save_key = ""

	_refresh_selected_save()

func _refresh_selected_save() -> void:
	var summary := _selected_summary()
	if summary.is_empty():
		_set_compact_label(_save_details_label, "No loadable expeditions are stored.", 3, 84)
		_load_selected_button.text = "Load Save"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = _selected_save_command_tooltip(summary)
		return

	var next_play_action := SaveService.describe_summary_next_play_action(summary)
	var play_check := SaveService.describe_summary_play_check(summary)
	var resume_handoff := SaveService.describe_summary_resume_handoff(summary)
	var details := SaveService.describe_slot_details(summary)
	if resume_handoff != "":
		details = "%s\n%s" % [resume_handoff, details]
	if play_check != "":
		details = "%s\n%s" % [play_check, details]
	if next_play_action != "":
		details = "%s\n%s" % [next_play_action, details]
	_set_compact_label(_save_details_label, details, 6, 88)
	_load_selected_button.text = SaveService.load_action_label(summary)
	_load_selected_button.disabled = not SaveService.can_load_summary(summary)
	_load_selected_button.tooltip_text = _selected_save_command_tooltip(summary)

func _save_browser_row_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Command cue: select a save row to inspect its resume target before loading."
	var lines := [
		"Command cue: selecting this row only changes the inspected save.",
		SaveService.describe_slot_continuity_cue(summary),
		SaveService.describe_summary_play_check(summary),
		SaveService.describe_summary_resume_handoff(summary),
	]
	if SaveService.can_load_summary(summary):
		lines.append("Load Selected: %s opens this saved state." % SaveService.load_action_label(summary))
	else:
		lines.append("Load Selected: unavailable until a loadable save row is selected.")
	return _join_nonempty_lines(lines)

func _selected_save_command_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Command cue: select a loadable save row before loading."
	var lines := [
		"Command cue: %s acts on the selected save row only." % SaveService.load_action_label(summary),
		SaveService.describe_summary_play_check(summary),
		SaveService.describe_summary_resume_handoff(summary),
	]
	var load_tooltip := SaveService.load_action_tooltip(summary).strip_edges()
	if load_tooltip != "":
		lines.append(load_tooltip)
	return _join_nonempty_lines(lines)

func _default_selected_save_index() -> int:
	var latest_key := _summary_key(_latest_loaded_save_summary())
	if latest_key != "":
		for index in range(_save_summaries.size()):
			if _summary_key(_save_summaries[index]) == latest_key:
				return index
	if not _save_summaries.is_empty():
		return 0
	return -1

func _selected_summary() -> Dictionary:
	for summary in _save_summaries:
		if _summary_key(summary) == _selected_save_key:
			return summary
	return {}

func _latest_loaded_save_summary() -> Dictionary:
	var latest := {}
	for summary in _save_summaries:
		if not SaveService.can_load_summary(summary):
			continue
		if latest.is_empty() or int(summary.get("modified_timestamp", 0)) > int(latest.get("modified_timestamp", 0)):
			latest = summary
	return latest

func _active_save_board_latest_summary() -> Dictionary:
	if not _save_browser_loaded or not _stage_dock_panel.visible or _menu_tabs.current_tab != TAB_SAVES:
		return {}
	return _latest_loaded_save_summary()

func _active_save_board_selected_summary() -> Dictionary:
	if not _save_browser_loaded or not _stage_dock_panel.visible or _menu_tabs.current_tab != TAB_SAVES:
		return {}
	return _selected_summary()

func _reset_save_browser_placeholder() -> void:
	if _save_browser_loaded:
		return
	_save_summaries = []
	_selected_save_key = ""
	if _save_list != null:
		_save_list.clear()
	if _save_details_label != null:
		_set_compact_label(_save_details_label, "Open Load to inspect saved expeditions.", 3, 84)
	if _load_selected_button != null:
		_load_selected_button.text = "Load Save"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = "Open Load to inspect save slots before loading."

func _ensure_save_browser_loaded() -> void:
	if not _save_browser_loaded:
		_rebuild_save_browser()

func _summary_key(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	return "%s:%s" % [String(summary.get("slot_type", "")), String(summary.get("slot_id", ""))]

func _join_nonempty_lines(lines: Array) -> String:
	var clean_lines := []
	for line in lines:
		var text := String(line).strip_edges()
		if text != "":
			clean_lines.append(text)
	return "\n".join(clean_lines)

func _configure_difficulty_picker() -> void:
	_difficulty_picker.clear()
	var options := ScenarioSelectRulesScript.build_difficulty_options(_selected_difficulty)
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		var label := String(option.get("label", option.get("id", "Difficulty")))
		_difficulty_picker.add_item(label, index)
		_difficulty_picker.set_item_metadata(index, String(option.get("id", ScenarioSelectRulesScript.default_difficulty_id())))
		if bool(option.get("selected", false)):
			selected_index = index
	if selected_index >= 0:
		_difficulty_picker.select(selected_index)

func _configure_generated_random_map_controls() -> void:
	var options := ScenarioSelectRulesScript.random_map_player_setup_options()
	if _generated_size_class_id == "":
		_generated_size_class_id = String(options.get("default_size_class_id", "homm3_small"))
	if _generated_template_id == "":
		_generated_template_id = String(options.get("default_template_id", "border_gate_compact_v1"))
	if _generated_profile_id == "":
		_generated_profile_id = String(options.get("default_profile_id", "border_gate_compact_profile_v1"))
	if _generated_player_count <= 0:
		_generated_player_count = int(options.get("default_player_count", 3))
	_clamp_generated_player_count_to_template()
	if _generated_water_mode == "":
		_generated_water_mode = String(options.get("default_water_mode", "land"))
	_generated_seed_edit.text = _generated_seed
	_generated_seed_edit.placeholder_text = "Auto seed"
	_generated_seed_edit.tooltip_text = "Seed: leave blank for a fresh generated seed on launch, or enter a seed to recreate the same map identity."

	_rebuild_generated_option_picker(_generated_size_picker, options.get("size_classes", []), _generated_size_class_id, "size")
	_rebuild_generated_option_picker(_generated_template_picker, options.get("templates", []), _generated_template_id, "template")
	_rebuild_generated_option_picker(_generated_profile_picker, options.get("profiles", []), _generated_profile_id, "profile")

	_rebuild_generated_player_count_picker()

	_generated_water_picker.clear()
	var water_selected := -1
	for index in range(options.get("water_modes", []).size()):
		var water_option = options.get("water_modes", [])[index]
		if not (water_option is Dictionary):
			continue
		_generated_water_picker.add_item(String(water_option.get("label", water_option.get("id", "Water"))), index)
		_generated_water_picker.set_item_metadata(index, String(water_option.get("id", "land")))
		if String(water_option.get("id", "land")) == _generated_water_mode:
			water_selected = index
	if water_selected >= 0:
		_generated_water_picker.select(water_selected)
	_generated_water_picker.tooltip_text = "Water: land or islands generation policy."

	_generated_underground_toggle.button_pressed = _generated_underground
	_generated_underground_toggle.tooltip_text = "Underground: include a second generated level when supported by the selected template."

func _rebuild_generated_option_picker(picker: OptionButton, options: Array, selected_id: String, label_key: String) -> void:
	picker.clear()
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		if not (option is Dictionary):
			continue
		var option_id := String(option.get("id", ""))
		picker.add_item(String(option.get("label", option_id)), index)
		picker.set_item_metadata(index, option_id)
		if option_id == selected_id:
			selected_index = index
	if selected_index >= 0:
		picker.select(selected_index)
	picker.tooltip_text = "%s: generated map setup provenance records this id." % label_key.capitalize()

func _rebuild_skirmish_browser() -> void:
	_skirmish_entries = ScenarioSelectRulesScript.build_skirmish_browser_entries()
	_skirmish_list.clear()

	var selected_index := -1
	for index in range(_skirmish_entries.size()):
		var entry = _skirmish_entries[index]
		_skirmish_list.add_item(String(entry.get("label", entry.get("scenario_id", "Scenario"))))
		_skirmish_list.set_item_tooltip(index, _skirmish_front_row_tooltip(entry))
		if String(entry.get("scenario_id", "")) == _selected_skirmish_id:
			selected_index = index

	if selected_index < 0 and not _skirmish_entries.is_empty():
		selected_index = 0
		_selected_skirmish_id = String(_skirmish_entries[0].get("scenario_id", ""))

	if selected_index >= 0 and selected_index < _skirmish_entries.size():
		_skirmish_list.select(selected_index)
		_selected_skirmish_id = String(_skirmish_entries[selected_index].get("scenario_id", ""))
	else:
		_selected_skirmish_id = ""

func _refresh_skirmish_setup() -> void:
	var selected_entry := _selected_skirmish_entry()
	_set_compact_label(_difficulty_summary_label, ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty), 3, 82)

	if selected_entry.is_empty():
		_set_compact_label(_skirmish_details_label, "No skirmish fronts are authored.", 2, 82)
		_set_compact_label(_setup_summary_label, "Select a front to review its opening setup.", 3, 82)
		_set_compact_label(_skirmish_commander_preview_label, "Commander preview appears here.", 3, 82)
		_set_compact_label(_skirmish_operational_board_label, "Operational pressure appears here.", 3, 82)
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "No skirmish scenarios are available."
		return

	_set_compact_label(_skirmish_details_label, String(selected_entry.get("summary", "")), 3, 84)
	var setup := ScenarioSelectRulesScript.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	if setup.is_empty():
		_set_compact_label(_setup_summary_label, "This front cannot be launched right now.", 3, 82)
		_set_compact_label(_skirmish_commander_preview_label, "Commander preview unavailable for this front.", 3, 82)
		_set_compact_label(_skirmish_operational_board_label, "Operational board unavailable for this front.", 3, 82)
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "This scenario cannot be launched as a skirmish."
		return

	var front_check := _skirmish_front_check_payload(setup)
	var recommended_difficulty := String(setup.get("recommended_difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	var difficulty_lines := [
		ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty),
		String(setup.get("difficulty_check", "")).strip_edges(),
	]
	if recommended_difficulty != _selected_difficulty:
		difficulty_lines.append("Recommended: %s." % String(setup.get("recommended_difficulty_label", "")))
	_set_compact_label(_difficulty_summary_label, _join_nonempty_lines(difficulty_lines), 3, 82)

	_set_compact_label(
		_setup_summary_label,
		_join_nonempty_lines([
			String(front_check.get("visible_text", "")),
			String(setup.get("setup_summary", "")),
		]),
		3,
		84
	)
	_set_compact_label(_skirmish_commander_preview_label, String(setup.get("commander_preview", "Commander preview unavailable.")), 4, 84)
	_set_compact_label(_skirmish_operational_board_label, String(setup.get("operational_board", "Operational board unavailable.")), 4, 84)
	_start_skirmish_button.disabled = false
	_start_skirmish_button.text = "Launch Skirmish"
	_start_skirmish_button.tooltip_text = _join_nonempty_lines([
		String(front_check.get("tooltip_text", "")),
		String(setup.get("action_tooltip", setup.get("launch_preview", ""))).strip_edges(),
	])
	if _start_skirmish_button.tooltip_text == "":
		_start_skirmish_button.tooltip_text = "Launch %s at %s difficulty." % [
			String(setup.get("scenario_name", _selected_skirmish_id)),
			String(setup.get("difficulty_label", ScenarioSelectRulesScript.difficulty_label(_selected_difficulty))),
		]

func _refresh_generated_random_map_setup() -> void:
	if _generated_generation_in_progress:
		return
	var setup := _generated_random_map_preview_setup()
	_generated_last_setup = setup.duplicate(true)
	_apply_generated_random_map_setup_surface(setup)

func _apply_generated_random_map_setup_surface(setup: Dictionary) -> void:
	var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	var status_text := ""
	var provenance_text := ""
	_start_generated_skirmish_button.text = "Launch Generated"
	if bool(setup.get("ok", false)):
		var seed_source := String(setup.get("seed_source", "explicit"))
		var seed_label := String(setup.get("normalized_seed", ""))
		if seed_source == "auto_on_launch":
			seed_label = "auto on launch"
		status_text = "Generated validation %s | %d attempt(s), %d retry." % [
			String(retry.get("validation_status", "pass")),
			int(retry.get("attempt_count", 1)),
			int(retry.get("retry_count", 0)),
		]
		provenance_text = "Seed %s | Size %s | Template %s | Profile %s | Players %d | Water %s | Underground %s" % [
			seed_label,
			ScenarioSelectRulesScript.random_map_size_class_label(_generated_size_class_id),
			String(setup.get("template_id", "")),
			String(setup.get("profile_id", "")),
			_generated_player_count,
			_generated_water_mode,
			"on" if _generated_underground else "off",
		]
		_start_generated_skirmish_button.disabled = false
		_start_generated_skirmish_button.tooltip_text = _join_nonempty_lines([
			String(setup.get("launch_handoff", "")),
			String(setup.get("failure_handoff", "")),
			String(setup.get("setup_summary", "")),
		])
	else:
		status_text = "Generated validation blocked | %d attempt(s), %d retry." % [
			int(retry.get("attempt_count", 0)),
			int(retry.get("retry_count", 0)),
		]
		provenance_text = String(setup.get("failure_handoff", "Generated setup failed validation."))
		_start_generated_skirmish_button.disabled = true
		_start_generated_skirmish_button.tooltip_text = _join_nonempty_lines([
			String(setup.get("failure_handoff", "")),
			String(setup.get("setup_summary", "")),
		])
	_set_compact_label(_generated_status_label, status_text, 2, 72)
	_set_compact_label(_generated_provenance_label, provenance_text, 2, 118)
	_generated_progress_bar.visible = false

func _start_generated_skirmish_staged(route_to_overworld: bool) -> Dictionary:
	if _generated_generation_in_progress or _start_generated_skirmish_button.disabled:
		return {
			"started": false,
			"blocked": true,
			"reason": "generated_launch_unavailable_or_already_in_progress",
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"snapshots": _duplicate_stage_snapshots(),
		}

	_generated_generation_in_progress = true
	_generated_generation_yield_count = 0
	_generated_generation_snapshots = []
	_set_generated_random_map_inputs_disabled(true)
	_set_generated_generation_stage(
		"Preparing generated map",
		10,
		"Preparing generated map launch; seed, size, template, player count, water, and underground choices are locked for this run."
	)
	await _yield_generated_generation_frame()

	var config := _generated_random_map_config()
	_set_generated_generation_stage(
		"Validating seed and template",
		25,
		"Validating generated map seed/config with bounded retry. Map size, template, player-count, and density rules are unchanged."
	)
	await _yield_generated_generation_frame()

	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		_selected_difficulty,
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	_generated_last_setup = setup.duplicate(true)
	_set_generated_generation_stage(
		"Generation validation complete" if bool(setup.get("ok", false)) else "Generation blocked",
		62,
		String(setup.get("setup_summary", setup.get("failure_handoff", "Generated map validation finished.")))
	)
	await _yield_generated_generation_frame()

	if not bool(setup.get("ok", false)):
		_generated_generation_in_progress = false
		_set_generated_random_map_inputs_disabled(false)
		_apply_generated_random_map_setup_surface(setup)
		return {
			"started": false,
			"blocked": false,
			"setup": setup.duplicate(true),
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"snapshots": _duplicate_stage_snapshots(),
		}

	_set_generated_generation_stage(
		"Materializing playable session",
		82,
		"Registering the generated scenario draft and normalizing the playable overworld without authored writeback."
	)
	await _yield_generated_generation_frame()

	var session := ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session.scenario_id == "":
		_generated_generation_in_progress = false
		_set_generated_random_map_inputs_disabled(false)
		_apply_generated_random_map_setup_surface(setup)
		return {
			"started": false,
			"blocked": false,
			"setup": setup.duplicate(true),
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"snapshots": _duplicate_stage_snapshots(),
		}

	_set_generated_generation_stage(
		"Opening generated map",
		96,
		"Generated map ready; opening the Day 1 overworld."
	)
	await _yield_generated_generation_frame()

	var result := {
		"started": true,
		"blocked": false,
		"setup": setup.duplicate(true),
		"yield_count": _generated_generation_yield_count,
		"stage": _generated_generation_stage.duplicate(true),
		"snapshots": _duplicate_stage_snapshots(),
		"active_scenario_id": session.scenario_id,
		"active_launch_mode": session.launch_mode,
		"active_generated_random_map": bool(session.flags.get("generated_random_map", false)),
		"active_retry_status": session.flags.get("generated_random_map_retry_status", {}),
		"active_provenance": session.flags.get("generated_random_map_provenance", {}),
	}
	if route_to_overworld:
		AppRouter.begin_overworld_handoff_profile(
			"generated_random_map_post_open_tail",
			{
				"stage": String(_generated_generation_stage.get("stage", "")),
				"progress": int(_generated_generation_stage.get("progress", 0)),
				"scenario_id": session.scenario_id,
				"size_class_id": _generated_size_class_id,
				"template_id": String(setup.get("template_id", "")),
				"profile_id": String(setup.get("profile_id", "")),
				"player_count": _generated_player_count,
			}
		)
		AppRouter.go_to_overworld()
	else:
		_generated_generation_in_progress = false
		_set_generated_random_map_inputs_disabled(false)
		_apply_generated_random_map_setup_surface(setup)
	return result

func _set_generated_generation_stage(stage_label: String, progress_value: int, detail: String) -> void:
	_generated_generation_stage = {
		"active": _generated_generation_in_progress,
		"stage": stage_label,
		"progress": clampi(progress_value, 0, 100),
		"yield_count": _generated_generation_yield_count,
		"detail": detail,
	}
	_generated_progress_bar.visible = true
	_generated_progress_bar.value = float(_generated_generation_stage.get("progress", 0))
	_start_generated_skirmish_button.text = "Generating..."
	_start_generated_skirmish_button.disabled = true
	_start_generated_skirmish_button.tooltip_text = detail
	_set_compact_label(_generated_status_label, "%s | %d%%" % [stage_label, int(_generated_generation_stage.get("progress", 0))], 2, 72)
	_set_compact_label(_generated_provenance_label, detail, 2, 118)
	_generated_generation_snapshots.append(_generated_generation_stage.duplicate(true))

func _yield_generated_generation_frame() -> void:
	await get_tree().process_frame
	_generated_generation_yield_count += 1
	_generated_generation_stage["yield_count"] = _generated_generation_yield_count
	if not _generated_generation_snapshots.is_empty():
		_generated_generation_snapshots[_generated_generation_snapshots.size() - 1]["yield_count_after_stage"] = _generated_generation_yield_count

func _set_generated_random_map_inputs_disabled(disabled: bool) -> void:
	for control in [
		_generated_seed_edit,
		_generated_size_picker,
		_generated_template_picker,
		_generated_profile_picker,
		_generated_player_count_picker,
		_generated_water_picker,
		_generated_underground_toggle,
	]:
		if control is LineEdit:
			control.editable = not disabled
		elif control != null:
			control.disabled = disabled
	if disabled:
		_start_generated_skirmish_button.disabled = true

func _duplicate_stage_snapshots() -> Array:
	var snapshots := []
	for snapshot in _generated_generation_snapshots:
		if snapshot is Dictionary:
			snapshots.append(snapshot.duplicate(true))
	return snapshots

func _generated_random_map_preview_setup() -> Dictionary:
	var seed := _generated_seed.strip_edges()
	var seed_source := "auto_on_launch" if ScenarioSelectRulesScript.random_map_seed_requests_auto(seed) else "explicit"
	if seed_source == "auto_on_launch":
		seed = "auto on launch"
	return {
		"ok": true,
		"setup_kind": "generated_random_map_skirmish",
		"launch_mode": SessionState.LAUNCH_MODE_SKIRMISH,
		"difficulty": _selected_difficulty,
		"difficulty_label": ScenarioSelectRulesScript.difficulty_label(_selected_difficulty),
		"scenario_id": "",
		"scenario_name": "Generated Skirmish",
		"size_class_id": _generated_size_class_id,
		"size_class_label": ScenarioSelectRulesScript.random_map_size_class_label(_generated_size_class_id),
		"template_id": _generated_template_id,
		"profile_id": _generated_profile_id,
		"normalized_seed": seed,
		"seed_source": seed_source,
		"retry_status": {
			"policy": "bounded_player_setup_retry_visible",
			"attempt_count": 0,
			"retry_count": 0,
			"max_attempts": int(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("max_attempts", 2)),
			"mode": String(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("mode", "seed_salt")),
			"status": "configured_pending_launch_validation",
			"validation_status": "pending_launch_validation",
			"failure_count": 0,
			"warning_count": 0,
		},
		"setup_summary": "Generated Skirmish setup configured; launch validates the map with bounded retry before creating a session.",
		"launch_handoff": "Launch handoff: validate generated Skirmish from seed/config provenance with bounded retry, then start a fresh Day 1 Skirmish expedition only if validation passes.",
		"failure_handoff": "Validation failures stay in this setup surface; no session, save, campaign progress, or authored content changes occur when generation is blocked.",
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

func _generated_random_map_config() -> Dictionary:
	var raw_seed := _generated_seed.strip_edges()
	var seed_source := "auto_on_launch" if ScenarioSelectRulesScript.random_map_seed_requests_auto(raw_seed) else "explicit"
	var seed := ScenarioSelectRulesScript.random_map_fresh_auto_seed() if seed_source == "auto_on_launch" else raw_seed
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		_generated_template_id,
		_generated_profile_id,
		_generated_player_count,
		_generated_water_mode,
		_generated_underground,
		_generated_size_class_id
	)
	config["seed_source"] = seed_source
	config["seed_input"] = raw_seed
	return config

func _select_generated_picker_metadata(picker: OptionButton, metadata: String) -> bool:
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) != metadata:
			continue
		picker.select(index)
		return true
	return false

func _select_generated_player_count_picker(player_count: int) -> bool:
	for index in range(_generated_player_count_picker.get_item_count()):
		if int(_generated_player_count_picker.get_item_metadata(index)) != player_count:
			continue
		_generated_player_count_picker.select(index)
		return true
	return false

func _rebuild_generated_player_count_picker() -> void:
	_generated_player_count_picker.clear()
	var player_selected := -1
	var player_counts := ScenarioSelectRulesScript.random_map_player_count_options_for_template(_generated_template_id)
	if player_counts.is_empty():
		player_counts = ScenarioSelectRulesScript.random_map_player_setup_options().get("player_counts", [])
	for index in range(player_counts.size()):
		var player_count := int(player_counts[index])
		_generated_player_count_picker.add_item("%d players" % player_count, index)
		_generated_player_count_picker.set_item_metadata(index, player_count)
		if player_count == _generated_player_count:
			player_selected = index
	if player_selected >= 0:
		_generated_player_count_picker.select(player_selected)
	_generated_player_count_picker.tooltip_text = "Player count: one human start plus generated opponents."

func _clamp_generated_player_count_to_template() -> void:
	var counts := ScenarioSelectRulesScript.random_map_player_count_options_for_template(_generated_template_id)
	if counts.is_empty():
		return
	var first_count := int(counts[0])
	var last_count := int(counts[counts.size() - 1])
	_generated_player_count = clampi(_generated_player_count, first_count, last_count)

func _skirmish_front_check_payload(setup: Dictionary) -> Dictionary:
	if setup.is_empty():
		return {
			"visible_text": "Skirmish front check: select a front before launching.",
			"tooltip_text": "Skirmish Front Check\n- Selection: none.\n- Launch target: unavailable until a skirmish front is selected.\n- State change: no campaign progress or expedition save changes.",
		}
	var scenario_name := String(setup.get("scenario_name", _selected_skirmish_id))
	var difficulty_label := String(setup.get("difficulty_label", ScenarioSelectRulesScript.difficulty_label(_selected_difficulty)))
	var launch_handoff := String(setup.get("launch_handoff", "")).strip_edges()
	var front_context := String(setup.get("front_context", "")).strip_edges()
	var action_consequence := String(setup.get("action_consequence", "")).strip_edges()
	return {
		"visible_text": "Skirmish front check: %s is the Launch Skirmish target; selection changes preview only." % scenario_name,
		"tooltip_text": _join_nonempty_lines([
			"Skirmish Front Check",
			"- Selected front: %s." % scenario_name,
			"- Launch target: Launch Skirmish starts this front as a fresh Skirmish expedition on Day 1 at %s difficulty." % difficulty_label,
			"- Selection: changing front rows updates briefing, commander preview, operational board, and launch target only.",
			"- Handoff: %s" % launch_handoff if launch_handoff != "" else "",
			"- Front context: %s" % front_context if front_context != "" else "",
			"- Action boundary: %s" % action_consequence if action_consequence != "" else "",
			"- Not changed: campaign progress, latest save, and manual save slots stay unchanged until Launch Skirmish creates a fresh run.",
		]),
		"scenario_name": scenario_name,
		"difficulty_label": difficulty_label,
	}

func _skirmish_front_row_tooltip(entry: Dictionary) -> String:
	if entry.is_empty():
		return "Front cue: select a skirmish front to inspect its launch target."
	var scenario_label := String(entry.get("label", entry.get("scenario_id", "Front")))
	var summary := String(entry.get("summary", "")).strip_edges()
	return _join_nonempty_lines([
		"Front cue: selecting %s changes the inspected skirmish front only." % scenario_label,
		"Launch Skirmish uses the selected front and chosen difficulty; campaign progress and expedition saves stay unchanged until launch.",
		summary,
	])

func _selected_skirmish_entry() -> Dictionary:
	for entry in _skirmish_entries:
		if String(entry.get("scenario_id", "")) == _selected_skirmish_id:
			return entry
	return {}

func _build_campaign_pulse() -> String:
	if _campaign_entries.is_empty():
		return "No campaign arcs loaded."

	var completed_count := 0
	for entry in _campaign_entries:
		if String(entry.get("label", "")).contains("Completed"):
			completed_count += 1

	var selected_label := "No focus arc."
	for entry in _campaign_entries:
		if String(entry.get("campaign_id", "")) == _selected_campaign_id:
			selected_label = String(entry.get("label", "Campaign"))
			break

	return "\n".join(
		[
			"Arcs %d | Cleared %d" % [_campaign_entries.size(), completed_count],
			"Focus %s" % selected_label,
		]
	)

func _build_save_pulse() -> String:
	var latest_summary := _active_save_board_latest_summary()
	if latest_summary.is_empty():
		return "Load board: open Load to inspect manual slots and autosave."
	var latest_line := "No active resume point."
	var play_check := ""
	if SaveService.can_load_summary(latest_summary):
		latest_line = "Continue Latest: %s | %s" % [
			SaveService.describe_resume_brief(latest_summary),
			SaveService.format_modified_timestamp(int(latest_summary.get("modified_timestamp", 0))),
		]
		play_check = SaveService.describe_summary_play_check(latest_summary)
	var resume_handoff := SaveService.describe_summary_resume_handoff(latest_summary) if SaveService.can_load_summary(latest_summary) else ""

	var lines := [
		"Manual %d + autosave" % SaveService.get_manual_slot_ids().size(),
		latest_line,
	]
	if play_check != "":
		lines.append(play_check)
	if resume_handoff != "":
		lines.append(resume_handoff)
	return "\n".join(lines)

func _build_footer_expedition_summary() -> String:
	var lines := [ScenarioSelectRulesScript.build_current_session_summary(SessionState.ensure_active_session())]
	lines.append(String(_continue_check_surface().get("visible_text", "")))
	lines.append(String(_quit_check_surface().get("visible_text", "")))
	var latest_summary := _active_save_board_latest_summary()
	if SaveService.can_load_summary(latest_summary):
		lines.append("Latest save: %s" % SaveService.describe_resume_brief(latest_summary))
		lines.append(SaveService.describe_summary_play_check(latest_summary))
		lines.append(SaveService.describe_summary_resume_handoff(latest_summary))
	return "\n".join(lines)

func _select_menu_tab(index: int) -> void:
	if _menu_tabs.get_tab_count() == 0:
		return
	if index != TAB_GUIDE:
		_last_context_tab = clampi(index, 0, _menu_tabs.get_tab_count() - 1)
	_menu_tabs.current_tab = clampi(index, 0, _menu_tabs.get_tab_count() - 1)
	_refresh_stage_dock_header()
	_sync_command_button_styles()

func _toggle_stage_dock(index: int) -> void:
	var clamped_index := clampi(index, 0, maxi(_menu_tabs.get_tab_count() - 1, 0))
	if _stage_dock_panel.visible and _menu_tabs.current_tab == clamped_index:
		_hide_stage_dock()
		return
	_select_menu_tab(clamped_index)
	_show_stage_dock()

func _show_stage_dock() -> void:
	_stage_dock_panel.visible = true
	if _menu_tabs.current_tab == TAB_SAVES:
		_ensure_save_browser_loaded()
	_refresh_stage_dock_header()
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()

func _hide_stage_dock() -> void:
	_stage_dock_panel.visible = false
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()

func _refresh_stage_dock_header() -> void:
	var stage_copy: Dictionary = TAB_STAGE_COPY.get(_menu_tabs.current_tab, TAB_STAGE_COPY[TAB_CAMPAIGN])
	_set_compact_label(_stage_dock_title_label, String(stage_copy.get("title", "Command board")), 1, 48)
	_set_compact_label(_stage_dock_hint_label, String(stage_copy.get("hint", "")), 2, 92)
	if _menu_tabs.current_tab == TAB_GUIDE:
		var return_copy: Dictionary = TAB_STAGE_COPY.get(_last_context_tab, TAB_STAGE_COPY[TAB_CAMPAIGN])
		_stage_help_button.text = "Back"
		_stage_help_button.tooltip_text = "%s\n%s" % [
			"Return to %s without closing the secondary board." % String(return_copy.get("title", "the previous board")).to_lower(),
			String(_help_handoff_surface().get("tooltip_text", "")),
		]
	else:
		var topic_label := SettingsService.help_topic_label(_help_topic_for_tab(_menu_tabs.current_tab))
		_stage_help_button.text = "Guide"
		_stage_help_button.tooltip_text = "%s\nHelp handoff: opens reference only; Back returns to this secondary board." % [
			"Open the Field Manual to the %s topic for this board. This does not start, load, save, or change settings." % topic_label
		]
	_close_stage_dock_button.tooltip_text = _close_stage_dock_tooltip()

func _quit_check_surface() -> Dictionary:
	var resume_line := "Quit does not inspect, create, or update save slots from the first-view menu."
	var visible := "Quit check: closes client; save first for an updated resume."
	var tooltip := "Quit Check\n- Action: closes the client from the scenic menu.\n- Resume point: %s\n- Save first: use an in-run save or outcome save before quitting when the latest play state must be preserved.\n- Not changed: campaign progress, expedition saves, and device settings are not written by reading this cue." % resume_line
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
	}

func _continue_check_surface() -> Dictionary:
	var latest_summary := _active_save_board_latest_summary()
	if not SaveService.can_load_summary(latest_summary):
		return {
			"visible_text": "Load check: open Load to inspect saved expeditions.",
			"tooltip_text": "Load Check\n- Resume point: not inspected on the first-view menu.\n- Next: open Load to inspect saves, or start Campaign or Skirmish for a fresh expedition.\n- Boot boundary: reading this cue does not inspect save slots, load, save, route, or change campaign progression.",
		}
	var resume_label := SaveService.describe_resume_brief(latest_summary)
	var play_check := SaveService.describe_summary_play_check(latest_summary)
	var resume_handoff := SaveService.describe_summary_resume_handoff(latest_summary)
	var visible := "Continue check: Continue Latest opens %s." % resume_label
	var tooltip := "Continue Check\n- Action: Continue Latest loads %s.\n- %s\n- %s\n- Inspection: reading this cue or opening the menu does not load, save, route, or change campaign progression." % [
		resume_label,
		play_check,
		resume_handoff,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
	}

func _settings_handoff_surface() -> Dictionary:
	var visible := "Settings handoff: changes apply now; close returns to the scenic menu."
	var tooltip := "Settings Handoff\n- Applies: presentation, sound, and readability changes take effect immediately.\n- Saved to: device config.\n- Not changed: campaign progress and expedition saves.\n- Close: returns to the scenic first view with these settings still active."
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
	}

func _close_stage_dock_tooltip() -> String:
	if _menu_tabs.current_tab == TAB_SETTINGS:
		return _join_nonempty_lines([
			"Dismiss Settings and return to the clean scenic first view.",
			String(_settings_handoff_surface().get("tooltip_text", "")),
			SettingsService.describe_settings_persistence_check(),
		])
	return "Dismiss this secondary board and return to the clean scenic first view."

func validation_snapshot() -> Dictionary:
	var primary_campaign_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
	var selected_chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	var campaign_chapter_check := _campaign_chapter_check_payload(selected_chapter_action, primary_campaign_action)
	var selected_skirmish_setup := ScenarioSelectRulesScript.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	var skirmish_front_check := _skirmish_front_check_payload(selected_skirmish_setup)
	var selected_save_summary := _active_save_board_selected_summary()
	var latest_continue := _latest_continue_surface()
	var latest_summary := _active_save_board_latest_summary()
	var quit_check := _quit_check_surface()
	var continue_check := _continue_check_surface()
	return {
		"scene_path": scene_file_path,
		"stage_dock_visible": _stage_dock_panel.visible,
		"current_tab": _menu_tabs.current_tab,
		"first_view_command_surface": "painted_backdrop_hotspots",
		"first_view_commands": _first_view_command_labels(),
		"first_view_command_tooltips": _first_view_command_tooltips(),
		"stage_help_text": _stage_help_button.text,
		"stage_help_tooltip": _stage_help_button.tooltip_text,
		"close_stage_dock_tooltip": _close_stage_dock_button.tooltip_text,
		"stage_help_return_tab": _last_context_tab,
		"has_generated_command_spine": get_node_or_null("CommandSpinePanel") != null,
		"has_first_view_status_box": get_node_or_null("SpineStatusPanel") != null,
		"campaign_count": _campaign_entries.size(),
		"selected_campaign_id": _selected_campaign_id,
		"selected_campaign_scenario_id": _selected_campaign_scenario_id,
		"primary_campaign_action": primary_campaign_action.duplicate(true),
		"selected_chapter_action": selected_chapter_action.duplicate(true),
		"campaign_chapter_check": campaign_chapter_check.duplicate(true),
		"campaign_chapter_check_text": String(campaign_chapter_check.get("text", "")),
		"campaign_chapter_check_tooltip": String(campaign_chapter_check.get("tooltip_text", "")),
		"campaign_primary_text": _campaign_primary_button.text,
		"campaign_primary_tooltip": _campaign_primary_button.tooltip_text,
		"start_chapter_text": _start_chapter_button.text,
		"start_chapter_tooltip": _start_chapter_button.tooltip_text,
		"campaign_details": _campaign_details_label.text,
		"campaign_details_full": _campaign_details_label.tooltip_text,
		"campaign_arc_status": _campaign_arc_status_label.text,
		"campaign_arc_status_full": _campaign_arc_status_label.tooltip_text,
		"chapter_details": _chapter_details_label.text,
		"chapter_details_full": _chapter_details_label.tooltip_text,
		"campaign_commander_preview": _campaign_commander_preview_label.text,
		"campaign_commander_preview_full": _campaign_commander_preview_label.tooltip_text,
		"campaign_operational_board": _campaign_operational_board_label.text,
		"campaign_operational_board_full": _campaign_operational_board_label.tooltip_text,
		"save_count": _save_summaries.size(),
		"help_topic_id": _selected_help_topic_id,
		"help_items": _help_browser_item_labels(),
		"help_item_tooltips": _help_browser_item_tooltips(),
		"help_handoff": _help_handoff_surface(),
		"help_handoff_text": String(_help_handoff_surface().get("text", "")),
		"help_handoff_tooltip": String(_help_handoff_surface().get("tooltip_text", "")),
		"help_intro": _help_intro_label.text,
		"help_intro_full": _help_intro_label.tooltip_text,
		"help_details": _help_details_label.text,
		"help_details_full": _help_details_label.tooltip_text,
		"skirmish_count": _skirmish_entries.size(),
		"selected_skirmish_id": _selected_skirmish_id,
		"selected_difficulty": _selected_difficulty,
		"selected_skirmish_setup": selected_skirmish_setup.duplicate(true),
		"skirmish_front_check": skirmish_front_check.duplicate(true),
		"skirmish_front_check_text": String(skirmish_front_check.get("visible_text", "")),
		"skirmish_front_check_tooltip": String(skirmish_front_check.get("tooltip_text", "")),
		"skirmish_details": _skirmish_details_label.text,
		"skirmish_details_full": _skirmish_details_label.tooltip_text,
		"skirmish_setup": _setup_summary_label.text,
		"skirmish_setup_full": _setup_summary_label.tooltip_text,
		"generated_random_map_controls": _generated_random_map_control_snapshot(),
		"generated_random_map_setup": _generated_last_setup.duplicate(true),
		"generated_random_map_status": _generated_status_label.text,
		"generated_random_map_status_full": _generated_status_label.tooltip_text,
		"generated_random_map_provenance": _generated_provenance_label.text,
		"generated_random_map_provenance_full": _generated_provenance_label.tooltip_text,
		"start_generated_skirmish_text": _start_generated_skirmish_button.text,
		"start_generated_skirmish_tooltip": _start_generated_skirmish_button.tooltip_text,
		"start_generated_skirmish_enabled": not _start_generated_skirmish_button.disabled,
		"skirmish_commander_preview": _skirmish_commander_preview_label.text,
		"skirmish_commander_preview_full": _skirmish_commander_preview_label.tooltip_text,
		"skirmish_browser_item_tooltips": _skirmish_browser_item_tooltips(),
		"difficulty_summary": _difficulty_summary_label.text,
		"difficulty_summary_full": _difficulty_summary_label.tooltip_text,
		"start_skirmish_text": _start_skirmish_button.text,
		"start_skirmish_tooltip": _start_skirmish_button.tooltip_text,
		"start_skirmish_enabled": not _start_skirmish_button.disabled,
		"selected_save_key": _selected_save_key,
		"save_browser_loaded": _save_browser_loaded,
		"latest_save_summary": latest_summary,
		"selected_save_summary": selected_save_summary.duplicate(true),
		"latest_play_check": SaveService.describe_summary_play_check(latest_summary),
		"continue_check": continue_check.duplicate(true),
		"continue_check_text": String(continue_check.get("visible_text", "")),
		"continue_check_tooltip": String(continue_check.get("tooltip_text", "")),
		"selected_save_play_check": SaveService.describe_summary_play_check(selected_save_summary),
		"selected_save_browser_cue": SaveService.describe_slot_continuity_cue(selected_save_summary),
		"latest_resume_handoff": SaveService.describe_summary_resume_handoff(latest_summary),
		"selected_save_resume_handoff": SaveService.describe_summary_resume_handoff(selected_save_summary),
		"save_browser_items": _save_browser_item_labels(),
		"save_browser_item_tooltips": _save_browser_item_tooltips(),
		"save_details": _save_details_label.text,
		"save_details_full": _save_details_label.tooltip_text,
		"save_pulse": _build_save_pulse(),
		"save_pulse_full": _build_save_pulse(),
		"continue_text": String(latest_continue.get("text", "")),
		"continue_tooltip": String(latest_continue.get("tooltip", "")),
		"continue_enabled": bool(latest_continue.get("enabled", false)),
		"load_selected_text": _load_selected_button.text,
		"load_selected_tooltip": _load_selected_button.tooltip_text,
		"selected_save_command_tooltip": _selected_save_command_tooltip(selected_save_summary),
		"load_selected_enabled": not _load_selected_button.disabled,
		"settings_summary": _settings_summary_label.text,
		"settings_summary_full": _settings_summary_label.tooltip_text,
		"settings_persistence_check": SettingsService.describe_settings_persistence_check(),
		"settings_handoff_text": _settings_handoff_label.text,
		"settings_handoff_tooltip": _settings_handoff_label.tooltip_text,
		"quit_check": quit_check.duplicate(true),
		"quit_check_text": String(quit_check.get("visible_text", "")),
		"quit_check_tooltip": String(quit_check.get("tooltip_text", "")),
		"presentation_mode": SettingsService.presentation_mode_id(),
		"presentation_mode_tooltip": _presentation_mode_picker.tooltip_text,
		"presentation_resolution": SettingsService.presentation_resolution_id(),
		"presentation_resolution_size": SettingsService.presentation_resolution_size(),
		"presentation_resolution_options": SettingsService.build_resolution_options(),
		"presentation_resolution_tooltip": _resolution_picker.tooltip_text,
		"resolution_picker_items": _picker_item_labels(_resolution_picker),
		"master_volume_tooltip": _master_volume_slider.tooltip_text,
		"music_volume_tooltip": _music_volume_slider.tooltip_text,
		"large_text_tooltip": _large_text_toggle.tooltip_text,
		"reduce_motion_tooltip": _reduce_motion_toggle.tooltip_text,
		"summary": _summary_label.text,
		"active_expedition": _active_expedition_label.text,
		"active_expedition_full": _active_expedition_label.tooltip_text,
	}

func validation_generated_random_map_snapshot() -> Dictionary:
	return {
		"controls": _generated_random_map_control_snapshot(),
		"setup": _generated_last_setup.duplicate(true),
		"status": _generated_status_label.text,
		"status_full": _generated_status_label.tooltip_text,
		"provenance": _generated_provenance_label.text,
		"provenance_full": _generated_provenance_label.tooltip_text,
		"start_text": _start_generated_skirmish_button.text,
		"start_tooltip": _start_generated_skirmish_button.tooltip_text,
		"start_enabled": not _start_generated_skirmish_button.disabled,
		"generation_in_progress": _generated_generation_in_progress,
		"generation_stage": _generated_generation_stage.duplicate(true),
		"generation_yield_count": _generated_generation_yield_count,
		"generation_progress_visible": _generated_progress_bar.visible,
		"generation_progress_value": _generated_progress_bar.value,
		"generation_snapshots": _duplicate_stage_snapshots(),
	}

func _first_view_command_labels() -> Array:
	var labels := []
	for button in [_open_campaign_button, _open_skirmish_button, _open_saves_button, _open_settings_button, _open_editor_button, _quit_button]:
		if button is Button and button.visible:
			labels.append(String(button.text))
	return labels

func _first_view_command_tooltips() -> Dictionary:
	return {
		"Campaign": _open_campaign_button.tooltip_text,
		"Skirmish": _open_skirmish_button.tooltip_text,
		"Load": _open_saves_button.tooltip_text,
		"Settings": _open_settings_button.tooltip_text,
		"Editor": _open_editor_button.tooltip_text,
		"Quit": _quit_button.tooltip_text,
	}

func _save_browser_item_labels() -> Array:
	var labels := []
	for index in range(_save_list.get_item_count()):
		labels.append(_save_list.get_item_text(index))
	return labels

func _save_browser_item_tooltips() -> Array:
	var tooltips := []
	for index in range(_save_list.get_item_count()):
		tooltips.append(_save_list.get_item_tooltip(index))
	return tooltips

func _help_browser_item_labels() -> Array:
	var labels := []
	for index in range(_help_list.get_item_count()):
		labels.append(_help_list.get_item_text(index))
	return labels

func _help_browser_item_tooltips() -> Array:
	var tooltips := []
	for index in range(_help_list.get_item_count()):
		tooltips.append(_help_list.get_item_tooltip(index))
	return tooltips

func _skirmish_browser_item_tooltips() -> Array:
	var tooltips := []
	for index in range(_skirmish_list.get_item_count()):
		tooltips.append(_skirmish_list.get_item_tooltip(index))
	return tooltips

func _generated_random_map_control_snapshot() -> Dictionary:
	return {
		"seed": _generated_seed,
		"size_class_id": _generated_size_class_id,
		"size_class_label": ScenarioSelectRulesScript.random_map_size_class_label(_generated_size_class_id),
		"template_id": _generated_template_id,
		"profile_id": _generated_profile_id,
		"player_count": _generated_player_count,
		"water_mode": _generated_water_mode,
		"underground": _generated_underground,
		"retry_policy": ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true),
		"size_options": _picker_item_labels(_generated_size_picker),
		"template_options": _picker_item_labels(_generated_template_picker),
		"profile_options": _picker_item_labels(_generated_profile_picker),
		"player_count_options": _picker_item_labels(_generated_player_count_picker),
		"player_count_values": _picker_item_metadata_ints(_generated_player_count_picker),
		"water_options": _picker_item_labels(_generated_water_picker),
	}

func _picker_item_labels(picker: OptionButton) -> Array:
	var labels := []
	for index in range(picker.get_item_count()):
		labels.append(picker.get_item_text(index))
	return labels

func _picker_item_metadata_ints(picker: OptionButton) -> Array:
	var values := []
	for index in range(picker.get_item_count()):
		values.append(int(picker.get_item_metadata(index)))
	return values

func validation_open_campaign_stage() -> void:
	_select_menu_tab(TAB_CAMPAIGN)
	_show_stage_dock()

func validation_open_skirmish_stage() -> void:
	_select_menu_tab(TAB_SKIRMISH)
	_show_stage_dock()

func validation_open_saves_stage() -> void:
	_select_menu_tab(TAB_SAVES)
	_show_stage_dock()
	_ensure_save_browser_loaded()

func validation_open_contextual_guide_stage() -> void:
	_on_stage_help_pressed()

func validation_return_from_contextual_guide() -> void:
	if _menu_tabs.current_tab == TAB_GUIDE:
		_on_stage_help_pressed()

func validation_open_settings_stage() -> void:
	_select_menu_tab(TAB_SETTINGS)
	_show_stage_dock()
	_refresh_settings_panel()

func validation_select_skirmish(scenario_id: String) -> bool:
	for index in range(_skirmish_entries.size()):
		if String(_skirmish_entries[index].get("scenario_id", "")) != scenario_id:
			continue
		_skirmish_list.select(index)
		_on_skirmish_selected(index)
		return true
	return false

func validation_select_campaign(campaign_id: String) -> bool:
	for index in range(_campaign_entries.size()):
		if String(_campaign_entries[index].get("campaign_id", "")) != campaign_id:
			continue
		_campaign_list.select(index)
		_on_campaign_selected(index)
		return true
	return false

func validation_select_campaign_chapter(scenario_id: String) -> bool:
	for index in range(_campaign_chapter_entries.size()):
		if String(_campaign_chapter_entries[index].get("scenario_id", "")) != scenario_id:
			continue
		_chapter_list.select(index)
		_on_chapter_selected(index)
		return true
	return false

func validation_set_difficulty(difficulty_id: String) -> bool:
	var normalized := ScenarioSelectRulesScript.normalize_difficulty(difficulty_id)
	for index in range(_difficulty_picker.get_item_count()):
		if String(_difficulty_picker.get_item_metadata(index)) != normalized:
			continue
		_difficulty_picker.select(index)
		_on_difficulty_selected(index)
		return true
	return false

func validation_set_generated_seed(seed: String) -> bool:
	_generated_seed_edit.text = seed
	_on_generated_seed_changed(seed)
	return _generated_seed == seed.strip_edges()

func validation_select_generated_template(template_id: String) -> bool:
	for index in range(_generated_template_picker.get_item_count()):
		if String(_generated_template_picker.get_item_metadata(index)) != template_id:
			continue
		_generated_template_picker.select(index)
		_on_generated_template_selected(index)
		return true
	return false

func validation_select_generated_size_class(size_class_id: String) -> bool:
	for index in range(_generated_size_picker.get_item_count()):
		if String(_generated_size_picker.get_item_metadata(index)) != size_class_id:
			continue
		_generated_size_picker.select(index)
		_on_generated_size_selected(index)
		return true
	return false

func validation_select_generated_profile(profile_id: String) -> bool:
	for index in range(_generated_profile_picker.get_item_count()):
		if String(_generated_profile_picker.get_item_metadata(index)) != profile_id:
			continue
		_generated_profile_picker.select(index)
		_on_generated_profile_selected(index)
		return true
	return false

func validation_select_generated_player_count(player_count: int) -> bool:
	for index in range(_generated_player_count_picker.get_item_count()):
		if int(_generated_player_count_picker.get_item_metadata(index)) != player_count:
			continue
		_generated_player_count_picker.select(index)
		_on_generated_player_count_selected(index)
		return true
	return false

func validation_select_generated_water_mode(water_mode: String) -> bool:
	for index in range(_generated_water_picker.get_item_count()):
		if String(_generated_water_picker.get_item_metadata(index)) != water_mode:
			continue
		_generated_water_picker.select(index)
		_on_generated_water_selected(index)
		return true
	return false

func validation_set_generated_underground(enabled: bool) -> bool:
	_generated_underground_toggle.button_pressed = enabled
	_on_generated_underground_toggled(enabled)
	return _generated_underground == enabled

func validation_force_generated_random_map_config(config: Dictionary) -> Dictionary:
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		_selected_difficulty,
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	_generated_last_setup = setup.duplicate(true)
	_set_compact_label(_generated_status_label, String(setup.get("setup_summary", setup.get("failure_handoff", ""))), 2, 92)
	_set_compact_label(_generated_provenance_label, String(setup.get("failure_handoff", setup.get("setup_summary", ""))), 2, 118)
	_start_generated_skirmish_button.disabled = not bool(setup.get("ok", false))
	return setup

func validation_start_generated_skirmish() -> Dictionary:
	var requested_setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		_generated_random_map_config(),
		_selected_difficulty,
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	_generated_last_setup = requested_setup.duplicate(true)
	if bool(requested_setup.get("ok", false)):
		ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(requested_setup)
	else:
		_apply_generated_random_map_setup_surface(requested_setup)
	var active_session := SessionState.ensure_active_session()
	return {
		"requested_scenario_id": String(requested_setup.get("scenario_id", "")),
		"requested_seed": String(requested_setup.get("normalized_seed", "")),
		"started": bool(requested_setup.get("ok", false))
			and active_session.scenario_id == String(requested_setup.get("scenario_id", ""))
			and active_session.launch_mode == SessionState.LAUNCH_MODE_SKIRMISH
			and bool(active_session.flags.get("generated_random_map", false)),
		"active_scenario_id": active_session.scenario_id,
		"active_launch_mode": active_session.launch_mode,
		"active_generated_random_map": bool(active_session.flags.get("generated_random_map", false)),
		"active_retry_status": active_session.flags.get("generated_random_map_retry_status", {}),
		"active_provenance": active_session.flags.get("generated_random_map_provenance", {}),
	}

func validation_start_generated_skirmish_staged() -> Dictionary:
	var result: Dictionary = await _start_generated_skirmish_staged(false)
	return result

func validation_start_generated_skirmish_staged_route_to_overworld() -> Dictionary:
	var result: Dictionary = await _start_generated_skirmish_staged(true)
	return result

func validation_select_resolution(resolution_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_resolution_picker.get_item_count()):
		if String(_resolution_picker.get_item_metadata(index)) != resolution_id:
			continue
		_resolution_picker.select(index)
		_on_resolution_selected(index)
		return SettingsService.presentation_resolution_id() == resolution_id
	return false

func validation_select_save_summary(slot_type: String, slot_id: String) -> bool:
	validation_open_saves_stage()
	var requested_key := "%s:%s" % [slot_type, slot_id]
	for index in range(_save_summaries.size()):
		if _summary_key(_save_summaries[index]) != requested_key:
			continue
		_save_list.select(index)
		_on_save_selected(index)
		return true
	return false

func validation_resume_selected_save() -> Dictionary:
	var summary := _selected_summary()
	if summary.is_empty():
		return {"ok": false, "message": "No save summary is selected for validation resume."}
	var expected_scenario_id := String(summary.get("scenario_id", ""))
	var expected_resume_target := String(summary.get("resume_target", ""))
	var expected_game_state := _validation_expected_game_state_for_resume_target(expected_resume_target)
	var loadable := SaveService.can_load_summary(summary)
	_on_load_selected_pressed()
	var active_session := SessionState.ensure_active_session()
	return {
		"ok": loadable
			and active_session.scenario_id == expected_scenario_id
			and SaveService.resume_target_for_session(active_session) == expected_resume_target
			and active_session.game_state == expected_game_state,
		"selected_key": _summary_key(summary),
		"scenario_id": expected_scenario_id,
		"resume_target": expected_resume_target,
		"game_state": expected_game_state,
		"active_scenario_id": active_session.scenario_id,
		"active_resume_target": SaveService.resume_target_for_session(active_session),
		"active_game_state": active_session.game_state,
		"active_battle_empty": active_session.battle.is_empty(),
	}

func validation_resume_latest() -> Dictionary:
	var summary := SaveService.latest_loadable_summary()
	if summary.is_empty():
		return {"ok": false, "message": "No latest save summary is available for validation resume."}
	var expected_scenario_id := String(summary.get("scenario_id", ""))
	var expected_resume_target := String(summary.get("resume_target", ""))
	var expected_game_state := _validation_expected_game_state_for_resume_target(expected_resume_target)
	var loadable := SaveService.can_load_summary(summary)
	AppRouter.resume_latest_session()
	var active_session := SessionState.ensure_active_session()
	return {
		"ok": loadable
			and active_session.scenario_id == expected_scenario_id
			and SaveService.resume_target_for_session(active_session) == expected_resume_target
			and active_session.game_state == expected_game_state,
		"selected_key": _summary_key(summary),
		"scenario_id": expected_scenario_id,
		"resume_target": expected_resume_target,
		"game_state": expected_game_state,
		"active_scenario_id": active_session.scenario_id,
		"active_resume_target": SaveService.resume_target_for_session(active_session),
		"active_game_state": active_session.game_state,
		"active_battle_empty": active_session.battle.is_empty(),
	}

func _validation_expected_game_state_for_resume_target(resume_target: String) -> String:
	match resume_target:
		"battle":
			return "battle"
		"town":
			return "town"
		"outcome":
			return "outcome"
		_:
			return "overworld"

func validation_start_selected_skirmish() -> Dictionary:
	var requested_scenario_id := _selected_skirmish_id
	var requested_difficulty := _selected_difficulty
	_on_start_skirmish_pressed()
	var active_session := SessionState.ensure_active_session()
	return {
		"requested_scenario_id": requested_scenario_id,
		"requested_difficulty": requested_difficulty,
		"started": active_session.scenario_id == requested_scenario_id
			and active_session.difficulty == requested_difficulty
			and active_session.launch_mode == SessionState.LAUNCH_MODE_SKIRMISH,
		"active_scenario_id": active_session.scenario_id,
		"active_difficulty": active_session.difficulty,
		"active_launch_mode": active_session.launch_mode,
	}

func validation_start_selected_campaign_chapter() -> Dictionary:
	var requested_campaign_id := _selected_campaign_id
	var requested_scenario_id := _selected_campaign_scenario_id
	var action := CampaignProgression.chapter_action(requested_campaign_id, requested_scenario_id)
	var action_disabled := _start_chapter_button.disabled or bool(action.get("disabled", false))
	_on_start_chapter_pressed()
	var active_session := SessionState.ensure_active_session()
	var active_campaign_id := String(active_session.flags.get("campaign_id", ""))
	return {
		"requested_campaign_id": requested_campaign_id,
		"requested_scenario_id": requested_scenario_id,
		"action_disabled": action_disabled,
		"started": not action_disabled
			and active_session.scenario_id == requested_scenario_id
			and active_session.launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN
			and active_campaign_id == requested_campaign_id,
		"active_scenario_id": active_session.scenario_id,
		"active_difficulty": active_session.difficulty,
		"active_launch_mode": active_session.launch_mode,
		"active_campaign_id": active_campaign_id,
		"active_campaign_name": String(active_session.flags.get("campaign_name", "")),
		"active_campaign_chapter_label": String(active_session.flags.get("campaign_chapter_label", "")),
	}

func _sync_command_button_styles() -> void:
	var tab_buttons := {
		TAB_CAMPAIGN: [_open_campaign_button],
		TAB_SKIRMISH: [_open_skirmish_button],
		TAB_SAVES: [_open_saves_button],
		TAB_SETTINGS: [_open_settings_button],
	}
	for tab_index in tab_buttons.keys():
		for button in tab_buttons[tab_index]:
			var is_active: bool = _stage_dock_panel.visible and _menu_tabs.current_tab == tab_index
			_apply_backdrop_plaque_button(button, is_active, false)

func _sync_system_command_buttons() -> void:
	_apply_backdrop_plaque_button(_open_editor_button, false, false)
	_apply_backdrop_plaque_button(_quit_button, false, true)

func _sync_first_view_command_tooltips() -> void:
	_open_campaign_button.tooltip_text = (
		"Command cue: Campaign opens the campaign board for arcs, carryover, and chapter launch handoffs. "
		+ "It does not start a chapter until a campaign action is chosen."
	)
	_open_skirmish_button.tooltip_text = (
		"Command cue: Skirmish opens the front charter for scenario, difficulty, and launch readiness. "
		+ "Fresh skirmishes do not change campaign progression."
	)
	_open_saves_button.tooltip_text = _first_view_load_tooltip()
	_open_settings_button.tooltip_text = (
		"Command cue: Settings opens presentation, sound, and readability controls. "
		+ "Changes apply to device config; expedition saves and campaign progress stay unchanged."
	)
	_open_editor_button.tooltip_text = (
		"Command cue: Editor opens map-editing tooling and Play Copy checks. "
		+ "Use it for scenario inspection or smoke-test handoff, not to resume a save."
	)
	_quit_button.tooltip_text = (
		"Command cue: Quit closes the client.\n%s" % String(_quit_check_surface().get("tooltip_text", ""))
	)

func _first_view_load_tooltip() -> String:
	var lines := [
		"Command cue: Load opens the war ledger and inspects save slots only after this command is chosen.",
		"Load Selected stays unavailable until a save row is inspected and selected.",
	]
	lines.append(String(_continue_check_surface().get("tooltip_text", "")))
	lines.append("No save summary is read for this first-view tooltip.")
	return "\n".join(lines)

func _help_topic_for_tab(tab_index: int) -> String:
	return String(TAB_HELP_TOPIC.get(tab_index, SettingsService.default_help_topic_id()))

func _apply_backdrop_plaque_button(button: BaseButton, active: bool, danger: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 19 if not danger else 18)
	var normal_color := Color(0.95, 0.94, 0.88, 1.0)
	var highlight_color := Color(1.0, 0.91, 0.60, 1.0)
	var pressed_color := Color(0.98, 0.82, 0.50, 1.0)
	if danger:
		highlight_color = Color(1.0, 0.72, 0.62, 1.0)
		pressed_color = Color(1.0, 0.61, 0.50, 1.0)
	button.add_theme_color_override("font_color", highlight_color if active else normal_color)
	button.add_theme_color_override("font_hover_color", highlight_color)
	button.add_theme_color_override("font_pressed_color", pressed_color)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.50, 0.53))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.92))
	button.add_theme_constant_override("outline_size", 4)
	var transparent_style := _plaque_button_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0)
	button.add_theme_stylebox_override("normal", transparent_style.duplicate())
	button.add_theme_stylebox_override("hover", transparent_style.duplicate())
	button.add_theme_stylebox_override("pressed", transparent_style.duplicate())
	button.add_theme_stylebox_override("disabled", transparent_style.duplicate())

func _plaque_button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _stage_dock_panel.visible:
		_hide_stage_dock()
		get_viewport().set_input_as_handled()

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 84) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars)

func _apply_visual_theme() -> void:
	var panel_tones := {
		"LogoPocketPanel": "smoke",
		"StageDockPanel": "smoke",
		"FooterPocketPanel": "smoke",
		"CampaignListPanel": "smoke",
		"CampaignDetailsPanel": "smoke",
		"ChapterListPanel": "smoke",
		"ChapterDetailsPanel": "smoke",
		"CommanderPreviewPanel": "smoke",
		"OperationalBoardPanel": "smoke",
		"JournalPanel": "smoke",
		"DifficultyPanel": "smoke",
		"GeneratedMapPanel": "smoke",
		"SkirmishListPanel": "smoke",
		"SkirmishBriefPanel": "smoke",
		"SkirmishCommanderPanel": "smoke",
		"SkirmishOperationalPanel": "smoke",
		"SaveListPanel": "smoke",
		"SaveDetailPanel": "smoke",
		"GuidePanel": "smoke",
		"SettingsPanel": "smoke",
		"MasterVolumePanel": "teal",
		"MusicVolumePanel": "blue",
	}
	for panel in find_children("*", "PanelContainer", true, false):
		if panel is PanelContainer and panel.name.ends_with("Panel"):
			FrontierVisualKit.apply_panel(panel, String(panel_tones.get(panel.name, "ink")))

	FrontierVisualKit.apply_tab_container(_menu_tabs, "smoke")

	for list in [_campaign_list, _chapter_list, _skirmish_list, _help_list, _save_list]:
		FrontierVisualKit.apply_item_list(list, "smoke")

	FrontierVisualKit.apply_button(_stage_help_button, "secondary", 96.0, 34.0, 13)
	FrontierVisualKit.apply_button(_close_stage_dock_button, "secondary", 112.0, 34.0, 13)
	FrontierVisualKit.apply_button(_campaign_primary_button, "primary", 208.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_chapter_button, "secondary", 176.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_skirmish_button, "primary", 188.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_generated_skirmish_button, "primary", 176.0, 34.0, 13)
	FrontierVisualKit.apply_button(_load_selected_button, "primary", 184.0, 38.0, 14)
	_sync_command_button_styles()
	_sync_system_command_buttons()

	for picker in [
		_difficulty_picker,
		_generated_template_picker,
		_generated_profile_picker,
		_generated_player_count_picker,
		_generated_water_picker,
		_presentation_mode_picker,
		_resolution_picker,
	]:
		FrontierVisualKit.apply_option_button(picker, "secondary", maxf(picker.custom_minimum_size.x, 176.0), 34.0, 13)

	for toggle in [_generated_underground_toggle, _large_text_toggle, _reduce_motion_toggle]:
		FrontierVisualKit.apply_button(toggle, "secondary", 180.0, 34.0, 13)

	for slider in [_master_volume_slider, _music_volume_slider]:
		FrontierVisualKit.apply_range(slider, "gold")

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body", 13)

	for title_label in find_children("*Title", "Label", true, false):
		if title_label is Label:
			FrontierVisualKit.apply_label(title_label, "title", 14)

	for node_name in ["CampaignTitle", "SkirmishTitle"]:
		var feature_title = find_child(node_name, true, false)
		if feature_title is Label:
			FrontierVisualKit.apply_label(feature_title, "title", 20)

	for node_name in [
		"GuideTitle",
		"SettingsTitle",
		"CampaignArcTitle",
		"CommanderPreviewTitle",
		"OperationalBoardTitle",
		"JournalTitle",
		"SkirmishCommanderPreviewTitle",
		"SkirmishOperationalBoardTitle",
	]:
		var section_title = find_child(node_name, true, false)
		if section_title is Label:
			FrontierVisualKit.apply_label(section_title, "title", 16)

	FrontierVisualKit.apply_label(_eyebrow_label, "gold", 14)
	FrontierVisualKit.apply_label(_title_label, "title", 38)
	FrontierVisualKit.apply_label(_subtitle_label, "body", 14)
	FrontierVisualKit.apply_label(_summary_label, "body", 15)
	FrontierVisualKit.apply_label(_stage_dock_title_label, "title", 18)
	FrontierVisualKit.apply_label(_stage_dock_hint_label, "muted", 13)
	FrontierVisualKit.apply_label(_active_expedition_label, "body", 13)
	FrontierVisualKit.apply_label(_master_volume_value, "gold", 13)
	FrontierVisualKit.apply_label(_music_volume_value, "gold", 13)
