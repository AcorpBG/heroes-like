extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SystemSaveWrittenCuePresenterScript = preload("res://scenes/shared/SystemSaveWrittenCuePresenter.gd")
const SystemLoadResumedCuePresenterScript = preload("res://scenes/shared/SystemLoadResumedCuePresenter.gd")
const RETURN_TO_MENU_FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."
const OUTCOME_AUTOSAVE_RECOVERY_MESSAGE := "Outcome reached, but autosave failed. Use Save Outcome now."
const OUTCOME_NEW_SESSION_CANCEL_TEXT := "Keep Outcome"
const OUTCOME_NEW_SESSION_STALE_MESSAGE := "That follow-up changed. Review the outcome and try again."
const OUTCOME_PRESENTATION_MODEL := "scenery_first_edge_docks"
const OUTCOME_COMPACT_BANNER_WIDTH := 620.0
const OUTCOME_WIDE_BANNER_WIDTH := 720.0
const OUTCOME_COMPACT_BANNER_HEIGHT := 146.0
const OUTCOME_WIDE_BANNER_HEIGHT := 180.0
const OUTCOME_COMPACT_BANNER_ART_WIDTH := 132.0
const OUTCOME_WIDE_BANNER_ART_WIDTH := 180.0
const OUTCOME_COMPACT_EMBLEM_HEIGHT := 88.0
const OUTCOME_WIDE_EMBLEM_HEIGHT := 120.0
const OUTCOME_COMPACT_SIDEBAR_WIDTH := 320.0
const OUTCOME_WIDE_SIDEBAR_WIDTH := 356.0
const OUTCOME_COMPACT_DOCK_HEIGHT := 184.0
const OUTCOME_WIDE_DOCK_HEIGHT := 204.0
const OUTCOME_WIDE_DOCK_WIDTH := 1250.0
const OUTCOME_COLLAPSED_COMMAND_WIDTH := 388.0
const OUTCOME_COLLAPSED_COMMAND_HEIGHT := 94.0
const OUTCOME_RECAP_TAB_CONTENT_MARGIN_HORIZONTAL := 4.0
const OUTCOME_RECAP_TAB_STATE_STYLES := [
	&"tab_selected",
	&"tab_hovered",
	&"tab_unselected",
	&"tab_disabled",
]
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

@onready var _backdrop: Control = %Backdrop
@onready var _header_label: Label = %Header
@onready var _summary_label: Label = %Summary
@onready var _mode_label: Label = %Mode
@onready var _result_glyph: Control = %ResultGlyph
@onready var _result_badge_label: Label = %ResultBadge
@onready var _result_badge_panel: PanelContainer = %ResultBadgePanel
@onready var _outcome_banner: Control = %OutcomeBanner
@onready var _recap_tabs: TabContainer = %RecapTabs
@onready var _hero_portrait: HeroPortraitView = %HeroPortrait
@onready var _hero_label: Label = %Hero
@onready var _army_label: Label = %Army
@onready var _resource_label: Label = %Resources
@onready var _progression_label: Label = %Progression
@onready var _campaign_arc_label: Label = %CampaignArc
@onready var _carryover_label: Label = %Carryover
@onready var _aftermath_label: Label = %Aftermath
@onready var _journal_label: Label = %Journal
@onready var _actions_hint_label: Label = %ActionsHint
@onready var _save_status_label: Label = %SaveStatus
@onready var _return_cue_label: Label = %ReturnCue
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _menu_button: Button = %Menu
@onready var _recap_details_button: Button = %RecapDetails
@onready var _guide_button: Button = %Guide
@onready var _guide_panel: PanelContainer = %GuidePanel
@onready var _guide_label: Label = %OutcomeGuide
@onready var _action_status_label: Label = %ActionStatus
@onready var _actions_bar: HFlowContainer = %Actions
@onready var _actions_panel: PanelContainer = $ContentMargin/Content/MainRow/CommandColumn/ActionsPanel
@onready var _manual_save_overwrite_dialog = $ManualSaveOverwriteDialog
@onready var _new_session_confirmation_dialog: ConfirmationDialog = $NewSessionConfirmationDialog
@onready var _content_margin: MarginContainer = $ContentMargin
@onready var _content_box: Control = $ContentMargin/Content
@onready var _banner: PanelContainer = $ContentMargin/Content/Banner
@onready var _banner_pad: MarginContainer = $ContentMargin/Content/Banner/BannerPad
@onready var _banner_columns: HBoxContainer = $ContentMargin/Content/Banner/BannerPad/BannerColumns
@onready var _banner_art_panel: PanelContainer = $ContentMargin/Content/Banner/BannerPad/BannerColumns/BannerArtPanel
@onready var _banner_art_pad: MarginContainer = $ContentMargin/Content/Banner/BannerPad/BannerColumns/BannerArtPanel/BannerArtPad
@onready var _banner_info: VBoxContainer = $ContentMargin/Content/Banner/BannerPad/BannerColumns/BannerInfo
@onready var _main_row: Control = $ContentMargin/Content/MainRow
@onready var _command_column: HBoxContainer = $ContentMargin/Content/MainRow/CommandColumn
@onready var _force_cards: VBoxContainer = $ContentMargin/Content/MainRow/CommandColumn/ForceCards
@onready var _hero_pad: MarginContainer = $ContentMargin/Content/MainRow/CommandColumn/ForceCards/HeroPanel/HeroPad
@onready var _army_pad: MarginContainer = $ContentMargin/Content/MainRow/CommandColumn/ForceCards/ArmyPanel/ArmyPad
@onready var _resource_pad: MarginContainer = $ContentMargin/Content/MainRow/CommandColumn/ForceCards/ResourcePanel/ResourcePad
@onready var _actions_pad: MarginContainer = $ContentMargin/Content/MainRow/CommandColumn/ActionsPanel/ActionsPad
@onready var _actions_box: VBoxContainer = $ContentMargin/Content/MainRow/CommandColumn/ActionsPanel/ActionsPad/ActionsBox
@onready var _sidebar_shell: PanelContainer = $ContentMargin/Content/MainRow/SidebarShell
@onready var _sidebar_pad: MarginContainer = $ContentMargin/Content/MainRow/SidebarShell/SidebarPad
@onready var _sidebar_box: VBoxContainer = $ContentMargin/Content/MainRow/SidebarShell/SidebarPad/SidebarBox
@onready var _save_pad: MarginContainer = $ContentMargin/Content/MainRow/SidebarShell/SidebarPad/SidebarBox/SavePanel/SavePad
@onready var _save_box: VBoxContainer = $ContentMargin/Content/MainRow/SidebarShell/SidebarPad/SidebarBox/SavePanel/SavePad/SaveBox
@onready var _save_title_label: Label = $ContentMargin/Content/MainRow/SidebarShell/SidebarPad/SidebarBox/SavePanel/SavePad/SaveBox/SaveTitle

var _session: SessionStateStore.SessionData
var _model: Dictionary = {}
var _last_action_message := ""
var _last_return_to_menu_result: Dictionary = {}
var _validation_return_to_menu_request_count := 0
var _outcome_recovery_pending := false
var _outcome_recovery_entry_result: Dictionary = {}
var _last_outcome_recovery_retry_result: Dictionary = {}
var _validation_outcome_recovery_request_count := 0
var _validation_outcome_recovery_retry_attempt_count := 0
var _validation_outcome_recovery_retry_failure_count := 0
var _validation_outcome_recovery_retry_success_count := 0
var _validation_outcome_recovery_blocked_action_count := 0
var _validation_outcome_focus_accept_count := 0
var _validation_outcome_focus_action_execution_suppressed := false
var _last_outcome_focus_accept_result: Dictionary = {}
var _last_outcome_focus_cycle: Array = []
var _last_outcome_focus_cycle_names: Array[String] = []
var _last_outcome_focus_tab_bar_occurrences := 0
var _last_outcome_focus_preferred_action_id := ""
var _last_outcome_recap_tab_index := 0
var _validation_outcome_recap_tab_change_sequence := 0
var _validation_outcome_recap_tab_change_count := 0
var _validation_outcome_recap_tab_focus_retention_count := 0
var _validation_outcome_recap_tab_boundary_retain_count := 0
var _last_outcome_recap_tab_change_result: Dictionary = {}
var _validation_outcome_recap_tab_resetting := false
var _pending_outcome_new_session_confirmation: Dictionary = {}
var _outcome_new_session_source_session: SessionStateStore.SessionData
var _outcome_new_session_return_focus: Control = null
var _forwarding_outcome_new_session_root_physical_input := false
var _last_outcome_new_session_confirmation_result: Dictionary = {}
var _validation_outcome_new_session_request_count := 0
var _validation_outcome_new_session_duplicate_request_count := 0
var _validation_outcome_new_session_cancel_count := 0
var _validation_outcome_new_session_confirm_count := 0
var _validation_outcome_new_session_stale_count := 0
var _validation_outcome_new_session_perform_count := 0
var _validation_outcome_new_session_route_count := 0
var _validation_outcome_new_session_routing_suppressed := false
var _compact_layout_active := false
var _recap_expanded := false
var _save_written_cue_presenter: SystemSaveWrittenCuePresenter
var _load_resumed_cue_presenter: SystemLoadResumedCuePresenter

func _ready() -> void:
	_apply_visual_theme()
	_save_written_cue_presenter = SystemSaveWrittenCuePresenterScript.new()
	_save_written_cue_presenter.name = "SystemSaveWrittenCuePresenter"
	add_child(_save_written_cue_presenter)
	_save_written_cue_presenter.configure(_save_button, _save_status_label, "scenario_outcome")
	_load_resumed_cue_presenter = SystemLoadResumedCuePresenterScript.new()
	_load_resumed_cue_presenter.name = "SystemLoadResumedCuePresenter"
	add_child(_load_resumed_cue_presenter)
	_load_resumed_cue_presenter.configure(_save_status_label, _save_button, "scenario_outcome")
	_last_outcome_recap_tab_index = _recap_tabs.current_tab
	_configure_outcome_recap_tab_accessibility()
	if not _recap_tabs.tab_changed.is_connected(_on_outcome_recap_tab_changed):
		_recap_tabs.tab_changed.connect(_on_outcome_recap_tab_changed)
	_configure_outcome_new_session_confirmation()
	resized.connect(_apply_responsive_layout)
	_content_box.resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		AppRouter.go_to_main_menu()
		return
	if _session.scenario_status == "in_progress":
		AppRouter.resume_active_session()
		return
	_configure_save_slot_picker()
	_sync_outcome_recovery_state(true)
	MusicAudio.sync_context("outcome", "outcome_shell_ready", _outcome_music_metadata())
	_refresh()
	_present_load_resumed_cue()
	call_deferred("_configure_outcome_keyboard_focus", true)

func _configure_outcome_new_session_confirmation() -> void:
	var cancel_button := _new_session_confirmation_dialog.get_cancel_button()
	cancel_button.text = OUTCOME_NEW_SESSION_CANCEL_TEXT
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	cancel_button.shortcut = cancel_shortcut
	var dialog_label := _new_session_confirmation_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(620.0, 0.0)
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if (
		_forwarding_outcome_new_session_root_physical_input
		or not (event is InputEventKey or event is InputEventJoypadButton)
		or not _new_session_confirmation_dialog.visible
		or _pending_outcome_new_session_confirmation.is_empty()
		or (_manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible)
	):
		return
	get_tree().root.set_input_as_handled()
	var dialog := _new_session_confirmation_dialog
	var pending := _pending_outcome_new_session_confirmation
	var source_session := _outcome_new_session_source_session
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred(
		"_forward_root_physical_input_to_outcome_new_session_confirmation",
		dialog,
		pending,
		source_session,
		detached_event
	)


func _forward_root_physical_input_to_outcome_new_session_confirmation(
	dialog: ConfirmationDialog,
	pending: Dictionary,
	source_session: SessionStateStore.SessionData,
	event: InputEvent
) -> void:
	if (
		_forwarding_outcome_new_session_root_physical_input
		or not is_instance_valid(dialog)
		or dialog != _new_session_confirmation_dialog
		or not dialog.visible
		or _pending_outcome_new_session_confirmation.is_empty()
		or not is_same(pending, _pending_outcome_new_session_confirmation)
		or not is_same(source_session, _outcome_new_session_source_session)
		or (_manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible)
	):
		return
	_forwarding_outcome_new_session_root_physical_input = true
	dialog.push_input(event)
	_forwarding_outcome_new_session_root_physical_input = false

