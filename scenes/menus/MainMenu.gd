extends Control

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

const TAB_CAMPAIGN := 0
const TAB_SKIRMISH := 1
const TAB_SAVES := 2
const TAB_GUIDE := 3
const TAB_SETTINGS := 4
const CAMPAIGN_COMPACT_DOCK_ANCHORS := Rect2(0.032, 0.258, 0.528, 0.440)
const CAMPAIGN_EXPANDED_DOCK_ANCHORS := Rect2(0.032, 0.258, 0.528, 0.600)
const STANDARD_DOCK_ANCHORS := Rect2(0.032, 0.258, 0.733, 0.620)
const SETTINGS_SUMMARY_MAX_LINES := 4
const SETTINGS_SUMMARY_MAX_CHARS := 84
const TAB_STAGE_COPY := {
	TAB_CAMPAIGN: {
		"title": "Campaign board",
		"hint": "Choose an arc and chapter; open Intel only when the deeper briefing is needed.",
	},
	TAB_SKIRMISH: {
		"title": "Skirmish charter",
		"hint": "Review a single-front plan, set difficulty, and launch a fresh expedition.",
	},
	TAB_SAVES: {
		"title": "Load expedition",
		"hint": "Choose a saved expedition and review exactly where play will resume.",
	},
	TAB_GUIDE: {
		"title": "Field manual",
		"hint": "Open help pages in a reference tray only when the player asks for them.",
	},
	TAB_SETTINGS: {
		"title": "Cabinet",
		"hint": "Presentation, sound, gameplay, and readability controls live in a secondary board.",
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
@onready var _footer_pocket_panel: PanelContainer = $FooterPocketPanel
@onready var _stage_dock_title_label: Label = %ActionLead
@onready var _stage_dock_hint_label: Label = %ActionHint
@onready var _campaign_arc_navigation: HBoxContainer = %CampaignArcNavigation
@onready var _campaign_chapter_navigation: HBoxContainer = %CampaignChapterNavigation
@onready var _campaign_command_rail: Control = %CampaignCommandRail
@onready var _skirmish_command_rail: Control = %SkirmishCommandRail
@onready var _campaign_launch_row: HBoxContainer = %CampaignLaunchRow
@onready var _skirmish_launch_row: HBoxContainer = %SkirmishLaunchRow
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
@onready var _previous_campaign_arc_button: Button = %PreviousCampaignArc
@onready var _next_campaign_arc_button: Button = %NextCampaignArc
@onready var _campaign_details_panel: PanelContainer = %CampaignDetailsPanel
@onready var _campaign_details_label: Label = %CampaignDetails
@onready var _campaign_arc_status_label: Label = %CampaignArcStatus
@onready var _chapter_list: ItemList = %ChapterList
@onready var _previous_campaign_chapter_button: Button = %PreviousCampaignChapter
@onready var _next_campaign_chapter_button: Button = %NextCampaignChapter
@onready var _chapter_details_panel: PanelContainer = %ChapterDetailsPanel
@onready var _chapter_details_label: Label = %ChapterDetails
@onready var _campaign_intel_row: HBoxContainer = %CampaignIntelRow
@onready var _campaign_commander_portrait: HeroPortraitView = %CampaignCommanderPortrait
@onready var _campaign_commander_preview_label: Label = %CampaignCommanderPreview
@onready var _campaign_operational_board_label: Label = %CampaignOperationalBoard
@onready var _campaign_journal_label: Label = %CampaignJournal
@onready var _campaign_intel_toggle: Button = %CampaignIntelToggle
@onready var _campaign_difficulty_picker: OptionButton = %CampaignDifficultyPicker
@onready var _campaign_restart_button: Button = %RestartCampaignArc
@onready var _campaign_primary_button: Button = %CampaignPrimaryAction
@onready var _start_chapter_button: Button = %StartChapter
@onready var _campaign_restart_dialog: ConfirmationDialog = $CampaignRestartDialog
@onready var _skirmish_list: ItemList = %SkirmishList
@onready var _previous_skirmish_front_button: Button = %PreviousCampaignArc
@onready var _next_skirmish_front_button: Button = %NextCampaignArc
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
@onready var _generated_underground_toggle: OptionButton = %GeneratedUndergroundToggle
@onready var _generated_status_label: Label = %GeneratedMapStatus
@onready var _generated_progress_bar: ProgressBar = %GeneratedMapProgress
@onready var _generated_provenance_label: Label = %GeneratedMapProvenance
@onready var _start_generated_skirmish_button: Button = %StartGeneratedSkirmish
@onready var _skirmish_commander_portrait: HeroPortraitView = %SkirmishCommanderPortrait
@onready var _skirmish_commander_preview_label: Label = %SkirmishCommanderPreview
@onready var _skirmish_operational_board_label: Label = %SkirmishOperationalBoard
@onready var _start_skirmish_button: Button = %NextCampaignChapter
@onready var _help_intro_label: Label = %HelpIntro
@onready var _help_list: ItemList = %HelpList
@onready var _help_details_label: Label = %HelpDetails
@onready var _open_credits_notices_button: Button = %OpenCreditsNotices
@onready var _credits_notices_dialog: Window = %CreditsNoticesDialog
@onready var _credits_notices_panel: PanelContainer = %CreditsNoticesPanel
@onready var _credits_notices_title_label: Label = %CreditsNoticesTitle
@onready var _credits_notices_body: TextEdit = %CreditsNoticesBody
@onready var _credits_notices_close_button: Button = %CreditsNoticesClose
@onready var _settings_summary_label: Label = %SettingsSummary
@onready var _settings_handoff_label: Label = %SettingsHandoff
@onready var _settings_scroll: ScrollContainer = %SettingsScroll
@onready var _presentation_mode_picker: OptionButton = %PresentationModePicker
@onready var _resolution_picker: OptionButton = %ResolutionPicker
@onready var _render_quality_picker: OptionButton = %RenderQualityPicker
@onready var _vsync_toggle: CheckButton = %VSyncToggle
@onready var _frame_rate_picker: OptionButton = %FrameRatePicker
@onready var _battle_playback_speed_picker: OptionButton = %BattlePlaybackSpeedPicker
@onready var _keyboard_navigation_layout_picker: OptionButton = %KeyboardNavigationLayoutPicker
@onready var _customize_movement_keys_button: Button = %CustomizeMovementKeys
@onready var _hero_keybindings_dialog: HeroKeybindingsDialog = $HeroKeybindingsDialog
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _master_volume_value: Label = %MasterVolumeValue
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _music_volume_value: Label = %MusicVolumeValue
@onready var _effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var _effects_volume_value: Label = %EffectsVolumeValue
@onready var _ui_scale_picker: OptionButton = %UIScalePicker
@onready var _battle_camera_shake_picker: OptionButton = %BattleCameraShakePicker
@onready var _high_contrast_toggle: CheckButton = %HighContrastToggle
@onready var _color_cue_picker: OptionButton = %ColorCuePicker
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _reduce_flashes_toggle: CheckButton = %ReduceFlashesToggle
@onready var _reduce_repetitive_sounds_toggle: CheckButton = %ReduceRepetitiveSoundsToggle
@onready var _export_support_bundle_button: Button = %ExportSupportBundle
@onready var _support_bundle_status_label: Label = %SupportBundleStatus
@onready var _restore_settings_defaults_button: Button = %RestoreSettingsDefaults
@onready var _settings_restore_status_label: Label = %SettingsRestoreStatus
@onready var _settings_restore_defaults_dialog: ConfirmationDialog = $SettingsRestoreDefaultsDialog
@onready var _display_change_confirmation_dialog: ConfirmationDialog = $DisplayChangeConfirmationDialog
@onready var _save_list: ItemList = %SaveList
@onready var _save_commander_portrait: HeroPortraitView = %SaveCommanderPortrait
@onready var _save_details_label: Label = %SaveDetails
@onready var _save_name_edit: LineEdit = %SaveNameEdit
@onready var _apply_save_name_button: Button = %ApplySaveName
@onready var _delete_selected_save_button: Button = %DeleteSelectedSave
@onready var _load_selected_button: Button = %LoadSelected
@onready var _save_delete_dialog: ConfirmationDialog = $SaveDeleteDialog

var _save_summaries: Array = []
var _selected_save_key := ""
var _save_browser_loaded := false
var _campaign_browser_loaded := false
var _save_load_notice := ""
var _pending_save_delete_identity := {}
var _campaign_entries: Array = []
var _selected_campaign_id := ""
var _campaign_chapter_entries: Array = []
var _selected_campaign_scenario_id := ""
var _pending_campaign_restart_id := ""
var _campaign_restart_notice := ""
var _campaign_storage_state: Dictionary = {}
var _campaign_storage_blocked := false
var _campaign_storage_warning := ""
var _campaign_last_mutation_result: Dictionary = {}
var _validation_campaign_blocked_command_count := 0
var _campaign_intel_expanded := false
var _skirmish_entries: Array = []
var _skirmish_browser_loaded := false
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
var _credits_notices_return_focus: Control
var _last_context_tab := TAB_CAMPAIGN
var _syncing_settings_ui := false
var _menu_notice := ""
var _stage_return_focus: Control
var _support_bundle_status := "No bundle exported"
var _support_bundle_result := {}
var _settings_restore_status := ""
var _settings_restore_pending := false
var _destructive_confirmation_generation := 0
var _destructive_confirmation_workflow_generations := {}
var _forwarding_destructive_root_physical_input := false
var _display_change_ui_active := false
var _display_change_focus_name := &"PresentationModePicker"
var _display_change_last_seconds := -1
var _display_change_preview_generation := 0
var _display_change_pending_fingerprint := {}
var _campaign_restart_return_focus: Control
var _save_delete_return_focus: Control
var _settings_restore_return_focus: Control
var _destructive_confirmation_counts := {
	"campaign_restart": {"request_count": 0, "cancel_count": 0, "confirm_count": 0},
	"save_delete": {"request_count": 0, "cancel_count": 0, "confirm_count": 0},
	"settings_restore": {"request_count": 0, "cancel_count": 0, "confirm_count": 0},
}

func _ready() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	var phase_started := ProfileLogScript.begin_usec()
	CampaignProgression.ensure_profile()
	_sync_campaign_storage_state()
	buckets["campaign_progression"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	SettingsService.ensure_settings()
	buckets["settings"] = ProfileLogScript.elapsed_ms(phase_started)
	_configure_display_change_confirmation()
	_configure_destructive_confirmations()
	_configure_settings_focus_visibility()
	_configure_credits_notices()
	phase_started = ProfileLogScript.begin_usec()
	_apply_visual_theme()
	buckets["theme"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	MusicAudio.sync_context("menu", "main_menu_ready", {"tab": TAB_CAMPAIGN})
	buckets["music_audio"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_select_menu_tab(TAB_CAMPAIGN)
	_hide_stage_dock()
	buckets["initial_layout"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_refresh_menu()
	_configure_first_view_focus_navigation()
	call_deferred("_focus_first_view_command")
	buckets["refresh_menu"] = ProfileLogScript.elapsed_ms(phase_started)
	ProfileLogScript.emit_general("menu", "ready", "main_menu_ready", ProfileLogScript.elapsed_ms(started), buckets, {
		"current_tab": _menu_tabs.current_tab,
	}, SessionState.ensure_active_session())

func _refresh_menu() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	var phase_started := ProfileLogScript.begin_usec()
	_menu_notice = AppRouter.consume_menu_notice()
	if _stage_dock_is_open() and _menu_tabs.current_tab == TAB_SAVES:
		_rebuild_save_browser()
	else:
		_reset_save_browser_placeholder()
	buckets["save_browser"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_configure_difficulty_pickers()
	if _campaign_browser_loaded:
		_rebuild_campaign_browser()
	buckets["campaign_browser"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	if _skirmish_browser_loaded:
		_configure_generated_random_map_controls()
		_rebuild_skirmish_browser()
		_refresh_skirmish_setup()
		_refresh_generated_random_map_setup()
	buckets["skirmish_setup"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_rebuild_help_browser()
	_refresh_settings_panel()
	buckets["help_settings"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_refresh_stage_dock_header()
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()
	_sync_first_view_command_tooltips()
	buckets["summary_commands"] = ProfileLogScript.elapsed_ms(phase_started)
	ProfileLogScript.emit_general("menu", "refresh", "refresh_menu", ProfileLogScript.elapsed_ms(started), buckets, {
		"current_tab": _menu_tabs.current_tab,
		"stage_dock_visible": _stage_dock_is_open(),
	}, SessionState.ensure_active_session())

func _latest_continue_surface() -> Dictionary:
	var latest_summary := _active_save_board_latest_summary()
	if latest_summary.is_empty():
		return {
			"text": "Continue Latest",
			"enabled": false,
			"tooltip": "Open Load to choose a saved expedition.",
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

func _on_campaign_selected(index: int) -> Dictionary:
	if index < 0 or index >= _campaign_entries.size():
		return _campaign_ui_failure_result("select_campaign", "Choose a campaign arc to browse.")
	_selected_campaign_id = String(_campaign_entries[index].get("campaign_id", ""))
	_selected_campaign_scenario_id = ""
	_campaign_restart_notice = ""
	var result := {}
	if _campaign_storage_is_blocked_now():
		result = _campaign_storage_blocked_result("select_campaign", {
			"campaign_id": _selected_campaign_id,
		})
	else:
		result = _consume_campaign_mutation_result(
			CampaignProgression.select_campaign(_selected_campaign_id),
			"select_campaign"
		)
	_rebuild_campaign_chapter_browser()
	_refresh_campaign_browser()
	return result.duplicate(true)

func _on_chapter_selected(index: int) -> Dictionary:
	if index < 0 or index >= _campaign_chapter_entries.size():
		return _campaign_ui_failure_result("select_scenario", "Choose a campaign chapter to browse.")
	_selected_campaign_scenario_id = String(_campaign_chapter_entries[index].get("scenario_id", ""))
	var result := {}
	if _campaign_storage_is_blocked_now():
		result = _campaign_storage_blocked_result("select_scenario", {
			"campaign_id": _selected_campaign_id,
			"scenario_id": _selected_campaign_scenario_id,
		})
	else:
		result = _consume_campaign_mutation_result(
			CampaignProgression.select_scenario(_selected_campaign_id, _selected_campaign_scenario_id),
			"select_scenario"
		)
	_refresh_campaign_browser()
	return result.duplicate(true)

func _on_previous_campaign_arc_pressed() -> void:
	if _menu_tabs.current_tab == TAB_SKIRMISH:
		_select_relative_skirmish_front(-1)
	elif _menu_tabs.current_tab == TAB_CAMPAIGN:
		_select_relative_campaign_arc(-1)
	else:
		_select_menu_tab(maxi(_menu_tabs.current_tab - 1, 0))

func _on_next_campaign_arc_pressed() -> void:
	if _menu_tabs.current_tab == TAB_SKIRMISH:
		_select_relative_skirmish_front(1)
	elif _menu_tabs.current_tab == TAB_CAMPAIGN:
		_select_relative_campaign_arc(1)
	else:
		_select_menu_tab(mini(_menu_tabs.current_tab + 1, _menu_tabs.get_tab_count() - 1))

func _on_previous_campaign_chapter_pressed() -> void:
	if _menu_tabs.current_tab == TAB_SKIRMISH:
		var selected_index := _difficulty_picker.selected
		if selected_index > 0:
			_difficulty_picker.select(selected_index - 1)
			_on_difficulty_selected(selected_index - 1)
	else:
		_select_relative_campaign_chapter(-1)

func _on_next_campaign_chapter_pressed() -> void:
	if _menu_tabs.current_tab == TAB_SKIRMISH:
		_on_start_skirmish_pressed()
	else:
		_select_relative_campaign_chapter(1)

func _select_relative_campaign_arc(delta: int) -> void:
	if delta == 0 or _campaign_entries.is_empty() or _campaign_list.item_count != _campaign_entries.size():
		return
	var selected_index := _selected_campaign_arc_index()
	var next_index := selected_index + delta
	if selected_index < 0 or next_index < 0 or next_index >= _campaign_entries.size():
		_sync_campaign_native_navigation()
		return
	_campaign_list.select(next_index)
	_on_campaign_selected(next_index)
	_campaign_list.ensure_current_is_visible()
	call_deferred("_refresh_stage_accessibility")

func _select_relative_campaign_chapter(delta: int) -> void:
	if delta == 0 or _campaign_chapter_entries.is_empty() or _chapter_list.item_count != _campaign_chapter_entries.size():
		return
	var selected_index := _selected_campaign_chapter_index()
	var next_index := selected_index + delta
	if selected_index < 0 or next_index < 0 or next_index >= _campaign_chapter_entries.size():
		_sync_campaign_native_navigation()
		return
	_chapter_list.select(next_index)
	_on_chapter_selected(next_index)
	_chapter_list.ensure_current_is_visible()
	call_deferred("_refresh_stage_accessibility")

func _selected_campaign_arc_index() -> int:
	for index in range(_campaign_entries.size()):
		if String(_campaign_entries[index].get("campaign_id", "")) == _selected_campaign_id:
			return index
	return -1

func _selected_campaign_chapter_index() -> int:
	for index in range(_campaign_chapter_entries.size()):
		if String(_campaign_chapter_entries[index].get("scenario_id", "")) == _selected_campaign_scenario_id:
			return index
	return -1

func _sync_campaign_native_navigation() -> void:
	_sync_campaign_arc_navigation()
	_sync_campaign_chapter_navigation()

func _sync_campaign_arc_navigation() -> void:
	var selected_index := _selected_campaign_arc_index()
	var has_selection := selected_index >= 0 and selected_index < _campaign_entries.size()
	_previous_campaign_arc_button.disabled = not has_selection or selected_index == 0
	_next_campaign_arc_button.disabled = not has_selection or selected_index == _campaign_entries.size() - 1
	if not has_selection:
		_previous_campaign_arc_button.tooltip_text = "No Campaign arc is available to select."
		_next_campaign_arc_button.tooltip_text = "No Campaign arc is available to select."
		return
	var current_label := String(_campaign_entries[selected_index].get("label", _selected_campaign_id))
	if _previous_campaign_arc_button.disabled:
		_previous_campaign_arc_button.tooltip_text = "%s is the first Campaign arc." % current_label
	else:
		var previous_label := String(_campaign_entries[selected_index - 1].get("label", "previous arc"))
		_previous_campaign_arc_button.tooltip_text = "Select the previous Campaign arc: %s." % previous_label
	if _next_campaign_arc_button.disabled:
		_next_campaign_arc_button.tooltip_text = "%s is the last Campaign arc." % current_label
	else:
		var next_label := String(_campaign_entries[selected_index + 1].get("label", "next arc"))
		_next_campaign_arc_button.tooltip_text = "Select the next Campaign arc: %s." % next_label

func _sync_campaign_chapter_navigation() -> void:
	var selected_index := _selected_campaign_chapter_index()
	var has_selection := selected_index >= 0 and selected_index < _campaign_chapter_entries.size()
	_previous_campaign_chapter_button.disabled = not has_selection or selected_index == 0
	_next_campaign_chapter_button.disabled = not has_selection or selected_index == _campaign_chapter_entries.size() - 1
	if not has_selection:
		_previous_campaign_chapter_button.tooltip_text = "No Campaign chapter is available to select."
		_next_campaign_chapter_button.tooltip_text = "No Campaign chapter is available to select."
		return
	var current_label := String(_campaign_chapter_entries[selected_index].get("label", _selected_campaign_scenario_id))
	if _previous_campaign_chapter_button.disabled:
		_previous_campaign_chapter_button.tooltip_text = "%s is the first Campaign chapter." % current_label
	else:
		var previous_label := String(_campaign_chapter_entries[selected_index - 1].get("label", "previous chapter"))
		_previous_campaign_chapter_button.tooltip_text = "Select the previous Campaign chapter: %s." % previous_label
	if _next_campaign_chapter_button.disabled:
		_next_campaign_chapter_button.tooltip_text = "%s is the last Campaign chapter." % current_label
	else:
		var next_label := String(_campaign_chapter_entries[selected_index + 1].get("label", "next chapter"))
		_next_campaign_chapter_button.tooltip_text = "Select the next Campaign chapter: %s." % next_label

func _on_campaign_intel_toggle_pressed() -> void:
	_set_campaign_intel_expanded(not _campaign_intel_expanded)

func _set_campaign_intel_expanded(expanded: bool) -> void:
	_campaign_intel_expanded = expanded
	_campaign_details_panel.visible = expanded
	_chapter_details_panel.visible = expanded
	_campaign_intel_row.visible = expanded
	_apply_stage_dock_layout()
	_campaign_intel_toggle.text = "Hide Intel" if expanded else "Show Intel"
	_campaign_intel_toggle.tooltip_text = (
		"Hide the selected arc, chapter, commander, operational, and journal detail; selection and launch actions stay unchanged."
		if expanded
		else "Show selected arc, chapter, commander, operational, and journal detail inside this campaign rail."
	)

func _on_campaign_primary_pressed() -> void:
	_launch_campaign_action(CampaignProgression.primary_campaign_action(_selected_campaign_id, _selected_difficulty))

func _on_start_chapter_pressed() -> void:
	_launch_campaign_action(CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty))

func _on_campaign_restart_pressed() -> Dictionary:
	if _campaign_storage_is_blocked_now():
		var blocked := _campaign_storage_blocked_result("restart_campaign", {
			"campaign_id": _selected_campaign_id,
		})
		_refresh_campaign_browser()
		return blocked
	var action := CampaignProgression.campaign_restart_action(_selected_campaign_id)
	if bool(action.get("disabled", true)):
		return _campaign_ui_failure_result(
			"restart_campaign",
			String(action.get("summary", "Campaign arc has no recorded progress."))
		)
	_campaign_restart_return_focus = _capture_confirmation_origin(_campaign_restart_button)
	_pending_campaign_restart_id = String(action.get("campaign_id", ""))
	_begin_destructive_confirmation_generation("campaign_restart")
	_count_destructive_confirmation("campaign_restart", "request_count")
	_campaign_restart_dialog.title = "Restart %s?" % String(action.get("campaign_name", "campaign arc"))
	_campaign_restart_dialog.dialog_text = String(action.get("summary", ""))
	var dialog_label := _campaign_restart_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(520.0, 72.0)
	_campaign_restart_dialog.get_ok_button().text = "Restart Arc"
	_campaign_restart_dialog.popup_centered(Vector2i(640, 210))
	_focus_destructive_confirmation_cancel.call_deferred(_campaign_restart_dialog, "campaign_restart")
	return {
		"ok": true,
		"pending": true,
		"operation": "restart_campaign",
		"campaign_id": _pending_campaign_restart_id,
	}

func _on_campaign_restart_confirmed() -> Dictionary:
	_campaign_restart_dialog.hide()
	var campaign_id := _pending_campaign_restart_id
	_pending_campaign_restart_id = ""
	if campaign_id == "":
		return _campaign_ui_failure_result("restart_campaign", "No campaign restart is pending.")
	_campaign_restart_return_focus = null
	_count_destructive_confirmation("campaign_restart", "confirm_count")
	if _campaign_storage_is_blocked_now():
		var blocked := _campaign_storage_blocked_result("restart_campaign", {
			"campaign_id": campaign_id,
		})
		_refresh_campaign_browser()
		return blocked
	var result := CampaignProgression.restart_campaign(campaign_id)
	_consume_campaign_mutation_result(result, "restart_campaign")
	_campaign_restart_notice = String(result.get("message", ""))
	if not bool(result.get("ok", false)):
		_refresh_campaign_browser()
		return _campaign_last_mutation_result.duplicate(true)
	_selected_campaign_id = campaign_id
	_selected_campaign_scenario_id = ""
	_rebuild_campaign_browser()
	return _campaign_last_mutation_result.duplicate(true)

func _on_campaign_restart_canceled() -> Dictionary:
	var had_pending := _pending_campaign_restart_id != ""
	_campaign_restart_dialog.hide()
	_pending_campaign_restart_id = ""
	if had_pending:
		_count_destructive_confirmation("campaign_restart", "cancel_count")
		_restore_destructive_confirmation_origin.call_deferred("campaign_restart")
	return {"ok": true, "canceled": had_pending, "pending": false}

func _launch_campaign_action(action: Dictionary) -> Dictionary:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	if _campaign_storage_is_blocked_now():
		var blocked := _campaign_storage_blocked_result("start_scenario", {
			"campaign_id": String(action.get("campaign_id", _selected_campaign_id)),
			"scenario_id": String(action.get("scenario_id", "")),
		})
		_refresh_campaign_browser()
		return blocked
	if bool(action.get("disabled", false)):
		var disabled_result := _campaign_ui_failure_result(
			"start_scenario",
			String(action.get("summary", "This campaign chapter is unavailable.")),
			{
				"campaign_id": String(action.get("campaign_id", _selected_campaign_id)),
				"scenario_id": String(action.get("scenario_id", "")),
			}
		)
		ProfileLogScript.emit_general("menu", "scenario_launch", "campaign_launch_blocked", ProfileLogScript.elapsed_ms(started), buckets, {
			"scenario_id": String(action.get("scenario_id", "")),
			"campaign_id": String(action.get("campaign_id", _selected_campaign_id)),
			"difficulty": _selected_difficulty,
		}, SessionState.ensure_active_session())
		return disabled_result
	var scenario_id := String(action.get("scenario_id", ""))
	var campaign_id := String(action.get("campaign_id", _selected_campaign_id))
	var start_started := ProfileLogScript.begin_usec()
	var session := CampaignProgression.start_scenario(
		scenario_id,
		_selected_difficulty,
		campaign_id
	)
	buckets["scenario_start"] = ProfileLogScript.elapsed_ms(start_started)
	if session.scenario_id == "":
		var failure := CampaignProgression.last_failure_result()
		if failure.is_empty():
			failure = _campaign_ui_failure_result(
				"start_scenario",
				"The campaign expedition could not be started.",
				{"campaign_id": campaign_id, "scenario_id": scenario_id}
			)
		else:
			failure = _consume_campaign_mutation_result(failure, "start_scenario")
		var refresh_started := ProfileLogScript.begin_usec()
		_refresh_menu()
		buckets["refresh_after_block"] = ProfileLogScript.elapsed_ms(refresh_started)
		ProfileLogScript.emit_general("menu", "scenario_launch", "campaign_launch_failed", ProfileLogScript.elapsed_ms(started), buckets, {
			"scenario_id": scenario_id,
			"campaign_id": campaign_id,
			"difficulty": _selected_difficulty,
		}, SessionState.ensure_active_session())
		return failure.duplicate(true)
	_campaign_last_mutation_result = {
		"ok": true,
		"changed": true,
		"operation": "start_scenario",
		"reason": "started",
		"message": "",
		"campaign_id": campaign_id,
		"scenario_id": scenario_id,
		"storage_state": CampaignProgression.storage_state(),
	}
	var refresh_started := ProfileLogScript.begin_usec()
	_refresh_menu()
	buckets["refresh_before_route"] = ProfileLogScript.elapsed_ms(refresh_started)
	ProfileLogScript.emit_general("menu", "scenario_launch", "campaign_launch", ProfileLogScript.elapsed_ms(started), buckets, {
		"scenario_id": scenario_id,
		"campaign_id": campaign_id,
		"difficulty": _selected_difficulty,
	}, session)
	_route_menu_launch_after_accessibility_handoff()
	return _campaign_last_mutation_result.duplicate(true)

func _route_menu_launch_after_accessibility_handoff() -> void:
	var tree := get_tree()
	if tree != null and tree.is_accessibility_supported():
		visible = false
		_queue_accessibility_subtree_update(self)
		await tree.process_frame
		await tree.process_frame
	if is_inside_tree():
		AppRouter.go_to_overworld()

func _queue_accessibility_subtree_update(node: Node) -> void:
	node.queue_accessibility_update()
	for child in node.get_children():
		_queue_accessibility_subtree_update(child)

func _on_continue_pressed() -> void:
	if not AppRouter.resume_latest_session():
		_refresh_menu()

func _on_open_campaign_pressed() -> void:
	_toggle_stage_dock(TAB_CAMPAIGN)

func _on_open_skirmish_pressed() -> void:
	_toggle_stage_dock(TAB_SKIRMISH)

func _on_open_saves_pressed() -> void:
	_toggle_stage_dock(TAB_SAVES)
	if _stage_dock_is_open() and _menu_tabs.current_tab == TAB_SAVES:
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
	_save_load_notice = ""
	_selected_save_key = _summary_key(_save_summaries[index])
	_refresh_selected_save()

func _on_delete_selected_save_pressed() -> void:
	var action := SaveService.build_delete_action(_selected_summary())
	if bool(action.get("disabled", true)):
		return
	_save_delete_return_focus = _capture_confirmation_origin(_delete_selected_save_button)
	_pending_save_delete_identity = {
		"slot_type": String(action.get("slot_type", "")),
		"slot_id": String(action.get("slot_id", "")),
	}
	_begin_destructive_confirmation_generation("save_delete")
	_count_destructive_confirmation("save_delete", "request_count")
	_save_delete_dialog.title = "Delete %s?" % String(action.get("slot_label", "save"))
	_save_delete_dialog.dialog_text = String(action.get("summary", ""))
	var dialog_label := _save_delete_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(520.0, 72.0)
	_save_delete_dialog.get_ok_button().text = "Delete Save"
	_save_delete_dialog.popup_centered(Vector2i(640, 210))
	_focus_destructive_confirmation_cancel.call_deferred(_save_delete_dialog, "save_delete")

func _on_save_name_text_changed(_new_text: String) -> void:
	_refresh_save_name_action()

func _on_save_name_submitted(_new_text: String) -> void:
	_on_apply_save_name_pressed()

func _on_apply_save_name_pressed() -> void:
	var result := SaveService.set_manual_slot_name_from_summary(_selected_summary(), _save_name_edit.text)
	_save_load_notice = String(result.get("message", "The manual save name was not changed."))
	_rebuild_save_browser()

func _on_save_delete_confirmed() -> void:
	_save_delete_dialog.hide()
	var identity := _pending_save_delete_identity.duplicate(true)
	_pending_save_delete_identity = {}
	if identity.is_empty():
		return
	_save_delete_return_focus = null
	_count_destructive_confirmation("save_delete", "confirm_count")
	var result := SaveService.delete_session_from_summary(identity)
	_save_load_notice = String(result.get("message", ""))
	_rebuild_save_browser()

func _on_save_delete_canceled() -> Dictionary:
	var had_pending := not _pending_save_delete_identity.is_empty()
	_save_delete_dialog.hide()
	_pending_save_delete_identity = {}
	if had_pending:
		_count_destructive_confirmation("save_delete", "cancel_count")
		_restore_destructive_confirmation_origin.call_deferred("save_delete")
	return {"ok": true, "canceled": had_pending, "pending": false}

func _on_load_selected_pressed() -> void:
	var live_summary := SaveService.refresh_summary(_selected_summary())
	if not SaveService.can_load_summary(live_summary):
		_save_load_notice = "This save is no longer available. Choose another saved expedition."
		_rebuild_save_browser()
		_refresh_selected_save()
		return
	if not AppRouter.resume_summary(live_summary):
		_save_load_notice = "This save could not be opened. Your saved slots were not changed."
		_rebuild_save_browser()
		_refresh_selected_save()

func _on_skirmish_selected(index: int) -> void:
	if index < 0 or index >= _skirmish_entries.size():
		return
	_selected_skirmish_id = String(_skirmish_entries[index].get("scenario_id", ""))
	_refresh_skirmish_setup()

func _on_previous_skirmish_front_pressed() -> void:
	_select_relative_skirmish_front(-1)

func _on_next_skirmish_front_pressed() -> void:
	_select_relative_skirmish_front(1)

func _select_relative_skirmish_front(delta: int) -> void:
	if delta == 0 or _skirmish_entries.is_empty() or _skirmish_list.item_count != _skirmish_entries.size():
		return
	var selected_index := _selected_skirmish_front_index()
	var next_index := selected_index + delta
	if selected_index < 0 or next_index < 0 or next_index >= _skirmish_entries.size():
		_sync_skirmish_front_navigation()
		return
	_skirmish_list.select(next_index)
	_on_skirmish_selected(next_index)
	_skirmish_list.ensure_current_is_visible()
	call_deferred("_refresh_stage_accessibility")

func _selected_skirmish_front_index() -> int:
	for index in range(_skirmish_entries.size()):
		if String(_skirmish_entries[index].get("scenario_id", "")) == _selected_skirmish_id:
			return index
	return -1

func _sync_skirmish_front_navigation() -> void:
	var selected_index := _selected_skirmish_front_index()
	var has_selection := selected_index >= 0 and selected_index < _skirmish_entries.size()
	_previous_skirmish_front_button.disabled = not has_selection or selected_index == 0
	_next_skirmish_front_button.disabled = not has_selection or selected_index == _skirmish_entries.size() - 1
	if not has_selection:
		_previous_skirmish_front_button.tooltip_text = "No Skirmish front is available to select."
		_next_skirmish_front_button.tooltip_text = "No Skirmish front is available to select."
		return
	var current_label := String(_skirmish_entries[selected_index].get("label", _selected_skirmish_id))
	if _previous_skirmish_front_button.disabled:
		_previous_skirmish_front_button.tooltip_text = "%s is the first Skirmish front." % current_label
	else:
		var previous_label := String(_skirmish_entries[selected_index - 1].get("label", "previous front"))
		_previous_skirmish_front_button.tooltip_text = "Select the previous Skirmish front: %s." % previous_label
	if _next_skirmish_front_button.disabled:
		_next_skirmish_front_button.tooltip_text = "%s is the last Skirmish front." % current_label
	else:
		var next_label := String(_skirmish_entries[selected_index + 1].get("label", "next front"))
		_next_skirmish_front_button.tooltip_text = "Select the next Skirmish front: %s." % next_label

func _on_difficulty_selected(index: int) -> void:
	_set_selected_difficulty_from_picker(_difficulty_picker, index)
	_sync_skirmish_difficulty_navigation()
	call_deferred("_refresh_stage_accessibility")

func _sync_skirmish_difficulty_navigation() -> void:
	var selected_index := _difficulty_picker.selected
	_previous_campaign_chapter_button.text = "Previous Difficulty"
	if _difficulty_picker.get_item_count() == 0 or selected_index < 0:
		_previous_campaign_chapter_button.disabled = true
		_previous_campaign_chapter_button.tooltip_text = "No Skirmish difficulty is available to select."
		return
	_previous_campaign_chapter_button.disabled = selected_index <= 0
	if selected_index <= 0:
		_previous_campaign_chapter_button.tooltip_text = "%s is the first difficulty." % _difficulty_picker.get_item_text(selected_index)
	else:
		_previous_campaign_chapter_button.tooltip_text = "Select the previous difficulty: %s." % _difficulty_picker.get_item_text(selected_index - 1)

func _on_campaign_difficulty_selected(index: int) -> void:
	_set_selected_difficulty_from_picker(_campaign_difficulty_picker, index)
	call_deferred("_refresh_stage_accessibility")

func _set_selected_difficulty_from_picker(picker: OptionButton, index: int) -> void:
	if index < 0 or index >= picker.get_item_count():
		return
	_selected_difficulty = ScenarioSelectRulesScript.normalize_difficulty(picker.get_item_metadata(index))
	_sync_difficulty_picker_selection()
	_refresh_campaign_browser()
	_refresh_skirmish_setup()
	_refresh_generated_random_map_setup()

func _on_start_skirmish_pressed() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	if _start_skirmish_button.disabled:
		ProfileLogScript.emit_general("menu", "scenario_launch", "skirmish_launch_blocked", ProfileLogScript.elapsed_ms(started), buckets, {
			"scenario_id": _selected_skirmish_id,
			"difficulty": _selected_difficulty,
		}, SessionState.ensure_active_session())
		return
	var launch_started := ProfileLogScript.begin_usec()
	var session := ScenarioSelectRulesScript.start_skirmish_session(_selected_skirmish_id, _selected_difficulty)
	buckets["start_skirmish_session"] = ProfileLogScript.elapsed_ms(launch_started)
	if session.scenario_id == "":
		var refresh_started := ProfileLogScript.begin_usec()
		_refresh_menu()
		buckets["refresh_after_block"] = ProfileLogScript.elapsed_ms(refresh_started)
		ProfileLogScript.emit_general("menu", "scenario_launch", "skirmish_launch_failed", ProfileLogScript.elapsed_ms(started), buckets, {
			"scenario_id": _selected_skirmish_id,
			"difficulty": _selected_difficulty,
		}, SessionState.ensure_active_session())
		return
	var refresh_started := ProfileLogScript.begin_usec()
	_refresh_menu()
	buckets["refresh_before_route"] = ProfileLogScript.elapsed_ms(refresh_started)
	ProfileLogScript.emit_general("menu", "scenario_launch", "skirmish_launch", ProfileLogScript.elapsed_ms(started), buckets, {
		"scenario_id": _selected_skirmish_id,
		"difficulty": _selected_difficulty,
	}, session)
	_route_menu_launch_after_accessibility_handoff()

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
	_rebuild_generated_profile_picker()
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
			break
	_rebuild_generated_profile_picker()
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
	_refresh_generated_random_map_setup()

func _on_generated_level_selected(index: int) -> void:
	if index < 0 or index >= _generated_underground_toggle.get_item_count():
		return
	_generated_underground = int(_generated_underground_toggle.get_item_metadata(index)) > 1
	_refresh_generated_random_map_setup()

func _on_generated_underground_toggled(enabled: bool) -> void:
	if enabled and not _generated_underground_supported():
		_generated_underground = false
		_select_generated_level_count(1)
		_refresh_generated_random_map_setup()
		return
	_generated_underground = enabled
	_select_generated_level_count(2 if _generated_underground else 1)
	_refresh_generated_random_map_setup()

func _on_start_generated_skirmish_pressed() -> void:
	await _start_generated_skirmish_staged(true)

func _on_help_selected(index: int) -> void:
	if index < 0 or index >= _help_entries.size():
		return
	_selected_help_topic_id = String(_help_entries[index].get("id", ""))
	_refresh_help_browser()

func _on_open_credits_notices_pressed() -> void:
	_open_credits_notices()

func _on_credits_notices_close_requested() -> void:
	_close_credits_notices()

func _on_credits_notices_close_pressed() -> void:
	_close_credits_notices()

func _on_credits_notices_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_credits_notices()
		_credits_notices_dialog.set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEDOWN:
			_scroll_credits_notices(1)
			_credits_notices_dialog.set_input_as_handled()
		elif event.keycode == KEY_PAGEUP:
			_scroll_credits_notices(-1)
			_credits_notices_dialog.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_scroll_credits_notices(1)
			_credits_notices_dialog.set_input_as_handled()
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_scroll_credits_notices(-1)
			_credits_notices_dialog.set_input_as_handled()

func _scroll_credits_notices(page_direction: int) -> void:
	if not _credits_notices_dialog.visible or page_direction == 0:
		return
	var scroll_bar := _credits_notices_body.get_v_scroll_bar()
	var page_step := maxi(1, int(floor(scroll_bar.page)))
	_credits_notices_body.scroll_vertical = clampi(
		_credits_notices_body.scroll_vertical + page_step * page_direction,
		0,
		maxi(0, int(ceil(scroll_bar.max_value - scroll_bar.page)))
	)

func _configure_credits_notices() -> void:
	_credits_notices_body.editable = false
	_credits_notices_body.context_menu_enabled = false
	UiAccessibility.describe_control(
		_credits_notices_body,
		"Credits and third-party notices",
		"Scrollable credits and software license notices from this running build. Use Page Up and Page Down or the controller shoulder buttons to scroll."
	)
	_open_credits_notices_button.tooltip_text = "Open a scrollable, read-only list of Aurelion Reach credits and software notices. Page with Page Up/Page Down or the controller shoulder buttons. This does not change play, saves, or settings."
	_credits_notices_close_button.tooltip_text = "Close Credits & Notices and return focus to the Guide command."
	FrontierVisualKit.configure_focus_cycle([_credits_notices_body, _credits_notices_close_button])

func _open_credits_notices() -> void:
	if _credits_notices_dialog.visible:
		return
	_credits_notices_return_focus = _open_credits_notices_button
	_credits_notices_body.text = SettingsService.credits_notices_text()
	_credits_notices_body.scroll_vertical = 0
	_credits_notices_dialog.popup_centered(Vector2i(760, 560))
	_credits_notices_close_button.call_deferred("grab_focus")

func _close_credits_notices() -> void:
	if not _credits_notices_dialog.visible:
		return
	_credits_notices_dialog.hide()
	if is_instance_valid(_credits_notices_return_focus) and _credits_notices_return_focus.is_visible_in_tree():
		_credits_notices_return_focus.call_deferred("grab_focus")

func _refresh_credits_notices_command() -> void:
	var selected := _selected_help_topic_id == "credits_notices"
	_open_credits_notices_button.visible = selected
	_open_credits_notices_button.disabled = not selected

func _configure_display_change_confirmation() -> void:
	_display_change_confirmation_dialog.get_ok_button().text = "Keep"
	_display_change_confirmation_dialog.get_cancel_button().text = "Revert"
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	_display_change_confirmation_dialog.get_cancel_button().shortcut = cancel_shortcut
	var callback := _on_display_change_state_changed
	if not SettingsService.display_change_state_changed.is_connected(callback):
		SettingsService.display_change_state_changed.connect(callback)


func _configure_destructive_confirmations() -> void:
	_configure_safe_confirmation(_campaign_restart_dialog, "Keep Progress")
	_configure_safe_confirmation(_save_delete_dialog, "Keep Save")
	_configure_safe_confirmation(_settings_restore_defaults_dialog, "Keep Settings")
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if _forwarding_destructive_root_physical_input or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	var owner := _active_destructive_confirmation_root_owner()
	if owner.is_empty():
		return
	get_tree().root.set_input_as_handled()
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred(
		"_forward_root_physical_input_to_destructive_confirmation",
		owner.get("dialog") as ConfirmationDialog,
		String(owner.get("workflow", "")),
		int(owner.get("generation", -1)),
		owner.get("pending"),
		detached_event
	)


func _forward_root_physical_input_to_destructive_confirmation(
	dialog: ConfirmationDialog,
	workflow: String,
	generation: int,
	pending: Variant,
	event: InputEvent
) -> void:
	if _forwarding_destructive_root_physical_input or not is_instance_valid(dialog):
		return
	var owner := _active_destructive_confirmation_root_owner()
	if (
		owner.is_empty()
		or owner.get("dialog") != dialog
		or String(owner.get("workflow", "")) != workflow
		or int(owner.get("generation", -1)) != generation
		or not _destructive_confirmation_pending_matches(workflow, pending)
	):
		return
	_forwarding_destructive_root_physical_input = true
	dialog.push_input(event)
	_forwarding_destructive_root_physical_input = false


func _active_destructive_confirmation_root_owner() -> Dictionary:
	if _hero_keybindings_dialog.visible:
		return {}
	var owners := []
	var display_change_state_present := (
		_display_change_confirmation_dialog.visible
		or _display_change_ui_active
		or SettingsService.display_change_pending()
	)
	if display_change_state_present:
		var current_display_fingerprint := _display_change_snapshot_fingerprint(
			SettingsService.display_change_snapshot()
		)
		if (
			not _display_change_confirmation_dialog.visible
			or not _display_change_ui_active
			or not SettingsService.display_change_pending()
			or _display_change_pending_fingerprint.is_empty()
			or current_display_fingerprint != _display_change_pending_fingerprint
		):
			return {}
		owners.append({
			"dialog": _display_change_confirmation_dialog,
			"workflow": "display_change",
			"generation": _display_change_preview_generation,
			"pending": _display_change_pending_fingerprint,
		})
	if _campaign_restart_dialog.visible and _pending_campaign_restart_id != "":
		owners.append({
			"dialog": _campaign_restart_dialog,
			"workflow": "campaign_restart",
			"generation": int(_destructive_confirmation_workflow_generations.get("campaign_restart", -1)),
			"pending": _pending_campaign_restart_id,
		})
	if _save_delete_dialog.visible and not _pending_save_delete_identity.is_empty():
		owners.append({
			"dialog": _save_delete_dialog,
			"workflow": "save_delete",
			"generation": int(_destructive_confirmation_workflow_generations.get("save_delete", -1)),
			"pending": _pending_save_delete_identity,
		})
	if _settings_restore_defaults_dialog.visible and _settings_restore_pending:
		owners.append({
			"dialog": _settings_restore_defaults_dialog,
			"workflow": "settings_restore",
			"generation": int(_destructive_confirmation_workflow_generations.get("settings_restore", -1)),
			"pending": true,
		})
	return owners[0] if owners.size() == 1 else {}


func _begin_destructive_confirmation_generation(workflow: String) -> void:
	_destructive_confirmation_generation += 1
	_destructive_confirmation_workflow_generations[workflow] = _destructive_confirmation_generation


func _destructive_confirmation_pending_matches(workflow: String, pending: Variant) -> bool:
	match workflow:
		"campaign_restart":
			return String(pending) != "" and String(pending) == _pending_campaign_restart_id
		"save_delete":
			return pending is Dictionary and is_same(pending, _pending_save_delete_identity)
		"settings_restore":
			return bool(pending) and _settings_restore_pending
		"display_change":
			return (
				pending is Dictionary
				and _display_change_ui_active
				and _display_change_confirmation_dialog.visible
				and SettingsService.display_change_pending()
				and not _display_change_pending_fingerprint.is_empty()
				and pending == _display_change_pending_fingerprint
				and _display_change_snapshot_fingerprint(SettingsService.display_change_snapshot()) == pending
			)
	return false


func _display_change_snapshot_fingerprint(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("pending", false)):
		return {}
	return {
		"mode": String(snapshot.get("mode", "")),
		"resolution": String(snapshot.get("resolution", "")),
		"requested_size": snapshot.get("requested_size", Vector2i.ZERO),
		"applied_size": snapshot.get("applied_size", Vector2i.ZERO),
		"deadline_msec": int(snapshot.get("deadline_msec", 0)),
		"prior_mode": String(snapshot.get("prior_mode", "")),
		"prior_resolution": String(snapshot.get("prior_resolution", "")),
		"prior_runtime": (snapshot.get("prior_runtime", {}) as Dictionary).duplicate(true),
	}


func _configure_safe_confirmation(dialog: ConfirmationDialog, cancel_text: String) -> void:
	var cancel_button := dialog.get_cancel_button()
	cancel_button.text = cancel_text
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	cancel_button.shortcut = cancel_shortcut


func _capture_confirmation_origin(fallback: Control) -> Control:
	var focus_owner := get_viewport().gui_get_focus_owner() as Control
	if (
		is_instance_valid(focus_owner)
		and focus_owner.is_inside_tree()
		and focus_owner.is_visible_in_tree()
		and focus_owner.focus_mode != Control.FOCUS_NONE
		and is_ancestor_of(focus_owner)
	):
		return focus_owner
	return fallback


func _focus_destructive_confirmation_cancel(dialog: ConfirmationDialog, workflow: String) -> void:
	if not dialog.visible or not _destructive_confirmation_pending(workflow):
		return
	dialog.get_cancel_button().grab_focus()
	await get_tree().process_frame
	if dialog.visible and _destructive_confirmation_pending(workflow):
		dialog.get_cancel_button().grab_focus()


func _restore_destructive_confirmation_origin(workflow: String) -> void:
	var target := _destructive_confirmation_return_focus(workflow)
	_set_destructive_confirmation_return_focus(workflow, null)
	await get_tree().process_frame
	if (
		is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	):
		target.grab_focus()


func _destructive_confirmation_return_focus(workflow: String) -> Control:
	match workflow:
		"campaign_restart":
			return _campaign_restart_return_focus
		"save_delete":
			return _save_delete_return_focus
		"settings_restore":
			return _settings_restore_return_focus
	return null


func _set_destructive_confirmation_return_focus(workflow: String, target: Control) -> void:
	match workflow:
		"campaign_restart":
			_campaign_restart_return_focus = target
		"save_delete":
			_save_delete_return_focus = target
		"settings_restore":
			_settings_restore_return_focus = target


func _destructive_confirmation_pending(workflow: String) -> bool:
	match workflow:
		"campaign_restart":
			return _pending_campaign_restart_id != ""
		"save_delete":
			return not _pending_save_delete_identity.is_empty()
		"settings_restore":
			return _settings_restore_pending
	return false


func _count_destructive_confirmation(workflow: String, field: String) -> void:
	var counts_value: Variant = _destructive_confirmation_counts.get(workflow, {})
	var counts: Dictionary = counts_value if counts_value is Dictionary else {}
	counts[field] = int(counts.get(field, 0)) + 1
	_destructive_confirmation_counts[workflow] = counts


func _confirmation_focus_owner_name(dialog: ConfirmationDialog) -> String:
	var focus_owner := dialog.get_cancel_button().get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""


func _root_focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""


func _destructive_confirmation_snapshot(workflow: String, dialog: ConfirmationDialog) -> Dictionary:
	var counts_value: Variant = _destructive_confirmation_counts.get(workflow, {})
	var counts: Dictionary = counts_value if counts_value is Dictionary else {}
	var return_focus := _destructive_confirmation_return_focus(workflow)
	return {
		"pending": _destructive_confirmation_pending(workflow),
		"dialog_visible": dialog.visible,
		"cancel_text": dialog.get_cancel_button().text,
		"focus_owner": _confirmation_focus_owner_name(dialog),
		"return_focus_name": String(return_focus.name) if is_instance_valid(return_focus) else "",
		"origin_focus_owner": _root_focus_owner_name(),
		"request_count": int(counts.get("request_count", 0)),
		"cancel_count": int(counts.get("cancel_count", 0)),
		"confirm_count": int(counts.get("confirm_count", 0)),
		"dialog_position": dialog.position,
		"dialog_size": dialog.size,
	}

func _request_display_change_preview(
	mode_id: String,
	resolution_id: String,
	focus_name: StringName
) -> Dictionary:
	_display_change_preview_generation += 1
	_display_change_pending_fingerprint = {}
	_display_change_ui_active = true
	_display_change_focus_name = focus_name
	_display_change_last_seconds = -1
	var result: Dictionary = SettingsService.preview_display_change(mode_id, resolution_id, 15.0)
	if not bool(result.get("ok", false)) or not SettingsService.display_change_pending():
		_finish_display_change_ui(result, true, "Display settings were not changed.")
		return result
	_display_change_ui_active = true
	var snapshot := SettingsService.display_change_snapshot()
	_display_change_pending_fingerprint = _display_change_snapshot_fingerprint(snapshot)
	_refresh_settings_panel()
	_show_display_change_confirmation(snapshot)
	return result

func _show_display_change_confirmation(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("pending", SettingsService.display_change_pending())):
		return
	var seconds_remaining := maxi(SettingsService.display_change_countdown_seconds(), 0)
	var mode_label := _display_mode_label(String(snapshot.get("mode", SettingsService.presentation_mode_id())))
	var resolution_label := _display_resolution_label(String(snapshot.get("resolution", SettingsService.presentation_resolution_id())))
	_display_change_confirmation_dialog.title = "Keep display settings?"
	_display_change_confirmation_dialog.dialog_text = "Keep %s at %s?\n\nThe previous display settings return automatically in %d second%s." % [
		mode_label,
		resolution_label,
		seconds_remaining,
		"" if seconds_remaining == 1 else "s",
	]
	var dialog_label := _display_change_confirmation_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(520.0, 92.0)
	if not _display_change_confirmation_dialog.visible:
		_display_change_confirmation_dialog.popup_centered(Vector2i(640, 230))
		call_deferred("_focus_display_change_revert")
	_display_change_last_seconds = seconds_remaining

func _focus_display_change_revert() -> void:
	if not _display_change_confirmation_dialog.visible:
		return
	_display_change_confirmation_dialog.get_cancel_button().grab_focus()
	await get_tree().process_frame
	if _display_change_confirmation_dialog.visible:
		_display_change_confirmation_dialog.get_cancel_button().grab_focus()

func _on_display_change_state_changed(snapshot: Dictionary) -> void:
	if not _display_change_ui_active:
		return
	if bool(snapshot.get("pending", false)):
		var seconds_remaining := maxi(SettingsService.display_change_countdown_seconds(), 0)
		if seconds_remaining != _display_change_last_seconds or not _display_change_confirmation_dialog.visible:
			_show_display_change_confirmation(snapshot)
		return
	_finish_display_change_ui(snapshot, true, "Previous display settings restored.")

func _on_display_change_confirmed() -> void:
	if not _display_change_ui_active:
		return
	var result: Dictionary = SettingsService.confirm_display_change()
	if _display_change_ui_active:
		_finish_display_change_ui(result, true, "Display settings kept.")

func _on_display_change_canceled() -> void:
	if not _display_change_ui_active:
		return
	_revert_pending_display_change("canceled", true)

func _revert_pending_display_change(reason: String, restore_focus: bool) -> Dictionary:
	var result := {
		"ok": true,
		"pending": false,
		"reason": reason,
		"message": "Previous display settings restored.",
	}
	if SettingsService.display_change_pending():
		result = SettingsService.revert_display_change(reason)
	if _display_change_ui_active:
		_finish_display_change_ui(result, restore_focus, "Previous display settings restored.")
	return result

func _finish_display_change_ui(
	result: Dictionary,
	restore_focus: bool,
	fallback_message: String
) -> void:
	_display_change_confirmation_dialog.hide()
	_display_change_ui_active = false
	_display_change_last_seconds = -1
	_display_change_pending_fingerprint = {}
	_settings_restore_status = String(result.get("message", fallback_message)).strip_edges()
	if _settings_restore_status == "":
		_settings_restore_status = fallback_message
	_refresh_settings_panel()
	if restore_focus:
		call_deferred("_focus_display_change_origin")

func _focus_display_change_origin() -> void:
	if not is_inside_tree() or not _stage_dock_is_open() or _menu_tabs.current_tab != TAB_SETTINGS:
		return
	var target := get_node_or_null("%%%s" % String(_display_change_focus_name)) as Control
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		_settings_scroll.ensure_control_visible(target)
		target.grab_focus()

func _display_mode_label(mode_id: String) -> String:
	for option_value in SettingsService.build_presentation_options():
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if String(option.get("id", "")) == mode_id:
			return String(option.get("label", mode_id.capitalize()))
	return mode_id.capitalize()

func _display_resolution_label(resolution_id: String) -> String:
	for option_value in SettingsService.build_resolution_options():
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if String(option.get("id", "")) == resolution_id:
			return String(option.get("label", resolution_id))
	return resolution_id

func _on_presentation_mode_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _presentation_mode_picker.get_item_count():
		return
	var mode_id := String(_presentation_mode_picker.get_item_metadata(index))
	_request_display_change_preview(
		mode_id,
		SettingsService.presentation_resolution_id(),
		&"PresentationModePicker"
	)

func _on_resolution_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _resolution_picker.get_item_count():
		return
	var resolution_id := String(_resolution_picker.get_item_metadata(index))
	_request_display_change_preview(
		SettingsService.presentation_mode_id(),
		resolution_id,
		&"ResolutionPicker"
	)

func _on_render_quality_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _render_quality_picker.get_item_count():
		return
	_finish_settings_commit(SettingsService.set_render_quality_id(String(_render_quality_picker.get_item_metadata(index))))

func _on_vsync_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_vsync_enabled(enabled))

func _on_frame_rate_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _frame_rate_picker.get_item_count():
		return
	_finish_settings_commit(SettingsService.set_frame_rate_limit(int(_frame_rate_picker.get_item_metadata(index))))

func _on_battle_playback_speed_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _battle_playback_speed_picker.get_item_count():
		return
	_finish_settings_commit(SettingsService.set_battle_playback_speed_id(String(_battle_playback_speed_picker.get_item_metadata(index))))

func _on_keyboard_navigation_layout_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _keyboard_navigation_layout_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_keyboard_navigation_layout_id(String(_keyboard_navigation_layout_picker.get_item_metadata(index)))
	_hero_keybindings_dialog.refresh_dialog()
	_finish_settings_commit(result)

func _on_customize_movement_keys_pressed() -> void:
	_hero_keybindings_dialog.open_dialog(_customize_movement_keys_button)

func _on_hero_keybindings_dialog_dismissed() -> void:
	_refresh_settings_panel()

func _on_master_volume_changed(value: float) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_master_volume_percent(int(round(value))))

func _on_music_volume_changed(value: float) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_music_volume_percent(int(round(value))))

func _on_effects_volume_changed(value: float) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_effects_volume_percent(int(round(value))))

func _on_ui_scale_selected(index: int) -> void:
	if _syncing_settings_ui:
		return
	if index < 0 or index >= _ui_scale_picker.get_item_count():
		return
	_finish_settings_commit(SettingsService.set_ui_scale_percent(int(_ui_scale_picker.get_item_metadata(index))))

func _on_battle_camera_shake_selected(index: int) -> void:
	if _syncing_settings_ui or index < 0 or index >= _battle_camera_shake_picker.get_item_count():
		return
	_finish_settings_commit(SettingsService.set_battle_camera_shake_mode_id(String(_battle_camera_shake_picker.get_item_metadata(index))))

func _on_high_contrast_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	var result: Dictionary = SettingsService.set_high_contrast_ui_enabled(enabled)
	_apply_visual_theme()
	_finish_settings_commit(result)

func _on_color_cue_selected(index: int) -> void:
	if _syncing_settings_ui:
		return
	if index < 0 or index >= _color_cue_picker.get_item_count():
		return
	var result: Dictionary = SettingsService.set_color_cue_mode_id(String(_color_cue_picker.get_item_metadata(index)))
	_apply_visual_theme()
	_finish_settings_commit(result)

func _on_reduce_motion_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_reduced_motion_enabled(enabled))

func _on_reduce_flashes_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_reduced_flashes_enabled(enabled))

func _on_reduce_repetitive_sounds_toggled(enabled: bool) -> void:
	if _syncing_settings_ui:
		return
	_finish_settings_commit(SettingsService.set_reduced_repetitive_sounds_enabled(enabled))

func _finish_settings_commit(result: Dictionary) -> bool:
	if bool(result.get("ok", false)):
		var success_message := String(result.get("message", "")).strip_edges()
		_settings_restore_status = success_message if success_message != "" else "Saved on this device."
	else:
		_settings_restore_status = _settings_commit_failure_text(result)
	_refresh_settings_panel()
	return bool(result.get("ok", false))

func _settings_commit_failure_text(result: Dictionary) -> String:
	var detail := String(result.get("message", "")).strip_edges()
	var message := "Settings not saved; previous settings restored."
	if detail != "" and detail.to_lower() not in message.to_lower():
		message = "%s %s" % [message, detail]
	return message.substr(0, 180)

func _on_export_support_bundle_pressed() -> void:
	_export_support_bundle(true)

func _on_restore_settings_defaults_pressed() -> void:
	_settings_restore_return_focus = _capture_confirmation_origin(_restore_settings_defaults_button)
	_settings_restore_pending = true
	_begin_destructive_confirmation_generation("settings_restore")
	_count_destructive_confirmation("settings_restore", "request_count")
	_settings_restore_defaults_dialog.dialog_text = "Restore presentation, sound, gameplay, custom movement keys, and readability settings to their defaults? Campaign progress and expedition saves will stay unchanged. Display mode and resolution will be previewed separately before they are kept."
	var dialog_label := _settings_restore_defaults_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(560.0, 86.0)
	_settings_restore_defaults_dialog.get_ok_button().text = "Restore Defaults"
	_settings_restore_defaults_dialog.popup_centered(Vector2i(680, 230))
	_focus_destructive_confirmation_cancel.call_deferred(_settings_restore_defaults_dialog, "settings_restore")

func _on_settings_restore_defaults_confirmed() -> void:
	_settings_restore_defaults_dialog.hide()
	if not _settings_restore_pending:
		return
	_settings_restore_pending = false
	_settings_restore_return_focus = null
	_count_destructive_confirmation("settings_restore", "confirm_count")
	var result: Dictionary = SettingsService.restore_default_settings(true)
	_settings_restore_status = (
		String(result.get("message", "Settings restored and saved.")).strip_edges()
		if bool(result.get("ok", false))
		else _settings_commit_failure_text(result)
	)
	_apply_visual_theme()
	_refresh_settings_panel()
	if not bool(result.get("ok", false)) or not bool(result.get("display_change_deferred", false)):
		_restore_settings_defaults_button.call_deferred("grab_focus")
		return
	var display_candidate_value: Variant = result.get("display_candidate", {})
	var display_candidate: Dictionary = display_candidate_value if display_candidate_value is Dictionary else {}
	if display_candidate.is_empty():
		_restore_settings_defaults_button.call_deferred("grab_focus")
		return
	var restore_status := _settings_restore_status
	var preview_result := _request_display_change_preview(
		String(display_candidate.get("mode", SettingsService.PRESENTATION_WINDOWED)),
		String(display_candidate.get("resolution", SettingsService.PRESENTATION_RESOLUTION_DEFAULT)),
		&"RestoreSettingsDefaults"
	)
	if bool(preview_result.get("ok", false)) and not bool(preview_result.get("changed", false)):
		_settings_restore_status = restore_status
		_refresh_settings_panel()

func _on_settings_restore_defaults_canceled() -> Dictionary:
	var had_pending := _settings_restore_pending
	_settings_restore_defaults_dialog.hide()
	_settings_restore_pending = false
	if had_pending:
		_count_destructive_confirmation("settings_restore", "cancel_count")
		_restore_destructive_confirmation_origin.call_deferred("settings_restore")
	return {"ok": true, "canceled": had_pending, "pending": false}

func _export_support_bundle(reveal_in_file_manager: bool) -> Dictionary:
	var result: Dictionary = RuntimeIssueLog.export_support_bundle(SettingsService.ensure_settings())
	_support_bundle_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		_support_bundle_status = "Support bundle ready"
		if reveal_in_file_manager and not OS.has_feature("headless"):
			var absolute_path := ProjectSettings.globalize_path(String(result.get("path", RuntimeIssueLog.SUPPORT_BUNDLE_PATH)))
			var reveal_error := OS.shell_show_in_file_manager(absolute_path, true)
			if reveal_error != OK:
				_support_bundle_status = "Support bundle ready; folder did not open"
	else:
		_support_bundle_status = String(result.get("message", "Support bundle export failed."))
	_refresh_support_bundle_surface()
	return result

func _on_quit_pressed() -> Dictionary:
	_revert_pending_display_change("menu_exit", false)
	var result: Dictionary = AppRouter.request_safe_quit("main_menu")
	if not bool(result.get("ok", false)):
		_menu_notice = String(result.get("message", "The game could not close safely."))
		if is_node_ready():
			_refresh_summary()
	return result

func validation_request_safe_quit() -> Dictionary:
	return _on_quit_pressed()

func _sync_campaign_storage_state() -> Dictionary:
	_campaign_storage_blocked = CampaignProgression.is_storage_blocked()
	_campaign_storage_state = CampaignProgression.storage_state()
	_campaign_storage_warning = CampaignProgression.storage_warning().strip_edges()
	if _campaign_storage_blocked and _campaign_storage_warning == "":
		_campaign_storage_warning = "Campaign progress is unavailable. Existing data was preserved and cannot be overwritten."
	elif not _campaign_storage_blocked:
		_campaign_storage_warning = ""
	if _campaign_storage_blocked and _campaign_last_mutation_result.is_empty():
		var failure := CampaignProgression.last_failure_result()
		if not failure.is_empty():
			_campaign_last_mutation_result = failure.duplicate(true)
	return _campaign_storage_state.duplicate(true)

func _campaign_storage_is_blocked_now() -> bool:
	_sync_campaign_storage_state()
	return _campaign_storage_blocked

func _campaign_storage_blocked_result(operation: String, context: Dictionary = {}) -> Dictionary:
	_sync_campaign_storage_state()
	_validation_campaign_blocked_command_count += 1
	var reason := "future_version" if String(_campaign_storage_state.get("status", "")) == "future_version" else "invalid_storage"
	_campaign_last_mutation_result = {
		"ok": false,
		"changed": false,
		"path": "",
		"operation": operation,
		"reason": reason,
		"message": _campaign_storage_warning,
		"storage_state": _campaign_storage_state.duplicate(true),
		"blocked": true,
	}
	for key in context.keys():
		_campaign_last_mutation_result[key] = context[key]
	_campaign_restart_notice = _campaign_storage_warning
	return _campaign_last_mutation_result.duplicate(true)

func _campaign_ui_failure_result(
	operation: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	_campaign_last_mutation_result = {
		"ok": false,
		"changed": false,
		"path": "",
		"operation": operation,
		"reason": "unavailable",
		"message": message.strip_edges(),
		"storage_state": _campaign_storage_state.duplicate(true),
		"blocked": false,
	}
	for key in context.keys():
		_campaign_last_mutation_result[key] = context[key]
	return _campaign_last_mutation_result.duplicate(true)

func _consume_campaign_mutation_result(result: Dictionary, operation: String) -> Dictionary:
	_campaign_last_mutation_result = result.duplicate(true)
	if not _campaign_last_mutation_result.has("operation"):
		_campaign_last_mutation_result["operation"] = operation
	_sync_campaign_storage_state()
	if not bool(_campaign_last_mutation_result.get("ok", false)):
		var message := String(_campaign_last_mutation_result.get("message", "")).strip_edges()
		if message == "" and _campaign_storage_blocked:
			message = _campaign_storage_warning
		_campaign_last_mutation_result["message"] = message
		_campaign_restart_notice = message
	return _campaign_last_mutation_result.duplicate(true)

func _rebuild_campaign_browser() -> void:
	_sync_campaign_storage_state()
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

func _ensure_campaign_browser_loaded() -> void:
	if _campaign_browser_loaded:
		return
	_rebuild_campaign_browser()
	_campaign_browser_loaded = true

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
		var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id, _selected_difficulty)
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
	_sync_campaign_storage_state()
	_sync_campaign_native_navigation()
	_refresh_campaign_row_tooltips()
	if _campaign_entries.is_empty():
		_set_commander_portrait(_campaign_commander_portrait, "")
		_set_compact_label(_campaign_details_label, "Campaign board: archived campaign arcs are not active in this build.", 2, 82)
		_set_compact_label(
			_campaign_arc_status_label,
			_campaign_storage_warning if _campaign_storage_blocked else "Campaign reset: no player-facing campaign progression is exposed.",
			3,
			86
		)
		_set_compact_label(_chapter_details_label, "No campaign chapters are selectable from the main menu.", 2, 82)
		_set_compact_label(_campaign_commander_preview_label, "Skirmish fronts remain available for fresh expeditions.", 3, 82)
		_set_compact_label(_campaign_operational_board_label, "Use Skirmish to launch playable authored fronts while campaign arcs stay archived.", 3, 82)
		_set_compact_label(_campaign_journal_label, "Campaign journal is dormant until campaign arcs are reactivated.", 3, 82)
		_campaign_primary_button.text = "No Campaign"
		_campaign_primary_button.disabled = true
		_campaign_primary_button.tooltip_text = "Campaign board is intentionally disabled by the archived campaign-domain reset; open Skirmish for playable fronts."
		_campaign_restart_button.visible = false
		_campaign_restart_button.disabled = true
		_campaign_difficulty_picker.disabled = true
		_campaign_difficulty_picker.tooltip_text = "Campaign difficulty is unavailable while no campaign arcs are active."
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.visible = true
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = "No campaign chapter is selectable while the campaign domain is archived."
		return

	_set_compact_label(_campaign_details_label, CampaignProgression.campaign_details(_selected_campaign_id), 4, 86)
	var arc_status := CampaignProgression.campaign_arc_status(_selected_campaign_id)
	if _campaign_storage_blocked:
		arc_status = _campaign_storage_warning
	elif _campaign_restart_notice != "":
		arc_status = "%s\n%s" % [_campaign_restart_notice, arc_status]
	_set_compact_label(_campaign_arc_status_label, arc_status, 3, 86)
	_set_compact_label(_campaign_journal_label, CampaignProgression.campaign_journal(_selected_campaign_id), 3, 86)
	_campaign_difficulty_picker.disabled = false
	_campaign_difficulty_picker.tooltip_text = "Campaign difficulty: %s\n%s" % [
		ScenarioSelectRulesScript.difficulty_label(_selected_difficulty),
		ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty),
	]

	var primary_action := CampaignProgression.primary_campaign_action(_selected_campaign_id, _selected_difficulty)
	var restart_action := CampaignProgression.campaign_restart_action(_selected_campaign_id)
	_campaign_restart_button.text = String(restart_action.get("label", "Restart Arc"))
	_campaign_restart_button.disabled = _campaign_storage_blocked or bool(restart_action.get("disabled", true))
	_campaign_restart_button.visible = not _campaign_restart_button.disabled
	_campaign_restart_button.tooltip_text = _campaign_storage_warning if _campaign_storage_blocked else String(restart_action.get("summary", ""))
	_campaign_primary_button.text = String(primary_action.get("label", "Advance Campaign"))
	_campaign_primary_button.disabled = _campaign_storage_blocked or bool(primary_action.get("disabled", false))
	_campaign_primary_button.tooltip_text = _campaign_storage_warning if _campaign_storage_blocked else String(primary_action.get("summary", ""))

	if _selected_campaign_scenario_id == "":
		_set_commander_portrait(_campaign_commander_portrait, "")
		_set_compact_label(_chapter_details_label, "Select a chapter to inspect carryover and the latest result.", 3, 86)
		_set_compact_label(_campaign_commander_preview_label, "Select a chapter to review the commander and opening force.", 3, 86)
		_set_compact_label(_campaign_operational_board_label, "Select a chapter to review terrain, pressure, and first contact.", 3, 86)
		_start_chapter_button.text = "Select Chapter"
		_start_chapter_button.visible = true
		_start_chapter_button.disabled = true
		_start_chapter_button.tooltip_text = _campaign_storage_warning if _campaign_storage_blocked else "Select a chapter to start or replay it."
		return

	var chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty)
	var campaign_scenario := ContentService.get_scenario(_selected_campaign_scenario_id)
	_set_commander_portrait(_campaign_commander_portrait, String(campaign_scenario.get("hero_id", "")))
	var chapter_check := _campaign_chapter_check_payload(chapter_action, primary_action)
	_start_chapter_button.visible = not _campaign_launch_actions_are_exact(chapter_action, primary_action)
	_set_compact_label(
		_chapter_details_label,
		_chapter_details_with_campaign_check(
			CampaignProgression.chapter_details(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty),
			chapter_check
		),
		4,
		86
	)
	_set_compact_label(
		_campaign_commander_preview_label,
		CampaignProgression.chapter_commander_preview(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty),
		4,
		86
	)
	_set_compact_label(
		_campaign_operational_board_label,
		CampaignProgression.chapter_operational_board(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty),
		4,
		86
	)

	_start_chapter_button.text = String(chapter_action.get("label", "Start Chapter"))
	_start_chapter_button.disabled = _campaign_storage_blocked or bool(chapter_action.get("disabled", false))
	_start_chapter_button.tooltip_text = (
		_campaign_storage_warning
		if _campaign_storage_blocked
		else _join_nonempty_lines([
			String(chapter_check.get("tooltip_text", "")),
			String(chapter_action.get("summary", "")),
		])
	)

func _campaign_launch_actions_are_exact(chapter_action: Dictionary, primary_action: Dictionary) -> bool:
	return not chapter_action.is_empty() and chapter_action == primary_action

func _refresh_campaign_row_tooltips() -> void:
	for index in range(mini(_campaign_list.item_count, _campaign_entries.size())):
		var campaign_id := String(_campaign_entries[index].get("campaign_id", ""))
		_campaign_list.set_item_tooltip(index, _join_nonempty_lines([
			CampaignProgression.campaign_details(campaign_id),
			CampaignProgression.campaign_arc_status(campaign_id),
		]))
	for index in range(mini(_chapter_list.item_count, _campaign_chapter_entries.size())):
		var scenario_id := String(_campaign_chapter_entries[index].get("scenario_id", ""))
		var action := CampaignProgression.chapter_action(_selected_campaign_id, scenario_id, _selected_difficulty)
		_chapter_list.set_item_tooltip(index, _join_nonempty_lines([
			CampaignProgression.chapter_details(_selected_campaign_id, scenario_id, _selected_difficulty),
			String(action.get("summary", "")),
		]))

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
		_refresh_credits_notices_command()
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
	_refresh_credits_notices_command()

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

func _set_settings_summary(full_text: String) -> void:
	_settings_summary_label.tooltip_text = full_text
	_settings_summary_label.text = _settings_summary_visible_text(full_text)

func _settings_summary_visible_text(full_text: String) -> String:
	var lines: Array[String] = []
	for raw_line in full_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		lines.append(_settings_summary_visible_line(line))
	if lines.is_empty():
		return full_text.strip_edges()
	if lines.size() > SETTINGS_SUMMARY_MAX_LINES:
		var hidden_count := lines.size() - SETTINGS_SUMMARY_MAX_LINES
		lines = lines.slice(0, SETTINGS_SUMMARY_MAX_LINES)
		lines.append("+ %d more" % hidden_count)
	return "\n".join(lines)

func _settings_summary_visible_line(line: String) -> String:
	if line.length() <= SETTINGS_SUMMARY_MAX_CHARS:
		return line
	if SETTINGS_SUMMARY_MAX_CHARS <= 1:
		return "…"
	var prefix := line.left(SETTINGS_SUMMARY_MAX_CHARS - 1).strip_edges()
	var setting_boundary := prefix.rfind(" | ")
	if setting_boundary > 0:
		return "%s…" % prefix.left(setting_boundary).strip_edges()
	var word_boundary := prefix.rfind(" ")
	if word_boundary > 0:
		return "%s…" % prefix.left(word_boundary).strip_edges()
	return "…"

func _refresh_settings_panel() -> void:
	_set_settings_summary(SettingsService.describe_settings())
	var settings_check := SettingsService.describe_settings_persistence_check()
	var display_settings_check := "Display changes preview immediately and are stored only after Keep. Revert or timeout restores the previous display; campaign progress and expedition saves stay unchanged."
	var settings_handoff := _settings_handoff_surface()
	_set_compact_label(_settings_handoff_label, String(settings_handoff.get("visible_text", "")), 2, 96)
	_settings_handoff_label.tooltip_text = String(settings_handoff.get("tooltip_text", ""))
	var display_snapshot: Dictionary = SettingsService.display_change_snapshot()
	var displayed_mode := String(display_snapshot.get("mode", SettingsService.presentation_mode_id())) if bool(display_snapshot.get("pending", false)) else SettingsService.presentation_mode_id()
	var displayed_resolution := String(display_snapshot.get("resolution", SettingsService.presentation_resolution_id())) if bool(display_snapshot.get("pending", false)) else SettingsService.presentation_resolution_id()

	_syncing_settings_ui = true
	_presentation_mode_picker.clear()
	var options := SettingsService.build_presentation_options()
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		var label := String(option.get("label", option.get("id", "Window Mode")))
		_presentation_mode_picker.add_item(label, index)
		_presentation_mode_picker.set_item_metadata(index, String(option.get("id", "")))
		if String(option.get("id", "")) == displayed_mode:
			selected_index = index
	if selected_index >= 0:
		_presentation_mode_picker.select(selected_index)
		_presentation_mode_picker.tooltip_text = "%s\n%s" % [String(options[selected_index].get("summary", "")), display_settings_check]

	_resolution_picker.clear()
	var resolution_options := SettingsService.build_resolution_options()
	var selected_resolution_index := -1
	for index in range(resolution_options.size()):
		var option = resolution_options[index]
		var label := String(option.get("label", option.get("id", "Resolution")))
		_resolution_picker.add_item(label, index)
		_resolution_picker.set_item_metadata(index, String(option.get("id", "")))
		if String(option.get("id", "")) == displayed_resolution:
			selected_resolution_index = index
	if selected_resolution_index >= 0:
		_resolution_picker.select(selected_resolution_index)
		_resolution_picker.tooltip_text = "%s\n%s" % [String(resolution_options[selected_resolution_index].get("summary", "")), display_settings_check]

	_render_quality_picker.clear()
	var quality_options := SettingsService.build_render_quality_options()
	var selected_quality_index := -1
	for index in range(quality_options.size()):
		var option: Dictionary = quality_options[index]
		_render_quality_picker.add_item(String(option.get("label", "Balanced")), index)
		_render_quality_picker.set_item_metadata(index, String(option.get("id", "balanced")))
		if bool(option.get("selected", false)):
			selected_quality_index = index
	if selected_quality_index >= 0:
		_render_quality_picker.select(selected_quality_index)
	_render_quality_picker.tooltip_text = "2D edge quality applies immediately; lower quality reduces multisampling cost.\n%s" % settings_check

	_vsync_toggle.button_pressed = SettingsService.vsync_enabled()
	_vsync_toggle.tooltip_text = "VSync applies immediately and reduces visible tearing.\n%s" % settings_check
	_frame_rate_picker.clear()
	var frame_rate_options := SettingsService.build_frame_rate_options()
	var selected_frame_rate_index := -1
	for index in range(frame_rate_options.size()):
		var option: Dictionary = frame_rate_options[index]
		_frame_rate_picker.add_item(String(option.get("label", "Unlimited")), index)
		_frame_rate_picker.set_item_metadata(index, int(option.get("value", 0)))
		if bool(option.get("selected", false)):
			selected_frame_rate_index = index
	if selected_frame_rate_index >= 0:
		_frame_rate_picker.select(selected_frame_rate_index)
	_frame_rate_picker.tooltip_text = "Frame limiting applies immediately; Unlimited leaves pacing to VSync or the display.\n%s" % settings_check

	_battle_playback_speed_picker.clear()
	var battle_speed_options := SettingsService.build_battle_playback_speed_options()
	var selected_battle_speed_index := -1
	for index in range(battle_speed_options.size()):
		var option: Dictionary = battle_speed_options[index]
		_battle_playback_speed_picker.add_item(String(option.get("label", "Normal")), index)
		_battle_playback_speed_picker.set_item_metadata(index, String(option.get("id", "normal")))
		if bool(option.get("selected", false)):
			selected_battle_speed_index = index
	if selected_battle_speed_index >= 0:
		_battle_playback_speed_picker.select(selected_battle_speed_index)
	_battle_playback_speed_picker.tooltip_text = "Sets the default playback pace for every new or resumed battle without changing combat results.\n%s" % settings_check

	_keyboard_navigation_layout_picker.clear()
	var keyboard_layout_options := SettingsService.build_keyboard_navigation_layout_options()
	var selected_keyboard_layout_index := -1
	for index in range(keyboard_layout_options.size()):
		var option: Dictionary = keyboard_layout_options[index]
		_keyboard_navigation_layout_picker.add_item(String(option.get("label", "WASD + Arrows")), index)
		_keyboard_navigation_layout_picker.set_item_metadata(index, String(option.get("id", "wasd")))
		if bool(option.get("selected", false)):
			selected_keyboard_layout_index = index
	if selected_keyboard_layout_index >= 0:
		_keyboard_navigation_layout_picker.select(selected_keyboard_layout_index)
	_keyboard_navigation_layout_picker.tooltip_text = "%s\nDirectional keyboard navigation applies immediately across menus and active play; controller input remains unchanged.\n%s" % [SettingsService.keyboard_navigation_layout_summary(), settings_check]
	_customize_movement_keys_button.text = "Keys: Custom" if SettingsService.has_custom_hero_movement_bindings() else "Customize Keys"
	_customize_movement_keys_button.tooltip_text = "Change all eight hero movement directions. Reserved interface and numpad keys remain available.\n%s" % settings_check

	_master_volume_slider.value = SettingsService.master_volume_percent()
	_master_volume_slider.tooltip_text = "Master volume applies immediately.\n%s" % settings_check
	_master_volume_value.text = "%d%%" % SettingsService.master_volume_percent()
	_music_volume_slider.value = SettingsService.music_volume_percent()
	_music_volume_slider.tooltip_text = "Music volume applies immediately.\n%s" % settings_check
	_music_volume_value.text = "%d%%" % SettingsService.music_volume_percent()
	_effects_volume_slider.value = SettingsService.effects_volume_percent()
	_effects_volume_slider.tooltip_text = "UI, battle, and ambient effects volume applies immediately.\n%s" % settings_check
	_effects_volume_value.text = "%d%%" % SettingsService.effects_volume_percent()
	_ui_scale_picker.clear()
	var ui_scale_options := SettingsService.build_ui_scale_options()
	var selected_ui_scale_index := -1
	for index in range(ui_scale_options.size()):
		var option: Dictionary = ui_scale_options[index]
		_ui_scale_picker.add_item(String(option.get("label", "100%")), index)
		_ui_scale_picker.set_item_metadata(index, int(option.get("value", 100)))
		if bool(option.get("selected", false)):
			selected_ui_scale_index = index
	if selected_ui_scale_index >= 0:
		_ui_scale_picker.select(selected_ui_scale_index)
	_ui_scale_picker.tooltip_text = "Whole-interface scale applies immediately.\n%s" % settings_check
	_battle_camera_shake_picker.clear()
	var battle_shake_options := SettingsService.build_battle_camera_shake_options()
	var selected_battle_shake_index := -1
	for index in range(battle_shake_options.size()):
		var option: Dictionary = battle_shake_options[index]
		_battle_camera_shake_picker.add_item(String(option.get("label", "Full")), index)
		_battle_camera_shake_picker.set_item_metadata(index, String(option.get("id", "full")))
		if bool(option.get("selected", false)):
			selected_battle_shake_index = index
	if selected_battle_shake_index >= 0:
		_battle_camera_shake_picker.select(selected_battle_shake_index)
	_battle_camera_shake_picker.tooltip_text = "Battle camera displacement applies immediately without changing animation timing.\n%s" % settings_check
	_high_contrast_toggle.button_pressed = SettingsService.high_contrast_ui_enabled()
	_high_contrast_toggle.tooltip_text = "High contrast applies immediately across shared interface surfaces.\n%s" % settings_check
	_color_cue_picker.clear()
	var color_cue_options := SettingsService.build_color_cue_options()
	var selected_color_cue_index := -1
	for index in range(color_cue_options.size()):
		var option: Dictionary = color_cue_options[index]
		_color_cue_picker.add_item(String(option.get("label", "Standard")), index)
		_color_cue_picker.set_item_metadata(index, String(option.get("id", "standard")))
		if bool(option.get("selected", false)):
			selected_color_cue_index = index
	if selected_color_cue_index >= 0:
		_color_cue_picker.select(selected_color_cue_index)
	_color_cue_picker.tooltip_text = "Shape and palette assistance applies immediately to semantic controls and gameplay ownership cues.\n%s" % settings_check
	_reduce_motion_toggle.button_pressed = SettingsService.reduced_motion_enabled()
	_reduce_motion_toggle.tooltip_text = "Reduced motion preference applies immediately.\n%s" % settings_check
	_reduce_flashes_toggle.button_pressed = SettingsService.reduced_flashes_enabled()
	_reduce_flashes_toggle.tooltip_text = "Replaces strong battle flashes with static cues while preserving normal motion and timing.\n%s" % settings_check
	_reduce_repetitive_sounds_toggle.button_pressed = SettingsService.reduced_repetitive_sounds_enabled()
	_reduce_repetitive_sounds_toggle.tooltip_text = "Limits repeated interface and battle cues while preserving decisive sounds and Effects volume.\n%s" % settings_check
	_refresh_support_bundle_surface()
	_restore_settings_defaults_button.tooltip_text = "Restore presentation, sound, gameplay, custom movement keys, and readability defaults. Campaign progress and expedition saves stay unchanged."
	_settings_restore_status_label.text = _settings_restore_status
	_settings_restore_status_label.tooltip_text = "This operation changes only device settings. Support bundles, campaign progress, expedition saves, and the active session remain unchanged."
	_syncing_settings_ui = false
	_queue_current_settings_focus_visibility()

func _refresh_support_bundle_surface() -> void:
	_export_support_bundle_button.tooltip_text = "Create a local support bundle from bounded device settings and recent runtime issues. No saves or telemetry are included."
	_support_bundle_status_label.text = _support_bundle_status
	if bool(_support_bundle_result.get("ok", false)):
		_support_bundle_status_label.tooltip_text = "Saved locally in the application's debug data folder. Recent issue records: %d. Bundle size: %d bytes." % [
			int(_support_bundle_result.get("issue_record_count", 0)),
			int(_support_bundle_result.get("size_bytes", 0)),
		]
	else:
		_support_bundle_status_label.tooltip_text = "Local-only export status. Expedition saves and campaign progression are never included."

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
			label = "Latest | %s" % label
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
		_save_commander_portrait.set_hero_id("")
		var empty_text := _save_load_notice if _save_load_notice != "" else "No saved expeditions are available."
		_set_compact_label(_save_details_label, empty_text, 3, 84)
		_delete_selected_save_button.visible = false
		_delete_selected_save_button.disabled = true
		_delete_selected_save_button.tooltip_text = "Select an occupied autosave or manual slot first."
		_save_name_edit.visible = false
		_apply_save_name_button.visible = false
		_load_selected_button.text = "Load Save"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = _selected_save_command_tooltip(summary)
		return

	_save_commander_portrait.set_hero_id(String(summary.get("hero_id", "")))
	var details := SaveService.describe_load_preview(summary)
	if _save_load_notice != "":
		details = "%s\n\n%s" % [_save_load_notice, details]
	_set_compact_label(_save_details_label, details, 6, 88)
	var delete_action := SaveService.build_delete_action(summary)
	var name_action := SaveService.build_manual_slot_name_action(summary)
	_save_name_edit.visible = not bool(name_action.get("disabled", true))
	_apply_save_name_button.visible = _save_name_edit.visible
	_save_name_edit.text = String(name_action.get("current_name", ""))
	_save_name_edit.placeholder_text = "Optional save name"
	_save_name_edit.tooltip_text = String(name_action.get("message", ""))
	_refresh_save_name_action()
	_delete_selected_save_button.text = String(delete_action.get("label", "Delete Save"))
	_delete_selected_save_button.disabled = bool(delete_action.get("disabled", true))
	_delete_selected_save_button.visible = not _delete_selected_save_button.disabled
	_delete_selected_save_button.tooltip_text = String(delete_action.get("summary", ""))
	_load_selected_button.text = SaveService.load_action_label(summary)
	_load_selected_button.disabled = not SaveService.can_load_summary(summary)
	_load_selected_button.tooltip_text = _selected_save_command_tooltip(summary)

func _refresh_save_name_action() -> void:
	if not _save_name_edit.visible:
		_apply_save_name_button.disabled = true
		return
	var action := SaveService.build_manual_slot_name_action(_selected_summary())
	var current_name := String(action.get("current_name", ""))
	var requested_name := _save_name_edit.text.strip_edges()
	_apply_save_name_button.text = "Clear Name" if requested_name == "" and current_name != "" else "Save Name"
	_apply_save_name_button.disabled = bool(action.get("disabled", true)) or requested_name == current_name
	_apply_save_name_button.tooltip_text = String(action.get("message", ""))

func _save_browser_row_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Select a saved expedition to preview it."
	return SaveService.load_action_tooltip(summary)

func _selected_save_command_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Select an available saved expedition first."
	return SaveService.load_action_tooltip(summary)

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
		if latest.is_empty() or SaveService.summary_recency_timestamp(summary) > SaveService.summary_recency_timestamp(latest):
			latest = summary
	return latest

func _active_save_board_latest_summary() -> Dictionary:
	if not _save_browser_loaded or not _stage_dock_is_open() or _menu_tabs.current_tab != TAB_SAVES:
		return {}
	return _latest_loaded_save_summary()

func _active_save_board_selected_summary() -> Dictionary:
	if not _save_browser_loaded or not _stage_dock_is_open() or _menu_tabs.current_tab != TAB_SAVES:
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
		_set_compact_label(_save_details_label, "Open Load to choose a saved expedition.", 3, 84)
	if _save_commander_portrait != null:
		_save_commander_portrait.set_hero_id("")
	if _load_selected_button != null:
		_load_selected_button.text = "Load Save"
		_load_selected_button.disabled = true
		_load_selected_button.tooltip_text = "Open Load to inspect save slots before loading."
	if _delete_selected_save_button != null:
		_delete_selected_save_button.visible = false
		_delete_selected_save_button.disabled = true
		_delete_selected_save_button.tooltip_text = "Open Load to inspect occupied save slots before deleting."

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

func _configure_difficulty_pickers() -> void:
	_populate_difficulty_picker(_campaign_difficulty_picker)
	_populate_difficulty_picker(_difficulty_picker)

func _populate_difficulty_picker(picker: OptionButton) -> void:
	picker.clear()
	var options := ScenarioSelectRulesScript.build_difficulty_options(_selected_difficulty)
	var selected_index := -1
	for index in range(options.size()):
		var option = options[index]
		var label := String(option.get("label", option.get("id", "Difficulty")))
		picker.add_item(label, index)
		picker.set_item_metadata(index, String(option.get("id", ScenarioSelectRulesScript.default_difficulty_id())))
		if bool(option.get("selected", false)):
			selected_index = index
	if selected_index >= 0:
		picker.select(selected_index)

func _sync_difficulty_picker_selection() -> void:
	for picker in [_campaign_difficulty_picker, _difficulty_picker]:
		for index in range(picker.get_item_count()):
			if String(picker.get_item_metadata(index)) == _selected_difficulty:
				picker.select(index)
				break

func _configure_generated_random_map_controls() -> void:
	var options := ScenarioSelectRulesScript.random_map_player_setup_options()
	if _generated_size_class_id == "":
		_generated_size_class_id = String(options.get("default_size_class_id", "homm3_small"))
	if _generated_template_id == "":
		_generated_template_id = String(options.get("default_template_id", "translated_rmg_template_049_v1"))
	if _generated_profile_id == "":
		_generated_profile_id = String(options.get("default_profile_id", "translated_rmg_profile_049_v1"))
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
	_rebuild_generated_profile_picker()
	_generated_template_picker.visible = false
	_generated_profile_picker.visible = false
	_generated_template_picker.tooltip_text = "Map layout is chosen automatically from the selected size and seed."
	_generated_profile_picker.tooltip_text = "Map rules are chosen automatically for this setup."

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
	if water_selected < 0:
		_generated_water_mode = String(options.get("default_water_mode", "land"))
		for index in range(_generated_water_picker.get_item_count()):
			if String(_generated_water_picker.get_item_metadata(index)) == _generated_water_mode:
				water_selected = index
				break
	if water_selected >= 0:
		_generated_water_picker.select(water_selected)
	_generated_water_picker.tooltip_text = "Choose the generated map water layout."

	_rebuild_generated_level_picker()
	var underground_supported := _generated_underground_supported()
	if not underground_supported:
		_generated_underground = false
	_select_generated_level_count(2 if _generated_underground else 1)
	_generated_underground_toggle.visible = underground_supported
	_generated_underground_toggle.disabled = not underground_supported
	_generated_underground_toggle.tooltip_text = "Level count: choose a surface-only map or add a second underground level."

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
	picker.tooltip_text = "Choose the generated map %s." % label_key

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
	_sync_skirmish_front_navigation()

func _ensure_skirmish_browser_loaded() -> void:
	if _skirmish_browser_loaded:
		return
	_configure_generated_random_map_controls()
	_rebuild_skirmish_browser()
	_refresh_skirmish_setup()
	_refresh_generated_random_map_setup()
	_skirmish_browser_loaded = true

func _refresh_skirmish_setup() -> void:
	var selected_entry := _selected_skirmish_entry()
	_sync_skirmish_front_navigation()
	_set_compact_label(_difficulty_summary_label, ScenarioSelectRulesScript.difficulty_summary(_selected_difficulty), 3, 82)

	if selected_entry.is_empty():
		_set_commander_portrait(_skirmish_commander_portrait, "")
		_set_compact_label(_skirmish_details_label, "No generated maps folder packages are available.", 2, 82)
		_set_compact_label(_setup_summary_label, "Use Generated Skirmish to create a fresh map package under maps/.", 3, 82)
		_set_compact_label(_skirmish_commander_preview_label, "Commander preview appears here.", 3, 82)
		_set_compact_label(_skirmish_operational_board_label, "Operational pressure appears here.", 3, 82)
		_start_skirmish_button.disabled = true
		_start_skirmish_button.tooltip_text = "No paired generated .amap/.ascenario packages are available under the active maps folder."
		return

	_set_compact_label(_skirmish_details_label, String(selected_entry.get("summary", "")), 3, 84)
	var setup := ScenarioSelectRulesScript.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	if setup.is_empty():
		_set_commander_portrait(_skirmish_commander_portrait, "")
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
	_set_commander_portrait(_skirmish_commander_portrait, String(setup.get("hero_id", "")))
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
	var plan_text := ""
	var pending_launch_validation := _generated_setup_pending_launch_validation(setup, retry)
	_start_generated_skirmish_button.text = "Build & Play"
	if bool(setup.get("ok", false)):
		var seed_source := String(setup.get("seed_source", "explicit"))
		var seed_label := String(setup.get("normalized_seed", ""))
		if seed_source == "auto_on_launch":
			seed_label = "Auto seed"
		if pending_launch_validation:
			status_text = "Ready to build | checked before Day 1"
		else:
			var attempt_count := int(retry.get("attempt_count", 1))
			status_text = "Map ready | built in %d attempt%s" % [attempt_count, "" if attempt_count == 1 else "s"]
		var water_label: String = {
			"land": "Land",
			"normal_water": "Normal Water",
			"islands": "Islands",
		}.get(_generated_water_mode, "Land")
		var level_label := "Surface + Underground" if _generated_underground else "Surface only"
		plan_text = "Seed: %s | %s | %d players | %s | %s" % [
			seed_label,
			ScenarioSelectRulesScript.random_map_size_class_label(_generated_size_class_id),
			_generated_player_count,
			water_label,
			level_label,
		]
		_start_generated_skirmish_button.disabled = false
		_start_generated_skirmish_button.tooltip_text = "Builds this map, checks that routes and starting positions are playable, and then starts Day 1. If map creation fails, you stay here and no save is changed."
	else:
		status_text = "Map build stopped | change the seed or setup"
		plan_text = "This setup is unavailable. Choose another supported size, water layout, level count, or seed."
		_start_generated_skirmish_button.text = "Setup Unavailable"
		_start_generated_skirmish_button.disabled = true
		_start_generated_skirmish_button.tooltip_text = "Change the seed or choose another available setup. No game starts and no save is changed."
	_set_compact_label(_generated_status_label, status_text, 2, 72)
	_set_compact_label(_generated_provenance_label, plan_text, 2, 118)
	_generated_progress_bar.visible = false

func _generated_setup_pending_launch_validation(setup: Dictionary, retry: Dictionary) -> bool:
	return bool(setup.get("preview_only", false)) \
		or String(setup.get("launch_validation_status", "")) == "pending_launch_validation" \
		or String(retry.get("validation_status", "")) == "pending_launch_validation"

func _start_generated_skirmish_staged(route_to_overworld: bool) -> Dictionary:
	var profile_started := ProfileLogScript.begin_usec()
	var profile_buckets := {}
	if _generated_generation_in_progress or _start_generated_skirmish_button.disabled:
		ProfileLogScript.emit_general("menu", "generated_setup", "generated_launch_blocked", ProfileLogScript.elapsed_ms(profile_started), profile_buckets, {
			"reason": "generated_launch_unavailable_or_already_in_progress",
			"route_to_overworld": route_to_overworld,
		}, SessionState.ensure_active_session())
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
		"Preparing map choices",
		10,
		"Locking the selected seed, size, player count, and land layout for this map."
	)
	await _yield_generated_generation_frame()

	var phase_started := ProfileLogScript.begin_usec()
	var config := _generated_random_map_config()
	profile_buckets["config"] = ProfileLogScript.elapsed_ms(phase_started)
	_set_generated_generation_stage(
		"Checking map routes",
		25,
		"Checking starting positions, travel routes, guards, and required map objects before play."
	)
	await _yield_generated_generation_frame()

	phase_started = ProfileLogScript.begin_usec()
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		_selected_difficulty,
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	profile_buckets["build_setup_with_retry"] = ProfileLogScript.elapsed_ms(phase_started)
	_generated_last_setup = setup.duplicate(true)
	_set_generated_generation_stage(
		"Map checks complete" if bool(setup.get("ok", false)) else "Map build stopped",
		62,
		"The map is playable and ready for Day 1." if bool(setup.get("ok", false)) else "This map could not be built. Change the seed or setup and try again."
	)
	await _yield_generated_generation_frame()

	if not bool(setup.get("ok", false)):
		_generated_generation_in_progress = false
		_set_generated_random_map_inputs_disabled(false)
		_apply_generated_random_map_setup_surface(setup)
		ProfileLogScript.emit_general("menu", "generated_setup", "generated_setup_blocked", ProfileLogScript.elapsed_ms(profile_started), profile_buckets, {
			"route_to_overworld": route_to_overworld,
			"setup_ok": false,
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
		}, SessionState.ensure_active_session())
		return {
			"started": false,
			"blocked": false,
			"setup": setup.duplicate(true),
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"snapshots": _duplicate_stage_snapshots(),
		}

	_set_generated_generation_stage(
		"Preparing Day 1",
		82,
		"Preparing commanders, towns, objectives, and starting resources."
	)
	await _yield_generated_generation_frame()

	phase_started = ProfileLogScript.begin_usec()
	var session := ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	profile_buckets["materialize_session"] = ProfileLogScript.elapsed_ms(phase_started)
	if session.scenario_id == "":
		_generated_generation_in_progress = false
		_set_generated_random_map_inputs_disabled(false)
		_apply_generated_random_map_setup_surface(setup)
		ProfileLogScript.emit_general("menu", "generated_setup", "generated_session_failed", ProfileLogScript.elapsed_ms(profile_started), profile_buckets, {
			"route_to_overworld": route_to_overworld,
			"setup_ok": true,
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
		}, SessionState.ensure_active_session())
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
		ProfileLogScript.emit_general("menu", "generated_setup", "generated_launch_route_to_overworld", ProfileLogScript.elapsed_ms(profile_started), profile_buckets, {
			"route_to_overworld": true,
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"scenario_id": session.scenario_id,
			"size_class_id": _generated_size_class_id,
			"template_id": String(setup.get("template_id", "")),
			"profile_id": String(setup.get("profile_id", "")),
			"player_count": _generated_player_count,
			"same_thread_frame_yields": _generated_generation_yield_count,
		}, session)
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
		ProfileLogScript.emit_general("menu", "generated_setup", "generated_launch_staged", ProfileLogScript.elapsed_ms(profile_started), profile_buckets, {
			"route_to_overworld": false,
			"yield_count": _generated_generation_yield_count,
			"stage": _generated_generation_stage.duplicate(true),
			"scenario_id": session.scenario_id,
			"size_class_id": _generated_size_class_id,
			"template_id": String(setup.get("template_id", "")),
			"profile_id": String(setup.get("profile_id", "")),
			"player_count": _generated_player_count,
			"same_thread_frame_yields": _generated_generation_yield_count,
		}, session)
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
	_start_generated_skirmish_button.text = "Building..."
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
		"template_id": "native_catalog_auto",
		"profile_id": "native_catalog_auto",
		"preview_template_id": _generated_template_id,
		"preview_profile_id": _generated_profile_id,
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
		"launch_validation_status": "pending_launch_validation",
		"preview_only": true,
		"setup_summary": "Map choices are ready. Build & Play checks the map before starting Day 1.",
		"launch_handoff": "Build the selected map and start a fresh Day 1 skirmish only after its routes and starting positions pass the playability check.",
		"failure_handoff": "If the map cannot be built, remain on this setup screen without changing any save.",
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

func _generated_random_map_config() -> Dictionary:
	var raw_seed := _generated_seed.strip_edges()
	var seed_source := "auto_on_launch" if ScenarioSelectRulesScript.random_map_seed_requests_auto(raw_seed) else "explicit"
	var seed := ScenarioSelectRulesScript.random_map_fresh_auto_seed() if seed_source == "auto_on_launch" else raw_seed
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		"",
		"",
		_generated_player_count,
		_generated_water_mode,
		_generated_underground,
		_generated_size_class_id,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
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

func _rebuild_generated_level_picker() -> void:
	_generated_underground_toggle.clear()
	var level_options: Array = ScenarioSelectRulesScript.random_map_player_setup_options().get("level_options", [])
	if level_options.is_empty():
		level_options = [
			{"label": "Surface Only (1 Level)", "level_count": 1},
			{"label": "Surface + Underground (2 Levels)", "level_count": 2},
		]
	for index in range(level_options.size()):
		var option = level_options[index]
		if not (option is Dictionary):
			continue
		_generated_underground_toggle.add_item(String(option.get("label", "%d Level" % int(option.get("level_count", 1)))), index)
		_generated_underground_toggle.set_item_metadata(index, int(option.get("level_count", 1)))
	_select_generated_level_count(2 if _generated_underground else 1)

func _select_generated_level_count(level_count: int) -> bool:
	var normalized_level_count := 2 if level_count > 1 else 1
	for index in range(_generated_underground_toggle.get_item_count()):
		if int(_generated_underground_toggle.get_item_metadata(index)) != normalized_level_count:
			continue
		_generated_underground_toggle.select(index)
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

func _rebuild_generated_profile_picker() -> void:
	var profile_options := ScenarioSelectRulesScript.random_map_profile_options_for_template(_generated_template_id)
	if profile_options.is_empty():
		profile_options = ScenarioSelectRulesScript.random_map_player_setup_options().get("profiles", [])
	var selected_still_valid := false
	for option in profile_options:
		if option is Dictionary and String(option.get("id", "")) == _generated_profile_id:
			selected_still_valid = true
			break
	if not selected_still_valid and not profile_options.is_empty() and profile_options[0] is Dictionary:
		_generated_profile_id = String(profile_options[0].get("id", _generated_profile_id))
	_rebuild_generated_option_picker(_generated_profile_picker, profile_options, _generated_profile_id, "profile")

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
	var briefing_check := String(setup.get("briefing_check", "")).strip_edges()
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
			"- Briefing: %s" % briefing_check if briefing_check != "" else "",
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
		return "No active campaign arcs loaded."

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
		return "Open Load to choose a saved expedition."
	if not SaveService.can_load_summary(latest_summary):
		return "No saved expedition is ready to resume."
	return "Latest: %s | %s" % [
		SaveService.describe_resume_brief(latest_summary),
		SaveService.format_modified_timestamp(int(latest_summary.get("modified_timestamp", 0))),
	]

func _build_footer_expedition_summary() -> String:
	var lines := [ScenarioSelectRulesScript.build_current_session_summary(SessionState.ensure_active_session())]
	lines.append(String(_continue_check_surface().get("visible_text", "")))
	lines.append(String(_quit_check_surface().get("visible_text", "")))
	var latest_summary := _active_save_board_latest_summary()
	if SaveService.can_load_summary(latest_summary):
		lines.append("Latest save: %s" % SaveService.describe_resume_brief(latest_summary))
	return "\n".join(lines)

func _select_menu_tab(index: int) -> void:
	if _menu_tabs.get_tab_count() == 0:
		return
	if index != TAB_GUIDE:
		_last_context_tab = clampi(index, 0, _menu_tabs.get_tab_count() - 1)
	_menu_tabs.current_tab = clampi(index, 0, _menu_tabs.get_tab_count() - 1)
	_apply_stage_dock_layout()
	_refresh_stage_dock_header()
	_sync_command_button_styles()

func _stage_dock_is_open() -> bool:
	return _stage_dock_panel.visible

func _toggle_stage_dock(index: int) -> void:
	var clamped_index := clampi(index, 0, maxi(_menu_tabs.get_tab_count() - 1, 0))
	if _stage_dock_is_open() and _menu_tabs.current_tab == clamped_index:
		_hide_stage_dock()
		return
	_stage_return_focus = _first_view_button_for_tab(clamped_index)
	_select_menu_tab(clamped_index)
	_show_stage_dock()

func _show_stage_dock() -> void:
	if _menu_tabs.current_tab == TAB_CAMPAIGN:
		_ensure_campaign_browser_loaded()
	elif _menu_tabs.current_tab == TAB_SKIRMISH:
		_ensure_skirmish_browser_loaded()
	_stage_dock_panel.visible = true
	_footer_pocket_panel.visible = false
	if _menu_tabs.current_tab == TAB_CAMPAIGN:
		_set_campaign_intel_expanded(false)
	if _menu_tabs.current_tab == TAB_SAVES:
		_ensure_save_browser_loaded()
	_refresh_stage_dock_header()
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()
	call_deferred("_focus_stage_entry")

func _queue_stage_accessibility_refresh() -> void:
	call_deferred("_finalize_stage_accessibility")

func _finalize_stage_accessibility() -> void:
	if (
		is_inside_tree()
		and _stage_dock_is_open()
		and _menu_tabs.current_tab == TAB_SETTINGS
		and get_viewport().gui_get_focus_owner() == _presentation_mode_picker
	):
		_settings_scroll.scroll_vertical = 0
	call_deferred("_refresh_stage_accessibility")

func _refresh_stage_accessibility() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if is_inside_tree() and _stage_dock_is_open():
		UiAccessibility.refresh_tree(_stage_dock_panel)
		UiAccessibility.refresh_tree(_campaign_command_rail)
		UiAccessibility.refresh_tree(_skirmish_command_rail)
		_queue_accessibility_subtree_update(_stage_dock_panel)
		_queue_accessibility_subtree_update(_campaign_command_rail)
		_queue_accessibility_subtree_update(_skirmish_command_rail)

func _apply_stage_dock_layout() -> void:
	var anchors := STANDARD_DOCK_ANCHORS
	if _menu_tabs.current_tab == TAB_CAMPAIGN:
		anchors = CAMPAIGN_EXPANDED_DOCK_ANCHORS if _campaign_intel_expanded else CAMPAIGN_COMPACT_DOCK_ANCHORS
	_stage_dock_panel.anchor_left = anchors.position.x
	_stage_dock_panel.anchor_top = anchors.position.y
	_stage_dock_panel.anchor_right = anchors.end.x
	_stage_dock_panel.anchor_bottom = anchors.end.y

func _hide_stage_dock() -> void:
	if SettingsService.display_change_pending() or _display_change_ui_active:
		_revert_pending_display_change("menu_exit", false)
	_stage_dock_panel.visible = false
	_campaign_command_rail.visible = false
	_skirmish_command_rail.visible = false
	_footer_pocket_panel.visible = true
	_refresh_summary()
	_sync_command_button_styles()
	_sync_system_command_buttons()
	call_deferred("_restore_first_view_focus")

func _first_view_buttons() -> Array[BaseButton]:
	return [
		_open_campaign_button,
		_open_skirmish_button,
		_open_saves_button,
		_open_settings_button,
		_open_editor_button,
		_quit_button,
	]

func _first_view_button_for_tab(tab_index: int) -> BaseButton:
	match tab_index:
		TAB_SKIRMISH:
			return _open_skirmish_button
		TAB_SAVES:
			return _open_saves_button
		TAB_SETTINGS:
			return _open_settings_button
		_:
			return _open_campaign_button

func _configure_first_view_focus_navigation() -> void:
	var buttons := _first_view_buttons()
	for index in range(buttons.size()):
		var button: BaseButton = buttons[index]
		var previous: BaseButton = buttons[(index - 1 + buttons.size()) % buttons.size()]
		var next: BaseButton = buttons[(index + 1) % buttons.size()]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)

