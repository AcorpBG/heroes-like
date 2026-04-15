extends Control

const ScenarioSelectRules = preload("res://scripts/core/ScenarioSelectRules.gd")

@onready var _summary_label: Label = $VBox/Summary
@onready var _continue_button: Button = $VBox/ActionRow/Continue
@onready var _campaign_list: ItemList = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignBrowser/CampaignList
@onready var _campaign_details_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignBrowser/CampaignDetails
@onready var _campaign_arc_status_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignArcStatus
@onready var _chapter_list: ItemList = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/ChapterBrowser/ChapterList
@onready var _chapter_details_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/ChapterBrowser/ChapterDetails
@onready var _campaign_commander_preview_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignCommanderPreview
@onready var _campaign_operational_board_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignOperationalBoard
@onready var _campaign_journal_label: Label = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignJournal
@onready var _campaign_primary_button: Button = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignActions/CampaignPrimaryAction
@onready var _start_chapter_button: Button = $VBox/MenuTabs/Play/ModeSplit/CampaignPanel/CampaignActions/StartChapter
@onready var _skirmish_list: ItemList = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/BrowserSplit/SkirmishList
@onready var _skirmish_details_label: Label = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/BrowserSplit/SkirmishDetails
@onready var _difficulty_picker: OptionButton = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/DifficultyRow/DifficultyPicker
@onready var _difficulty_summary_label: Label = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/DifficultySummary
@onready var _setup_summary_label: Label = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/SetupSummary
@onready var _skirmish_commander_preview_label: Label = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/SkirmishCommanderPreview
@onready var _skirmish_operational_board_label: Label = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/SkirmishOperationalBoard
@onready var _start_skirmish_button: Button = $VBox/MenuTabs/Play/ModeSplit/SkirmishPanel/StartSkirmish
@onready var _help_intro_label: Label = $VBox/MenuTabs/Guide/HelpIntro
@onready var _help_list: ItemList = $VBox/MenuTabs/Guide/HelpSplit/HelpList
@onready var _help_details_label: Label = $VBox/MenuTabs/Guide/HelpSplit/HelpDetails
@onready var _settings_summary_label: Label = $VBox/MenuTabs/Settings/SettingsSummary
@onready var _presentation_mode_picker: OptionButton = $VBox/MenuTabs/Settings/PresentationRow/PresentationModePicker
@onready var _master_volume_slider: HSlider = $VBox/MenuTabs/Settings/MasterVolumeRow/MasterVolumeSlider
@onready var _master_volume_value: Label = $VBox/MenuTabs/Settings/MasterVolumeRow/MasterVolumeValue
@onready var _music_volume_slider: HSlider = $VBox/MenuTabs/Settings/MusicVolumeRow/MusicVolumeSlider
@onready var _music_volume_value: Label = $VBox/MenuTabs/Settings/MusicVolumeRow/MusicVolumeValue
@onready var _large_text_toggle: CheckButton = $VBox/MenuTabs/Settings/LargeTextToggle
@onready var _reduce_motion_toggle: CheckButton = $VBox/MenuTabs/Settings/ReduceMotionToggle
@onready var _save_list: ItemList = $VBox/MenuTabs/Saves/SaveList
@onready var _save_details_label: Label = $VBox/MenuTabs/Saves/SaveDetails
@onready var _load_selected_button: Button = $VBox/MenuTabs/Saves/LoadSelected

var _save_summaries: Array = []
var _selected_save_key := ""
var _campaign_entries: Array = []
var _selected_campaign_id := ""
var _campaign_chapter_entries: Array = []
var _selected_campaign_scenario_id := ""
var _skirmish_entries: Array = []
var _selected_skirmish_id := ""
var _selected_difficulty: String = ScenarioSelectRules.default_difficulty_id()
var _help_entries: Array = []
var _selected_help_topic_id := ""
var _syncing_settings_ui := false
var _menu_notice := ""

func _ready() -> void:
	CampaignProgression.ensure_profile()
	SettingsService.ensure_settings()
	_refresh_menu()

func _refresh_menu() -> void:
	_menu_notice = AppRouter.consume_menu_notice()
	_rebuild_save_browser()
	_update_continue_enabled()
	_refresh_summary()
	_rebuild_campaign_browser()
	_configure_difficulty_picker()
	_rebuild_skirmish_browser()
	_refresh_skirmish_setup()
	_rebuild_help_browser()
	_refresh_settings_panel()

func _update_continue_enabled() -> void:
	var latest_summary := SaveService.latest_loadable_summary()
	_continue_button.text = SaveService.continue_action_label(latest_summary)
	_continue_button.disabled = latest_summary.is_empty()
	_continue_button.tooltip_text = SaveService.load_action_tooltip(latest_summary)

func _refresh_summary() -> void:
	var lines := []
	if _menu_notice != "":
		lines.append(_menu_notice)
	lines.append(ScenarioSelectRules.build_current_session_summary(SessionState.ensure_active_session()))
	lines.append("Campaign progression, expedition saves, and device settings are managed on separate tracks.")
	_summary_label.text = "\n".join(lines)

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
		ScenarioSelectRules.default_difficulty_id(),
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
	_selected_difficulty = ScenarioSelectRules.normalize_difficulty(metadata)
	_refresh_skirmish_setup()