func _configure_outcome_recap_tab_accessibility() -> void:
	var tab_bar := _recap_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.focus_mode = Control.FOCUS_ALL
	if not tab_bar.gui_input.is_connected(_on_outcome_recap_tab_bar_gui_input):
		tab_bar.gui_input.connect(_on_outcome_recap_tab_bar_gui_input)
	_sync_outcome_recap_tab_tooltip()

func _on_outcome_recap_tab_changed(tab: int) -> void:
	if _validation_outcome_recap_tab_resetting:
		_last_outcome_recap_tab_index = tab
		_sync_outcome_recap_tab_tooltip()
		return
	var previous_tab := _last_outcome_recap_tab_index
	_last_outcome_recap_tab_index = tab
	_validation_outcome_recap_tab_change_sequence += 1
	_validation_outcome_recap_tab_change_count += 1
	var change_sequence := _validation_outcome_recap_tab_change_sequence
	_last_outcome_recap_tab_change_result = {
		"ok": true,
		"from_tab": previous_tab,
		"to_tab": tab,
		"tab_title": _recap_tabs.get_tab_title(tab) if tab >= 0 and tab < _recap_tabs.get_tab_count() else "",
		"focus_retained": false,
		"focus_owner": "",
		"sequence": change_sequence,
	}
	_sync_outcome_recap_tab_tooltip()
	call_deferred("_complete_outcome_recap_tab_focus_retention", tab, change_sequence)

func _complete_outcome_recap_tab_focus_retention(tab: int, change_sequence: int) -> void:
	if (
		not is_inside_tree()
		or tab != _recap_tabs.current_tab
		or change_sequence != _validation_outcome_recap_tab_change_sequence
	):
		return
	var tab_bar := _recap_tabs.get_tab_bar()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var retained := tab_bar != null and focus_owner == tab_bar
	if retained:
		_validation_outcome_recap_tab_focus_retention_count += 1
	_last_outcome_recap_tab_change_result["focus_retained"] = retained
	_last_outcome_recap_tab_change_result["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""

func _on_outcome_recap_tab_bar_gui_input(event: InputEvent) -> void:
	var direction := 0
	if event.is_action_pressed("ui_left", true):
		direction = -1
	elif event.is_action_pressed("ui_right", true):
		direction = 1
	if direction == 0:
		return
	var tab_bar := _recap_tabs.get_tab_bar()
	var viewport := get_viewport()
	if tab_bar == null or viewport == null or viewport.gui_get_focus_owner() != tab_bar:
		return
	if _selectable_outcome_recap_tab_in_direction(tab_bar, _recap_tabs.current_tab, direction) >= 0:
		return
	_validation_outcome_recap_tab_boundary_retain_count += 1
	tab_bar.accept_event()
	tab_bar.grab_focus()

func _selectable_outcome_recap_tab_in_direction(tab_bar: TabBar, from_tab: int, direction: int) -> int:
	var candidate := from_tab + direction
	while candidate >= 0 and candidate < tab_bar.tab_count:
		if not tab_bar.is_tab_disabled(candidate) and not tab_bar.is_tab_hidden(candidate):
			return candidate
		candidate += direction
	return -1

func _sync_outcome_recap_tab_tooltip() -> void:
	var tab_bar := _recap_tabs.get_tab_bar()
	if tab_bar == null:
		return
	var selected_title := "Outcome recap"
	if _recap_tabs.current_tab >= 0 and _recap_tabs.current_tab < _recap_tabs.get_tab_count():
		selected_title = _recap_tabs.get_tab_title(_recap_tabs.current_tab)
	tab_bar.tooltip_text = _join_tooltip_sections([
		"Outcome recap tabs. Use Left and Right while the tabs are focused.",
		"Selected: %s." % selected_title,
	])

func _apply_responsive_layout() -> void:
	if _content_margin == null:
		return
	var available_size := size
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		available_size = parent_control.size
	var compact_layout := available_size.x < 1360.0 or available_size.y < 760.0
	var layout_changed := _compact_layout_active != compact_layout
	_compact_layout_active = compact_layout
	_set_margin(_content_margin, 8 if compact_layout else 12)
	var content_size := _content_box.size
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		call_deferred("_apply_responsive_layout")
		return
	_recap_tabs.visible = _recap_expanded
	_save_title_label.visible = _recap_expanded
	_save_status_label.visible = _recap_expanded
	_actions_hint_label.visible = _recap_expanded
	_return_cue_label.visible = _recap_expanded and not compact_layout
	_set_margin(_sidebar_pad, (6 if compact_layout else 10) if _recap_expanded else 4)
	_sidebar_box.add_theme_constant_override("separation", (4 if compact_layout else 8) if _recap_expanded else 0)
	_set_margin(_save_pad, (6 if compact_layout else 10) if _recap_expanded else 4, (4 if compact_layout else 8) if _recap_expanded else 2)
	_save_box.add_theme_constant_override("separation", 2 if compact_layout else 4)
	var edge_gap := 6.0 if compact_layout else 8.0
	var sidebar_width := (OUTCOME_COMPACT_SIDEBAR_WIDTH if compact_layout else OUTCOME_WIDE_SIDEBAR_WIDTH) if _recap_expanded else OUTCOME_COLLAPSED_COMMAND_WIDTH
	sidebar_width = minf(sidebar_width, content_size.x * 0.42)
	var sidebar_height := content_size.y if _recap_expanded else maxf(OUTCOME_COLLAPSED_COMMAND_HEIGHT, _sidebar_shell.get_combined_minimum_size().y)
	var left_available := maxf(0.0, content_size.x - sidebar_width - edge_gap)
	var banner_width := minf(left_available, OUTCOME_COMPACT_BANNER_WIDTH if compact_layout else OUTCOME_WIDE_BANNER_WIDTH)
	var banner_height := maxf(
		OUTCOME_COMPACT_BANNER_HEIGHT if compact_layout else OUTCOME_WIDE_BANNER_HEIGHT,
		_banner.get_combined_minimum_size().y
	)
	var dock_width := left_available if compact_layout else minf(left_available, OUTCOME_WIDE_DOCK_WIDTH)
	var dock_height := minf(
		content_size.y - banner_height - edge_gap,
		maxf(
			OUTCOME_COMPACT_DOCK_HEIGHT if compact_layout else OUTCOME_WIDE_DOCK_HEIGHT,
			_command_column.get_combined_minimum_size().y
		)
	)
	_banner.position = Vector2.ZERO
	_banner.size = Vector2(banner_width, banner_height)
	_main_row.position = Vector2.ZERO
	_main_row.size = content_size
	_sidebar_shell.position = Vector2(content_size.x - sidebar_width, 0.0 if _recap_expanded else content_size.y - sidebar_height)
	_sidebar_shell.size = Vector2(sidebar_width, sidebar_height)
	_command_column.position = Vector2(0.0, content_size.y - dock_height)
	_command_column.size = Vector2(dock_width, dock_height)
	_set_margin(_banner_pad, 6 if compact_layout else 10)
	_banner_columns.add_theme_constant_override("separation", 8 if compact_layout else 10)
	_banner_art_panel.custom_minimum_size.x = OUTCOME_COMPACT_BANNER_ART_WIDTH if compact_layout else OUTCOME_WIDE_BANNER_ART_WIDTH
	_set_margin(_banner_art_pad, 4 if compact_layout else 8)
	_outcome_banner.custom_minimum_size.y = OUTCOME_COMPACT_EMBLEM_HEIGHT if compact_layout else OUTCOME_WIDE_EMBLEM_HEIGHT
	_banner_info.add_theme_constant_override("separation", 4 if compact_layout else 6)
	_command_column.add_theme_constant_override("separation", 6 if compact_layout else 8)
	_force_cards.add_theme_constant_override("separation", 6 if compact_layout else 8)
	_set_margin(_hero_pad, 4 if compact_layout else 6, 3 if compact_layout else 4)
	_set_margin(_army_pad, 4 if compact_layout else 6, 3 if compact_layout else 4)
	_set_margin(_resource_pad, 4 if compact_layout else 6, 3 if compact_layout else 4)
	_set_margin(_actions_pad, 6 if compact_layout else 10)
	_actions_box.add_theme_constant_override("separation", 4 if compact_layout else 6)
	_recap_details_button.text = "Close" if _recap_expanded else "Details"
	_recap_details_button.tooltip_text = "Close the detailed outcome recap." if _recap_expanded else "Open progress, campaign, carryover, aftermath, and chronicle details."
	if layout_changed and _session != null:
		call_deferred("_refresh")

func _on_recap_details_pressed() -> void:
	_recap_expanded = not _recap_expanded
	_apply_responsive_layout()
	_recap_details_button.grab_focus()
	call_deferred("_configure_outcome_keyboard_focus", false)

func _set_margin(container: MarginContainer, horizontal: int, vertical: int = -1) -> void:
	if container == null:
		return
	var vertical_margin := horizontal if vertical < 0 else vertical
	container.add_theme_constant_override("margin_left", horizontal)
	container.add_theme_constant_override("margin_top", vertical_margin)
	container.add_theme_constant_override("margin_right", horizontal)
	container.add_theme_constant_override("margin_bottom", vertical_margin)

func _outcome_music_metadata() -> Dictionary:
	if _session == null:
		return {}
	return {
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"status": _session.scenario_status,
		"day": _session.day,
	}

func _refresh() -> void:
	_model = ScenarioRules.build_outcome_model(_session)
	var status := String(_session.scenario_status)
	_apply_result_palette(status)
	_sync_scenic_epilogue(status)
	_header_label.text = String(_model.get("header", "Scenario Outcome"))
	_set_compact_label(_summary_label, String(_model.get("summary", "Scenario resolution recorded.")), 2)
	_mode_label.text = String(_model.get("mode_summary", ""))
	_result_badge_label.text = _result_status_label(status)
	if _outcome_banner.has_method("set_outcome"):
		_outcome_banner.call("set_outcome", status)
	_hero_portrait.set_hero_id(_live_player_hero_id())
	_set_compact_label(_hero_label, String(_model.get("hero_summary", "Hero data unavailable.")), 2)
	_set_compact_label(_army_label, String(_model.get("army_summary", "Army data unavailable.")), 2)
	_set_compact_label(_resource_label, String(_model.get("resource_summary", "Resource data unavailable.")), 2)
	_set_compact_label(_progression_label, String(_model.get("progression_summary", "")), 2 if _compact_layout_active else 4)
	_set_compact_label(_campaign_arc_label, String(_model.get("campaign_arc_summary", "")), 2 if _compact_layout_active else 4)
	var carryover_check := _outcome_carryover_check(AppRouter.active_save_surface())
	_set_compact_label(
		_carryover_label,
		_join_tooltip_sections([
			String(carryover_check.get("visible_text", "")),
			String(_model.get("carryover_summary", "")),
		]),
		2 if _compact_layout_active else 4
	)
	_carryover_label.tooltip_text = _join_tooltip_sections([
		String(carryover_check.get("tooltip_text", "")),
		String(_model.get("carryover_summary", "")),
	])
	_set_compact_label(_aftermath_label, String(_model.get("aftermath_summary", "")), 2 if _compact_layout_active else 4)
	_set_compact_label(_journal_label, String(_model.get("journal_summary", "")), 2 if _compact_layout_active else 4)
	_refresh_save_surface()
	var next_step_summary := String(_model.get("next_step_summary", ""))
	var next_play_action_summary := String(_model.get("next_play_action_summary", ""))
	var continuity_choice_summary := String(_model.get("continuity_choice_summary", ""))
	var post_result_handoff := String(_model.get("post_result_handoff_summary", ""))
	var action_cue_summary := String(_model.get("action_cue_summary", ""))
	var follow_up_check := _outcome_follow_up_check(AppRouter.active_save_surface())
	var follow_up_visible := String(follow_up_check.get("visible_text", ""))
	var follow_up_tooltip := String(follow_up_check.get("tooltip_text", ""))
	var retry_check := _outcome_retry_check(AppRouter.active_save_surface())
	var retry_visible := String(retry_check.get("visible_text", ""))
	var retry_tooltip := String(retry_check.get("tooltip_text", ""))
	var resolution_handoff := _outcome_resolution_handoff_text()
	var action_status_lines := []
	if next_step_summary != "":
		action_status_lines.append(next_step_summary)
	if follow_up_visible != "":
		action_status_lines.append(follow_up_visible)
	if retry_visible != "":
		action_status_lines.append(retry_visible)
	if resolution_handoff != "":
		action_status_lines.append(resolution_handoff)
	if post_result_handoff != "":
		action_status_lines.append(post_result_handoff)
	if continuity_choice_summary != "":
		action_status_lines.append(continuity_choice_summary)
	if next_play_action_summary != "":
		action_status_lines.append(next_play_action_summary)
	var visible_status_line := (
		_last_action_message
		if _last_action_message != ""
		else (next_step_summary if next_step_summary != "" else (action_cue_summary if action_cue_summary != "" else "Review the outcome, then choose the next step."))
	)
	_set_compact_label(
		_action_status_label,
		visible_status_line,
		1,
		156
	)
	_action_status_label.tooltip_text = "\n".join(action_status_lines + [follow_up_tooltip, retry_tooltip]).strip_edges()
	var visible_action_hint := action_cue_summary if action_cue_summary != "" else (next_play_action_summary if next_play_action_summary != "" else visible_status_line)
	_set_compact_label(
		_actions_hint_label,
		visible_action_hint,
		1,
		148
	)
	_actions_hint_label.tooltip_text = "\n".join(action_status_lines + [follow_up_tooltip, retry_tooltip, action_cue_summary, visible_action_hint]).strip_edges()
	_refresh_guide_surface()
	_rebuild_actions()
	call_deferred("_apply_responsive_layout")

func _configure_save_slot_picker() -> void:
	_save_slot_picker.hide()
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))
	_refresh_save_surface()