func _settings_focus_visibility_controls() -> Array[Control]:
	return [
		_presentation_mode_picker,
		_render_quality_picker,
		_vsync_toggle,
		_resolution_picker,
		_frame_rate_picker,
		_battle_playback_speed_picker,
		_keyboard_navigation_layout_picker,
		_customize_movement_keys_button,
		_master_volume_slider,
		_music_volume_slider,
		_effects_volume_slider,
		_ui_scale_picker,
		_battle_camera_shake_picker,
		_color_cue_picker,
		_high_contrast_toggle,
		_reduce_motion_toggle,
		_reduce_flashes_toggle,
		_reduce_repetitive_sounds_toggle,
		_export_support_bundle_button,
		_restore_settings_defaults_button,
	]

func _configure_settings_focus_visibility() -> void:
	for control in _settings_focus_visibility_controls():
		var callback := _on_settings_focus_control_entered.bind(control)
		if not control.focus_entered.is_connected(callback):
			control.focus_entered.connect(callback)

func _on_settings_focus_control_entered(control: Control) -> void:
	if (
		is_inside_tree()
		and _stage_dock_is_open()
		and _menu_tabs.current_tab == TAB_SETTINGS
		and _settings_scroll.is_ancestor_of(control)
	):
		call_deferred("_ensure_settings_focus_control_visible", control)

