extends Control

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _menu_tabs: TabContainer = %MenuTabs
@onready var _summary_label: Label = %Summary
@onready var _active_expedition_label: Label = %ActiveExpedition
@onready var _campaign_pulse_label: Label = %CampaignPulse
@onready var _save_pulse_label: Label = %SavePulse
@onready var _continue_button: Button = %Continue
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
	_apply_visual_theme()
	CampaignProgression.ensure_profile()
	SettingsService.ensure_settings()
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
	_refresh_summary()

func _update_continue_enabled() -> void:
	var latest_summary := SaveService.latest_loadable_summary()
	_continue_button.text = SaveService.continue_action_label(latest_summary)
	_continue_button.disabled = latest_summary.is_empty()
	_continue_button.tooltip_text = SaveService.load_action_tooltip(latest_summary)

func _refresh_summary() -> void:
	var lines := []
	if _menu_notice != "":
		lines.append(_menu_notice)
	else:
		lines.append("Command the frontier from a single war table: launch authored campaigns, open skirmish fronts, or resume the latest expedition without dropping into tool-like menu stacks.")
	lines.append("Campaign progression, expedition saves, and device settings remain on separate tracks.")
	_set_compact_label(_summary_label, "\n".join(lines), 3)
	_set_compact_label(_active_expedition_label, ScenarioSelectRulesScript.build_current_session_summary(SessionState.ensure_active_session()), 4)
	_set_compact_label(_campaign_pulse_label, _build_campaign_pulse(), 3)
	_set_compact_label(_save_pulse_label, _build_save_pulse(), 3)

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

func _on_open_play_pressed() -> void:
	_menu_tabs.current_tab = 0

func _on_open_guide_pressed() -> void:
	_menu_tabs.current_tab = 1

func _on_open_settings_pressed() -> void:
	_menu_tabs.current_tab = 2

func _on_open_saves_pressed() -> void:
	_menu_tabs.current_tab = 3

func _on_save_selected(index: int) -> void:
	if index < 0 or index >= _save_summaries.size():
		return
	_selected_save_key = _summary_key(_save_summaries[index])
	_refresh_selected_save()

func _on_load_selected_pressed() -> void:
	if not AppRouter.resume_summary(_selected_summary()):
		_refresh_menu()

func _resume_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		_refresh_menu()
		return

	if not AppRouter.resume_summary(summary):
		_refresh_menu()
		return

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
		_set_compact_label(_campaign_details_label, "No authored campaigns are available.", 3)
		_set_compact_label(_campaign_arc_status_label, "Campaign arc goals and finale state appear here once a campaign is selected.", 3)
		_set_compact_label(_chapter_details_label, "No campaign chapters are authored.", 3)
		_set_compact_label(_campaign_commander_preview_label, "Select a chapter to preview commander, spellbook, relics, and opening army.", 4)
		_set_compact_label(_campaign_operational_board_label, "Select a chapter to review terrain, enemy posture, objective pressure, and first-contact risk.", 4)
		_set_compact_label(_campaign_journal_label, "Campaign chronicle entries appear here once a chapter record exists.", 4)
		_campaign_primary_button.text = "No Campaign Available"
		_campaign_primary_button.disabled = true
		_campaign_primary_button.tooltip_text = "Author a campaign to launch it from this menu."
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or retry."
		return

	_set_compact_label(_campaign_details_label, CampaignProgression.campaign_details(_selected_campaign_id), 5)
	_set_compact_label(_campaign_arc_status_label, CampaignProgression.campaign_arc_status(_selected_campaign_id), 4)
	_set_compact_label(_campaign_journal_label, CampaignProgression.campaign_journal(_selected_campaign_id), 4)

	var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
	_campaign_primary_button.text = String(primary_action.get("label", "Start Next Chapter"))
	_campaign_primary_button.disabled = bool(primary_action.get("disabled", false))
	_campaign_primary_button.tooltip_text = String(primary_action.get("summary", ""))

	if _selected_campaign_scenario_id == "":
		_set_compact_label(_chapter_details_label, "Select a chapter to review its unlock state, carryover, and last result.", 4)
		_set_compact_label(_campaign_commander_preview_label, "Select a chapter to preview commander, spellbook, relics, and opening army.", 4)
		_set_compact_label(_campaign_operational_board_label, "Select a chapter to review terrain, enemy posture, objective pressure, and first-contact risk.", 4)
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or retry."
		return

	_set_compact_label(_chapter_details_label, CampaignProgression.chapter_details(_selected_campaign_id, _selected_campaign_scenario_id), 5)
	_set_compact_label(_campaign_commander_preview_label, CampaignProgression.chapter_commander_preview(
		_selected_campaign_id,
		_selected_campaign_scenario_id
	), 4)
	_set_compact_label(_campaign_operational_board_label, CampaignProgression.chapter_operational_board(
		_selected_campaign_id,
		_selected_campaign_scenario_id
	), 4)
	var chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	_start_chapter_button.text = String(chapter_action.get("label", "Start Chapter"))
	_start_chapter_button.disabled = bool(chapter_action.get("disabled", false))
	_start_chapter_button.tooltip_text = String(chapter_action.get("summary", ""))