func _on_start_skirmish_pressed() -> void:
	if _start_skirmish_button.disabled:
		return
	var session := ScenarioSelectRules.start_skirmish_session(_selected_skirmish_id, _selected_difficulty)
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
		_campaign_details_label.text = "No authored campaigns are available."
		_campaign_arc_status_label.text = "Campaign arc goals and finale state appear here once a campaign is selected."
		_chapter_details_label.text = "No campaign chapters are authored."
		_campaign_commander_preview_label.text = "Select a chapter to preview commander, spellbook, relics, and opening army."
		_campaign_operational_board_label.text = "Select a chapter to review terrain, enemy posture, objective pressure, and first-contact risk."
		_campaign_journal_label.text = "Campaign chronicle entries appear here once a chapter record exists."
		_campaign_primary_button.text = "No Campaign Available"
		_campaign_primary_button.disabled = true
		_campaign_primary_button.tooltip_text = "Author a campaign to launch it from this menu."
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or retry."
		return

	_campaign_details_label.text = CampaignProgression.campaign_details(_selected_campaign_id)
	_campaign_arc_status_label.text = CampaignProgression.campaign_arc_status(_selected_campaign_id)
	_campaign_journal_label.text = CampaignProgression.campaign_journal(_selected_campaign_id)

	var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id)
	_campaign_primary_button.text = String(primary_action.get("label", "Start Next Chapter"))
	_campaign_primary_button.disabled = bool(primary_action.get("disabled", false))
	_campaign_primary_button.tooltip_text = String(primary_action.get("summary", ""))

	if _selected_campaign_scenario_id == "":
		_chapter_details_label.text = "Select a chapter to review its unlock state, carryover, and last result."
		_campaign_commander_preview_label.text = "Select a chapter to preview commander, spellbook, relics, and opening army."
		_campaign_operational_board_label.text = "Select a chapter to review terrain, enemy posture, objective pressure, and first-contact risk."
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "Select a chapter to start or retry."
		return

	_chapter_details_label.text = CampaignProgression.chapter_details(_selected_campaign_id, _selected_campaign_scenario_id)
	_campaign_commander_preview_label.text = CampaignProgression.chapter_commander_preview(
		_selected_campaign_id,
		_selected_campaign_scenario_id
	)
	_campaign_operational_board_label.text = CampaignProgression.chapter_operational_board(
		_selected_campaign_id,
		_selected_campaign_scenario_id
	)
	var chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id)
	_start_chapter_button.text = String(chapter_action.get("label", "Start Chapter"))
	_start_chapter_button.disabled = bool(chapter_action.get("disabled", false))
	_start_chapter_button.tooltip_text = String(chapter_action.get("summary", ""))

func _rebuild_help_browser() -> void:
	_help_intro_label.text = SettingsService.help_browser_summary()
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
		_help_details_label.text = "Select a guide topic to review a system summary."
		return
	_help_details_label.text = SettingsService.describe_help_topic(_selected_help_topic_id)

func _refresh_settings_panel() -> void:
	_syncing_settings_ui = true
	_settings_summary_label.text = SettingsService.describe_settings()

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
		_save_details_label.text = "No save slots are available."
		_load_selected_button.text = "Load Selected"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = "Select a loadable save to resume."
		return

	_save_details_label.text = SaveService.describe_slot_details(summary)
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
	var options := ScenarioSelectRules.build_difficulty_options(_selected_difficulty)
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		var label := String(option.get("label", option.get("id", "Difficulty")))
		_difficulty_picker.add_item(label, index)
		_difficulty_picker.set_item_metadata(index, String(option.get("id", ScenarioSelectRules.default_difficulty_id())))
		if bool(option.get("selected", false)):
			selected_index = index
	if selected_index >= 0:
		_difficulty_picker.select(selected_index)

func _rebuild_skirmish_browser() -> void:
	_skirmish_entries = ScenarioSelectRules.build_skirmish_browser_entries()
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
	_difficulty_summary_label.text = ScenarioSelectRules.difficulty_summary(_selected_difficulty)

	if selected_entry.is_empty():
		_skirmish_details_label.text = "No skirmish scenarios are authored."
		_setup_summary_label.text = "Select an authored skirmish scenario to review its start setup."
		_skirmish_commander_preview_label.text = "Select a skirmish to preview commander, spellbook, relics, and opening army."
		_skirmish_operational_board_label.text = "Select a skirmish to review terrain, enemy posture, objective pressure, and first-contact risk."
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "No skirmish scenarios are available."
		return

	_skirmish_details_label.text = String(selected_entry.get("summary", ""))
	var setup := ScenarioSelectRules.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	if setup.is_empty():
		_setup_summary_label.text = "This scenario is not available for skirmish launch."
		_skirmish_commander_preview_label.text = "Commander preview unavailable for this front."
		_skirmish_operational_board_label.text = "Operational board unavailable for this front."
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "This scenario cannot be launched as a skirmish."
		return

	var recommended_difficulty := String(setup.get("recommended_difficulty", ScenarioSelectRules.default_difficulty_id()))
	if recommended_difficulty != _selected_difficulty:
		_difficulty_summary_label.text = "%s\nRecommended for this map: %s." % [
			ScenarioSelectRules.difficulty_summary(_selected_difficulty),
			String(setup.get("recommended_difficulty_label", "")),
		]

	_setup_summary_label.text = String(setup.get("setup_summary", ""))
	_skirmish_commander_preview_label.text = String(setup.get("commander_preview", "Commander preview unavailable."))
	_skirmish_operational_board_label.text = String(setup.get("operational_board", "Operational board unavailable."))
	_start_skirmish_button.disabled = false
	_start_skirmish_button.text = "Start Skirmish"
	_start_skirmish_button.tooltip_text = "Launch %s at %s difficulty." % [
		String(setup.get("scenario_name", _selected_skirmish_id)),
		String(setup.get("difficulty_label", ScenarioSelectRules.difficulty_label(_selected_difficulty))),
	]

func _selected_skirmish_entry() -> Dictionary:
	for entry in _skirmish_entries:
		if String(entry.get("scenario_id", "")) == _selected_skirmish_id:
			return entry
	return {}