func _refresh_save_surface() -> void:
	if _save_slot_picker.get_item_count() <= 0:
		return
	var surface := AppRouter.active_save_surface()
	var selected_slot := SaveService.get_selected_manual_slot()
	for index in range(_save_slot_picker.get_item_count()):
		if _save_slot_picker.get_item_id(index) == selected_slot:
			_save_slot_picker.select(index)
			break
	var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	var summary: Dictionary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	var current_context := String(surface.get("current_context", ""))
	var save_check := String(surface.get("save_check", "")).strip_edges()
	var play_check := String(surface.get("play_check", "")).strip_edges()
	var return_handoff := String(surface.get("return_handoff", "")).strip_edges()
	var slot_check := _outcome_slot_check(surface, summary)
	var slot_check_text := String(slot_check.get("visible_text", "")).strip_edges()
	var outcome_save_check := _outcome_save_check(surface, summary)
	var outcome_save_check_text := String(outcome_save_check.get("visible_text", "")).strip_edges()
	var visible_save_text := _join_tooltip_sections([
		slot_check_text,
		outcome_save_check_text,
		save_check if save_check != "" else (current_save_recap if current_save_recap != "" else latest_context),
	])
	_set_compact_label(_save_status_label, visible_save_text, 2 if _compact_layout_active else 3)
	var return_cue := _outcome_return_cue_text(surface)
	_set_compact_label(_return_cue_label, return_cue, 2, 108)
	var save_tooltip_lines := [latest_context]
	if String(slot_check.get("tooltip_text", "")).strip_edges() != "":
		save_tooltip_lines.append(String(slot_check.get("tooltip_text", "")))
	if String(outcome_save_check.get("tooltip_text", "")).strip_edges() != "":
		save_tooltip_lines.append(String(outcome_save_check.get("tooltip_text", "")))
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if play_check != "":
		save_tooltip_lines.append(play_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	var slot_resume_recap := String(surface.get("slot_resume_recap", ""))
	if slot_resume_recap != "":
		save_tooltip_lines.append("Selected slot recap:\n%s" % slot_resume_recap)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_return_cue_label.tooltip_text = _join_tooltip_sections([
		return_cue,
		return_handoff,
		String(surface.get("menu_button_tooltip", "")),
	])
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Outcome")) if _recap_expanded else "Save"
	_save_button.tooltip_text = _join_tooltip_sections([
		"Create or replace a named file for this outcome.",
		String(outcome_save_check.get("tooltip_text", "")),
		String(slot_check.get("tooltip_text", "")),
		save_check,
		return_handoff,
	])
	_menu_button.text = String(surface.get("menu_button_label", "Main Menu")) if _recap_expanded else "Menu"
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))
	_refresh_guide_surface()

func _rebuild_actions() -> void:
	var focused_action_id := _focused_outcome_action_id()
	for child in _actions_bar.get_children():
		child.queue_free()

	var actions = _model.get("actions", [])
	if not (actions is Array) or actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No follow-up actions are available."
		_actions_bar.add_child(placeholder)
		call_deferred("_configure_outcome_keyboard_focus", false, focused_action_id)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var action_id := String(action.get("id", ""))
		var recovery_blocked := _outcome_recovery_pending and _outcome_action_starts_new_session(action_id)
		var button := Button.new()
		button.set_meta("outcome_action_id", action_id)
		button.text = String(action.get("label", action_id if action_id != "" else "Action"))
		button.disabled = bool(action.get("disabled", false)) or recovery_blocked
		button.tooltip_text = _outcome_action_tooltip(action)
		if recovery_blocked:
			button.tooltip_text = _join_tooltip_sections([
				OUTCOME_AUTOSAVE_RECOVERY_MESSAGE,
				button.tooltip_text,
			])
		FrontierVisualKit.apply_button(button, "primary", 172.0, 36.0)
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_actions_bar.add_child(button)
	call_deferred("_configure_outcome_keyboard_focus", false, focused_action_id)

func _on_action_pressed(action_id: String) -> Dictionary:
	_validation_outcome_focus_accept_count += 1
	if _validation_outcome_focus_action_execution_suppressed:
		_last_outcome_focus_accept_result = {
			"ok": true,
			"performed": false,
			"routed": false,
			"suppressed": true,
			"action_id": action_id,
			"message": "Outcome focus activation recorded without changing the active expedition.",
		}
		return _last_outcome_focus_accept_result.duplicate(true)
	if _outcome_action_starts_new_session(action_id):
		_last_outcome_focus_accept_result = _request_outcome_new_session_confirmation(
			action_id,
			_outcome_action_button(action_id)
		).duplicate(true)
	else:
		_last_outcome_focus_accept_result = _perform_outcome_action(action_id).duplicate(true)
	_last_outcome_focus_accept_result["action_id"] = action_id
	_last_outcome_focus_accept_result["suppressed"] = false
	return _last_outcome_focus_accept_result.duplicate(true)

func _configure_outcome_keyboard_focus(
	force: bool = false,
	preferred_action_id: String = ""
) -> void:
	if not is_inside_tree() \
			or (_manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible) \
			or not _pending_outcome_new_session_confirmation.is_empty() \
			or (_new_session_confirmation_dialog != null and _new_session_confirmation_dialog.visible):
		return
	var surfaces := [
		_actions_bar,
		_recap_tabs.get_tab_bar(),
		_save_slot_picker,
		_save_button,
		_menu_button,
		_recap_details_button,
		_guide_button,
	]
	var controls := FrontierVisualKit.configure_focus_cycle(surfaces)
	_last_outcome_focus_cycle = []
	_last_outcome_focus_cycle_names = []
	_last_outcome_focus_tab_bar_occurrences = 0
	var tab_bar := _recap_tabs.get_tab_bar()
	for control in controls:
		if control is Control:
			_last_outcome_focus_cycle_names.append(String(control.name))
			if control == tab_bar:
				_last_outcome_focus_tab_bar_occurrences += 1
			_last_outcome_focus_cycle.append({
				"node_name": String(control.name),
				"action_id": String(control.get_meta("outcome_action_id", "")),
				"disabled": bool(control.disabled) if control is BaseButton else false,
				"is_recap_tab_bar": control == tab_bar,
			})
	var preferred: Control = null
	_last_outcome_focus_preferred_action_id = ""
	if _outcome_recovery_pending:
		preferred = _save_button
	else:
		var action_id := preferred_action_id
		if action_id == "":
			action_id = _primary_outcome_action_id()
		preferred = _outcome_action_button(action_id)
		if not FrontierVisualKit.is_keyboard_focusable(preferred):
			action_id = _primary_outcome_action_id()
			preferred = _outcome_action_button(action_id)
		if FrontierVisualKit.is_keyboard_focusable(preferred):
			_last_outcome_focus_preferred_action_id = action_id
		else:
			preferred = _save_button if FrontierVisualKit.is_keyboard_focusable(_save_button) else _menu_button
	FrontierVisualKit.grab_keyboard_focus(self, preferred, controls, force)

func _focused_outcome_action_id() -> String:
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	if focus_owner is Control and _actions_bar.is_ancestor_of(focus_owner):
		return String(focus_owner.get_meta("outcome_action_id", ""))
	return ""

func _outcome_action_button(action_id: String) -> Button:
	if action_id == "":
		return null
	for child in _actions_bar.get_children():
		if child is Button and not child.is_queued_for_deletion() and String(child.get_meta("outcome_action_id", "")) == action_id:
			return child
	return null

func _request_outcome_new_session_confirmation(action_id: String, focus_origin: Control = null) -> Dictionary:
	_validation_outcome_new_session_request_count += 1
	if not _pending_outcome_new_session_confirmation.is_empty():
		_validation_outcome_new_session_duplicate_request_count += 1
		var duplicate_result := {
			"ok": false,
			"pending": true,
			"confirmation_required": true,
			"performed": false,
			"routed": false,
			"reason": "confirmation_already_pending",
			"action_id": String(_pending_outcome_new_session_confirmation.get("action_id", "")),
			"requested_action_id": action_id,
			"message": "Finish the current outcome confirmation first.",
		}
		_last_outcome_new_session_confirmation_result = duplicate_result.duplicate(true)
		return duplicate_result

	_sync_outcome_recovery_state(false, true)
	if _outcome_recovery_pending:
		var recovery_result := {
			"ok": false,
			"pending": false,
			"confirmation_required": false,
			"performed": false,
			"routed": false,
			"reason": "outcome_autosave_recovery_pending",
			"action_id": action_id,
			"message": OUTCOME_AUTOSAVE_RECOVERY_MESSAGE,
		}
		_last_outcome_new_session_confirmation_result = recovery_result.duplicate(true)
		_save_button.call_deferred("grab_focus")
		return recovery_result

	var action := _outcome_action_record(action_id)
	if action.is_empty() or bool(action.get("disabled", false)) or not _outcome_action_starts_new_session(action_id):
		var unavailable_result := {
			"ok": false,
			"pending": false,
			"confirmation_required": false,
			"performed": false,
			"routed": false,
			"reason": "action_unavailable",
			"action_id": action_id,
			"message": "That outcome follow-up is not available.",
		}
		_last_outcome_new_session_confirmation_result = unavailable_result.duplicate(true)
		_restore_outcome_new_session_origin(focus_origin, action_id)
		return unavailable_result

	var active_session := SessionState.ensure_active_session()
	if active_session != _session:
		var stale_result := {
			"ok": false,
			"pending": false,
			"confirmation_required": false,
			"performed": false,
			"routed": false,
			"reason": "stale_request",
			"stale_fields": ["session_reference"],
			"action_id": action_id,
			"message": OUTCOME_NEW_SESSION_STALE_MESSAGE,
		}
		_last_outcome_new_session_confirmation_result = stale_result.duplicate(true)
		_restore_outcome_new_session_origin(focus_origin, action_id)
		return stale_result

	var label := String(action.get("label", action_id)).strip_edges()
	var identity := _outcome_new_session_identity(_session)
	_pending_outcome_new_session_confirmation = identity.merged({
		"action_id": action_id,
		"action_label": label,
	}, true)
	_outcome_new_session_source_session = _session
	_outcome_new_session_return_focus = _capture_outcome_new_session_origin(
		focus_origin if focus_origin != null else _outcome_action_button(action_id)
	)
	_new_session_confirmation_dialog.title = "Start Fresh Expedition?"
	_new_session_confirmation_dialog.dialog_text = "%s starts a fresh expedition and replaces Continue Latest after its opening checkpoint. Save Outcome first if you want to keep this review." % label
	_new_session_confirmation_dialog.get_ok_button().text = label
	_new_session_confirmation_dialog.get_cancel_button().text = OUTCOME_NEW_SESSION_CANCEL_TEXT
	_new_session_confirmation_dialog.popup_centered(Vector2i(700, 220))
	_new_session_confirmation_dialog.get_cancel_button().call_deferred("grab_focus")
	_focus_outcome_new_session_cancel_after_popup()
	var request_result := {
		"ok": true,
		"pending": true,
		"confirmation_required": true,
		"performed": false,
		"routed": false,
		"reason": "confirmation_required",
		"action_id": action_id,
		"action_label": label,
		"message": "Confirm %s or keep this outcome." % label,
	}
	_last_outcome_new_session_confirmation_result = request_result.duplicate(true)
	return request_result

