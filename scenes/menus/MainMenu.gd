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

@onready var _menu_tabs: TabContainer = %MenuTabs
@onready var _stage_dock_panel: PanelContainer = $StageDockPanel
@onready var _stage_dock_title_label: Label = %ActionLead
@onready var _stage_dock_hint_label: Label = %ActionHint
@onready var _close_stage_dock_button: Button = %CloseStageDock
@onready var _eyebrow_label: Label = %Eyebrow
@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _summary_label: Label = %Summary
@onready var _active_expedition_label: Label = %ActiveExpedition
@onready var _campaign_pulse_label: Label = %CampaignPulse
@onready var _save_pulse_label: Label = %SavePulse
@onready var _continue_button: Button = %Continue
@onready var _menu_button: Button = %Menu
@onready var _quit_button: Button = %Quit
@onready var _open_campaign_button: Button = %OpenCampaign
@onready var _open_skirmish_button: Button = %OpenSkirmish
@onready var _open_saves_button: Button = %OpenSaves
@onready var _open_guide_button: Button = %OpenGuide
@onready var _open_settings_button: Button = %OpenSettings
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
@onready var _skirmish_commander_preview_label: Label = %SkirmishCommanderPreview
@onready var _skirmish_operational_board_label: Label = %SkirmishOperationalBoard
@onready var _start_skirmish_button: Button = %StartSkirmish
@onready var _help_intro_label: Label = %HelpIntro
@onready var _help_list: ItemList = %HelpList
@onready var _help_details_label: Label = %HelpDetails
@onready var _settings_summary_label: Label = %SettingsSummary
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
var _campaign_entries: Array = []
var _selected_campaign_id := ""
var _campaign_chapter_entries: Array = []
var _selected_campaign_scenario_id := ""
var _skirmish_entries: Array = []
var _selected_skirmish_id := ""
var _selected_difficulty: String = ScenarioSelectRulesScript.default_difficulty_id()
var _help_entries: Array = []
var _selected_help_topic_id := ""
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
	_rebuild_save_browser()
	_update_continue_enabled()
	_rebuild_campaign_browser()
	_configure_difficulty_picker()
	_rebuild_skirmish_browser()
	_refresh_skirmish_setup()
	_rebuild_help_browser()
	_refresh_settings_panel()
	_refresh_stage_dock_header()
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()

func _update_continue_enabled() -> void:
	var latest_summary := SaveService.latest_loadable_summary()
	_continue_button.text = SaveService.continue_action_label(latest_summary)
	_continue_button.disabled = latest_summary.is_empty()
	_continue_button.tooltip_text = SaveService.load_action_tooltip(latest_summary)

func _refresh_summary() -> void:
	var lead := _menu_notice
	if lead == "":
		if _stage_dock_panel.visible:
			lead = "The command board is open. Review detail here, then close it to return to the scenic front."
		else:
			lead = "First view stays scenic. Open deeper boards from the right spine when needed."
	_set_compact_label(_summary_label, lead, 3, 84)
	_set_compact_label(
		_active_expedition_label,
		ScenarioSelectRulesScript.build_current_session_summary(SessionState.ensure_active_session()),
		4,
		84
	)
	_set_compact_label(_campaign_pulse_label, _build_campaign_pulse(), 2, 80)
	_set_compact_label(_save_pulse_label, _build_save_pulse(), 2, 80)

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

func _on_open_guide_pressed() -> void:
	_toggle_stage_dock(TAB_GUIDE)

func _on_open_settings_pressed() -> void:
	_toggle_stage_dock(TAB_SETTINGS)

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