func _queue_current_settings_focus_visibility() -> void:
	if (
		is_inside_tree()
		and _stage_dock_is_open()
		and _menu_tabs.current_tab == TAB_SETTINGS
	):
		var control := get_viewport().gui_get_focus_owner() as Control
		if control != null and _settings_scroll.is_ancestor_of(control):
			call_deferred("_ensure_settings_focus_control_visible", control)

func _ensure_settings_focus_control_visible(control: Control) -> void:
	if (
		is_inside_tree()
		and is_instance_valid(control)
		and _stage_dock_is_open()
		and _menu_tabs.current_tab == TAB_SETTINGS
		and _settings_scroll.is_ancestor_of(control)
		and get_viewport().gui_get_focus_owner() == control
	):
		_settings_scroll.ensure_control_visible(control)

func _focus_first_view_command() -> void:
	if _stage_dock_is_open() or not is_inside_tree():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		_open_campaign_button.grab_focus()

func _focus_stage_entry() -> void:
	if (
		not _stage_dock_is_open()
		or not is_inside_tree()
		or _display_change_confirmation_dialog.visible
		or _settings_restore_defaults_dialog.visible
		or _campaign_restart_dialog.visible
		or _save_delete_dialog.visible
	):
		return
	var target: Control
	match _menu_tabs.current_tab:
		TAB_CAMPAIGN:
			target = _campaign_list if _campaign_list.item_count > 0 else _campaign_primary_button
		TAB_SKIRMISH:
			target = _skirmish_list if _skirmish_list.item_count > 0 else _difficulty_picker
		TAB_SAVES:
			target = _save_list if _save_list.item_count > 0 else _close_stage_dock_button
		TAB_GUIDE:
			target = _help_list if _help_list.item_count > 0 else _stage_help_button
		TAB_SETTINGS:
			target = _presentation_mode_picker
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
		_queue_stage_accessibility_refresh()