func _capture_outcome_new_session_origin(fallback: Control) -> Control:
	if (
		is_instance_valid(fallback)
		and fallback.is_inside_tree()
		and fallback.is_visible_in_tree()
		and fallback.focus_mode != Control.FOCUS_NONE
		and is_ancestor_of(fallback)
	):
		return fallback
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

func _focus_outcome_new_session_cancel_after_popup() -> void:
	if not _new_session_confirmation_dialog.visible or _pending_outcome_new_session_confirmation.is_empty():
		return
	_new_session_confirmation_dialog.get_cancel_button().grab_focus()
	await get_tree().process_frame
	if _new_session_confirmation_dialog.visible and not _pending_outcome_new_session_confirmation.is_empty():
		_new_session_confirmation_dialog.get_cancel_button().grab_focus()

func _restore_outcome_new_session_origin(target: Control, action_id: String) -> void:
	await get_tree().process_frame
	var resolved_target := target
	if not is_instance_valid(resolved_target) \
			or not resolved_target.is_inside_tree() \
			or resolved_target.is_queued_for_deletion() \
			or not resolved_target.is_visible_in_tree() \
			or resolved_target.focus_mode == Control.FOCUS_NONE:
		resolved_target = _outcome_action_button(action_id)
	if FrontierVisualKit.is_keyboard_focusable(resolved_target):
		resolved_target.grab_focus()

func _on_outcome_new_session_confirmation_canceled() -> Dictionary:
	if _pending_outcome_new_session_confirmation.is_empty():
		return {
			"ok": false,
			"canceled": false,
			"pending": false,
			"performed": false,
			"routed": false,
			"reason": "no_pending_confirmation",
		}
	var pending := _pending_outcome_new_session_confirmation.duplicate(true)
	var return_focus := _outcome_new_session_return_focus
	_clear_outcome_new_session_confirmation()
	_new_session_confirmation_dialog.hide()
	_validation_outcome_new_session_cancel_count += 1
	var result := {
		"ok": true,
		"canceled": true,
		"pending": false,
		"confirmation_required": false,
		"performed": false,
		"routed": false,
		"reason": "canceled",
		"action_id": String(pending.get("action_id", "")),
		"action_label": String(pending.get("action_label", "")),
		"message": "Kept this outcome review.",
	}
	_last_outcome_new_session_confirmation_result = result.duplicate(true)
	_restore_outcome_new_session_origin(return_focus, String(pending.get("action_id", "")))
	return result

func _on_outcome_new_session_confirmation_confirmed() -> Dictionary:
	if _pending_outcome_new_session_confirmation.is_empty():
		return {
			"ok": false,
			"confirmed": false,
			"pending": false,
			"performed": false,
			"routed": false,
			"reason": "no_pending_confirmation",
		}
	_validation_outcome_new_session_confirm_count += 1
	var pending := _pending_outcome_new_session_confirmation.duplicate(true)
	var source_session := _outcome_new_session_source_session
	var return_focus := _outcome_new_session_return_focus
	var action_id := String(pending.get("action_id", ""))
	_sync_outcome_recovery_state(false, false)
	if _outcome_recovery_pending:
		_clear_outcome_new_session_confirmation()
		_new_session_confirmation_dialog.hide()
		var recovery_result := {
			"ok": false,
			"confirmed": false,
			"pending": false,
			"confirmation_required": false,
			"performed": false,
			"routed": false,
			"reason": "outcome_autosave_recovery_pending",
			"action_id": action_id,
			"message": OUTCOME_AUTOSAVE_RECOVERY_MESSAGE,
		}
		_last_outcome_new_session_confirmation_result = recovery_result.duplicate(true)
		_save_button.call_deferred("grab_focus")
		return recovery_result

	var stale_fields := _outcome_new_session_stale_fields(pending, source_session)
	if not stale_fields.is_empty():
		_clear_outcome_new_session_confirmation()
		_new_session_confirmation_dialog.hide()
		_validation_outcome_new_session_stale_count += 1
		_last_action_message = OUTCOME_NEW_SESSION_STALE_MESSAGE
		var stale_result := {
			"ok": false,
			"confirmed": false,
			"pending": false,
			"confirmation_required": false,
			"performed": false,
			"routed": false,
			"reason": "stale_request",
			"stale_fields": stale_fields,
			"action_id": action_id,
			"message": OUTCOME_NEW_SESSION_STALE_MESSAGE,
		}
		_last_outcome_new_session_confirmation_result = stale_result.duplicate(true)
		_restore_outcome_new_session_origin(return_focus, action_id)
		return stale_result

	_clear_outcome_new_session_confirmation()
	_new_session_confirmation_dialog.hide()
	_validation_outcome_new_session_perform_count += 1
	var action_result := _perform_outcome_action(action_id)
	var routed := String(action_result.get("route", "stay")) == "overworld"
	var result := {
		"ok": bool(action_result.get("ok", false)),
		"confirmed": true,
		"pending": false,
		"confirmation_required": false,
		"performed": true,
		"routed": routed,
		"route_suppressed": routed and _validation_outcome_new_session_routing_suppressed,
		"reason": "confirmed" if bool(action_result.get("ok", false)) else "action_failed",
		"action_id": action_id,
		"action_label": String(pending.get("action_label", "")),
		"route": String(action_result.get("route", "stay")),
		"action_result": action_result.duplicate(true),
		"message": String(action_result.get("message", "")),
	}
	_last_outcome_new_session_confirmation_result = result.duplicate(true)
	if not bool(result.get("ok", false)):
		_restore_outcome_new_session_origin(return_focus, action_id)
	return result

func _clear_outcome_new_session_confirmation() -> void:
	_pending_outcome_new_session_confirmation = {}
	_outcome_new_session_source_session = null
	_outcome_new_session_return_focus = null

func _outcome_new_session_stale_fields(pending: Dictionary, source_session: SessionStateStore.SessionData) -> Array[String]:
	var stale_fields: Array[String] = []
	var active_session := SessionState.ensure_active_session()
	if active_session != source_session or source_session != _session:
		stale_fields.append("session_reference")
	var current_identity := _outcome_new_session_identity(active_session)
	for field in ["session_id", "scenario_id", "scenario_status", "launch_mode", "day"]:
		if current_identity.get(field) != pending.get(field):
			stale_fields.append(field)
	var action_id := String(pending.get("action_id", ""))
	var action := _outcome_action_record(action_id)
	var action_button := _outcome_action_button(action_id)
	if action.is_empty() \
			or bool(action.get("disabled", false)) \
			or not FrontierVisualKit.is_keyboard_focusable(action_button) \
			or not _outcome_action_starts_new_session(action_id):
		stale_fields.append("action")
	return stale_fields

func _outcome_new_session_identity(session: SessionStateStore.SessionData) -> Dictionary:
	if session == null:
		return {
			"session_id": "",
			"scenario_id": "",
			"scenario_status": "",
			"launch_mode": "",
			"day": 0,
		}
	return {
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"scenario_status": session.scenario_status,
		"launch_mode": session.launch_mode,
		"day": session.day,
	}

func _outcome_action_record(action_id: String) -> Dictionary:
	var actions = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary and String(action.get("id", "")) == action_id:
				return action.duplicate(true)
	return {}

func _perform_outcome_action(action_id: String) -> Dictionary:
	_sync_outcome_recovery_state(false, true)
	if _outcome_recovery_pending and _outcome_action_starts_new_session(action_id):
		_validation_outcome_recovery_blocked_action_count += 1
		var blocked_result := {
			"ok": false,
			"routed": false,
			"reason": "outcome_autosave_recovery_pending",
			"retry_action": "retry_outcome_autosave",
			"action_id": action_id,
			"message": OUTCOME_AUTOSAVE_RECOVERY_MESSAGE,
		}
		_last_action_message = OUTCOME_AUTOSAVE_RECOVERY_MESSAGE
		_refresh()
		_save_button.call_deferred("grab_focus")
		return blocked_result
	if action_id == "return_to_menu":
		var return_result := _on_menu_pressed()
		return_result["action_id"] = action_id
		return_result["route"] = "main_menu" if bool(return_result.get("routed", false)) else "stay"
		return return_result
	var result := ScenarioRules.perform_outcome_action(_session, action_id)
	_last_action_message = String(result.get("message", ""))
	match String(result.get("route", "stay")):
		"overworld":
			if _outcome_action_starts_new_session(action_id):
				_validation_outcome_new_session_route_count += 1
				result["routed"] = true
				result["route_suppressed"] = _validation_outcome_new_session_routing_suppressed
				if not _validation_outcome_new_session_routing_suppressed:
					AppRouter.go_to_overworld()
			else:
				AppRouter.go_to_overworld()
		"main_menu":
			AppRouter.return_to_main_menu_from_active_play()
		_:
			result["routed"] = false
			_refresh()
	return result

func _on_save_pressed(legacy_slot: bool = false) -> Dictionary:
	_sync_outcome_recovery_state(false, true)
	var recovery_result: Dictionary = {}
	if _outcome_recovery_pending:
		_validation_outcome_recovery_request_count += 1
		_validation_outcome_recovery_retry_attempt_count += 1
		recovery_result = AppRouter.retry_scenario_outcome_autosave()
		_last_outcome_recovery_retry_result = recovery_result.duplicate(true)
		_sync_outcome_recovery_state()
		if not bool(recovery_result.get("ok", false)) or _outcome_recovery_pending:
			_validation_outcome_recovery_retry_failure_count += 1
			_last_action_message = OUTCOME_AUTOSAVE_RECOVERY_MESSAGE if _outcome_recovery_pending else String(
				recovery_result.get("message", "Outcome autosave recovery is no longer available.")
			).strip_edges().left(180)
			_refresh()
			_save_button.call_deferred("grab_focus")
			return _outcome_recovery_shell_result(recovery_result, false, false)
		_validation_outcome_recovery_retry_success_count += 1
		_last_action_message = ""
		_refresh()
	if not legacy_slot:
		var opened: bool = _manual_save_overwrite_dialog.open_file_browser(_session, _commit_file_save)
		return {"ok": opened, "saved": false, "pending": opened, "reason": "file_browser", "message": "Choose a save file."}
	var action := AppRouter.active_manual_save_action()
	if bool(action.get("disabled", true)):
		_last_action_message = String(action.get("summary", "The outcome could not be saved."))
		_refresh()
		return _outcome_recovery_shell_result(action, false, false, recovery_result)
	if bool(action.get("requires_confirmation", false)):
		_manual_save_overwrite_dialog.open_action(action)
		return _outcome_recovery_shell_result(action, false, true, recovery_result)
	var manual_result := _commit_manual_save(int(action.get("slot", SaveService.get_selected_manual_slot())))
	return _outcome_recovery_shell_result(manual_result, bool(manual_result.get("ok", false)), false, recovery_result)

func _commit_file_save(file_name: String, expected_sha256: String) -> Dictionary:
	return _commit_manual_save(SaveService.get_selected_manual_slot(), file_name, expected_sha256)

func _commit_manual_save(manual_slot: int, file_name: String = "", expected_sha256: String = "") -> Dictionary:
	var result := AppRouter.save_active_session_to_file(file_name, expected_sha256) if file_name != "" else AppRouter.save_active_session_to_manual_slot(manual_slot)
	_last_action_message = String(result.get("message", ""))
	_refresh()
	if bool(result.get("ok", false)):
		_save_written_cue_presenter.present(result, manual_slot)
	return result

func validation_save_written_cue_snapshot() -> Dictionary:
	return _save_written_cue_presenter.validation_snapshot() if _save_written_cue_presenter != null else {}

func _present_load_resumed_cue() -> void:
	var payload: Dictionary = AppRouter.consume_load_resumed_presentation("scenario_outcome")
	if not payload.is_empty() and _load_resumed_cue_presenter != null:
		_load_resumed_cue_presenter.present(payload)

func validation_load_resumed_cue_snapshot() -> Dictionary:
	return _load_resumed_cue_presenter.validation_snapshot() if _load_resumed_cue_presenter != null else {}

func _on_manual_save_overwrite_confirmed() -> void:
	var manual_slot: int = int(_manual_save_overwrite_dialog.consume_pending_slot())
	if SaveService.get_manual_slot_ids().has(manual_slot):
		_commit_manual_save(manual_slot)

func _on_manual_save_overwrite_canceled() -> void:
	_manual_save_overwrite_dialog.clear_pending()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_surface()