func _on_start_skirmish_pressed() -> void:
	if _start_skirmish_button.disabled:
		return
	var session := ScenarioSelectRulesScript.start_skirmish_session(_selected_skirmish_id, _selected_difficulty)
	if session.scenario_id == "":
		_refresh_menu()
		return
	_refresh_menu()
	AppRouter.go_to_overworld()

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

	_set_compact_label(
		_chapter_details_label,
		CampaignProgression.chapter_details(_selected_campaign_id, _selected_campaign_scenario_id),
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

	var chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	_start_chapter_button.text = String(chapter_action.get("label", "Start Chapter"))
	_start_chapter_button.disabled = bool(chapter_action.get("disabled", false))
	_start_chapter_button.tooltip_text = String(chapter_action.get("summary", ""))

func _rebuild_help_browser() -> void:
	_set_compact_label(_help_intro_label, SettingsService.help_browser_summary(), 3, 84)
	_help_entries = SettingsService.build_help_topics()
	_help_list.clear()

	var preferred_help_topic_id := _selected_help_topic_id
	if preferred_help_topic_id == "":
		preferred_help_topic_id = SettingsService.default_help_topic_id()

	var selected_index := -1
	for index in range(_help_entries.size()):
		var entry = _help_entries[index]
		_help_list.add_item(String(entry.get("label", entry.get("id", "Topic"))))
		if String(entry.get("id", "")) == preferred_help_topic_id:
			selected_index = index

	if selected_index < 0 and not _help_entries.is_empty():
		selected_index = 0

	if selected_index >= 0 and selected_index < _help_entries.size():
		_help_list.select(selected_index)
		_selected_help_topic_id = String(_help_entries[selected_index].get("id", ""))
	else:
		_selected_help_topic_id = ""

	_refresh_help_browser()

func _refresh_help_browser() -> void:
	if _help_entries.is_empty():
		_set_compact_label(_help_details_label, "No guide entries are available.", 2, 84)
		return

	if _selected_help_topic_id == "":
		_selected_help_topic_id = String(_help_entries[0].get("id", ""))
		_help_list.select(0)

	_set_compact_label(_help_details_label, SettingsService.describe_help_topic(_selected_help_topic_id), 7, 88)

func _refresh_settings_panel() -> void:
	_set_compact_label(_settings_summary_label, SettingsService.describe_settings(), 4, 84)

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
		_presentation_mode_picker.tooltip_text = String(options[selected_index].get("summary", ""))

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
		_resolution_picker.tooltip_text = String(resolution_options[selected_resolution_index].get("summary", ""))

	_master_volume_slider.value = SettingsService.master_volume_percent()
	_master_volume_value.text = "%d%%" % SettingsService.master_volume_percent()
	_music_volume_slider.value = SettingsService.music_volume_percent()
	_music_volume_value.text = "%d%%" % SettingsService.music_volume_percent()
	_large_text_toggle.button_pressed = SettingsService.large_ui_text_enabled()
	_reduce_motion_toggle.button_pressed = SettingsService.reduced_motion_enabled()
	_syncing_settings_ui = false

func _rebuild_save_browser() -> void:
	_save_summaries = SaveService.list_session_summaries()
	_save_list.clear()

	var latest_key := _summary_key(SaveService.latest_loadable_summary())
	var selected_index := -1
	for index in range(_save_summaries.size()):
		var summary: Dictionary = _save_summaries[index]
		var label := SaveService.describe_slot(summary)
		if _summary_key(summary) == latest_key and SaveService.can_load_summary(summary):
			label = "%s | Latest" % label
		_save_list.add_item(label)
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
		_load_selected_button.tooltip_text = "Select a loadable save to resume it."
		return

	_set_compact_label(_save_details_label, SaveService.describe_slot_details(summary), 6, 88)
	_load_selected_button.text = SaveService.load_action_label(summary)
	_load_selected_button.disabled = not SaveService.can_load_summary(summary)
	_load_selected_button.tooltip_text = SaveService.load_action_tooltip(summary)

func _default_selected_save_index() -> int:
	var latest_key := _summary_key(SaveService.latest_loadable_summary())
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

func _summary_key(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	return "%s:%s" % [String(summary.get("slot_type", "")), String(summary.get("slot_id", ""))]

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

func _rebuild_skirmish_browser() -> void:
	_skirmish_entries = ScenarioSelectRulesScript.build_skirmish_browser_entries()
	_skirmish_list.clear()

	var selected_index := -1
	for index in range(_skirmish_entries.size()):
		var entry = _skirmish_entries[index]
		_skirmish_list.add_item(String(entry.get("label", entry.get("scenario_id", "Scenario"))))
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

	var recommended_difficulty := String(setup.get("recommended_difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	if recommended_difficulty != _selected_difficulty:
		_set_compact_label(
			_difficulty_summary_label,
			"%s\nRecommended: %s." % [
				ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty),
				String(setup.get("recommended_difficulty_label", "")),
			],
			3,
			82
		)

	_set_compact_label(_setup_summary_label, String(setup.get("setup_summary", "")), 3, 84)
	_set_compact_label(_skirmish_commander_preview_label, String(setup.get("commander_preview", "Commander preview unavailable.")), 4, 84)
	_set_compact_label(_skirmish_operational_board_label, String(setup.get("operational_board", "Operational board unavailable.")), 4, 84)
	_start_skirmish_button.disabled = false
	_start_skirmish_button.text = "Launch Skirmish"
	_start_skirmish_button.tooltip_text = "Launch %s at %s difficulty." % [
		String(setup.get("scenario_name", _selected_skirmish_id)),
		String(setup.get("difficulty_label", ScenarioSelectRulesScript.difficulty_label(_selected_difficulty))),
	]

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
	var latest_summary := SaveService.latest_loadable_summary()
	var latest_line := "No active resume point."
	if not latest_summary.is_empty():
		latest_line = SaveService.describe_slot(latest_summary)

	return "\n".join(
		[
			"Manual %d + autosave" % SaveService.get_manual_slot_ids().size(),
			latest_line,
		]
	)

func _select_menu_tab(index: int) -> void:
	if _menu_tabs.get_tab_count() == 0:
		return
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
	_close_stage_dock_button.tooltip_text = "Dismiss this secondary board and return to the clean scenic first view."

func validation_snapshot() -> Dictionary:
	var primary_campaign_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
	var selected_chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	var selected_save_summary := _selected_summary()
	return {
		"scene_path": scene_file_path,
		"stage_dock_visible": _stage_dock_panel.visible,
		"current_tab": _menu_tabs.current_tab,
		"campaign_count": _campaign_entries.size(),
		"selected_campaign_id": _selected_campaign_id,
		"selected_campaign_scenario_id": _selected_campaign_scenario_id,
		"primary_campaign_action": primary_campaign_action.duplicate(true),
		"selected_chapter_action": selected_chapter_action.duplicate(true),
		"campaign_details": _campaign_details_label.text,
		"campaign_details_full": _campaign_details_label.tooltip_text,
		"campaign_arc_status": _campaign_arc_status_label.text,
		"campaign_arc_status_full": _campaign_arc_status_label.tooltip_text,
		"chapter_details": _chapter_details_label.text,
		"chapter_details_full": _chapter_details_label.tooltip_text,
		"save_count": _save_summaries.size(),
		"skirmish_count": _skirmish_entries.size(),
		"selected_skirmish_id": _selected_skirmish_id,
		"selected_difficulty": _selected_difficulty,
		"selected_save_key": _selected_save_key,
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"selected_save_summary": selected_save_summary.duplicate(true),
		"save_browser_items": _save_browser_item_labels(),
		"save_details": _save_details_label.text,
		"save_details_full": _save_details_label.tooltip_text,
		"save_pulse": _save_pulse_label.text,
		"save_pulse_full": _save_pulse_label.tooltip_text,
		"continue_text": _continue_button.text,
		"continue_tooltip": _continue_button.tooltip_text,
		"continue_enabled": not _continue_button.disabled,
		"load_selected_text": _load_selected_button.text,
		"load_selected_tooltip": _load_selected_button.tooltip_text,
		"load_selected_enabled": not _load_selected_button.disabled,
		"settings_summary": _settings_summary_label.text,
		"settings_summary_full": _settings_summary_label.tooltip_text,
		"presentation_mode": SettingsService.presentation_mode_id(),
		"presentation_resolution": SettingsService.presentation_resolution_id(),
		"presentation_resolution_size": SettingsService.presentation_resolution_size(),
		"presentation_resolution_options": SettingsService.build_resolution_options(),
		"resolution_picker_items": _picker_item_labels(_resolution_picker),
		"summary": _summary_label.text,
	}

func _save_browser_item_labels() -> Array:
	var labels := []
	for index in range(_save_list.get_item_count()):
		labels.append(_save_list.get_item_text(index))
	return labels

func _picker_item_labels(picker: OptionButton) -> Array:
	var labels := []
	for index in range(picker.get_item_count()):
		labels.append(picker.get_item_text(index))
	return labels

func validation_open_campaign_stage() -> void:
	_select_menu_tab(TAB_CAMPAIGN)
	_show_stage_dock()

func validation_open_skirmish_stage() -> void:
	_select_menu_tab(TAB_SKIRMISH)
	_show_stage_dock()

func validation_open_saves_stage() -> void:
	_select_menu_tab(TAB_SAVES)
	_show_stage_dock()
	_rebuild_save_browser()

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
	_on_continue_pressed()
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
		TAB_GUIDE: [_open_guide_button],
		TAB_SETTINGS: [_open_settings_button],
	}
	for tab_index in tab_buttons.keys():
		for button in tab_buttons[tab_index]:
			var is_active: bool = _stage_dock_panel.visible and _menu_tabs.current_tab == tab_index
			var role := "spine_active" if is_active else "spine"
			FrontierVisualKit.apply_button(button, role, 182.0, 42.0, 15)

func _sync_system_command_buttons() -> void:
	_menu_button.disabled = not _stage_dock_panel.visible
	_menu_button.tooltip_text = "Return to the clean scenic menu view." if _stage_dock_panel.visible else "The clean scenic menu view is already showing."
	FrontierVisualKit.apply_button(_menu_button, "secondary", 162.0, 36.0, 13)
	FrontierVisualKit.apply_button(_quit_button, "danger", 162.0, 36.0, 13)

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
		"CommandSpinePanel": "clear",
		"SpineStatusPanel": "smoke",
		"CommandBlockPanel": "smoke",
		"CampaignListPanel": "smoke",
		"CampaignDetailsPanel": "smoke",
		"ChapterListPanel": "smoke",
		"ChapterDetailsPanel": "smoke",
		"CommanderPreviewPanel": "smoke",
		"OperationalBoardPanel": "smoke",
		"JournalPanel": "smoke",
		"DifficultyPanel": "smoke",
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

	FrontierVisualKit.apply_button(_continue_button, "spine_active", 182.0, 46.0, 16)
	FrontierVisualKit.apply_button(_close_stage_dock_button, "secondary", 112.0, 34.0, 13)
	FrontierVisualKit.apply_button(_campaign_primary_button, "primary", 208.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_chapter_button, "secondary", 176.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_skirmish_button, "primary", 188.0, 40.0, 14)
	FrontierVisualKit.apply_button(_load_selected_button, "primary", 184.0, 38.0, 14)
	_sync_command_button_styles()
	_sync_system_command_buttons()

	for picker in [_difficulty_picker, _presentation_mode_picker, _resolution_picker]:
		FrontierVisualKit.apply_option_button(picker, "secondary", maxf(picker.custom_minimum_size.x, 176.0), 34.0, 13)

	for toggle in [_large_text_toggle, _reduce_motion_toggle]:
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
		"SpineHeader",
		"CommandBlockTitle",
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
	FrontierVisualKit.apply_label(_campaign_pulse_label, "body", 13)
	FrontierVisualKit.apply_label(_save_pulse_label, "muted", 13)
	FrontierVisualKit.apply_label(_master_volume_value, "gold", 13)
	FrontierVisualKit.apply_label(_music_volume_value, "gold", 13)