func _restore_first_view_focus() -> void:
	if _stage_dock_is_open() or not is_inside_tree():
		return
	var target := _stage_return_focus if is_instance_valid(_stage_return_focus) else _open_campaign_button
	if target != null and target.is_visible_in_tree():
		target.grab_focus()

func _refresh_stage_dock_header() -> void:
	var stage_copy: Dictionary = TAB_STAGE_COPY.get(_menu_tabs.current_tab, TAB_STAGE_COPY[TAB_CAMPAIGN])
	var campaign_navigation_visible := _menu_tabs.current_tab == TAB_CAMPAIGN
	_stage_dock_hint_label.visible = false
	_campaign_arc_navigation.visible = true
	_campaign_chapter_navigation.visible = campaign_navigation_visible or _menu_tabs.current_tab == TAB_SKIRMISH
	_campaign_command_rail.visible = _stage_dock_is_open() and _menu_tabs.current_tab == TAB_CAMPAIGN
	_skirmish_command_rail.visible = _stage_dock_is_open() and _menu_tabs.current_tab == TAB_SKIRMISH
	_set_compact_label(_stage_dock_title_label, String(stage_copy.get("title", "Command board")), 1, 48)
	_stage_dock_title_label.tooltip_text = String(stage_copy.get("hint", ""))
	_stage_dock_title_label.accessibility_description = String(stage_copy.get("hint", ""))
	_set_compact_label(_stage_dock_hint_label, String(stage_copy.get("hint", "")), 2, 92)
	if _menu_tabs.current_tab == TAB_CAMPAIGN:
		_previous_campaign_arc_button.text = "Previous Arc"
		_next_campaign_arc_button.text = "Next Arc"
		_previous_campaign_chapter_button.text = "Previous Chapter"
		_next_campaign_chapter_button.text = "Next Chapter"
		_sync_campaign_native_navigation()
	elif _menu_tabs.current_tab == TAB_SKIRMISH:
		_previous_campaign_arc_button.text = "Previous Front"
		_next_campaign_arc_button.text = "Next Front"
		# The persistent chapter action is also the native Skirmish launch action.
		# Reapply the live Skirmish setup after Campaign navigation may have changed
		# its disabled state and tooltip while another board owned the control.
		_refresh_skirmish_setup()
		_sync_skirmish_front_navigation()
		_sync_skirmish_difficulty_navigation()
		_next_campaign_chapter_button.text = "Launch Skirmish"
	else:
		_previous_campaign_arc_button.text = "Previous Board"
		_next_campaign_arc_button.text = "Next Board"
		_previous_campaign_arc_button.disabled = _menu_tabs.current_tab <= 0
		_next_campaign_arc_button.disabled = _menu_tabs.current_tab >= _menu_tabs.get_tab_count() - 1
		_previous_campaign_arc_button.tooltip_text = "Open the previous Main Menu command board."
		_next_campaign_arc_button.tooltip_text = "Open the next Main Menu command board."
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
	var resume_line := "The current expedition is transactionally autosaved before shutdown."
	var visible := "Quit check: save first automatically, then closes client."
	var tooltip := "Quit Check\n- Action: safely saves the active expedition, then closes the client.\n- Resume point: %s\n- Save first: automatic through the verified autosave path.\n- Save failure: the game stays open and reports the problem.\n- No active expedition: closes immediately.\n- Not changed: reading this cue does not write campaign progress, expedition saves, or device settings." % resume_line
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
	}