func _rebuild_help_browser() -> void:
	_set_compact_label(_help_intro_label, SettingsService.help_browser_summary(), 4)
	_help_entries = SettingsService.build_help_topics()
	_help_list.clear()

	var selected_index := -1
	var preferred_help_topic_id := _selected_help_topic_id
	if preferred_help_topic_id == "":
		preferred_help_topic_id = SettingsService.default_help_topic_id()

	for index in range(_help_entries.size()):
		var entry = _help_entries[index]
		_help_list.add_item(String(entry.get("label", entry.get("id", "Guide"))))
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
	if _selected_help_topic_id == "":
		_set_compact_label(_help_details_label, "Select a guide topic to review a system summary.", 4)
		return
	_set_compact_label(_help_details_label, SettingsService.describe_help_topic(_selected_help_topic_id), 6)

func _refresh_settings_panel() -> void:
	_syncing_settings_ui = true
	_set_compact_label(_settings_summary_label, SettingsService.describe_settings(), 5)

	_presentation_mode_picker.clear()
	var options := SettingsService.build_presentation_options()
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		_presentation_mode_picker.add_item(String(option.get("label", option.get("id", "Mode"))), index)
		_presentation_mode_picker.set_item_metadata(index, String(option.get("id", "")))
		if bool(option.get("selected", false)):
			selected_index = index
	if selected_index >= 0:
		_presentation_mode_picker.select(selected_index)

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
		var summary = _save_summaries[index]
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
		_set_compact_label(_save_details_label, "No save slots are available.", 3)
		_load_selected_button.text = "Load Selected"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = "Select a loadable save to resume."
		return

	_set_compact_label(_save_details_label, SaveService.describe_slot_details(summary), 6)
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
	_set_compact_label(_difficulty_summary_label, ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty), 4)

	if selected_entry.is_empty():
		_set_compact_label(_skirmish_details_label, "No skirmish scenarios are authored.", 3)
		_set_compact_label(_setup_summary_label, "Select an authored skirmish scenario to review its start setup.", 4)
		_set_compact_label(_skirmish_commander_preview_label, "Select a skirmish to preview commander, spellbook, relics, and opening army.", 4)
		_set_compact_label(_skirmish_operational_board_label, "Select a skirmish to review terrain, enemy posture, objective pressure, and first-contact risk.", 4)
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "No skirmish scenarios are available."
		return

	_set_compact_label(_skirmish_details_label, String(selected_entry.get("summary", "")), 4)
	var setup := ScenarioSelectRulesScript.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	if setup.is_empty():
		_set_compact_label(_setup_summary_label, "This scenario is not available for skirmish launch.", 4)
		_set_compact_label(_skirmish_commander_preview_label, "Commander preview unavailable for this front.", 4)
		_set_compact_label(_skirmish_operational_board_label, "Operational board unavailable for this front.", 4)
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "This scenario cannot be launched as a skirmish."
		return

	var recommended_difficulty := String(setup.get("recommended_difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	if recommended_difficulty != _selected_difficulty:
		_set_compact_label(_difficulty_summary_label, "%s\nRecommended for this map: %s." % [
			ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty),
			String(setup.get("recommended_difficulty_label", "")),
		], 4)

	_set_compact_label(_setup_summary_label, String(setup.get("setup_summary", "")), 4)
	_set_compact_label(_skirmish_commander_preview_label, String(setup.get("commander_preview", "Commander preview unavailable.")), 4)
	_set_compact_label(_skirmish_operational_board_label, String(setup.get("operational_board", "Operational board unavailable.")), 4)
	_start_skirmish_button.disabled = false
	_start_skirmish_button.text = "Start Skirmish"
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
		return "No authored campaign arcs are loaded."

	var completed_count := 0
	for entry in _campaign_entries:
		if String(entry.get("label", "")).contains("Completed"):
			completed_count += 1

	var selected_label := "No campaign selected."
	for entry in _campaign_entries:
		if String(entry.get("campaign_id", "")) == _selected_campaign_id:
			selected_label = String(entry.get("label", "Campaign"))
			break

	return "\n".join(
		[
			"Arcs %d | Completed %d" % [_campaign_entries.size(), completed_count],
			"Focus: %s" % selected_label,
		]
	)

func _build_save_pulse() -> String:
	var latest_summary := SaveService.latest_loadable_summary()
	var latest_line := "No loadable expedition is ready."
	if not latest_summary.is_empty():
		latest_line = SaveService.describe_slot(latest_summary)

	return "\n".join(
		[
			"Manual slots %d + autosave" % SaveService.get_manual_slot_ids().size(),
			latest_line,
		]
	)

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 96) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars)