func _on_menu_pressed() -> Dictionary:
	_validation_return_to_menu_request_count += 1
	var result: Dictionary = AppRouter.return_to_main_menu_from_active_play()
	_last_return_to_menu_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		return _last_return_to_menu_result.duplicate(true)
	var message := String(result.get("message", "")).strip_edges().left(180)
	if message == "":
		message = RETURN_TO_MENU_FAILURE_MESSAGE
	_last_return_to_menu_result["message"] = message
	_sync_outcome_recovery_state()
	_last_action_message = OUTCOME_AUTOSAVE_RECOVERY_MESSAGE if _outcome_recovery_pending else message
	_refresh()
	_menu_button.call_deferred("grab_focus")
	return _last_return_to_menu_result.duplicate(true)

func _sync_outcome_recovery_state(capture_entry: bool = false, refresh_on_clear: bool = false) -> Dictionary:
	var was_pending := _outcome_recovery_pending
	var snapshot: Dictionary = AppRouter.scenario_outcome_recovery_snapshot()
	_outcome_recovery_pending = bool(snapshot.get("recovery_pending", snapshot.get("pending", false)))
	var entry_value: Variant = snapshot.get("last_result", snapshot.get("entry_result", {}))
	if capture_entry and entry_value is Dictionary:
		_outcome_recovery_entry_result = (entry_value as Dictionary).duplicate(true)
	if _outcome_recovery_pending:
		_last_action_message = OUTCOME_AUTOSAVE_RECOVERY_MESSAGE
	elif was_pending and _last_action_message == OUTCOME_AUTOSAVE_RECOVERY_MESSAGE:
		_last_action_message = ""
		if refresh_on_clear:
			_refresh()
	return snapshot

func _outcome_action_starts_new_session(action_id: String) -> bool:
	return action_id.begins_with("campaign_start:") or action_id.begins_with("skirmish_start:")

func _outcome_action_effectively_disabled(action: Dictionary) -> bool:
	return bool(action.get("disabled", false)) or (
		_outcome_recovery_pending
		and _outcome_action_starts_new_session(String(action.get("id", "")))
	)

func _outcome_recovery_blocked_action_ids() -> Array[String]:
	var blocked_ids: Array[String] = []
	if not _outcome_recovery_pending:
		return blocked_ids
	var actions: Variant = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				var action_id := String(action.get("id", ""))
				if _outcome_action_starts_new_session(action_id):
					blocked_ids.append(action_id)
	return blocked_ids

func _outcome_recovery_shell_result(
	result: Dictionary,
	manual_saved: bool,
	confirmation_required: bool,
	recovery_result: Dictionary = {}
) -> Dictionary:
	var result_ok := bool(result.get("ok", false)) or confirmation_required
	var reason := String(result.get("reason", ""))
	if reason == "" and confirmation_required:
		reason = "confirmation_required"
	return {
		"ok": result_ok,
		"saved": manual_saved,
		"confirmation_required": confirmation_required,
		"recovery_pending": _outcome_recovery_pending,
		"reason": reason,
		"message": _last_action_message,
		"result": result.duplicate(true),
		"recovery_result": recovery_result.duplicate(true),
	}

func _on_guide_pressed() -> void:
	_guide_panel.visible = not _guide_panel.visible
	_refresh_guide_surface()

func validation_snapshot() -> Dictionary:
	var action_ids: Array[String] = []
	var action_payloads := []
	var actions = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				action_ids.append(String(action.get("id", "")))
				action_payloads.append(action.duplicate(true))
	var save_surface := AppRouter.active_save_surface()
	var outcome_recovery_router_snapshot := _sync_outcome_recovery_state(false, true)
	return {
		"scene_path": scene_file_path,
		"scenic_epilogue": validation_scenic_epilogue_summary(),
		"outcome_focus": validation_outcome_focus_snapshot(),
		"outcome_recap_tab_navigation": validation_outcome_recap_tab_navigation_snapshot(),
		"new_session_confirmation": validation_outcome_new_session_confirmation_snapshot(),
		"manual_save_overwrite_dialog": _manual_save_overwrite_dialog.validation_snapshot(),
		"return_to_menu_last_result": _last_return_to_menu_result.duplicate(true),
		"return_to_menu_visible_message": _last_action_message,
		"return_to_menu_focus_owner": _return_to_menu_focus_owner_name(),
		"return_to_menu_request_count": _validation_return_to_menu_request_count,
		"outcome_recovery_pending": _outcome_recovery_pending,
		"outcome_recovery_message": _last_action_message if _outcome_recovery_pending else "",
		"outcome_recovery_focus_owner": _outcome_recovery_focus_owner_name(),
		"outcome_recovery_entry_result": _outcome_recovery_entry_result.duplicate(true),
		"outcome_recovery_last_retry_result": _last_outcome_recovery_retry_result.duplicate(true),
		"outcome_recovery_request_count": _validation_outcome_recovery_request_count,
		"outcome_recovery_retry_attempt_count": _validation_outcome_recovery_retry_attempt_count,
		"outcome_recovery_retry_failure_count": _validation_outcome_recovery_retry_failure_count,
		"outcome_recovery_retry_success_count": _validation_outcome_recovery_retry_success_count,
		"outcome_recovery_blocked_action_count": _validation_outcome_recovery_blocked_action_count,
		"outcome_recovery_blocked_action_ids": _outcome_recovery_blocked_action_ids(),
		"outcome_recovery_router_snapshot": outcome_recovery_router_snapshot,
		"music_audio": MusicAudio.validation_summary(),
		"scenario_id": _session.scenario_id,
		"hero_portrait": _hero_portrait.validation_snapshot(),
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"scenario_status": _session.scenario_status,
		"scenario_summary": _session.scenario_summary,
		"game_state": _session.game_state,
		"day": _session.day,
		"resume_target": SaveService.resume_target_for_session(_session),
			"header": String(_model.get("header", "")),
			"summary": String(_model.get("summary", "")),
			"mode_summary": String(_model.get("mode_summary", "")),
			"hero_summary": String(_model.get("hero_summary", "")),
			"hero_visible": _hero_label.text,
			"hero_tooltip": _hero_label.tooltip_text,
			"army_summary": String(_model.get("army_summary", "")),
			"army_visible": _army_label.text,
			"army_tooltip": _army_label.tooltip_text,
			"resource_summary": String(_model.get("resource_summary", "")),
			"resource_visible": _resource_label.text,
			"resource_tooltip": _resource_label.tooltip_text,
		"progression_summary": String(_model.get("progression_summary", "")),
		"campaign_arc_summary": String(_model.get("campaign_arc_summary", "")),
		"carryover_summary": String(_model.get("carryover_summary", "")),
		"carryover_label": _carryover_label.text,
		"carryover_tooltip": _carryover_label.tooltip_text,
		"aftermath_summary": String(_model.get("aftermath_summary", "")),
		"journal_summary": String(_model.get("journal_summary", "")),
		"next_step_summary": String(_model.get("next_step_summary", "")),
		"outcome_resolution_handoff": _outcome_resolution_handoff_text(),
		"continuity_choice_summary": String(_model.get("continuity_choice_summary", "")),
		"post_result_handoff_summary": String(_model.get("post_result_handoff_summary", "")),
		"outcome_follow_up_check": _outcome_follow_up_check(save_surface),
		"outcome_retry_check": _outcome_retry_check(save_surface),
		"outcome_retry_check_text": String(_outcome_retry_check(save_surface).get("visible_text", "")),
		"outcome_retry_check_tooltip": String(_outcome_retry_check(save_surface).get("tooltip_text", "")),
		"outcome_carryover_check": _outcome_carryover_check(save_surface),
		"outcome_carryover_check_text": String(_outcome_carryover_check(save_surface).get("visible_text", "")),
		"outcome_carryover_check_tooltip": String(_outcome_carryover_check(save_surface).get("tooltip_text", "")),
		"next_play_action_summary": String(_model.get("next_play_action_summary", "")),
		"action_cue_summary": String(_model.get("action_cue_summary", "")),
		"actions_hint": _actions_hint_label.text,
		"actions_hint_tooltip": _actions_hint_label.tooltip_text,
		"action_status": _action_status_label.text,
		"action_status_tooltip": _action_status_label.tooltip_text,
		"action_ids": action_ids,
		"action_tooltips": _outcome_action_tooltip_snapshot(),
		"actions": action_payloads,
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"save_surface": save_surface,
		"save_status": _save_status_label.text,
		"save_status_tooltip": _save_status_label.tooltip_text,
		"save_button_tooltip": _save_button.tooltip_text,
		"menu_button_label": _menu_button.text,
		"menu_button_tooltip": _menu_button.tooltip_text,
		"return_cue": _return_cue_label.text,
		"return_cue_tooltip": _return_cue_label.tooltip_text,
		"outcome_save_check": _outcome_save_check(save_surface),
		"outcome_save_check_text": String(_outcome_save_check(save_surface).get("visible_text", "")),
		"outcome_save_check_tooltip": String(_outcome_save_check(save_surface).get("tooltip_text", "")),
		"outcome_slot_check": _outcome_slot_check(save_surface),
		"outcome_slot_check_text": String(_outcome_slot_check(save_surface).get("visible_text", "")),
		"outcome_slot_check_tooltip": String(_outcome_slot_check(save_surface).get("tooltip_text", "")),
		"outcome_guide_visible": _guide_panel.visible,
		"outcome_guide_button": _guide_button.text,
		"outcome_guide_tooltip": _guide_button.tooltip_text,
		"outcome_guide": _guide_label.text,
		"outcome_guide_full": _guide_label.tooltip_text,
		"save_check": String(save_surface.get("save_check", "")),
		"play_check": String(save_surface.get("play_check", "")),
		"return_handoff": String(save_surface.get("return_handoff", "")),
		"current_save_recap": String(save_surface.get("current_save_recap", "")),
		"slot_resume_recap": String(save_surface.get("slot_resume_recap", "")),
	}


func _live_player_hero_id() -> String:
	var hero = _session.overworld.get("hero", {})
	if hero is Dictionary and String(hero.get("id", "")) != "":
		return String(hero.get("id", ""))
	return String(_session.overworld.get("active_hero_id", ""))


func validation_scenic_epilogue_summary() -> Dictionary:
	var backdrop_summary: Dictionary = _backdrop.call("validation_summary") if _backdrop.has_method("validation_summary") else {}
	var panel_alphas := {}
	for panel_name in OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME:
		var matches := find_children(String(panel_name), "PanelContainer", true, false)
		if not matches.is_empty() and matches[0] is PanelContainer:
			panel_alphas[String(panel_name)] = (matches[0] as PanelContainer).self_modulate.a
	var banner_rect := Rect2(_banner.global_position, _banner.size)
	var command_rect := Rect2(_command_column.global_position, _command_column.size)
	var action_rect := Rect2(_actions_panel.global_position, _actions_panel.size)
	var sidebar_rect := Rect2(_sidebar_shell.global_position, _sidebar_shell.size)
	var scenic_window := Rect2(
		Vector2(_content_box.global_position.x, banner_rect.end.y),
		Vector2(maxf(0.0, sidebar_rect.position.x - _content_box.global_position.x), maxf(0.0, command_rect.position.y - banner_rect.end.y))
	)
	var viewport_size := size
	var shell_rect := Rect2(global_position, size)
	var edge_docks_contained := shell_rect.encloses(banner_rect) and shell_rect.encloses(command_rect) and shell_rect.encloses(sidebar_rect)
	var edge_docks_nonoverlapping := not banner_rect.intersects(command_rect) and not banner_rect.intersects(sidebar_rect) and not command_rect.intersects(sidebar_rect)
	var scenic_window_area_fraction := (
		scenic_window.size.x * scenic_window.size.y / (viewport_size.x * viewport_size.y)
		if viewport_size.x > 0.0 and viewport_size.y > 0.0
		else 0.0
	)
	backdrop_summary.merge({
			"presentation_model": OUTCOME_PRESENTATION_MODEL,
		"viewport_size": viewport_size,
		"content_above_backdrop": _content_margin.get_index() > _backdrop.get_index(),
		"draw_order": ["scenic_backdrop", "scenic_veil", "status_ambient", "outcome_content"],
			"banner_rect": banner_rect,
			"actions_panel_rect": action_rect,
		"actions_panel_vertical_expand": bool(_actions_panel.size_flags_vertical & Control.SIZE_EXPAND),
			"command_column_rect": command_rect,
			"sidebar_rect": sidebar_rect,
			"edge_docks_contained": edge_docks_contained,
			"edge_docks_nonoverlapping": edge_docks_nonoverlapping,
		"scenic_window_rect": scenic_window,
		"scenic_window_positive": scenic_window.size.x > 0.0 and scenic_window.size.y > 0.0,
		"scenic_window_area_fraction": scenic_window_area_fraction,
			"content_overlay_top_fraction": banner_rect.end.y / viewport_size.y if viewport_size.y > 0.0 else 1.0,
			"content_overlay_bottom_fraction": (viewport_size.y - command_rect.position.y) / viewport_size.y if viewport_size.y > 0.0 else 1.0,
			"banner_width": _banner.size.x,
			"banner_height": _banner.size.y,
			"banner_minimum_size": _banner.get_combined_minimum_size(),
			"command_minimum_size": _command_column.get_combined_minimum_size(),
			"banner_art_width": _banner_art_panel.custom_minimum_size.x,
			"emblem_height": _outcome_banner.custom_minimum_size.y,
			"action_status_surface_visible": _action_status_label.get_parent().get_parent().visible,
		"action_status_visible_line_count": _action_status_label.text.split("\n", false).size(),
		"actions_hint_visible_line_count": _actions_hint_label.text.split("\n", false).size(),
		"action_status_tooltip": _action_status_label.tooltip_text,
		"actions_hint_tooltip": _actions_hint_label.tooltip_text,
		"panel_alphas": panel_alphas,
		"panel_alpha_contract": OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME.duplicate(true),
	})
	return backdrop_summary