func _continue_check_surface() -> Dictionary:
	var latest_summary := _active_save_board_latest_summary()
	if not SaveService.can_load_summary(latest_summary):
		return {
			"visible_text": "Load: choose a saved expedition.",
			"tooltip_text": "Open saved expeditions. Previewing a save does not change it.",
		}
	var resume_label := SaveService.describe_resume_brief(latest_summary)
	var visible := "Latest: %s." % resume_label
	var tooltip := SaveService.load_action_tooltip(latest_summary)
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
	}

func _settings_handoff_surface() -> Dictionary:
	var visible := "Settings handoff: changes apply now; close returns to the scenic menu."
	var tooltip := "Settings Handoff\n- Applies: presentation, sound, gameplay, and readability changes take effect immediately.\n- Saved to: device config.\n- Not changed: campaign progress and expedition saves.\n- Close: returns to the scenic first view with these settings still active."
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
	var primary_campaign_action := CampaignProgression.primary_campaign_action(_selected_campaign_id, _selected_difficulty)
	var selected_chapter_action := CampaignProgression.chapter_action(_selected_campaign_id, _selected_campaign_scenario_id, _selected_difficulty)
	var campaign_restart_action := CampaignProgression.campaign_restart_action(_selected_campaign_id)
	var campaign_chapter_check := _campaign_chapter_check_payload(selected_chapter_action, primary_campaign_action)
	var selected_skirmish_setup := ScenarioSelectRulesScript.build_skirmish_setup(_selected_skirmish_id, _selected_difficulty)
	var skirmish_front_check := _skirmish_front_check_payload(selected_skirmish_setup)
	var selected_save_summary := _active_save_board_selected_summary()
	var latest_continue := _latest_continue_surface()
	var latest_summary := _active_save_board_latest_summary()
	var quit_check := _quit_check_surface()
	var continue_check := _continue_check_surface()
	var campaign_restart_confirmation := _destructive_confirmation_snapshot("campaign_restart", _campaign_restart_dialog)
	var save_delete_confirmation := _destructive_confirmation_snapshot("save_delete", _save_delete_dialog)
	var settings_restore_confirmation := _destructive_confirmation_snapshot("settings_restore", _settings_restore_defaults_dialog)
	return {
		"scene_path": scene_file_path,
		"music_audio": MusicAudio.validation_summary(),
		"stage_dock_visible": _stage_dock_is_open(),
		"campaign_layout": _campaign_layout_snapshot(),
		"skirmish_layout": _skirmish_layout_snapshot(),
		"footer_pocket_visible": _footer_pocket_panel.visible,
		"current_tab": _menu_tabs.current_tab,
		"first_view_command_surface": "painted_backdrop_hotspots",
		"first_view_commands": _first_view_command_labels(),
		"first_view_command_tooltips": _first_view_command_tooltips(),
		"editor_utility_frame": _editor_utility_frame_snapshot(),
		"stage_help_text": _stage_help_button.text,
		"stage_help_tooltip": _stage_help_button.tooltip_text,
		"close_stage_dock_tooltip": _close_stage_dock_button.tooltip_text,
		"stage_help_return_tab": _last_context_tab,
		"has_generated_command_spine": get_node_or_null("CommandSpinePanel") != null,
		"has_first_view_status_box": get_node_or_null("SpineStatusPanel") != null,
		"campaign_browser_loaded": _campaign_browser_loaded,
		"campaign_count": _campaign_entries.size(),
		"campaign_board_status": "deferred" if not _campaign_browser_loaded else ("active" if not _campaign_entries.is_empty() else "archived_empty"),
		"campaign_storage_state": _campaign_storage_state.duplicate(true),
		"campaign_storage_blocked": _campaign_storage_blocked,
		"campaign_storage_warning": _campaign_storage_warning,
		"campaign_last_mutation_result": _campaign_last_mutation_result.duplicate(true),
		"campaign_storage_blocked_command_count": _validation_campaign_blocked_command_count,
		"campaign_empty_state_text": _campaign_details_label.text,
		"campaign_empty_state_tooltip": _campaign_details_label.tooltip_text,
		"selected_campaign_id": _selected_campaign_id,
		"selected_campaign_scenario_id": _selected_campaign_scenario_id,
		"selected_campaign_index": _selected_campaign_arc_index(),
		"selected_campaign_chapter_index": _selected_campaign_chapter_index(),
		"previous_campaign_arc_text": _previous_campaign_arc_button.text,
		"previous_campaign_arc_tooltip": _previous_campaign_arc_button.tooltip_text,
		"previous_campaign_arc_enabled": not _previous_campaign_arc_button.disabled,
		"next_campaign_arc_text": _next_campaign_arc_button.text,
		"next_campaign_arc_tooltip": _next_campaign_arc_button.tooltip_text,
		"next_campaign_arc_enabled": not _next_campaign_arc_button.disabled,
		"previous_campaign_chapter_text": _previous_campaign_chapter_button.text,
		"previous_campaign_chapter_tooltip": _previous_campaign_chapter_button.tooltip_text,
		"previous_campaign_chapter_enabled": not _previous_campaign_chapter_button.disabled,
		"next_campaign_chapter_text": _next_campaign_chapter_button.text,
		"next_campaign_chapter_tooltip": _next_campaign_chapter_button.tooltip_text,
		"next_campaign_chapter_enabled": not _next_campaign_chapter_button.disabled,
		"selected_campaign_difficulty": _selected_difficulty,
		"campaign_difficulty_text": _campaign_difficulty_picker.get_item_text(_campaign_difficulty_picker.selected) if _campaign_difficulty_picker.selected >= 0 else "",
		"campaign_difficulty_tooltip": _campaign_difficulty_picker.tooltip_text,
		"campaign_difficulty_disabled": _campaign_difficulty_picker.disabled,
		"campaign_restart_action": campaign_restart_action.duplicate(true),
		"campaign_restart_visible": _campaign_restart_button.visible,
		"campaign_restart_disabled": _campaign_restart_button.disabled,
		"campaign_restart_tooltip": _campaign_restart_button.tooltip_text,
		"campaign_restart_dialog_visible": _campaign_restart_dialog.visible,
		"campaign_restart_pending_id": _pending_campaign_restart_id,
		"campaign_restart_notice": _campaign_restart_notice,
		"campaign_restart_cancel_text": String(campaign_restart_confirmation.get("cancel_text", "")),
		"campaign_restart_dialog_focus_owner": String(campaign_restart_confirmation.get("focus_owner", "")),
		"campaign_restart_return_focus_name": String(campaign_restart_confirmation.get("return_focus_name", "")),
		"campaign_restart_origin_focus_owner": String(campaign_restart_confirmation.get("origin_focus_owner", "")),
		"campaign_restart_request_count": int(campaign_restart_confirmation.get("request_count", 0)),
		"campaign_restart_cancel_count": int(campaign_restart_confirmation.get("cancel_count", 0)),
		"campaign_restart_confirm_count": int(campaign_restart_confirmation.get("confirm_count", 0)),
		"campaign_restart_confirmation": campaign_restart_confirmation,
		"primary_campaign_action": primary_campaign_action.duplicate(true),
		"selected_chapter_action": selected_chapter_action.duplicate(true),
		"campaign_chapter_check": campaign_chapter_check.duplicate(true),
		"campaign_chapter_check_text": String(campaign_chapter_check.get("text", "")),
		"campaign_chapter_check_tooltip": String(campaign_chapter_check.get("tooltip_text", "")),
		"campaign_primary_text": _campaign_primary_button.text,
		"campaign_primary_tooltip": _campaign_primary_button.tooltip_text,
		"campaign_primary_disabled": _campaign_primary_button.disabled,
		"campaign_primary_visible": _campaign_primary_button.visible,
		"start_chapter_text": _start_chapter_button.text,
		"start_chapter_tooltip": _start_chapter_button.tooltip_text,
		"start_chapter_disabled": _start_chapter_button.disabled,
		"start_chapter_visible": _start_chapter_button.visible,
		"campaign_launch_actions_deduplicated": _campaign_launch_actions_are_exact(selected_chapter_action, primary_campaign_action) and not _start_chapter_button.visible,
		"campaign_details": _campaign_details_label.text,
		"campaign_details_full": _campaign_details_label.tooltip_text,
		"campaign_arc_status": _campaign_arc_status_label.text,
		"campaign_arc_status_full": _campaign_arc_status_label.tooltip_text,
		"chapter_details": _chapter_details_label.text,
		"chapter_details_full": _chapter_details_label.tooltip_text,
		"campaign_commander_preview": _campaign_commander_preview_label.text,
		"campaign_commander_preview_full": _campaign_commander_preview_label.tooltip_text,
		"campaign_commander_portrait_visible": _campaign_commander_portrait.visible,
		"campaign_commander_portrait_path": _campaign_commander_portrait.texture.resource_path if _campaign_commander_portrait.texture is Texture2D else "",
		"campaign_commander_portrait_tooltip": _campaign_commander_portrait.tooltip_text,
		"campaign_operational_board": _campaign_operational_board_label.text,
		"campaign_operational_board_full": _campaign_operational_board_label.tooltip_text,
		"campaign_journal": _campaign_journal_label.text,
		"campaign_journal_full": _campaign_journal_label.tooltip_text,
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
		"credits_notices_command_visible": _open_credits_notices_button.visible,
		"credits_notices_command_disabled": _open_credits_notices_button.disabled,
		"credits_notices_dialog_visible": _credits_notices_dialog.visible,
		"credits_notices_dialog_position": _credits_notices_dialog.position,
		"credits_notices_dialog_size": _credits_notices_dialog.size,
		"credits_notices_body_text": _credits_notices_body.text,
		"credits_notices_body_accessibility_name": _credits_notices_body.accessibility_name,
		"credits_notices_body_accessibility_description": _credits_notices_body.accessibility_description,
		"credits_notices_body_scroll": _credits_notices_body.scroll_vertical,
		"credits_notices_close_has_focus": _credits_notices_close_button.has_focus(),
		"skirmish_browser_loaded": _skirmish_browser_loaded,
		"skirmish_count": _skirmish_entries.size(),
		"selected_skirmish_id": _selected_skirmish_id,
		"selected_skirmish_index": _selected_skirmish_front_index(),
		"previous_skirmish_front_text": _previous_skirmish_front_button.text,
		"previous_skirmish_front_tooltip": _previous_skirmish_front_button.tooltip_text,
		"previous_skirmish_front_enabled": not _previous_skirmish_front_button.disabled,
		"next_skirmish_front_text": _next_skirmish_front_button.text,
		"next_skirmish_front_tooltip": _next_skirmish_front_button.tooltip_text,
		"next_skirmish_front_enabled": not _next_skirmish_front_button.disabled,
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
		"skirmish_commander_portrait_visible": _skirmish_commander_portrait.visible,
		"skirmish_commander_portrait_path": _skirmish_commander_portrait.texture.resource_path if _skirmish_commander_portrait.texture is Texture2D else "",
		"skirmish_commander_portrait_tooltip": _skirmish_commander_portrait.tooltip_text,
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
		"save_commander_portrait": _save_commander_portrait.validation_snapshot(),
		"save_pulse": _build_save_pulse(),
		"save_pulse_full": _build_save_pulse(),
		"continue_text": String(latest_continue.get("text", "")),
		"continue_tooltip": String(latest_continue.get("tooltip", "")),
		"continue_enabled": bool(latest_continue.get("enabled", false)),
		"load_selected_text": _load_selected_button.text,
		"load_selected_tooltip": _load_selected_button.tooltip_text,
		"selected_save_command_tooltip": _selected_save_command_tooltip(selected_save_summary),
		"load_selected_enabled": not _load_selected_button.disabled,
		"save_delete_action": SaveService.build_delete_action(selected_save_summary),
		"save_delete_visible": _delete_selected_save_button.visible,
		"save_delete_enabled": not _delete_selected_save_button.disabled,
		"save_delete_tooltip": _delete_selected_save_button.tooltip_text,
		"save_delete_dialog_visible": _save_delete_dialog.visible,
		"save_delete_pending_identity": _pending_save_delete_identity.duplicate(true),
		"save_delete_cancel_text": String(save_delete_confirmation.get("cancel_text", "")),
		"save_delete_dialog_focus_owner": String(save_delete_confirmation.get("focus_owner", "")),
		"save_delete_return_focus_name": String(save_delete_confirmation.get("return_focus_name", "")),
		"save_delete_origin_focus_owner": String(save_delete_confirmation.get("origin_focus_owner", "")),
		"save_delete_request_count": int(save_delete_confirmation.get("request_count", 0)),
		"save_delete_cancel_count": int(save_delete_confirmation.get("cancel_count", 0)),
		"save_delete_confirm_count": int(save_delete_confirmation.get("confirm_count", 0)),
		"save_delete_confirmation": save_delete_confirmation,
		"save_name_action": SaveService.build_manual_slot_name_action(selected_save_summary),
		"save_name_text": _save_name_edit.text,
		"save_name_edit_visible": _save_name_edit.visible,
		"save_name_edit_tooltip": _save_name_edit.tooltip_text,
		"apply_save_name_text": _apply_save_name_button.text,
		"apply_save_name_visible": _apply_save_name_button.visible,
		"apply_save_name_enabled": not _apply_save_name_button.disabled,
		"apply_save_name_tooltip": _apply_save_name_button.tooltip_text,
		"settings_summary": _settings_summary_label.text,
		"settings_summary_full": _settings_summary_label.tooltip_text,
		"settings_persistence_check": SettingsService.describe_settings_persistence_check(),
		"settings_handoff_text": _settings_handoff_label.text,
		"settings_handoff_tooltip": _settings_handoff_label.tooltip_text,
		"support_bundle_button_text": _export_support_bundle_button.text,
		"support_bundle_button_tooltip": _export_support_bundle_button.tooltip_text,
		"support_bundle_status": _support_bundle_status_label.text,
		"support_bundle_status_tooltip": _support_bundle_status_label.tooltip_text,
		"support_bundle_result": _support_bundle_result.duplicate(true),
		"restore_settings_defaults_button_text": _restore_settings_defaults_button.text,
		"restore_settings_defaults_button_tooltip": _restore_settings_defaults_button.tooltip_text,
		"settings_restore_status": _settings_restore_status_label.text,
		"settings_restore_status_tooltip": _settings_restore_status_label.tooltip_text,
		"settings_restore_dialog_visible": _settings_restore_defaults_dialog.visible,
		"settings_restore_dialog_title": _settings_restore_defaults_dialog.title,
		"settings_restore_dialog_text": _settings_restore_defaults_dialog.dialog_text,
		"settings_restore_pending": _settings_restore_pending,
		"settings_restore_cancel_text": String(settings_restore_confirmation.get("cancel_text", "")),
		"settings_restore_dialog_focus_owner": String(settings_restore_confirmation.get("focus_owner", "")),
		"settings_restore_return_focus_name": String(settings_restore_confirmation.get("return_focus_name", "")),
		"settings_restore_origin_focus_owner": String(settings_restore_confirmation.get("origin_focus_owner", "")),
		"settings_restore_request_count": int(settings_restore_confirmation.get("request_count", 0)),
		"settings_restore_cancel_count": int(settings_restore_confirmation.get("cancel_count", 0)),
		"settings_restore_confirm_count": int(settings_restore_confirmation.get("confirm_count", 0)),
		"settings_restore_confirmation": settings_restore_confirmation,
		"display_change_dialog_visible": _display_change_confirmation_dialog.visible,
		"display_change_dialog_title": _display_change_confirmation_dialog.title,
		"display_change_dialog_text": _display_change_confirmation_dialog.dialog_text,
		"display_change_ok_text": _display_change_confirmation_dialog.get_ok_button().text,
		"display_change_cancel_text": _display_change_confirmation_dialog.get_cancel_button().text,
		"display_change_ui_active": _display_change_ui_active,
		"display_change_focus_name": String(_display_change_focus_name),
		"display_change_snapshot": SettingsService.display_change_snapshot(),
		"display_change_countdown_seconds": SettingsService.display_change_countdown_seconds(),
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
		"render_quality": SettingsService.render_quality_id(),
		"render_quality_picker_items": _picker_item_labels(_render_quality_picker),
		"render_quality_tooltip": _render_quality_picker.tooltip_text,
		"vsync_enabled": SettingsService.vsync_enabled(),
		"vsync_tooltip": _vsync_toggle.tooltip_text,
		"frame_rate_limit": SettingsService.frame_rate_limit(),
		"frame_rate_picker_items": _picker_item_labels(_frame_rate_picker),
		"frame_rate_tooltip": _frame_rate_picker.tooltip_text,
		"battle_playback_speed": SettingsService.battle_playback_speed_id(),
		"battle_playback_speed_picker_items": _picker_item_labels(_battle_playback_speed_picker),
		"battle_playback_speed_tooltip": _battle_playback_speed_picker.tooltip_text,
		"keyboard_navigation_layout": SettingsService.keyboard_navigation_layout_id(),
		"keyboard_navigation_layout_picker_items": _picker_item_labels(_keyboard_navigation_layout_picker),
		"keyboard_navigation_layout_tooltip": _keyboard_navigation_layout_picker.tooltip_text,
		"custom_movement_keys_text": _customize_movement_keys_button.text,
		"custom_movement_keys_tooltip": _customize_movement_keys_button.tooltip_text,
		"hero_keybindings_dialog": _hero_keybindings_dialog.validation_snapshot(),
		"master_volume_tooltip": _master_volume_slider.tooltip_text,
		"music_volume_tooltip": _music_volume_slider.tooltip_text,
		"effects_volume_tooltip": _effects_volume_slider.tooltip_text,
		"ui_scale_percent": SettingsService.ui_scale_percent(),
		"ui_scale_picker_items": _picker_item_labels(_ui_scale_picker),
		"ui_scale_tooltip": _ui_scale_picker.tooltip_text,
		"battle_camera_shake": SettingsService.battle_camera_shake_mode_id(),
		"battle_camera_shake_scale": SettingsService.battle_camera_shake_scale(),
		"battle_camera_shake_picker_items": _picker_item_labels(_battle_camera_shake_picker),
		"battle_camera_shake_tooltip": _battle_camera_shake_picker.tooltip_text,
		"high_contrast_enabled": SettingsService.high_contrast_ui_enabled(),
		"high_contrast_tooltip": _high_contrast_toggle.tooltip_text,
		"color_cue_mode": SettingsService.color_cue_mode_id(),
		"color_cue_picker_items": _picker_item_labels(_color_cue_picker),
		"color_cue_tooltip": _color_cue_picker.tooltip_text,
		"reduce_flashes_enabled": SettingsService.reduced_flashes_enabled(),
		"reduce_flashes_tooltip": _reduce_flashes_toggle.tooltip_text,
		"reduce_repetitive_sounds_enabled": SettingsService.reduced_repetitive_sounds_enabled(),
		"reduce_repetitive_sounds_tooltip": _reduce_repetitive_sounds_toggle.tooltip_text,
		"reduce_motion_tooltip": _reduce_motion_toggle.tooltip_text,
		"settings_scroll_max": _settings_scroll.get_v_scroll_bar().max_value,
		"settings_scroll_page": _settings_scroll.get_v_scroll_bar().page,
		"settings_scroll_value": _settings_scroll.scroll_vertical,
		"reduce_flashes_visible_in_scroll": _settings_control_visible(_reduce_flashes_toggle),
		"reduce_repetitive_sounds_visible_in_scroll": _settings_control_visible(_reduce_repetitive_sounds_toggle),
		"support_bundle_visible_in_scroll": _settings_control_visible(_export_support_bundle_button),
		"restore_settings_defaults_visible_in_scroll": _settings_control_visible(_restore_settings_defaults_button),
		"summary": _summary_label.text,
		"active_expedition": _active_expedition_label.text,
		"active_expedition_full": _active_expedition_label.tooltip_text,
	}