func _apply_visual_theme() -> void:
	var panel_tones := {
		"HeroPanel": "banner",
		"HeroArtPanel": "earth",
		"ExpeditionPanel": "teal",
		"CampaignPulsePanel": "gold",
		"SavePulsePanel": "ink",
		"SummaryPanel": "earth",
		"PlayLeadPanel": "ink",
		"CampaignPanel": "banner",
		"CampaignRosterPanel": "ink",
		"ChapterRosterPanel": "ink",
		"CampaignDetailPanel": "gold",
		"ChapterDetailPanel": "earth",
		"CampaignArcPanel": "earth",
		"CampaignCommanderPanel": "teal",
		"CampaignOperationalPanel": "blue",
		"CampaignJournalPanel": "ink",
		"SkirmishPanel": "ink",
		"SkirmishListPanel": "ink",
		"SkirmishDetailPanel": "gold",
		"DifficultyPanel": "earth",
		"SetupPanel": "teal",
		"SkirmishCommanderPanel": "teal",
		"SkirmishOperationalPanel": "blue",
		"GuideIntroPanel": "ink",
		"HelpListPanel": "ink",
		"HelpDetailPanel": "gold",
		"SettingsSummaryPanel": "ink",
		"PresentationAudioPanel": "earth",
		"MasterVolumePanel": "teal",
		"MusicVolumePanel": "blue",
		"AccessibilityPanel": "teal",
		"SettingsNotesPanel": "ink",
		"SaveIntroPanel": "ink",
		"SaveListPanel": "ink",
		"SaveDetailPanel": "gold",
	}
	for panel in find_children("*", "PanelContainer", true, false):
		if panel is PanelContainer:
			var tone := String(panel_tones.get(panel.name, "ink"))
			if panel.name.ends_with("Panel"):
				FrontierVisualKit.apply_panel(panel, tone)

	FrontierVisualKit.apply_tab_container(_menu_tabs)

	for list in [_campaign_list, _chapter_list, _skirmish_list, _help_list, _save_list]:
		FrontierVisualKit.apply_item_list(list, "ink")

	var primary_buttons := [
		_continue_button,
		_campaign_primary_button,
		_start_chapter_button,
		_start_skirmish_button,
		_load_selected_button,
	]
	for button in primary_buttons:
		FrontierVisualKit.apply_button(button, "primary", maxf(button.custom_minimum_size.x, 180.0), 36.0)

	var secondary_buttons := [
		get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/ActionColumn/NavActions/OpenPlay"),
		get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/ActionColumn/NavActions/OpenGuide"),
		get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/ActionColumn/NavActions/OpenSettings"),
		get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/ActionColumn/NavActions/OpenSaves"),
	]
	for button in secondary_buttons:
		FrontierVisualKit.apply_button(button, "secondary", 126.0, 34.0)
	FrontierVisualKit.apply_button(get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/ActionColumn/PrimaryActions/Quit"), "danger", 120.0, 36.0)

	for picker in [_difficulty_picker, _presentation_mode_picker]:
		FrontierVisualKit.apply_option_button(picker, "secondary", 180.0, 36.0)

	for toggle in [_large_text_toggle, _reduce_motion_toggle]:
		FrontierVisualKit.apply_button(toggle, "secondary", 180.0, 34.0)

	for slider in [_master_volume_slider, _music_volume_slider]:
		FrontierVisualKit.apply_range(slider, "gold")

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body")
	for title_label in find_children("*Title", "Label", true, false):
		if title_label is Label:
			FrontierVisualKit.apply_label(title_label, "title")

	for title_path in [
		"RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/TitleBox/Eyebrow",
		"RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/TitleBox/Title",
	]:
		var label: Label = get_node(title_path)
		FrontierVisualKit.apply_label(label, "gold" if label.name == "Eyebrow" else "title", 16 if label.name == "Eyebrow" else 34)

	FrontierVisualKit.apply_label(get_node("RootMargin/Shell/HeroPanel/HeroPad/HeroLayout/HeroInfo/TopRow/TitleBox/Subtitle"), "body", 14)
	FrontierVisualKit.apply_label(_summary_label, "body", 14)
	FrontierVisualKit.apply_label(_active_expedition_label, "body", 13)
	FrontierVisualKit.apply_label(_campaign_pulse_label, "body", 13)
	FrontierVisualKit.apply_label(_save_pulse_label, "muted", 13)
	FrontierVisualKit.apply_label(_master_volume_value, "gold", 13)
	FrontierVisualKit.apply_label(_music_volume_value, "gold", 13)