func validation_select_save_slot(slot: int) -> bool:
	var normalized_slot := int(slot)
	if not SaveService.get_manual_slot_ids().has(normalized_slot):
		return false
	SaveService.set_selected_manual_slot(normalized_slot)
	_refresh_save_surface()
	return SaveService.get_selected_manual_slot() == normalized_slot

func validation_save_to_selected_slot() -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot()
	_commit_manual_save(selected_slot)
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_action_message,
	}

func validation_request_save_outcome() -> Dictionary:
	return _on_save_pressed(true)

func validation_request_outcome_new_session_confirmation(action_id: String) -> Dictionary:
	return _request_outcome_new_session_confirmation(action_id, _outcome_action_button(action_id))

func validation_cancel_outcome_new_session_confirmation() -> Dictionary:
	return _on_outcome_new_session_confirmation_canceled()

func validation_confirm_outcome_new_session_confirmation() -> Dictionary:
	return _on_outcome_new_session_confirmation_confirmed()

func validation_set_outcome_new_session_routing_suppressed(suppressed: bool) -> bool:
	_validation_outcome_new_session_routing_suppressed = suppressed
	return _validation_outcome_new_session_routing_suppressed == suppressed

func validation_reset_outcome_new_session_confirmation_state() -> void:
	_new_session_confirmation_dialog.hide()
	_clear_outcome_new_session_confirmation()
	_last_outcome_new_session_confirmation_result = {}
	_validation_outcome_new_session_request_count = 0
	_validation_outcome_new_session_duplicate_request_count = 0
	_validation_outcome_new_session_cancel_count = 0
	_validation_outcome_new_session_confirm_count = 0
	_validation_outcome_new_session_stale_count = 0
	_validation_outcome_new_session_perform_count = 0
	_validation_outcome_new_session_route_count = 0

func validation_outcome_new_session_confirmation_snapshot() -> Dictionary:
	var pending := _pending_outcome_new_session_confirmation.duplicate(true)
	var cancel_button := _new_session_confirmation_dialog.get_cancel_button()
	var dialog_viewport := cancel_button.get_viewport() if cancel_button != null else null
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	var root_viewport := get_viewport()
	var origin_focus_owner := root_viewport.gui_get_focus_owner() if root_viewport != null else null
	var current_session := SessionState.ensure_active_session()
	var current_identity := _outcome_new_session_identity(current_session)
	return {
		"pending": not pending.is_empty(),
		"dialog_visible": _new_session_confirmation_dialog.visible,
		"action_id": String(pending.get("action_id", "")),
		"action_label": String(pending.get("action_label", "")),
		"captured_action_id": String(pending.get("action_id", "")),
		"captured_action_label": String(pending.get("action_label", "")),
		"captured_session_id": String(pending.get("session_id", "")),
		"captured_scenario_id": String(pending.get("scenario_id", "")),
		"captured_scenario_status": String(pending.get("scenario_status", "")),
		"captured_launch_mode": String(pending.get("launch_mode", "")),
		"captured_day": int(pending.get("day", 0)),
		"captured_identity": {
			"session_id": String(pending.get("session_id", "")),
			"scenario_id": String(pending.get("scenario_id", "")),
			"scenario_status": String(pending.get("scenario_status", "")),
			"launch_mode": String(pending.get("launch_mode", "")),
			"day": int(pending.get("day", 0)),
		},
		"current_identity": current_identity,
		"title": _new_session_confirmation_dialog.title,
		"text": _new_session_confirmation_dialog.dialog_text,
		"confirm_text": _new_session_confirmation_dialog.get_ok_button().text,
		"cancel_text": cancel_button.text if cancel_button != null else "",
		"dialog_focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"return_focus_name": String(_outcome_new_session_return_focus.name) if is_instance_valid(_outcome_new_session_return_focus) else "",
		"origin_focus_owner": String(origin_focus_owner.name) if origin_focus_owner != null else "",
		"dialog_position": _new_session_confirmation_dialog.position,
		"dialog_size": _new_session_confirmation_dialog.size,
		"request_count": _validation_outcome_new_session_request_count,
		"duplicate_request_count": _validation_outcome_new_session_duplicate_request_count,
		"cancel_count": _validation_outcome_new_session_cancel_count,
		"confirm_count": _validation_outcome_new_session_confirm_count,
		"stale_count": _validation_outcome_new_session_stale_count,
		"perform_count": _validation_outcome_new_session_perform_count,
		"route_count": _validation_outcome_new_session_route_count,
		"route_suppressed": _validation_outcome_new_session_routing_suppressed,
		"routing_suppressed": _validation_outcome_new_session_routing_suppressed,
		"last_result": _last_outcome_new_session_confirmation_result.duplicate(true),
	}

func validation_set_outcome_focus_action_execution_suppressed(suppressed: bool) -> bool:
	_validation_outcome_focus_action_execution_suppressed = suppressed
	return _validation_outcome_focus_action_execution_suppressed == suppressed

func validation_reset_outcome_focus_state() -> Dictionary:
	_validation_outcome_focus_accept_count = 0
	_last_outcome_focus_accept_result = {}
	return validation_outcome_focus_snapshot()

func validation_refresh_outcome_focus() -> Dictionary:
	_refresh()
	return validation_outcome_focus_snapshot()

func validation_reset_outcome_recap_tab_navigation_state() -> Dictionary:
	_validation_outcome_recap_tab_resetting = true
	_recap_tabs.current_tab = 0
	_last_outcome_recap_tab_index = _recap_tabs.current_tab
	_validation_outcome_recap_tab_resetting = false
	_validation_outcome_recap_tab_change_sequence = 0
	_validation_outcome_recap_tab_change_count = 0
	_validation_outcome_recap_tab_focus_retention_count = 0
	_validation_outcome_recap_tab_boundary_retain_count = 0
	_last_outcome_recap_tab_change_result = {}
	_sync_outcome_recap_tab_tooltip()
	return validation_outcome_recap_tab_navigation_snapshot()

func validation_outcome_recap_tab_navigation_snapshot() -> Dictionary:
	var tab_bar := _recap_tabs.get_tab_bar()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var tab_titles: Array[String] = []
	for tab_index in range(_recap_tabs.get_tab_count()):
		tab_titles.append(_recap_tabs.get_tab_title(tab_index))
	return {
		"active_tab": _recap_tabs.current_tab,
		"tab_count": _recap_tabs.get_tab_count(),
		"tab_titles": tab_titles,
		"selected_tab_title": _recap_tabs.get_tab_title(_recap_tabs.current_tab) if _recap_tabs.current_tab >= 0 and _recap_tabs.current_tab < _recap_tabs.get_tab_count() else "",
		"tab_bar_name": String(tab_bar.name) if tab_bar != null else "",
		"tab_bar_focus_mode": tab_bar.focus_mode if tab_bar != null else Control.FOCUS_NONE,
		"tab_bar_boundary_policy": "retain",
		"tab_bar_has_focus": focus_owner == tab_bar,
		"tab_bar_focus_owner": String(focus_owner.name) if focus_owner == tab_bar else "",
		"tab_bar_tooltip": tab_bar.tooltip_text if tab_bar != null else "",
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"change_sequence": _validation_outcome_recap_tab_change_sequence,
		"change_count": _validation_outcome_recap_tab_change_count,
		"focus_retention_count": _validation_outcome_recap_tab_focus_retention_count,
		"boundary_retain_count": _validation_outcome_recap_tab_boundary_retain_count,
		"last_change_result": _last_outcome_recap_tab_change_result.duplicate(true),
		"focus_cycle_names": _last_outcome_focus_cycle_names.duplicate(),
		"focus_cycle_count": _last_outcome_focus_cycle_names.size(),
		"tab_bar_occurrences": _last_outcome_focus_tab_bar_occurrences,
	}

func validation_outcome_focus_snapshot() -> Dictionary:
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var enabled_action_ids: Array[String] = []
	var disabled_action_ids: Array[String] = []
	for child in _actions_bar.get_children():
		if not (child is Button):
			continue
		var action_id := String(child.get_meta("outcome_action_id", ""))
		if child.disabled:
			disabled_action_ids.append(action_id)
		else:
			enabled_action_ids.append(action_id)
	return {
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"focused_action_id": String(focus_owner.get_meta("outcome_action_id", "")) if focus_owner is Control else "",
		"focus_inside_outcome": focus_owner is Control and (focus_owner == self or is_ancestor_of(focus_owner)),
		"focus_has_visible_style": focus_owner is Control and focus_owner.get_theme_stylebox("focus") != null,
		"preferred_action_id": _last_outcome_focus_preferred_action_id,
		"primary_action_id": _primary_outcome_action_id(),
		"enabled_action_ids": enabled_action_ids,
		"disabled_action_ids": disabled_action_ids,
		"focus_cycle": _last_outcome_focus_cycle.duplicate(true),
		"accept_count": _validation_outcome_focus_accept_count,
		"last_accept_result": _last_outcome_focus_accept_result.duplicate(true),
		"action_execution_suppressed": _validation_outcome_focus_action_execution_suppressed,
		"recovery_pending": _outcome_recovery_pending,
		"manual_overwrite_visible": _manual_save_overwrite_dialog.visible,
		"save_button_name": String(_save_button.name),
		"menu_button_name": String(_menu_button.name),
		"guide_button_name": String(_guide_button.name),
	}

func validation_reset_outcome_recovery_state() -> void:
	_validation_outcome_recovery_request_count = 0
	_validation_outcome_recovery_retry_attempt_count = 0
	_validation_outcome_recovery_retry_failure_count = 0
	_validation_outcome_recovery_retry_success_count = 0
	_validation_outcome_recovery_blocked_action_count = 0
	_last_outcome_recovery_retry_result = {}

func validation_outcome_recovery_snapshot() -> Dictionary:
	var router_snapshot := _sync_outcome_recovery_state(false, true)
	return {
		"pending": _outcome_recovery_pending,
		"message": _last_action_message if _outcome_recovery_pending else "",
		"focus_owner": _outcome_recovery_focus_owner_name(),
		"entry_result": _outcome_recovery_entry_result.duplicate(true),
		"last_retry_result": _last_outcome_recovery_retry_result.duplicate(true),
		"request_count": _validation_outcome_recovery_request_count,
		"retry_attempt_count": _validation_outcome_recovery_retry_attempt_count,
		"retry_failure_count": _validation_outcome_recovery_retry_failure_count,
		"retry_success_count": _validation_outcome_recovery_retry_success_count,
		"blocked_action_count": _validation_outcome_recovery_blocked_action_count,
		"blocked_action_ids": _outcome_recovery_blocked_action_ids(),
		"router_snapshot": router_snapshot,
	}

func _outcome_recovery_focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func validation_request_manual_save() -> Dictionary:
	_on_save_pressed(true)
	return _manual_save_overwrite_dialog.validation_snapshot()