func _editor_utility_frame_snapshot() -> Dictionary:
	var normal_style := _open_editor_button.get_theme_stylebox("normal")
	var normal_texture_path := ""
	if normal_style is StyleBoxTexture:
		var texture := (normal_style as StyleBoxTexture).texture
		if texture != null:
			normal_texture_path = texture.resource_path
	return {
		"style_class": normal_style.get_class() if normal_style != null else "",
		"normal_texture_path": normal_texture_path,
		"anchor_top": _open_editor_button.anchor_top,
		"anchor_bottom": _open_editor_button.anchor_bottom,
		"tooltip_text": _open_editor_button.tooltip_text,
	}

func _campaign_layout_snapshot() -> Dictionary:
	var viewport_size := get_viewport().get_visible_rect().size
	var stage_rect := _stage_dock_panel.get_global_rect()
	var surface_visibility := {
		"arc": _campaign_details_label.is_visible_in_tree(),
		"arc_status": _campaign_arc_status_label.is_visible_in_tree(),
		"chapter": _chapter_details_label.is_visible_in_tree(),
		"commander": _campaign_commander_preview_label.is_visible_in_tree(),
		"operational": _campaign_operational_board_label.is_visible_in_tree(),
		"journal": _campaign_journal_label.is_visible_in_tree(),
	}

	var control_rects := {}
	for control in [
		_campaign_list,
		_previous_campaign_arc_button,
		_next_campaign_arc_button,
		_chapter_list,
		_previous_campaign_chapter_button,
		_next_campaign_chapter_button,
		_campaign_intel_toggle,
		_campaign_difficulty_picker,
		_campaign_restart_button,
		_campaign_launch_row,
		_campaign_primary_button,
		_start_chapter_button,
	]:
		if control is Control and control.visible:
			control_rects[String(control.name)] = _control_rect_snapshot(control)
	return {
		"viewport_size": {"x": viewport_size.x, "y": viewport_size.y},
		"stage_rect": _rect_snapshot(stage_rect),
		"width_ratio": stage_rect.size.x / viewport_size.x if viewport_size.x > 0.0 else 0.0,
		"height_ratio": stage_rect.size.y / viewport_size.y if viewport_size.y > 0.0 else 0.0,
		"uncovered_right_ratio": 1.0 - (stage_rect.end.x / viewport_size.x) if viewport_size.x > 0.0 else 0.0,
		"intel_expanded": _campaign_intel_expanded,
		"intel_toggle_text": _campaign_intel_toggle.text,
		"intel_toggle_tooltip": _campaign_intel_toggle.tooltip_text,
		"launch_row_visible": _campaign_launch_row.is_visible_in_tree(),
		"detail_surface_visibility": surface_visibility,
		"control_rects": control_rects,
		"campaign_items": _campaign_item_rows(),
		"chapter_items": _chapter_item_rows(),
	}