func validation_confirm_manual_save_overwrite() -> Dictionary:
	var pending_slot := int(_manual_save_overwrite_dialog.validation_snapshot().get("pending_slot", 0))
	_on_manual_save_overwrite_confirmed()
	return {
		"pending_slot": pending_slot,
		"summary": SaveService.inspect_manual_slot(pending_slot) if SaveService.get_manual_slot_ids().has(pending_slot) else {},
		"message": _last_action_message,
	}

func validation_cancel_manual_save_overwrite() -> void:
	_on_manual_save_overwrite_canceled()

func validation_perform_action(action_id: String) -> Dictionary:
	var expected_route := "stay"
	var found := false
	var actions = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary and String(action.get("id", "")) == action_id:
				found = true
				if bool(action.get("disabled", false)):
					return {"ok": false, "action_id": action_id, "message": "Outcome action is disabled."}
				if action_id == "return_to_menu":
					expected_route = "main_menu"
				elif action_id.begins_with("campaign_start:") or action_id.begins_with("skirmish_start:"):
					expected_route = "overworld"
				break
	if not found:
		return {"ok": false, "action_id": action_id, "message": "Outcome action is not available."}
	var source_scenario_id := _session.scenario_id
	var source_scenario_status := _session.scenario_status
	var result := _perform_outcome_action(action_id)
	var active_session := SessionState.ensure_active_session()
	var result_route := String(result.get("route", "stay"))
	return {
		"ok": bool(result.get("ok", false)) and result_route == expected_route,
		"action_id": action_id,
		"expected_route": expected_route,
		"route": result_route,
		"action_result": result.duplicate(true),
		"source_scenario_id": source_scenario_id,
		"source_scenario_status": source_scenario_status,
		"active_scenario_id": active_session.scenario_id,
		"active_scenario_status": active_session.scenario_status,
		"active_game_state": active_session.game_state,
		"active_resume_target": SaveService.resume_target_for_session(active_session),
		"active_battle_empty": active_session.battle.is_empty(),
		"message": _last_action_message,
	}

func validation_return_to_menu() -> Dictionary:
	return _on_menu_pressed()

func validation_active_play_return_snapshot() -> Dictionary:
	return {
		"last_result": _last_return_to_menu_result.duplicate(true),
		"visible_message": _last_action_message,
		"focus_owner": _return_to_menu_focus_owner_name(),
		"request_count": _validation_return_to_menu_request_count,
		"scenario_id": _session.scenario_id,
		"resume_target": SaveService.resume_target_for_session(_session),
	}

func _return_to_menu_focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func validation_open_outcome_guide() -> void:
	if not _guide_panel.visible:
		_on_guide_pressed()

func validation_close_outcome_guide() -> void:
	if _guide_panel.visible:
		_on_guide_pressed()

func _result_status_label(status: String) -> String:
	var normalized := status.replace("_", " ").strip_edges()
	if normalized == "":
		return "OUTCOME"
	return normalized.to_upper()

func _apply_result_palette(status: String) -> void:
	var backdrop_color := Color(0.07, 0.08, 0.10, 1.0)
	var accent := Color(0.84, 0.74, 0.47, 1.0)
	match status:
		"victory":
			backdrop_color = Color(0.05, 0.09, 0.10, 1.0)
			accent = Color(0.87, 0.74, 0.38, 1.0)
		"defeat":
			backdrop_color = Color(0.11, 0.05, 0.07, 1.0)
			accent = Color(0.88, 0.48, 0.35, 1.0)
		_:
			backdrop_color = Color(0.08, 0.08, 0.11, 1.0)
			accent = Color(0.80, 0.74, 0.52, 1.0)

	if _backdrop.has_method("set_fallback_color"):
		_backdrop.call("set_fallback_color", backdrop_color)
	_header_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 1.0))
	FrontierVisualKit.apply_label(_summary_label, "body", 14)
	_mode_label.add_theme_color_override("font_color", accent.lightened(0.08))
	_action_status_label.add_theme_color_override("font_color", accent)
	_result_badge_label.add_theme_color_override("font_color", accent)
	if _result_glyph.has_method("set_glyph"):
		_result_glyph.call("set_glyph", "outcome", accent)

	var badge_style := FrontierVisualKit.badge_style("gold")
	badge_style.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.95)
	badge_style.border_color = accent
	_result_badge_panel.add_theme_stylebox_override("panel", badge_style)


func _sync_scenic_epilogue(status: String) -> void:
	if _backdrop.has_method("set_outcome"):
		_backdrop.call("set_outcome", status)

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 96) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars)

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _outcome_return_cue_text(surface: Dictionary) -> String:
	var return_handoff := String(surface.get("return_handoff", "")).strip_edges()
	if return_handoff.find("Editor restores") >= 0:
		return "Return cue: Editor restores the Play Copy launch snapshot."
	if SaveService.resume_target_for_session(_session) == "outcome":
		return "Return cue: Menu autosaves this outcome; Continue Latest reviews it later."
	if return_handoff != "":
		return return_handoff.replace("Return handoff:", "Return cue:")
	return "Return cue: Menu refreshes autosave before opening the main menu."

func _outcome_resolution_handoff_text() -> String:
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var primary_label := _primary_outcome_action_label()
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
		if primary_label != "" and primary_label != "Return to Menu":
			return "Outcome handoff: %s recorded; %s is the primary follow-up for this result path, while Return to Menu keeps outcome review resumable." % [
				status_text.capitalize(),
				primary_label,
			]
		return "Outcome handoff: %s recorded; Return to Menu keeps this campaign result available from Continue Latest." % status_text.capitalize()
	if primary_label != "" and primary_label != "Return to Menu":
		return "Outcome handoff: %s recorded; %s is the primary follow-up and starts fresh, while Return to Menu keeps this outcome resumable." % [
			status_text.capitalize(),
			primary_label,
		]
	return "Outcome handoff: %s recorded; Return to Menu keeps this outcome resumable from Continue Latest." % status_text.capitalize()

func _outcome_follow_up_check(surface: Dictionary = {}) -> Dictionary:
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var status_label := status_text.capitalize()
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	var primary_label := _primary_outcome_action_label()
	var primary_action_id := _primary_outcome_action_id()
	if primary_label == "":
		primary_label = "Return to Menu"
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var return_line := _outcome_return_cue_text(surface)
	var primary_effect := _outcome_primary_follow_up_effect(primary_action_id, primary_label, launch_mode)
	var save_effect := "%s keeps this review available from the selected manual slot." % save_label
	var return_effect := "Return to Menu keeps Continue Latest pointed at this outcome review."
	if return_line != "":
		return_effect = return_line.replace("Return cue:", "").strip_edges()
	var visible := "Follow-up check: %s | %s | Return keeps review" % [
		primary_label,
		"save first" if primary_action_id != "return_to_menu" else "menu route",
	]
	var tooltip := "Outcome Follow-up Check\n- Result: %s recorded.\n- Primary follow-up: %s.\n- Save first: %s\n- Return: %s\n- State change: pressing a follow-up starts fresh play or routes to the menu; it does not rewrite the resolved result.\n- Inspection: reading this check does not save, route, or change campaign progression." % [
		status_label,
		primary_effect,
		save_effect,
		return_effect,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"primary_label": primary_label,
		"primary_action_id": primary_action_id,
		"save_label": save_label,
		"return_effect": return_effect,
	}

func _outcome_slot_check(surface: Dictionary = {}, summary_override: Dictionary = {}) -> Dictionary:
	var selected_slot := int(surface.get("selected_slot", SaveService.get_selected_manual_slot()))
	var summary := summary_override
	if summary.is_empty():
		var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
		summary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var current_context := String(surface.get("current_context", "")).strip_edges()
	if current_context == "":
		current_context = "this outcome review"
	var slot_label := "Manual %d" % selected_slot
	var slot_state := "empty slot"
	var overwrite_line := "Save Outcome writes %s into %s." % [current_context, slot_label]
	var existing_resume := SaveService.describe_resume_brief(summary)
	if SaveService.can_load_summary(summary):
		slot_state = "will overwrite %s" % SaveService.describe_resume_brief(summary)
		overwrite_line = "%s replaces the selected %s snapshot with %s." % [
			save_label,
			slot_label,
			current_context,
		]
	elif String(summary.get("validity", "")) == "missing":
		slot_state = "empty slot"
		overwrite_line = "%s writes %s into empty %s." % [save_label, current_context, slot_label]
	elif not summary.is_empty() and String(summary.get("status_text", "")).strip_edges() != "":
		slot_state = "blocked slot: %s" % String(summary.get("status_text", "")).strip_edges()
		overwrite_line = "%s attempts to write a fresh outcome snapshot into %s." % [save_label, slot_label]
	if existing_resume == "":
		existing_resume = String(summary.get("status_text", "No save selected."))
	var visible := "Slot check: %s | %s" % [slot_label, slot_state]
	var tooltip := "Outcome Slot Check\n- Selected slot: %s.\n- Current slot: %s\n- Saving now: %s\n- Resume after save: Continue Latest and Load Selected can review this outcome from the saved slot.\n- Scope: changing the slot selection or reading this check does not save, route, or change campaign progression." % [
		slot_label,
		existing_resume,
		overwrite_line,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"selected_slot": selected_slot,
		"slot_state": slot_state,
		"current_slot": existing_resume,
		"save_effect": overwrite_line,
	}

func _outcome_save_check(surface: Dictionary = {}, summary_override: Dictionary = {}) -> Dictionary:
	var selected_slot := int(surface.get("selected_slot", SaveService.get_selected_manual_slot()))
	var summary := summary_override
	if summary.is_empty():
		var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
		summary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var current_context := String(surface.get("current_context", "")).strip_edges()
	if current_context == "":
		current_context = "this outcome review"
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var status_label := status_text.capitalize()
	var slot_label := "Manual %d" % selected_slot
	var resume_line := "Continue Latest and Load Selected can review this outcome from %s after saving." % slot_label
	var slot_check := _outcome_slot_check(surface, summary)
	var save_effect := String(slot_check.get("save_effect", "")).strip_edges()
	if save_effect == "":
		save_effect = "%s writes %s into %s." % [save_label, current_context, slot_label]
	var primary_label := _primary_outcome_action_label()
	if primary_label == "":
		primary_label = "Return to Menu"
	var visible := "Outcome save check: %s -> %s | review preserved" % [
		save_label,
		slot_label,
	]
	var tooltip := "Outcome Save Check\n- Result: %s recorded.\n- Save target: %s.\n- Save action: %s\n- Resume after save: %s\n- Follow-up boundary: saving does not start %s or route to the menu.\n- Scope: pressing %s writes the selected manual slot; reading this check does not save, route, or change campaign progression." % [
		status_label,
		slot_label,
		save_effect,
		resume_line,
		primary_label,
		save_label,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"selected_slot": selected_slot,
		"save_label": save_label,
		"save_target": slot_label,
		"save_effect": save_effect,
		"resume_after_save": resume_line,
		"primary_follow_up": primary_label,
	}

func _outcome_carryover_check(surface: Dictionary = {}) -> Dictionary:
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var status_label := status_text.capitalize()
	var carryover_summary := String(_model.get("carryover_summary", "")).strip_edges()
	if carryover_summary == "":
		carryover_summary = "No carryover summary is available for this result."
	var primary_label := _primary_outcome_action_label()
	var primary_action_id := _primary_outcome_action_id()
	if primary_label == "":
		primary_label = "Return to Menu"
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var selected_slot := int(surface.get("selected_slot", SaveService.get_selected_manual_slot()))
	var mode_label := ScenarioSelectRulesScript.launch_mode_label(launch_mode)
	var visible := "Carryover check: %s | no campaign export" % mode_label
	var replay_line := "Fresh skirmish starts do not import or export campaign carryover."
	var next_line := _outcome_primary_follow_up_effect(primary_action_id, primary_label, launch_mode)
	if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
		visible = "Carryover check: Campaign export | %s" % (
			"next chapter ready" if primary_action_id.begins_with("campaign_start:") else "review saved"
		)
		replay_line = "Replay or next-chapter choices start fresh play from recorded campaign progress; this review stays available until another autosave replaces it."
	elif primary_action_id.begins_with("skirmish_start:"):
		visible = "Carryover check: Skirmish result | retry starts fresh"
	var tooltip := "Outcome Carryover Check\n- Result: %s recorded in %s mode.\n- Carryover: %s\n- Next follow-up: %s\n- Replay/new run: %s\n- Manual save: %s can preserve this result review in Manual %d before leaving.\n- Scope: reading this check does not save, route, or change campaign progression." % [
		status_label,
		mode_label,
		carryover_summary,
		next_line,
		replay_line,
		save_label,
		selected_slot,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"mode": launch_mode,
		"primary_action_id": primary_action_id,
		"primary_label": primary_label,
		"carryover_summary": carryover_summary,
		"next_follow_up": next_line,
		"replay_line": replay_line,
	}

func _outcome_retry_check(surface: Dictionary = {}) -> Dictionary:
	var retry_action := _retry_or_replay_outcome_action()
	if retry_action.is_empty():
		return {
			"visible_text": "Retry check: no fresh retry or replay action is available.",
			"tooltip_text": "Outcome Retry Check\n- Action: unavailable for this result.\n- Save first: Save Outcome can still preserve this review in the selected manual slot.\n- Scope: reading this check does not save, route, restart play, or change campaign progression.",
		}
	var action_id := String(retry_action.get("id", ""))
	var label := String(retry_action.get("label", "Retry")).strip_edges()
	if label == "":
		label = "Retry"
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	var mode_label := ScenarioSelectRulesScript.launch_mode_label(launch_mode)
	var selected_slot := int(surface.get("selected_slot", SaveService.get_selected_manual_slot()))
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var fresh_start := _retry_action_start_line(action_id, label, launch_mode)
	var preservation := "current campaign record stays as recorded" if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN else "campaign progression stays unchanged"
	var visible := "Retry check: %s starts fresh | save keeps review" % label
	var tooltip := "Outcome Retry Check\n- Action: %s.\n- Fresh start: %s\n- Preservation: %s; the resolved outcome review stays resumable only if autosave or a manual slot keeps it.\n- Save first: %s can preserve this review in Manual %d before pressing %s.\n- State change: pressing %s starts a fresh %s run; reading this check does not save, route, restart play, or change campaign progression." % [
		label,
		fresh_start,
		preservation,
		save_label,
		selected_slot,
		label,
		label,
		mode_label,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"action_id": action_id,
		"action_label": label,
		"fresh_start": fresh_start,
		"preservation": preservation,
		"selected_slot": selected_slot,
	}

func _primary_outcome_action_label() -> String:
	var actions = _model.get("actions", [])
	if not (actions is Array):
		return ""
	for action in actions:
		if action is Dictionary and not _outcome_action_effectively_disabled(action):
			var action_id := String(action.get("id", ""))
			if action_id != "" and action_id != "return_to_menu":
				return String(action.get("label", action_id)).strip_edges()
	for action in actions:
		if action is Dictionary and not _outcome_action_effectively_disabled(action):
			var label := String(action.get("label", action.get("id", ""))).strip_edges()
			if label != "":
				return label
	return ""

func _retry_or_replay_outcome_action() -> Dictionary:
	var actions = _model.get("actions", [])
	if not (actions is Array):
		return {}
	var same_scenario_action := {}
	var first_fresh_action := {}
	for action in actions:
		if not (action is Dictionary) or _outcome_action_effectively_disabled(action):
			continue
		var action_id := String(action.get("id", ""))
		if not (action_id.begins_with("campaign_start:") or action_id.begins_with("skirmish_start:")):
			continue
		if first_fresh_action.is_empty():
			first_fresh_action = action
		var target_scenario_id := action_id.trim_prefix("campaign_start:").trim_prefix("skirmish_start:")
		if target_scenario_id == _session.scenario_id:
			same_scenario_action = action
			break
	return same_scenario_action if not same_scenario_action.is_empty() else first_fresh_action

func _primary_outcome_action_id() -> String:
	var actions = _model.get("actions", [])
	if not (actions is Array):
		return ""
	for action in actions:
		if action is Dictionary and not _outcome_action_effectively_disabled(action):
			var action_id := String(action.get("id", ""))
			if action_id != "" and action_id != "return_to_menu":
				return action_id
	for action in actions:
		if action is Dictionary and not _outcome_action_effectively_disabled(action):
			return String(action.get("id", ""))
	return ""

func _outcome_primary_follow_up_effect(action_id: String, label: String, launch_mode: String) -> String:
	if action_id.begins_with("campaign_start:"):
		if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
			return "%s starts a fresh campaign chapter from recorded campaign progress" % label
		return "%s starts a fresh campaign expedition" % label
	if action_id.begins_with("skirmish_start:"):
		return "%s starts a fresh skirmish expedition" % label
	if action_id == "" or action_id == "return_to_menu":
		return "%s opens the menu and keeps the outcome review resumable" % label
	return "%s follows the resolved outcome action" % label

func _retry_action_start_line(action_id: String, label: String, launch_mode: String) -> String:
	if action_id.begins_with("campaign_start:"):
		var target_scenario_id := action_id.trim_prefix("campaign_start:")
		if target_scenario_id == _session.scenario_id:
			if _session.scenario_status == "victory":
				return "%s replays this chapter from its authored opening state at current difficulty." % label
			return "%s retries this chapter from its authored opening state at current difficulty." % label
		if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
			return "%s starts the next campaign chapter from recorded campaign progress at current difficulty." % label
		return "%s starts a fresh campaign expedition at current difficulty." % label
	if action_id.begins_with("skirmish_start:"):
		return "%s starts this skirmish from Day 1 at current difficulty." % label
	return "%s starts fresh play from this outcome action." % label

func _outcome_action_tooltip(action: Dictionary) -> String:
	var follow_up_check := _outcome_follow_up_check(AppRouter.active_save_surface())
	var retry_check := _outcome_retry_check(AppRouter.active_save_surface())
	return _join_tooltip_sections([
		String(action.get("summary", "")),
		String(follow_up_check.get("tooltip_text", "")),
		String(retry_check.get("tooltip_text", "")),
		_outcome_resolution_handoff_text(),
		String(_model.get("post_result_handoff_summary", "")),
	])

func _outcome_action_tooltip_snapshot() -> Array:
	var tooltips := []
	for child in _actions_bar.get_children():
		if child is Button:
			tooltips.append({
				"label": String((child as Button).text),
				"tooltip": String((child as Button).tooltip_text),
			})
	return tooltips

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_confirmation_dialog(_new_session_confirmation_dialog, "danger")
	FrontierVisualKit.apply_confirmation_dialog(_manual_save_overwrite_dialog as ConfirmationDialog, "danger")
	var panel_tones := {
		"Banner": "banner",
		"BannerArtPanel": "earth",
		"ActionStatusPanel": "earth",
		"HeroPanel": "teal",
		"ArmyPanel": "earth",
		"ResourcePanel": "gold",
		"ProgressionPanel": "ink",
		"AftermathPanel": "earth",
		"CampaignArcPanel": "ink",
		"CarryoverPanel": "teal",
		"JournalPanel": "ink",
		"SavePanel": "ink",
		"ActionsPanel": "gold",
	}
	for panel in find_children("*", "PanelContainer", true, false):
		if panel is PanelContainer:
			FrontierVisualKit.apply_panel(panel, String(panel_tones.get(panel.name, "ink")))
			if OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME.has(panel.name):
				panel.self_modulate = Color(1.0, 1.0, 1.0, float(OUTCOME_SCENIC_PANEL_ALPHA_BY_NAME[panel.name]))

	FrontierVisualKit.apply_tab_container(_recap_tabs)
	_apply_outcome_recap_tab_breathing_room()
	_recap_tabs.set_tab_title(0, "Progress")
	_recap_tabs.set_tab_title(1, "Arc")
	_recap_tabs.set_tab_title(2, "Carry")
	_recap_tabs.set_tab_title(3, "After")
	_recap_tabs.set_tab_title(4, "Journal")

	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 132.0, 34.0, 13)
	FrontierVisualKit.apply_button(_save_button, "primary", 126.0, 34.0, 13)
	FrontierVisualKit.apply_button(_menu_button, "secondary", 138.0, 34.0, 13)
	FrontierVisualKit.apply_button(_recap_details_button, "secondary", 96.0, 34.0, 13)
	FrontierVisualKit.apply_button(_guide_button, "secondary", 96.0, 34.0, 13)
	FrontierVisualKit.apply_clear_panel($ContentMargin/Content/MainRow/CommandColumn/ForceCards/HeroPanel)
	FrontierVisualKit.apply_clear_panel($ContentMargin/Content/MainRow/CommandColumn/ForceCards/ArmyPanel)
	FrontierVisualKit.apply_clear_panel($ContentMargin/Content/MainRow/CommandColumn/ForceCards/ResourcePanel)
	FrontierVisualKit.apply_clear_panel($ContentMargin/Content/MainRow/SidebarShell/SidebarPad/SidebarBox/SavePanel)
	FrontierVisualKit.apply_clear_panel(_banner)
	FrontierVisualKit.apply_clear_panel(_actions_panel)
	FrontierVisualKit.apply_clear_panel(_sidebar_shell)

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body")

	for label_name in ["HeroTitle", "ArmyTitle", "ResourceTitle", "ProgressionTitle", "AftermathTitle", "CampaignArcTitle", "CarryoverTitle", "JournalTitle", "SaveTitle", "ActionsTitle", "GuideTitle"]:
		for title_label in find_children(label_name, "Label", true, false):
			if title_label is Label:
				FrontierVisualKit.apply_label(title_label, "title", 14)
	FrontierVisualKit.apply_label(_header_label, "title", 24)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)
	FrontierVisualKit.apply_label(_return_cue_label, "muted", 12)

func _apply_outcome_recap_tab_breathing_room() -> void:
	for style_name in OUTCOME_RECAP_TAB_STATE_STYLES:
		var shared_style := _recap_tabs.get_theme_stylebox(style_name)
		var outcome_style := shared_style.duplicate() as StyleBox
		outcome_style.content_margin_left = OUTCOME_RECAP_TAB_CONTENT_MARGIN_HORIZONTAL
		outcome_style.content_margin_right = OUTCOME_RECAP_TAB_CONTENT_MARGIN_HORIZONTAL
		_recap_tabs.add_theme_stylebox_override(style_name, outcome_style)

func _refresh_guide_surface() -> void:
	if _guide_button == null or _guide_label == null or _guide_panel == null:
		return
	_guide_button.text = "Hide Guide" if _guide_panel.visible else "Guide"
	_guide_button.tooltip_text = (
		"Hide the outcome Field Manual without saving, loading, routing, or changing campaign progression."
		if _guide_panel.visible
		else "Open the outcome Field Manual. This does not save, load, route, or change campaign progression."
	)
	var guide_text := _build_outcome_guide_text()
	_set_compact_label(_guide_label, guide_text, 8, 92)

func _build_outcome_guide_text() -> String:
	var lines := [SettingsService.describe_help_topic("outcome")]
	var continuity_choice := String(_model.get("continuity_choice_summary", "")).strip_edges()
	var next_play_action := String(_model.get("next_play_action_summary", "")).strip_edges()
	var action_cue := String(_model.get("action_cue_summary", "")).strip_edges()
	var post_result_handoff := String(_model.get("post_result_handoff_summary", "")).strip_edges()
	var resolution_handoff := _outcome_resolution_handoff_text()
	var save_surface := AppRouter.active_save_surface()
	var follow_up_check := _outcome_follow_up_check(save_surface)
	var retry_check := _outcome_retry_check(save_surface)
	var carryover_check := _outcome_carryover_check(save_surface)
	var slot_check := _outcome_slot_check(save_surface)
	var outcome_save_check := _outcome_save_check(save_surface)
	var save_check := String(save_surface.get("save_check", "")).strip_edges()
	var play_check := String(save_surface.get("play_check", "")).strip_edges()
	var return_handoff := String(save_surface.get("return_handoff", "")).strip_edges()
	if continuity_choice != "":
		lines.append(continuity_choice)
	if next_play_action != "":
		lines.append(next_play_action)
	if String(follow_up_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(follow_up_check.get("tooltip_text", "")).strip_edges())
	if String(retry_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(retry_check.get("tooltip_text", "")).strip_edges())
	if String(carryover_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(carryover_check.get("tooltip_text", "")).strip_edges())
	if String(slot_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(slot_check.get("tooltip_text", "")).strip_edges())
	if String(outcome_save_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(outcome_save_check.get("tooltip_text", "")).strip_edges())
	if resolution_handoff != "":
		lines.append(resolution_handoff)
	if post_result_handoff != "":
		lines.append(post_result_handoff)
	if action_cue != "":
		lines.append(action_cue)
	if save_check != "":
		lines.append(save_check)
	if play_check != "":
		lines.append(play_check)
	if return_handoff != "":
		lines.append(return_handoff)
	lines.append("Guide handoff: this panel is informational; close it to keep choosing from the same outcome actions.")
	return "\n".join(lines)