func _skirmish_layout_snapshot() -> Dictionary:
	var viewport_size := get_viewport().get_visible_rect().size
	var stage_rect := _stage_dock_panel.get_global_rect()
	var control_rects := {}
	for control in [
		_skirmish_launch_row,
		_previous_skirmish_front_button,
		_next_skirmish_front_button,
		_difficulty_picker,
		_start_skirmish_button,
		_skirmish_list,
	]:
		if control is Control and control.visible:
			control_rects[String(control.name)] = _control_rect_snapshot(control)
	return {
		"viewport_size": {"x": viewport_size.x, "y": viewport_size.y},
		"stage_rect": _rect_snapshot(stage_rect),
		"launch_row_visible": _skirmish_launch_row.is_visible_in_tree(),
		"control_rects": control_rects,
	}

func _campaign_item_rows() -> Array:
	var rows := []
	for index in range(mini(_campaign_list.item_count, _campaign_entries.size())):
		rows.append({
			"id": String(_campaign_entries[index].get("campaign_id", "")),
			"label": _campaign_list.get_item_text(index),
			"tooltip": _campaign_list.get_item_tooltip(index),
			"selected": _campaign_list.is_selected(index),
		})
	return rows

func _chapter_item_rows() -> Array:
	var rows := []
	for index in range(mini(_chapter_list.item_count, _campaign_chapter_entries.size())):
		rows.append({
			"id": String(_campaign_chapter_entries[index].get("scenario_id", "")),
			"label": _chapter_list.get_item_text(index),
			"tooltip": _chapter_list.get_item_tooltip(index),
			"selected": _chapter_list.is_selected(index),
		})
	return rows

func _control_rect_snapshot(control: Control) -> Dictionary:
	return _rect_snapshot(control.get_global_rect())

func _rect_snapshot(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
		"right": rect.end.x,
		"bottom": rect.end.y,
	}

func validation_campaign_storage_snapshot() -> Dictionary:
	_sync_campaign_storage_state()
	return {
		"storage_state": _campaign_storage_state.duplicate(true),
		"blocked": _campaign_storage_blocked,
		"warning": _campaign_storage_warning,
		"last_mutation_result": _campaign_last_mutation_result.duplicate(true),
		"blocked_command_count": _validation_campaign_blocked_command_count,
		"selected_campaign_id": _selected_campaign_id,
		"selected_scenario_id": _selected_campaign_scenario_id,
		"campaign_browsing_enabled": _campaign_list.focus_mode != Control.FOCUS_NONE and _campaign_list.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"chapter_browsing_enabled": _chapter_list.focus_mode != Control.FOCUS_NONE and _chapter_list.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"campaign_list_disabled": _campaign_list.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"chapter_list_disabled": _chapter_list.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"primary_disabled": _campaign_primary_button.disabled,
		"chapter_start_disabled": _start_chapter_button.disabled,
		"restart_disabled": _campaign_restart_button.disabled,
		"restart_dialog_visible": _campaign_restart_dialog.visible,
		"warning_surface": _campaign_arc_status_label.text,
		"warning_surface_full": _campaign_arc_status_label.tooltip_text,
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
	var level_count := 2 if _generated_underground else 1
	var visible_controls := [
		"seed",
		"size_class",
		"player_count",
		"water_mode",
		"level_count",
		"launch_generated",
	]
	if _generated_underground_supported():
		visible_controls.insert(5, "underground")
	return {
		"seed": _generated_seed,
		"size_class_id": _generated_size_class_id,
		"size_class_label": ScenarioSelectRulesScript.random_map_size_class_label(_generated_size_class_id),
		"player_count": _generated_player_count,
		"water_mode": _generated_water_mode,
		"underground": _generated_underground,
		"level_count": level_count,
		"level_options": _picker_item_labels(_generated_underground_toggle),
		"retry_policy": ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true),
		"size_options": _picker_item_labels(_generated_size_picker),
		"player_count_options": _picker_item_labels(_generated_player_count_picker),
		"player_count_values": _picker_item_metadata_ints(_generated_player_count_picker),
		"water_options": _picker_item_labels(_generated_water_picker),
		"visible_player_controls": visible_controls,
		"level_picker_visible": _generated_underground_toggle.visible,
		"internal_template_provenance": _generated_random_map_internal_template_provenance(),
	}

func _generated_underground_supported() -> bool:
	var level_options: Array = ScenarioSelectRulesScript.random_map_player_setup_options().get("level_options", [])
	for option in level_options:
		if option is Dictionary and int(option.get("level_count", 1)) > 1:
			return true
	return false

func _generated_random_map_internal_template_provenance() -> Dictionary:
	var size_defaults := ScenarioSelectRulesScript.random_map_size_class_default(_generated_size_class_id)
	return {
		"selection_source": "native_catalog_auto_on_launch",
		"template_id": "native_catalog_auto",
		"profile_id": "native_catalog_auto",
		"preview_template_id": _generated_template_id,
		"preview_profile_id": _generated_profile_id,
		"size_class_id": _generated_size_class_id,
		"size_class_default_template_id": String(size_defaults.get("template_id", "")),
		"size_class_default_profile_id": String(size_defaults.get("profile_id", "")),
		"launch_selection_deferred_to_native": true,
		"template_picker_visible": _generated_template_picker.visible,
		"profile_picker_visible": _generated_profile_picker.visible,
		"underground_player_control_visible": _generated_underground_toggle.visible,
		"underground_supported": _generated_underground_supported(),
		"manual_template_player_control": false,
		"manual_profile_player_control": false,
	}

func _picker_item_labels(picker: OptionButton) -> Array:
	var labels := []
	for index in range(picker.get_item_count()):
		labels.append(picker.get_item_text(index))
	return labels

func _picker_item_metadata_strings(picker: OptionButton) -> Array:
	var ids := []
	for index in range(picker.get_item_count()):
		ids.append(String(picker.get_item_metadata(index)))
	return ids

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

func validation_refresh_save_browser() -> void:
	_save_browser_loaded = true
	_rebuild_save_browser()

func validation_open_contextual_guide_stage() -> void:
	_on_stage_help_pressed()

func validation_select_help_topic(topic_id: String) -> void:
	_select_help_topic(topic_id)

func validation_open_credits_notices() -> void:
	_select_help_topic("credits_notices")
	_open_credits_notices()

func validation_close_credits_notices() -> void:
	_close_credits_notices()

func validation_return_from_contextual_guide() -> void:
	if _menu_tabs.current_tab == TAB_GUIDE:
		_on_stage_help_pressed()

func validation_open_settings_stage() -> void:
	_select_menu_tab(TAB_SETTINGS)
	_show_stage_dock()
	_refresh_settings_panel()

func validation_export_support_bundle() -> Dictionary:
	validation_open_settings_stage()
	return _export_support_bundle(false)

func validation_request_settings_restore_defaults() -> Dictionary:
	validation_open_settings_stage()
	_on_restore_settings_defaults_pressed()
	var result := {
		"pending": _settings_restore_pending,
		"dialog_visible": _settings_restore_defaults_dialog.visible,
		"title": _settings_restore_defaults_dialog.title,
		"text": _settings_restore_defaults_dialog.dialog_text,
	}
	result.merge(_destructive_confirmation_snapshot("settings_restore", _settings_restore_defaults_dialog), true)
	return result

func validation_confirm_settings_restore_defaults() -> Dictionary:
	_on_settings_restore_defaults_confirmed()
	var result := {
		"pending": _settings_restore_pending,
		"status": _settings_restore_status,
		"settings": SettingsService.ensure_settings().duplicate(true),
		"display_change_pending": SettingsService.display_change_pending(),
		"display_change_snapshot": SettingsService.display_change_snapshot(),
		"display_dialog_visible": _display_change_confirmation_dialog.visible,
	}
	result.merge(_destructive_confirmation_snapshot("settings_restore", _settings_restore_defaults_dialog), true)
	return result

func validation_cancel_settings_restore_defaults() -> Dictionary:
	var result := _on_settings_restore_defaults_canceled()
	result.merge(_destructive_confirmation_snapshot("settings_restore", _settings_restore_defaults_dialog), true)
	return result

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

func validation_set_campaign_difficulty(difficulty_id: String) -> bool:
	var normalized := ScenarioSelectRulesScript.normalize_difficulty(difficulty_id)
	for index in range(_campaign_difficulty_picker.get_item_count()):
		if String(_campaign_difficulty_picker.get_item_metadata(index)) != normalized:
			continue
		_campaign_difficulty_picker.select(index)
		_on_campaign_difficulty_selected(index)
		return true
	return false

func validation_request_campaign_restart() -> Dictionary:
	var mutation_result := _on_campaign_restart_pressed()
	var result := {
		"pending_campaign_id": _pending_campaign_restart_id,
		"dialog_visible": _campaign_restart_dialog.visible,
		"title": _campaign_restart_dialog.title,
		"text": _campaign_restart_dialog.dialog_text,
		"mutation_result": mutation_result.duplicate(true),
	}
	result.merge(_destructive_confirmation_snapshot("campaign_restart", _campaign_restart_dialog), true)
	return result

func validation_confirm_campaign_restart() -> Dictionary:
	var mutation_result := _on_campaign_restart_confirmed()
	var result := {
		"pending_campaign_id": _pending_campaign_restart_id,
		"selected_campaign_id": _selected_campaign_id,
		"selected_scenario_id": _selected_campaign_scenario_id,
		"notice": _campaign_restart_notice,
		"mutation_result": mutation_result.duplicate(true),
	}
	result.merge(_destructive_confirmation_snapshot("campaign_restart", _campaign_restart_dialog), true)
	return result


func validation_cancel_campaign_restart() -> Dictionary:
	var result := _on_campaign_restart_canceled()
	result.merge(_destructive_confirmation_snapshot("campaign_restart", _campaign_restart_dialog), true)
	return result

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
	if enabled and not _generated_underground_supported():
		_on_generated_underground_toggled(enabled)
		return false
	_select_generated_level_count(2 if enabled else 1)
	_on_generated_level_selected(_generated_underground_toggle.selected)
	return _generated_underground == enabled

func validation_force_generated_random_map_config(config: Dictionary) -> Dictionary:
	var setup := {}
	if bool(config.get("validation_force_failure", false)):
		setup = _validation_forced_generated_random_map_failure(config)
	else:
		setup = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
			config,
			_selected_difficulty,
			ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
		)
	_generated_last_setup = setup.duplicate(true)
	_apply_generated_random_map_setup_surface(setup)
	return setup

func _validation_forced_generated_random_map_failure(config: Dictionary) -> Dictionary:
	var max_attempts := int(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("max_attempts", 2))
	var validation := {
		"schema_id": String(config.get("validation_schema_id", "generated_random_map_validation_forced_failure_v1")),
		"status": "fail",
		"validation_status": "fail",
		"failure_count": 1,
		"warning_count": 0,
		"failures": [String(config.get("validation_failure", "forced_validation_failure"))],
		"size_policy": config.get("validation_size_policy", {}),
	}
	var retry_status := {
		"policy": "bounded_player_setup_retry_visible",
		"attempt_count": max_attempts,
		"retry_count": max(0, max_attempts - 1),
		"max_attempts": max_attempts,
		"mode": String(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("mode", "seed_salt")),
		"status": "failed_before_launch",
		"validation_status": "fail",
		"failure_count": 1,
		"warning_count": 0,
	}
	return {
		"ok": false,
		"setup_kind": "generated_random_map_skirmish",
		"launch_mode": SessionState.LAUNCH_MODE_SKIRMISH,
		"difficulty": _selected_difficulty,
		"difficulty_label": ScenarioSelectRulesScript.difficulty_label(_selected_difficulty),
		"validation": validation,
		"retry_status": retry_status,
		"retry_attempts": [],
		"failure_handoff": "Generated setup blocked by validation after bounded retry attempts; no session, save, campaign progress, or authored content changes occur.",
		"setup_summary": "Generated validation blocked before launch | attempts %d | retry %d | Boundary: no session, save, campaign adoption, authored JSON writeback, or alpha/parity claim." % [
			int(retry_status.get("attempt_count", 0)),
			int(retry_status.get("retry_count", 0)),
		],
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

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
	if not _stage_dock_is_open() or _menu_tabs.current_tab != TAB_SETTINGS:
		validation_open_settings_stage()
	for index in range(_resolution_picker.get_item_count()):
		if String(_resolution_picker.get_item_metadata(index)) != resolution_id:
			continue
		_resolution_picker.select(index)
		_on_resolution_selected(index)
		var snapshot: Dictionary = SettingsService.display_change_snapshot()
		return (
			bool(snapshot.get("pending", false))
			and String(snapshot.get("resolution", "")) == resolution_id
		) or (
			not bool(snapshot.get("pending", false))
			and SettingsService.presentation_resolution_id() == resolution_id
		)
	return false

func validation_select_presentation_mode(mode_id: String) -> bool:
	if not _stage_dock_is_open() or _menu_tabs.current_tab != TAB_SETTINGS:
		validation_open_settings_stage()
	for index in range(_presentation_mode_picker.get_item_count()):
		if String(_presentation_mode_picker.get_item_metadata(index)) != mode_id:
			continue
		_presentation_mode_picker.select(index)
		_on_presentation_mode_selected(index)
		var snapshot: Dictionary = SettingsService.display_change_snapshot()
		return (
			bool(snapshot.get("pending", false))
			and String(snapshot.get("mode", "")) == mode_id
		) or (
			not bool(snapshot.get("pending", false))
			and SettingsService.presentation_mode_id() == mode_id
		)
	return false

func validation_confirm_display_change() -> Dictionary:
	_on_display_change_confirmed()
	return {
		"pending": SettingsService.display_change_pending(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"snapshot": SettingsService.display_change_snapshot(),
		"dialog_visible": _display_change_confirmation_dialog.visible,
		"status": _settings_restore_status,
	}

func validation_revert_display_change(reason: String = "validation_canceled") -> Dictionary:
	var result := _revert_pending_display_change(reason, true)
	return {
		"result": result,
		"pending": SettingsService.display_change_pending(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"snapshot": SettingsService.display_change_snapshot(),
		"dialog_visible": _display_change_confirmation_dialog.visible,
		"status": _settings_restore_status,
	}

func validation_set_vsync(enabled: bool) -> bool:
	validation_open_settings_stage()
	_vsync_toggle.set_pressed_no_signal(enabled)
	_on_vsync_toggled(enabled)
	return SettingsService.vsync_enabled() == enabled

func validation_select_render_quality(quality_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_render_quality_picker.get_item_count()):
		if String(_render_quality_picker.get_item_metadata(index)) != quality_id:
			continue
		_render_quality_picker.select(index)
		_on_render_quality_selected(index)
		return SettingsService.render_quality_id() == quality_id
	return false

func validation_select_ui_scale(value: int) -> bool:
	validation_open_settings_stage()
	for index in range(_ui_scale_picker.get_item_count()):
		if int(_ui_scale_picker.get_item_metadata(index)) != value:
			continue
		_ui_scale_picker.select(index)
		_on_ui_scale_selected(index)
		return SettingsService.ui_scale_percent() == value
	return false

func validation_select_battle_camera_shake(mode_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_battle_camera_shake_picker.get_item_count()):
		if String(_battle_camera_shake_picker.get_item_metadata(index)) != mode_id:
			continue
		_battle_camera_shake_picker.select(index)
		_on_battle_camera_shake_selected(index)
		return SettingsService.battle_camera_shake_mode_id() == mode_id
	return false

func validation_set_high_contrast(enabled: bool) -> bool:
	validation_open_settings_stage()
	_high_contrast_toggle.set_pressed_no_signal(enabled)
	_on_high_contrast_toggled(enabled)
	return SettingsService.high_contrast_ui_enabled() == enabled

func validation_set_reduced_flashes(enabled: bool) -> bool:
	validation_open_settings_stage()
	_reduce_flashes_toggle.set_pressed_no_signal(enabled)
	_on_reduce_flashes_toggled(enabled)
	return SettingsService.reduced_flashes_enabled() == enabled

func validation_set_reduced_repetitive_sounds(enabled: bool) -> bool:
	validation_open_settings_stage()
	_reduce_repetitive_sounds_toggle.set_pressed_no_signal(enabled)
	_on_reduce_repetitive_sounds_toggled(enabled)
	return SettingsService.reduced_repetitive_sounds_enabled() == enabled

func validation_reveal_reduced_flashes() -> void:
	validation_open_settings_stage()
	_settings_scroll.ensure_control_visible(_reduce_flashes_toggle)

func validation_reveal_reduced_repetitive_sounds() -> void:
	validation_open_settings_stage()
	_settings_scroll.ensure_control_visible(_reduce_repetitive_sounds_toggle)

func validation_reveal_support_bundle() -> void:
	validation_open_settings_stage()
	_settings_scroll.ensure_control_visible(_export_support_bundle_button)

func validation_reveal_restore_settings_defaults() -> void:
	validation_open_settings_stage()
	_settings_scroll.ensure_control_visible(_restore_settings_defaults_button)

func _settings_control_visible(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	return _settings_scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect())

func validation_select_color_cue_mode(mode_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_color_cue_picker.get_item_count()):
		if String(_color_cue_picker.get_item_metadata(index)) != mode_id:
			continue
		_color_cue_picker.select(index)
		_on_color_cue_selected(index)
		return SettingsService.color_cue_mode_id() == mode_id
	return false

func validation_select_frame_rate_limit(value: int) -> bool:
	validation_open_settings_stage()
	for index in range(_frame_rate_picker.get_item_count()):
		if int(_frame_rate_picker.get_item_metadata(index)) != value:
			continue
		_frame_rate_picker.select(index)
		_on_frame_rate_selected(index)
		return SettingsService.frame_rate_limit() == value
	return false

func validation_select_battle_playback_speed(speed_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_battle_playback_speed_picker.get_item_count()):
		if String(_battle_playback_speed_picker.get_item_metadata(index)) != speed_id:
			continue
		_battle_playback_speed_picker.select(index)
		_on_battle_playback_speed_selected(index)
		return SettingsService.battle_playback_speed_id() == speed_id
	return false

func validation_select_keyboard_navigation_layout(layout_id: String) -> bool:
	validation_open_settings_stage()
	for index in range(_keyboard_navigation_layout_picker.get_item_count()):
		if String(_keyboard_navigation_layout_picker.get_item_metadata(index)) != layout_id:
			continue
		_keyboard_navigation_layout_picker.select(index)
		_on_keyboard_navigation_layout_selected(index)
		return SettingsService.keyboard_navigation_layout_id() == layout_id
	return false

func validation_open_hero_keybindings_dialog() -> Dictionary:
	_hero_keybindings_dialog.open_dialog(_customize_movement_keys_button)
	return _hero_keybindings_dialog.validation_snapshot()

func validation_begin_hero_key_capture(action: StringName) -> bool:
	return _hero_keybindings_dialog.validation_begin_capture(action)

func validation_capture_hero_key(keycode: int) -> Dictionary:
	return _hero_keybindings_dialog.validation_capture_key(keycode)

func validation_reset_hero_keybindings() -> void:
	_hero_keybindings_dialog.validation_reset()

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

func validation_request_selected_save_delete() -> Dictionary:
	_on_delete_selected_save_pressed()
	var result := {
		"pending_identity": _pending_save_delete_identity.duplicate(true),
		"dialog_visible": _save_delete_dialog.visible,
		"title": _save_delete_dialog.title,
		"text": _save_delete_dialog.dialog_text,
	}
	result.merge(_destructive_confirmation_snapshot("save_delete", _save_delete_dialog), true)
	return result

func validation_confirm_selected_save_delete() -> Dictionary:
	var selected_key_before := _selected_save_key
	_on_save_delete_confirmed()
	var result := {
		"selected_key_before": selected_key_before,
		"selected_key_after": _selected_save_key,
		"pending_identity": _pending_save_delete_identity.duplicate(true),
		"notice": _save_load_notice,
	}
	result.merge(_destructive_confirmation_snapshot("save_delete", _save_delete_dialog), true)
	return result

func validation_cancel_selected_save_delete() -> Dictionary:
	var result := _on_save_delete_canceled()
	result.merge(_destructive_confirmation_snapshot("save_delete", _save_delete_dialog), true)
	return result

func validation_set_selected_save_name(name: String) -> Dictionary:
	_save_name_edit.text = name
	_refresh_save_name_action()
	_on_apply_save_name_pressed()
	return {
		"selected_key": _selected_save_key,
		"notice": _save_load_notice,
		"summary": _selected_summary().duplicate(true),
	}

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
	_start_skirmish_button.pressed.emit()
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
	var requested_difficulty := _selected_difficulty
	var action := CampaignProgression.chapter_action(requested_campaign_id, requested_scenario_id, requested_difficulty)
	var action_disabled := _start_chapter_button.disabled or bool(action.get("disabled", false))
	var primary_action := CampaignProgression.primary_campaign_action(requested_campaign_id, requested_difficulty)
	if _campaign_launch_actions_are_exact(action, primary_action):
		action_disabled = _campaign_primary_button.disabled or bool(primary_action.get("disabled", false))
		_campaign_primary_button.pressed.emit()
	else:
		_start_chapter_button.pressed.emit()
	var mutation_result := _campaign_last_mutation_result.duplicate(true)
	var active_session := SessionState.ensure_active_session()
	var active_campaign_id := String(active_session.flags.get("campaign_id", ""))
	return {
		"requested_campaign_id": requested_campaign_id,
		"requested_scenario_id": requested_scenario_id,
		"requested_difficulty": requested_difficulty,
		"action_disabled": action_disabled,
		"mutation_result": mutation_result.duplicate(true),
		"campaign_storage": validation_campaign_storage_snapshot(),
		"started": not action_disabled
			and active_session.scenario_id == requested_scenario_id
			and active_session.difficulty == requested_difficulty
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
			var is_active: bool = _stage_dock_is_open() and _menu_tabs.current_tab == tab_index
			_apply_backdrop_plaque_button(button, is_active, false)

func _sync_system_command_buttons() -> void:
	_apply_editor_utility_button()
	_apply_backdrop_plaque_button(_quit_button, false, true)

func _apply_editor_utility_button() -> void:
	# The painted backdrop has five plaque frames. Editor occupies the deliberate
	# utility gap between Settings and Quit, so it needs its own authored frame
	# instead of pretending that bare text sits on a sixth painted plaque.
	FrontierVisualKit.apply_button(_open_editor_button, "secondary", 0.0, 0.0, 16)

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
		"Command cue: Settings opens presentation, sound, gameplay, and readability controls. "
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
	return "Open saved expeditions. Previewing or loading from this menu does not overwrite any saved slot."

func _help_topic_for_tab(tab_index: int) -> String:
	return String(TAB_HELP_TOPIC.get(tab_index, SettingsService.default_help_topic_id()))

func _apply_backdrop_plaque_button(button: BaseButton, active: bool, danger: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
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
	button.add_theme_stylebox_override("focus", FrontierVisualKit._button_focus_style(6))

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
	if event.is_action_pressed("ui_cancel") and _credits_notices_dialog.visible:
		_close_credits_notices()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _stage_dock_is_open():
		_hide_stage_dock()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if SettingsService.display_change_pending():
		SettingsService.revert_display_change("menu_exit")

func _set_commander_portrait(target: HeroPortraitView, hero_id: String) -> void:
	target.set_hero_id(hero_id)

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
		"CreditsNoticesPanel": "ink",
		"SettingsPanel": "smoke",
		"MasterVolumePanel": "teal",
		"MusicVolumePanel": "blue",
		"EffectsVolumePanel": "earth",
	}
	for panel in find_children("*", "PanelContainer", true, false):
		if panel is PanelContainer and panel.name.ends_with("Panel"):
			FrontierVisualKit.apply_panel(panel, String(panel_tones.get(panel.name, "ink")))

	FrontierVisualKit.apply_tab_container(_menu_tabs, "smoke")
	for list in [_campaign_list, _chapter_list, _skirmish_list, _help_list, _save_list]:
		FrontierVisualKit.apply_item_list(list, "smoke")

	FrontierVisualKit.apply_button(_stage_help_button, "secondary", 96.0, 34.0, 13)
	FrontierVisualKit.apply_button(_open_credits_notices_button, "secondary", 220.0, 38.0, 13)
	FrontierVisualKit.apply_button(_credits_notices_close_button, "secondary", 128.0, 38.0, 13)
	_credits_notices_body.add_theme_font_size_override("font_size", 13)
	_credits_notices_body.add_theme_color_override("font_color", FrontierVisualKit.text_color("body"))
	FrontierVisualKit.apply_button(_close_stage_dock_button, "secondary", 112.0, 34.0, 13)
	FrontierVisualKit.apply_button(_campaign_intel_toggle, "secondary", 116.0, 40.0, 13)
	FrontierVisualKit.apply_button(_previous_campaign_arc_button, "secondary", 104.0, 30.0, 11)
	FrontierVisualKit.apply_button(_next_campaign_arc_button, "secondary", 104.0, 30.0, 11)
	FrontierVisualKit.apply_button(_previous_campaign_chapter_button, "secondary", 116.0, 30.0, 11)
	FrontierVisualKit.apply_button(_next_campaign_chapter_button, "secondary", 116.0, 30.0, 11)
	FrontierVisualKit.apply_button(_campaign_restart_button, "secondary", 136.0, 40.0, 13)
	FrontierVisualKit.apply_button(_campaign_primary_button, "primary", 208.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_chapter_button, "secondary", 176.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_skirmish_button, "primary", 188.0, 40.0, 14)
	FrontierVisualKit.apply_button(_start_generated_skirmish_button, "primary", 176.0, 34.0, 13)
	FrontierVisualKit.apply_button(_delete_selected_save_button, "secondary", 132.0, 38.0, 13)
	FrontierVisualKit.apply_button(_apply_save_name_button, "secondary", 112.0, 38.0, 13)
	FrontierVisualKit.apply_button(_load_selected_button, "primary", 184.0, 38.0, 14)
	FrontierVisualKit.apply_button(_customize_movement_keys_button, "secondary", 140.0, 34.0, 13)
	FrontierVisualKit.apply_button(_export_support_bundle_button, "secondary", 196.0, 34.0, 13)
	FrontierVisualKit.apply_button(_restore_settings_defaults_button, "secondary", 196.0, 34.0, 13)
	_sync_command_button_styles()
	_sync_system_command_buttons()

	for picker in [
		_campaign_difficulty_picker,
		_difficulty_picker,
		_generated_template_picker,
		_generated_profile_picker,
		_generated_player_count_picker,
		_generated_water_picker,
		_generated_underground_toggle,
		_presentation_mode_picker,
		_resolution_picker,
		_render_quality_picker,
		_frame_rate_picker,
		_battle_playback_speed_picker,
		_keyboard_navigation_layout_picker,
		_ui_scale_picker,
		_color_cue_picker,
	]:
		FrontierVisualKit.apply_option_button(picker, "secondary", maxf(picker.custom_minimum_size.x, 176.0), 34.0, 13)

	for toggle in [_vsync_toggle, _high_contrast_toggle, _reduce_motion_toggle, _reduce_flashes_toggle, _reduce_repetitive_sounds_toggle]:
		FrontierVisualKit.apply_button(toggle, "secondary", 180.0, 34.0, 13)

	for slider in [_master_volume_slider, _music_volume_slider, _effects_volume_slider]:
		FrontierVisualKit.apply_range(slider, "gold")

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body", 13)

	for title_label in find_children("*Title", "Label", true, false):
		if title_label is Label:
			FrontierVisualKit.apply_label(title_label, "title", 14)
	_hero_keybindings_dialog.refresh_theme()

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
	FrontierVisualKit.apply_label(_effects_volume_value, "gold", 13)
