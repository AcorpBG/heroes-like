extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SystemSaveWrittenCuePresenterScript = preload("res://scenes/shared/SystemSaveWrittenCuePresenter.gd")
const SystemLoadResumedCuePresenterScript = preload("res://scenes/shared/SystemLoadResumedCuePresenter.gd")

const UI_ART_BATTLE_INITIATIVE_BAR := "res://art/ui/runtime/battle/initiative_bar.png"
const UI_ART_BATTLE_COMBAT_LOG_PANEL := "res://art/ui/runtime/battle/combat_log_panel.png"
const UI_ART_BATTLE_UNIT_CARD := "res://art/ui/runtime/battle/unit_card.png"
const UI_ART_BATTLE_FOOTER_PANEL := "res://art/ui/runtime/battle/battle_footer_panel.png"
const RETURN_TO_MENU_FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."
const BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE := "Battle resolved, but autosave failed. Press Save to retry the checkpoint."
const BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE := "Briefing shown, but autosave failed. Press Save to protect this checkpoint."
const BATTLE_PLAYBACK_SPEED_SAVE_FAILURE_MESSAGE := "Playback speed not saved. Previous speed restored."
const BATTLE_ORDER_VISIBLE_LINE_COUNT := 3
const BATTLE_ORDER_VISIBLE_STACK_CHAR_LIMIT := 18
const BATTLE_INFO_TAB_VISIBLE_TITLES := ["Order", "Focus", "Spell", "Timing"]
const BATTLE_FOCUS_VISIBLE_NAME_CHAR_LIMIT := 14
const BATTLE_FOCUS_VISIBLE_ORDER_CHAR_LIMIT := 16
const BATTLE_SPELL_VISIBLE_NAME_CHAR_LIMIT := 16

@onready var _banner_panel: PanelContainer = %Banner
@onready var _briefing_panel: PanelContainer = %BriefingPanel
@onready var _risk_panel: PanelContainer = %RiskPanel
@onready var _consequence_panel: PanelContainer = %ConsequencePanel
@onready var _battlefield_panel: PanelContainer = %BattlefieldPanel
@onready var _battlefield_frame_panel: PanelContainer = %BattlefieldFrame
@onready var _sidebar_shell_panel: PanelContainer = %SidebarShell
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _battle_tabs: TabContainer = %BattleTabs
@onready var _initiative_panel: PanelContainer = %InitiativePanel
@onready var _context_panel: PanelContainer = %ContextPanel
@onready var _spell_panel: PanelContainer = %SpellPanel
@onready var _timing_panel: PanelContainer = %TimingPanel
@onready var _player_panel: PanelContainer = %PlayerPanel
@onready var _enemy_panel: PanelContainer = %EnemyPanel
@onready var _footer_panel: PanelContainer = %Footer
@onready var _footer_row: GridContainer = %FooterRow
@onready var _action_panel: PanelContainer = %ActionPanel
@onready var _action_pad: MarginContainer = %ActionPad
@onready var _system_panel: PanelContainer = %SystemPanel
@onready var _system_pad: MarginContainer = %SystemPad
@onready var _speed_bar: HBoxContainer = %SpeedBar
@onready var _header_label: Label = %Header
@onready var _status_label: Label = %Status
@onready var _pressure_label: Label = %Pressure
@onready var _event_label: Label = %Event
@onready var _battle_context_label: Label = %BattleContext
@onready var _briefing_label: Label = %Briefing
@onready var _risk_label: Label = %Risk
@onready var _consequence_label: Label = %Consequence
@onready var _battle_board_view = %BattleBoard
@onready var _player_commander_portrait: HeroPortraitView = %PlayerCommanderPortrait
@onready var _player_command_label: Label = %PlayerCommand
@onready var _enemy_commander_portrait: HeroPortraitView = %EnemyCommanderPortrait
@onready var _enemy_command_label: Label = %EnemyCommand
@onready var _initiative_label: Label = %Initiative
@onready var _active_label: Label = %Active
@onready var _target_label: Label = %Target
@onready var _spell_label: Label = %Spellbook
@onready var _effect_label: Label = %Effects
@onready var _timing_label: Label = %Timing
@onready var _player_roster: Label = %PlayerRoster
@onready var _enemy_roster: Label = %EnemyRoster
@onready var _action_guide: Label = %ActionGuide
@onready var _spell_actions: HFlowContainer = %SpellActions
@onready var _prev_target_button: Button = %PrevTarget
@onready var _next_target_button: Button = %NextTarget
@onready var _advance_button: Button = %Advance
@onready var _strike_button: Button = %Strike
@onready var _shoot_button: Button = %Shoot
@onready var _defend_button: Button = %Defend
@onready var _quick_resolve_button: Button = %QuickResolve
@onready var _retreat_button: Button = %Retreat
@onready var _surrender_button: Button = %Surrender
@onready var _speed_normal_button: Button = %SpeedNormal
@onready var _speed_fast_button: Button = %SpeedFast
@onready var _speed_instant_button: Button = %SpeedInstant
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _system_body_label: Label = %SystemBody
@onready var _settings_button: Button = %Settings
@onready var _menu_button: Button = %Menu
@onready var _quick_resolve_confirmation_dialog: ConfirmationDialog = $QuickResolveConfirmationDialog
@onready var _withdrawal_confirmation_dialog: ConfirmationDialog = $WithdrawalConfirmationDialog
@onready var _manual_save_overwrite_dialog = $ManualSaveOverwriteDialog
@onready var _active_play_settings_dialog = %ActivePlaySettingsDialog

var _session: SessionStateStore.SessionData
var _last_message := ""
var _last_return_to_menu_result: Dictionary = {}
var _validation_return_to_menu_request_count := 0
var _tactical_briefing_text := ""
var _validation_spell_casts := 0
var _validation_max_spell_casts := 1
var _validation_prioritize_support_spell := false
var _validation_spell_casting_enabled := true
var _validation_battle_resolution_routing_enabled := true
var _last_action_recap_payload := {}
var _last_action_recap_text := ""
var _battle_exit_handoff_in_progress := false
var _battle_presentation_stream_text := ""
var _pending_withdrawal_action := ""
var _withdrawal_focus_origin: Button = null
var _last_withdrawal_confirmation_result := {}
var _validation_perform_action_counts := {}
var _validation_battle_resolution_attempt_count := 0
var _validation_last_battle_resolution_route := {}
var _battle_resolution_checkpoint_pending := {}
var _last_battle_resolution_checkpoint_result := {}
var _last_battle_resolution_checkpoint_retry_result := {}
var _last_battle_resolution_route_result := {}
var _last_battle_resolution_routed := false
var _validation_battle_resolution_checkpoint_request_count := 0
var _validation_battle_resolution_checkpoint_success_count := 0
var _validation_battle_resolution_checkpoint_failure_count := 0
var _validation_battle_resolution_checkpoint_retry_count := 0
var _validation_battle_resolution_durable_route_count := 0
var _briefing_consumption_autosave_failure_pending := false
var _last_briefing_consumption_autosave_result := {}
var _last_briefing_consumption_runtime_issue := {}
var _validation_briefing_consumption_save_attempt_count := 0
var _validation_briefing_consumption_save_success_count := 0
var _validation_briefing_consumption_save_failure_count := 0
var _last_battle_playback_speed_result := {}
var _validation_battle_playback_speed_request_count := 0
var _validation_battle_playback_speed_success_count := 0
var _validation_battle_playback_speed_failure_count := 0
var _quick_resolve_confirmation_pending := false
var _quick_resolve_confirmation_focus_origin: Button = null
var _forwarding_confirmation_root_physical_input := false
var _last_quick_resolve_confirmation_result := {}
var _validation_quick_resolve_confirmation_request_count := 0
var _validation_quick_resolve_confirmation_cancel_count := 0
var _validation_quick_resolve_confirmation_confirm_count := 0
var _validation_quick_resolve_confirmation_perform_count := 0
var _last_battle_info_tab_index := 0
var _validation_battle_info_tab_change_sequence := 0
var _validation_battle_info_tab_change_count := 0
var _validation_battle_info_tab_focus_retention_count := 0
var _validation_battle_info_tab_boundary_retain_count := 0
var _last_battle_info_tab_change_result: Dictionary = {}
var _last_battle_keyboard_focus_cycle_names := []
var _last_battle_keyboard_focus_tab_bar_occurrences := 0
var _validation_battle_info_tab_resetting := false
var _save_written_cue_presenter: SystemSaveWrittenCuePresenter
var _load_resumed_cue_presenter: SystemLoadResumedCuePresenter
var _compact_layout_active := false
var _compact_system_panel_style := StyleBoxEmpty.new()
var _action_guide_source_text := ""

func _ready() -> void:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var phase_started := ProfileLogScript.begin_usec()
	_apply_visual_theme()
	_save_written_cue_presenter = SystemSaveWrittenCuePresenterScript.new()
	_save_written_cue_presenter.name = "SystemSaveWrittenCuePresenter"
	add_child(_save_written_cue_presenter)
	_save_written_cue_presenter.configure(_save_button, _system_body_label, "battle")
	_load_resumed_cue_presenter = SystemLoadResumedCuePresenterScript.new()
	_load_resumed_cue_presenter.name = "SystemLoadResumedCuePresenter"
	add_child(_load_resumed_cue_presenter)
	_load_resumed_cue_presenter.configure(_system_body_label, _save_button, "battle")
	_configure_quick_resolve_confirmation()
	_configure_withdrawal_confirmation()
	_configure_confirmation_input_forwarding()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	buckets["theme"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	if _battle_board_view.has_signal("stack_focus_requested"):
		_battle_board_view.stack_focus_requested.connect(_on_board_stack_focus_requested)
	if _battle_board_view.has_signal("hex_destination_requested"):
		_battle_board_view.hex_destination_requested.connect(_on_board_hex_destination_requested)
	if _battle_board_view.has_signal("controller_navigation_cancelled"):
		_battle_board_view.controller_navigation_cancelled.connect(_on_board_controller_navigation_cancelled)
	buckets["connect_board_signals"] = ProfileLogScript.elapsed_ms(phase_started)
	_battle_tabs.current_tab = 0
	_last_battle_info_tab_index = _battle_tabs.current_tab
	_configure_battle_info_tab_accessibility()
	if not _battle_tabs.tab_changed.is_connected(_on_battle_info_tab_changed):
		_battle_tabs.tab_changed.connect(_on_battle_info_tab_changed)
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter battle without an active scenario session.")
		AppRouter.go_to_main_menu()
		return
	if _session.battle.is_empty():
		push_warning("Cannot enter battle without a battle payload.")
		AppRouter.go_to_overworld()
		return

	phase_started = ProfileLogScript.begin_usec()
	OverworldRules.normalize_overworld_state(_session)
	buckets["normalize_overworld"] = ProfileLogScript.elapsed_ms(phase_started)
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return
	phase_started = ProfileLogScript.begin_usec()
	if not BattleRules.normalize_battle_state(_session):
		push_warning("Battle payload could not be normalized.")
		AppRouter.go_to_overworld()
		return
	BattleRules.set_battle_presentation_speed(_session, SettingsService.battle_playback_speed_id())
	buckets["normalize_battle"] = ProfileLogScript.elapsed_ms(phase_started)
	_session.game_state = "battle"
	phase_started = ProfileLogScript.begin_usec()
	_configure_save_slot_picker()
	buckets["configure_save_surface"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	MusicAudio.sync_context("battle", "battle_shell_ready", _battle_music_metadata())
	buckets["music_audio"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	var initial_result := BattleRules.resolve_if_battle_ready(_session)
	buckets["resolve_ready"] = ProfileLogScript.elapsed_ms(phase_started)
	_last_message = String(initial_result.get("message", ""))
	if _handle_battle_resolution(initial_result):
		return
	phase_started = ProfileLogScript.begin_usec()
	_tactical_briefing_text = BattleRules.consume_tactical_briefing(_session)
	buckets["consume_payload_briefing"] = ProfileLogScript.elapsed_ms(phase_started)
	if _tactical_briefing_text != "":
		phase_started = ProfileLogScript.begin_usec()
		_checkpoint_consumed_tactical_briefing()
		buckets["briefing_autosave"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_refresh()
	_present_load_resumed_cue()
	buckets["first_refresh"] = ProfileLogScript.elapsed_ms(phase_started)
	ProfileLogScript.emit_general("battle", "entry", "battle_ready", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(true), _session)
	call_deferred("_configure_battle_keyboard_focus", true)

func _configure_quick_resolve_confirmation() -> void:
	_quick_resolve_confirmation_dialog.get_cancel_button().text = "Keep Fighting"
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	_quick_resolve_confirmation_dialog.get_cancel_button().shortcut = cancel_shortcut
	var dialog_label := _quick_resolve_confirmation_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(620.0, 0.0)

func _configure_withdrawal_confirmation() -> void:
	_withdrawal_confirmation_dialog.get_cancel_button().text = "Keep Fighting"
	var cancel_shortcut := Shortcut.new()
	var cancel_action := InputEventAction.new()
	cancel_action.action = "ui_cancel"
	cancel_shortcut.events = [cancel_action]
	_withdrawal_confirmation_dialog.get_cancel_button().shortcut = cancel_shortcut

func _configure_battle_info_tab_accessibility() -> void:
	var tab_bar := _battle_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.focus_mode = Control.FOCUS_ALL
	if not tab_bar.gui_input.is_connected(_on_battle_info_tab_bar_gui_input):
		tab_bar.gui_input.connect(_on_battle_info_tab_bar_gui_input)
	_sync_battle_info_tab_tooltip()

func _on_battle_info_tab_changed(tab: int) -> void:
	if _validation_battle_info_tab_resetting:
		_last_battle_info_tab_index = tab
		return
	var previous_tab := _last_battle_info_tab_index
	_last_battle_info_tab_index = tab
	_validation_battle_info_tab_change_sequence += 1
	_validation_battle_info_tab_change_count += 1
	var change_sequence := _validation_battle_info_tab_change_sequence
	_last_battle_info_tab_change_result = {
		"ok": true,
		"from_tab": previous_tab,
		"to_tab": tab,
		"tab_title": _battle_tabs.get_tab_title(tab) if tab >= 0 and tab < _battle_tabs.get_tab_count() else "",
		"focus_retained": false,
		"focus_owner": "",
		"sequence": change_sequence,
	}
	_refresh_battle_tab_cues()
	call_deferred("_complete_battle_info_tab_focus_retention", tab, change_sequence)

func _complete_battle_info_tab_focus_retention(tab: int, change_sequence: int) -> void:
	if (
		not is_inside_tree()
		or tab != _battle_tabs.current_tab
		or change_sequence != _validation_battle_info_tab_change_sequence
	):
		return
	var tab_bar := _battle_tabs.get_tab_bar()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var retained := tab_bar != null and focus_owner == tab_bar
	if retained:
		_validation_battle_info_tab_focus_retention_count += 1
	_last_battle_info_tab_change_result["focus_retained"] = retained
	_last_battle_info_tab_change_result["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""

func _on_battle_info_tab_bar_gui_input(event: InputEvent) -> void:
	var direction := 0
	if event.is_action_pressed("ui_left", true):
		direction = -1
	elif event.is_action_pressed("ui_right", true):
		direction = 1
	if direction == 0:
		return
	var tab_bar := _battle_tabs.get_tab_bar()
	if tab_bar == null or get_viewport().gui_get_focus_owner() != tab_bar:
		return
	if _selectable_battle_info_tab_in_direction(tab_bar, _battle_tabs.current_tab, direction) >= 0:
		return
	_validation_battle_info_tab_boundary_retain_count += 1
	tab_bar.accept_event()
	tab_bar.grab_focus()

func _selectable_battle_info_tab_in_direction(tab_bar: TabBar, from_tab: int, direction: int) -> int:
	var candidate := from_tab + direction
	while candidate >= 0 and candidate < tab_bar.tab_count:
		if not tab_bar.is_tab_disabled(candidate) and not tab_bar.is_tab_hidden(candidate):
			return candidate
		candidate += direction
	return -1

func _sync_battle_info_tab_tooltip() -> void:
	var tab_bar := _battle_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.tooltip_text = _join_tooltip_sections([
		"Battle information tabs. Use Left and Right while the tabs are focused.",
		_battle_tabs.tooltip_text,
	])

func _battle_music_metadata() -> Dictionary:
	if _session == null:
		return {}
	var scenario := ContentService.get_scenario(_session.scenario_id)
	return {
		"scenario_id": _session.scenario_id,
		"player_faction_id": String(scenario.get("player_faction_id", "")),
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"encounter_id": String(_session.battle.get("encounter_id", "")) if _session.battle is Dictionary else "",
		"encounter_difficulty": String(_session.battle.get("difficulty", _session.difficulty)) if _session.battle is Dictionary else _session.difficulty,
	}

func _checkpoint_consumed_tactical_briefing() -> Dictionary:
	_validation_briefing_consumption_save_attempt_count += 1
	var save_value: Variant = SaveService.save_runtime_autosave_session(_session)
	var save_result: Dictionary = save_value if save_value is Dictionary else {}
	if bool(save_result.get("ok", false)):
		_validation_briefing_consumption_save_success_count += 1
		_briefing_consumption_autosave_failure_pending = false
		_last_briefing_consumption_autosave_result = {
			"ok": true,
			"saved": true,
			"reason": "saved",
			"retry_action": "",
			"briefing_shown": _tactical_briefing_is_shown(),
			"message": String(save_result.get("message", "Autosave updated.")).strip_edges().left(220),
			"save_result": save_result.duplicate(true),
		}
		return _last_briefing_consumption_autosave_result.duplicate(true)

	_validation_briefing_consumption_save_failure_count += 1
	_briefing_consumption_autosave_failure_pending = true
	_last_message = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	_last_briefing_consumption_runtime_issue = RuntimeIssueLog.emit_error(
		"battle",
		"briefing_consumption_autosave_failed",
		BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE,
		{
			"scenario_id": _session.scenario_id.left(100),
			"encounter_id": String(_session.battle.get("encounter_id", "")).left(100),
			"round": int(_session.battle.get("round", 0)),
			"briefing_shown": _tactical_briefing_is_shown(),
			"save_reason": String(save_result.get("reason", "write_failed")).strip_edges().left(80),
			"retry_action": "manual_save",
		},
		_session
	)
	_last_briefing_consumption_autosave_result = {
		"ok": false,
		"saved": false,
		"routed": false,
		"reason": "autosave_failed",
		"retry_action": "manual_save",
		"briefing_shown": _tactical_briefing_is_shown(),
		"briefing_visible": _tactical_briefing_text.strip_edges() != "",
		"message": BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE,
		"save_result": save_result.duplicate(true),
	}
	return _last_briefing_consumption_autosave_result.duplicate(true)

func _tactical_briefing_is_shown() -> bool:
	if _session == null or _session.battle.is_empty():
		return false
	var state_value: Variant = _session.battle.get(BattleRules.TACTICAL_BRIEFING_KEY, {})
	return state_value is Dictionary and bool(state_value.get("shown", false))

func _on_prev_target_pressed() -> void:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return
	var started := ProfileLogScript.begin_usec()
	BattleRules.cycle_target(_session, -1)
	_refresh()
	ProfileLogScript.emit_general("battle", "action", "cycle_target", ProfileLogScript.elapsed_ms(started), {}, _battle_profile_metadata(false).merged({"direction": -1}, true), _session)

func _on_next_target_pressed() -> void:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return
	var started := ProfileLogScript.begin_usec()
	BattleRules.cycle_target(_session, 1)
	_refresh()
	ProfileLogScript.emit_general("battle", "action", "cycle_target", ProfileLogScript.elapsed_ms(started), {}, _battle_profile_metadata(false).merged({"direction": 1}, true), _session)

func _on_board_stack_focus_requested(battle_id: String) -> Dictionary:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result(_battle_resolution_checkpoint_block_result("board_target"))
	if _session == null or _session.battle.is_empty() or battle_id == "":
		return _reject_board_stack_click(battle_id, "No battle target was clicked.")
	var active_stack := BattleRules.get_active_stack(_session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return _reject_board_stack_click(battle_id, "It is not the player's turn.")
	var clicked_stack := _stack_by_battle_id(battle_id)
	if clicked_stack.is_empty() or String(clicked_stack.get("side", "")) != "enemy":
		return _reject_board_stack_click(battle_id, "Only enemy stacks can be targeted from the battle board.")

	var selected_before := String(BattleRules.get_selected_target(_session.battle).get("battle_id", "")) == battle_id
	var selection_result := BattleRules.select_target(_session, battle_id)
	if not bool(selection_result.get("ok", false)):
		return _reject_board_stack_click(
			battle_id,
			String(selection_result.get("message", "Could not select that target.")),
			String(selection_result.get("state", "invalid")),
			{"selected_before": selected_before}
		)
	var board_intent := BattleRules.board_click_attack_intent_for_target(_session.battle, battle_id)
	var board_action := String(board_intent.get("action", ""))
	if board_action != "":
		var recap_context := BattleRules.post_action_recap_context(_session, board_action)
		var result := BattleRules.perform_player_action(_session, board_action)
		_last_message = String(result.get("message", ""))
		_record_action_recap(board_action, result, recap_context)
		if bool(result.get("ok", false)):
			_dismiss_tactical_briefing()
		var handled := _handle_battle_resolution(result)
		if not handled:
			_refresh()
		var selected_after := {}
		var selected_legality := {}
		var selected_click_intent := {}
		var selected_continuity_context := {}
		var selected_closing_context := {}
		var selected_direct_actionable := false
		var action_guidance := ""
		var target_context := ""
		var board_summary := {}
		if _session != null and not _session.battle.is_empty():
			selected_after = BattleRules.get_selected_target(_session.battle)
			selected_legality = BattleRules.selected_target_legality(_session.battle)
			selected_click_intent = BattleRules.selected_target_board_click_intent(_session.battle)
			selected_continuity_context = BattleRules.selected_target_continuity_context(_session.battle)
			selected_closing_context = BattleRules.selected_target_closing_context(_session.battle)
			selected_direct_actionable = (
				selected_continuity_context.is_empty()
				and selected_closing_context.is_empty()
				and bool(selected_legality.get("attackable", false))
				and String(selected_click_intent.get("label", "")) != ""
			)
			action_guidance = BattleRules.describe_action_surface(_session)
			target_context = BattleRules.describe_target_context(_session)
			if not handled:
				board_summary = _validation_battle_board_summary()
		return _return_board_cursor_action_result({
			"ok": bool(result.get("ok", false)),
			"action": board_action,
			"target_battle_id": battle_id,
			"selected_before": selected_before,
			"attack_result": result.duplicate(true),
			"attack_target_battle_id": String(result.get("attack_target_battle_id", battle_id)),
			"selected_target_after_click": String(selected_after.get("battle_id", "")),
			"selected_target_after_attack_battle_id": String(result.get("selected_target_after_attack_battle_id", selected_after.get("battle_id", ""))),
			"selected_target_after_attack_legality": selected_legality.duplicate(true),
			"selected_target_after_attack_board_click_intent": selected_click_intent.duplicate(true),
			"selected_target_after_attack_board_click_action": String(selected_click_intent.get("action", "")),
			"selected_target_after_attack_board_click_label": String(selected_click_intent.get("label", "")),
			"selected_target_direct_actionable": selected_direct_actionable,
			"selected_target_direct_actionable_after_attack": bool(result.get("selected_target_direct_actionable_after_attack", false)),
			"selected_target_handoff_after_attack": bool(result.get("selected_target_handoff_after_attack", false)),
			"selected_target_handoff_direct_actionable_after_attack": bool(result.get("selected_target_handoff_direct_actionable_after_attack", false)),
			"selected_target_handoff_blocked_after_attack": bool(result.get("selected_target_handoff_blocked_after_attack", false)),
			"selected_target_continuity_context": selected_continuity_context.duplicate(true),
			"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
			"selected_target_closing_context": selected_closing_context.duplicate(true),
			"selected_target_closing_on_target": not selected_closing_context.is_empty(),
			"action_guidance": action_guidance,
			"target_context": target_context,
			"post_action_recap": _last_action_recap_payload.duplicate(true),
			"post_action_recap_text": _last_action_recap_text,
			"battle_board": board_summary,
			"state": String(result.get("state", "")),
			"message": _last_message,
			"routed": _last_battle_resolution_routed if handled else false,
		})

	var legal_target_ids := BattleRules.legal_attack_target_ids_for_active_stack(_session.battle)
	var selected_after := BattleRules.get_selected_target(_session.battle)
	var selected_continuity_context := BattleRules.selected_target_continuity_context(_session.battle)
	var selected_closing_context := BattleRules.selected_target_closing_context(_session.battle)
	if not legal_target_ids.is_empty() and battle_id not in legal_target_ids:
		_last_message = String(board_intent.get("message", "%s is blocked from this hex. Click a highlighted enemy to attack, or move first." % String(clicked_stack.get("name", "That target"))))
		_refresh()
		var blocked_alternative_board_summary := _validation_battle_board_summary()
		return _return_board_cursor_action_result({
			"ok": false,
			"action": "blocked_target",
			"target_battle_id": battle_id,
			"selected_before": selected_before,
			"selected_target_after_click": String(selected_after.get("battle_id", "")),
			"selected_target_continuity_context": selected_continuity_context.duplicate(true),
			"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
			"selected_target_closing_context": selected_closing_context.duplicate(true),
			"selected_target_closing_on_target": not selected_closing_context.is_empty(),
			"action_guidance": BattleRules.describe_action_surface(_session),
			"target_context": BattleRules.describe_target_context(_session),
			"battle_board": blocked_alternative_board_summary,
			"state": "invalid",
			"message": _last_message,
		})

	_last_message = String(board_intent.get("message", "%s is blocked from this hex. Move to a highlighted hex before attacking." % String(clicked_stack.get("name", "That target"))))
	_refresh()
	var blocked_only_board_summary := _validation_battle_board_summary()
	return _return_board_cursor_action_result({
		"ok": false,
		"action": "blocked_target",
		"target_battle_id": battle_id,
		"selected_before": selected_before,
		"selected_target_after_click": String(selected_after.get("battle_id", "")),
		"selected_target_continuity_context": selected_continuity_context.duplicate(true),
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_closing_context": selected_closing_context.duplicate(true),
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"action_guidance": BattleRules.describe_action_surface(_session),
		"target_context": BattleRules.describe_target_context(_session),
		"battle_board": blocked_only_board_summary,
		"state": "invalid",
		"message": _last_message,
	})

func _reject_board_stack_click(
	battle_id: String,
	message: String,
	state: String = "invalid",
	extra_fields: Dictionary = {}
) -> Dictionary:
	_last_message = message
	if _session != null and not _session.battle.is_empty():
		_refresh()
	var response := {
		"ok": false,
		"action": "",
		"target_battle_id": battle_id,
		"state": state,
		"message": _last_message,
	}
	for key in extra_fields.keys():
		response[key] = extra_fields[key]
	return _return_board_cursor_action_result(response)

func _on_board_hex_destination_requested(q: int, r: int) -> Dictionary:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result(_battle_resolution_checkpoint_block_result("board_move"))
	var movement_intent := BattleRules.movement_intent_for_destination(_session.battle, q, r)
	var recap_context := BattleRules.post_action_recap_context(_session, "move")
	var result := BattleRules.move_active_stack_to_hex(_session, q, r)
	var result_intent_value: Variant = result.get("movement_intent", movement_intent)
	if result_intent_value is Dictionary:
		movement_intent = result_intent_value
	_last_message = String(result.get("message", ""))
	_record_action_recap("move", result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		return _return_board_cursor_action_result(
			_movement_click_response(result, movement_intent, q, r, _last_battle_resolution_routed)
		)
	_refresh()
	call_deferred("_configure_battle_keyboard_focus", true)
	return _return_board_cursor_action_result(_movement_click_response(result, movement_intent, q, r, false))

func _return_board_cursor_action_result(result: Dictionary) -> Dictionary:
	if not result.is_empty() and not bool(result.get("ok", false)):
		UiAudio.play_invalid("BattleShell._return_board_cursor_action_result", {
			"action": String(result.get("action", "")),
			"target_battle_id": String(result.get("target_battle_id", "")),
			"state": String(result.get("state", "")),
			"message": String(result.get("message", "")),
		})
	if _battle_board_view != null and _battle_board_view.has_method("publish_controller_action_result"):
		_battle_board_view.call("publish_controller_action_result", result)
	return result

func _on_board_controller_navigation_cancelled() -> void:
	call_deferred("_configure_battle_keyboard_focus", true)

func _on_advance_pressed() -> void:
	_perform_action("advance")

func _on_strike_pressed() -> void:
	_perform_action("strike")

func _on_shoot_pressed() -> void:
	_perform_action("shoot")

func _on_defend_pressed() -> void:
	_perform_action("defend")

func _on_quick_resolve_pressed() -> Dictionary:
	if _quick_resolve_confirmation_pending:
		return {
			"ok": false,
			"pending": true,
			"performed": false,
			"reason": "confirmation_already_pending",
			"message": "Finish the current Quick Resolve confirmation first.",
		}
	if _session == null or _session.battle.is_empty() or _session.scenario_status != "in_progress":
		_last_message = "Quick Resolve is unavailable because there is no active battle to resolve."
		if _session != null and not _session.battle.is_empty():
			_refresh()
		return {
			"ok": false,
			"pending": false,
			"performed": false,
			"reason": "quick_resolve_unavailable",
			"message": _last_message,
		}
	_quick_resolve_confirmation_pending = true
	_quick_resolve_confirmation_focus_origin = _quick_resolve_button
	_validation_quick_resolve_confirmation_request_count += 1
	_quick_resolve_confirmation_dialog.popup_centered(Vector2i(700, 300))
	_quick_resolve_confirmation_dialog.get_cancel_button().call_deferred("grab_focus")
	_focus_quick_resolve_cancel_after_popup()
	var result := {
		"ok": true,
		"pending": true,
		"confirmation_required": true,
		"performed": false,
		"reason": "confirmation_required",
		"session_id": _session.session_id,
		"scenario_id": _session.scenario_id,
		"encounter_id": String(_session.battle.get("encounter_id", "")),
		"message": "Confirm Quick Resolve or keep fighting.",
	}
	_last_quick_resolve_confirmation_result = result.duplicate(true)
	return result

func _focus_quick_resolve_cancel_after_popup() -> void:
	if not _quick_resolve_confirmation_dialog.visible or not _quick_resolve_confirmation_pending:
		return
	_quick_resolve_confirmation_dialog.get_cancel_button().grab_focus()
	await get_tree().process_frame
	if _quick_resolve_confirmation_dialog.visible and _quick_resolve_confirmation_pending:
		_quick_resolve_confirmation_dialog.get_cancel_button().grab_focus()

func _restore_quick_resolve_confirmation_focus(origin: Button) -> void:
	await get_tree().process_frame
	if (
		is_instance_valid(origin)
		and origin.is_inside_tree()
		and origin.is_visible_in_tree()
		and not origin.disabled
	):
		origin.grab_focus()

func _configure_confirmation_input_forwarding() -> void:
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if (
		_forwarding_confirmation_root_physical_input
		or not (event is InputEventKey or event is InputEventJoypadButton)
	):
		return
	if _battle_board_root_cancel_input_owned() and event.is_action_pressed("ui_cancel"):
		if bool(_battle_board_view.call("handle_root_controller_navigation_cancel")):
			get_tree().root.set_input_as_handled()
		return
	var dialog := _active_exclusive_confirmation_dialog()
	if dialog == null:
		return
	get_tree().root.set_input_as_handled()
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred("_forward_root_physical_input_to_confirmation", dialog, detached_event)


func _battle_board_root_cancel_input_owned() -> bool:
	if (
		_battle_board_view == null
		or not is_instance_valid(_battle_board_view)
		or not _battle_board_view.has_method("handle_root_controller_navigation_cancel")
		or not _battle_board_view.is_inside_tree()
		or not _battle_board_view.is_visible_in_tree()
		or get_tree().root.gui_get_focus_owner() != _battle_board_view
		or (_quick_resolve_confirmation_dialog != null and _quick_resolve_confirmation_dialog.visible)
		or (_withdrawal_confirmation_dialog != null and _withdrawal_confirmation_dialog.visible)
		or (_manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible)
	):
		return false
	return _active_play_settings_dialog == null or not _active_play_settings_dialog.is_open()


func _forward_root_physical_input_to_confirmation(dialog: ConfirmationDialog, event: InputEvent) -> void:
	if (
		_forwarding_confirmation_root_physical_input
		or not is_instance_valid(dialog)
		or _active_exclusive_confirmation_dialog() != dialog
	):
		return
	_forwarding_confirmation_root_physical_input = true
	dialog.push_input(event)
	_forwarding_confirmation_root_physical_input = false


func _active_exclusive_confirmation_dialog() -> ConfirmationDialog:
	var quick_resolve_active := _quick_resolve_confirmation_pending and _quick_resolve_confirmation_dialog.visible
	var withdrawal_active := _pending_withdrawal_action != "" and _withdrawal_confirmation_dialog.visible
	if quick_resolve_active == withdrawal_active:
		return null
	return _quick_resolve_confirmation_dialog if quick_resolve_active else _withdrawal_confirmation_dialog


func _on_quick_resolve_canceled() -> Dictionary:
	if not _quick_resolve_confirmation_pending:
		return {
			"ok": false,
			"canceled": false,
			"pending": false,
			"performed": false,
			"reason": "no_pending_confirmation",
		}
	var origin := _quick_resolve_confirmation_focus_origin
	_quick_resolve_confirmation_pending = false
	_quick_resolve_confirmation_focus_origin = null
	_validation_quick_resolve_confirmation_cancel_count += 1
	_quick_resolve_confirmation_dialog.hide()
	var result := {
		"ok": true,
		"canceled": true,
		"pending": false,
		"performed": false,
		"routed": false,
		"reason": "canceled",
		"message": "Kept fighting without resolving the battle.",
	}
	_last_quick_resolve_confirmation_result = result.duplicate(true)
	_restore_quick_resolve_confirmation_focus(origin)
	return result

func _on_quick_resolve_confirmed() -> void:
	if not _quick_resolve_confirmation_pending:
		return
	_quick_resolve_confirmation_pending = false
	_quick_resolve_confirmation_focus_origin = null
	_validation_quick_resolve_confirmation_confirm_count += 1
	_quick_resolve_confirmation_dialog.hide()
	if not _battle_resolution_checkpoint_pending.is_empty():
		_last_quick_resolve_confirmation_result = {
			"ok": false,
			"confirmed": true,
			"pending": false,
			"performed": false,
			"routed": false,
			"reason": "battle_resolution_checkpoint_pending",
		}
		_apply_battle_resolution_checkpoint_failure_surface()
		return
	var profile_started := ProfileLogScript.begin_usec()
	_validation_quick_resolve_confirmation_perform_count += 1
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(_session)
	var terminal_value: Variant = result.get("terminal_result", {})
	var terminal_result: Dictionary = terminal_value if terminal_value is Dictionary else {}
	_last_quick_resolve_confirmation_result = {
		"ok": bool(result.get("ok", false)),
		"confirmed": true,
		"pending": false,
		"performed": true,
		"routed": false,
		"reason": "resolved" if bool(result.get("completed", false)) else String(result.get("stop_reason", "resolution_incomplete")),
		"result": result.duplicate(true),
		"terminal_result": terminal_result.duplicate(true),
	}
	if bool(result.get("completed", false)) and not terminal_result.is_empty():
		_last_message = String(terminal_result.get("message", "Quick Resolve completed the battle."))
		_dismiss_tactical_briefing()
		if _handle_battle_resolution(terminal_result):
			_last_quick_resolve_confirmation_result["routed"] = _last_battle_resolution_routed
			ProfileLogScript.emit_general("battle", "action", "quick_resolve", ProfileLogScript.elapsed_ms(profile_started), {}, _battle_profile_metadata(false).merged({
				"result_ok": bool(result.get("ok", false)),
				"routed": _last_battle_resolution_routed,
				"steps": int(result.get("steps", 0)),
			}, true), _session)
			return
	_last_message = _quick_resolve_failure_message(result)
	_refresh()
	call_deferred("_configure_battle_keyboard_focus", true)
	ProfileLogScript.emit_general("battle", "action", "quick_resolve", ProfileLogScript.elapsed_ms(profile_started), {}, _battle_profile_metadata(false).merged({
		"result_ok": bool(result.get("ok", false)),
		"routed": false,
		"steps": int(result.get("steps", 0)),
		"stop_reason": String(result.get("stop_reason", "")),
	}, true), _session)

func _quick_resolve_failure_message(result: Dictionary) -> String:
	var last_value: Variant = result.get("last_result", {})
	if last_value is Dictionary:
		var last_message := String(last_value.get("message", "")).strip_edges()
		if last_message != "":
			return "Quick Resolve stopped: %s" % last_message
	var stop_reason := String(result.get("stop_reason", "resolution_incomplete")).strip_edges()
	if stop_reason == "":
		stop_reason = "resolution_incomplete"
	return "Quick Resolve stopped before the battle ended (%s). You can continue issuing orders." % stop_reason.replace("_", " ")

func _on_retreat_pressed() -> void:
	_request_withdrawal_confirmation("retreat", _retreat_button)

func _on_surrender_pressed() -> void:
	_request_withdrawal_confirmation("surrender", _surrender_button)

func _request_withdrawal_confirmation(action_id: String, focus_origin: Button = null) -> Dictionary:
	if _pending_withdrawal_action != "":
		return {
			"ok": false,
			"pending": true,
			"performed": false,
			"action_id": _pending_withdrawal_action,
			"reason": "withdrawal_confirmation_already_pending",
			"message": "Finish the current withdrawal confirmation first.",
		}
	var availability := _withdrawal_action_availability(action_id)
	if not bool(availability.get("ok", false)):
		_last_message = String(availability.get("message", "That withdrawal order is no longer available."))
		_last_withdrawal_confirmation_result = availability.duplicate(true)
		if _session != null and not _session.battle.is_empty():
			_refresh()
		_restore_withdrawal_focus(focus_origin)
		return availability
	var copy := _withdrawal_confirmation_copy(action_id, availability.get("action", {}))
	_pending_withdrawal_action = action_id
	_withdrawal_focus_origin = focus_origin if focus_origin != null else _withdrawal_action_button(action_id)
	_withdrawal_confirmation_dialog.title = String(copy.get("title", "Confirm Withdrawal?"))
	_withdrawal_confirmation_dialog.dialog_text = String(copy.get("text", "Confirm this withdrawal order?"))
	_withdrawal_confirmation_dialog.get_ok_button().text = String(copy.get("confirm_text", "Confirm Withdrawal"))
	_withdrawal_confirmation_dialog.get_cancel_button().text = "Keep Fighting"
	var dialog_label := _withdrawal_confirmation_dialog.get_label()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(800.0, 0.0)
	_withdrawal_confirmation_dialog.popup_centered(Vector2i(880, 320))
	_withdrawal_confirmation_dialog.get_cancel_button().call_deferred("grab_focus")
	_focus_withdrawal_cancel_after_popup()
	var result := _withdrawal_confirmation_snapshot(true)
	_last_withdrawal_confirmation_result = result.duplicate(true)
	return result

func _withdrawal_action_availability(action_id: String) -> Dictionary:
	if action_id not in ["retreat", "surrender"]:
		return _withdrawal_rejection(action_id, "unsupported_withdrawal_action", "Only Retreat or Surrender can use this confirmation.")
	if _session == null or _session.battle.is_empty():
		return _withdrawal_rejection(action_id, "battle_missing", "There is no active battle to leave.")
	if _session.scenario_status != "in_progress" or _battle_exit_handoff_in_progress:
		return _withdrawal_rejection(action_id, "battle_resolving", "The battle is already resolving and cannot accept another exit order.")
	var surface := BattleRules.get_action_surface(_session)
	var action_value: Variant = surface.get(action_id, {})
	var action: Dictionary = action_value if action_value is Dictionary else {}
	if action.is_empty():
		return _withdrawal_rejection(action_id, "action_missing", "%s is not available in this battle." % action_id.capitalize())
	if bool(action.get("disabled", true)):
		return _withdrawal_rejection(
			action_id,
			"action_no_longer_available",
			String(action.get("summary", "%s is no longer available." % action_id.capitalize()))
		)
	return {
		"ok": true,
		"pending": false,
		"performed": false,
		"action_id": action_id,
		"action": action.duplicate(true),
	}

func _withdrawal_rejection(action_id: String, reason: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"performed": false,
		"action_id": action_id,
		"reason": reason,
		"message": message,
	}

func _withdrawal_confirmation_copy(action_id: String, action_value: Variant) -> Dictionary:
	var action: Dictionary = action_value if action_value is Dictionary else {}
	var label := String(action.get("label", action_id.capitalize()))
	var surface := BattleRules.get_action_surface(_session)
	var exit_cue := _battle_exit_order_cue_surface(surface)
	var lines := [
		String(action.get("summary", "")),
		String(action.get("consequence", "")),
		String(action.get("confirmation", "")),
		String(exit_cue.get("route", "")),
		String(exit_cue.get("save", "")),
	]
	var compact: Array[String] = []
	for line_value in lines:
		var line := String(line_value).strip_edges()
		if line != "" and line not in compact:
			compact.append(line)
	return {
		"title": "Confirm %s?" % label,
		"text": "  ".join(compact),
		"confirm_text": "Confirm %s" % label,
	}

func _on_withdrawal_confirmation_canceled() -> void:
	_cancel_withdrawal_confirmation()

func _cancel_withdrawal_confirmation() -> Dictionary:
	var action_id := _pending_withdrawal_action
	var focus_origin := _withdrawal_focus_origin
	_withdrawal_confirmation_dialog.hide()
	_pending_withdrawal_action = ""
	_withdrawal_focus_origin = null
	var result := {
		"ok": true,
		"pending": false,
		"performed": false,
		"canceled": true,
		"action_id": action_id,
	}
	_last_withdrawal_confirmation_result = result.duplicate(true)
	_restore_withdrawal_focus(focus_origin)
	return result

func _on_withdrawal_confirmation_confirmed() -> Dictionary:
	var action_id := _pending_withdrawal_action
	var focus_origin := _withdrawal_focus_origin
	var route_attempts_before := _validation_battle_resolution_attempt_count
	_withdrawal_confirmation_dialog.hide()
	_pending_withdrawal_action = ""
	_withdrawal_focus_origin = null
	var availability := _withdrawal_action_availability(action_id)
	if not bool(availability.get("ok", false)):
		_last_message = "Withdrawal not confirmed: %s" % String(availability.get("message", "the order is no longer available."))
		var rejected := availability.duplicate(true)
		rejected["pending"] = false
		rejected["performed"] = false
		rejected["routing_attempt_delta"] = _validation_battle_resolution_attempt_count - route_attempts_before
		rejected["routed"] = false
		_last_withdrawal_confirmation_result = rejected.duplicate(true)
		if _session != null and not _session.battle.is_empty():
			_refresh()
		_restore_withdrawal_focus(focus_origin)
		return rejected
	var action_result := _perform_action(action_id)
	var route_delta := _validation_battle_resolution_attempt_count - route_attempts_before
	var result := {
		"ok": bool(action_result.get("ok", false)),
		"pending": false,
		"performed": bool(action_result.get("ok", false)),
		"invoked": true,
		"action_id": action_id,
		"result": action_result.duplicate(true),
		"routing_attempt_delta": route_delta,
		"routed": _last_battle_resolution_routed if route_delta > 0 else false,
		"route_target": String(_validation_last_battle_resolution_route.get("target", "")) if route_delta > 0 else "",
	}
	_last_withdrawal_confirmation_result = result.duplicate(true)
	return result

func _withdrawal_confirmation_snapshot(ok: bool) -> Dictionary:
	return {
		"ok": ok,
		"pending": _pending_withdrawal_action != "",
		"performed": false,
		"action_id": _pending_withdrawal_action,
		"dialog_visible": _withdrawal_confirmation_dialog.visible,
		"title": _withdrawal_confirmation_dialog.title,
		"text": _withdrawal_confirmation_dialog.dialog_text,
		"confirm_text": _withdrawal_confirmation_dialog.get_ok_button().text,
		"cancel_text": _withdrawal_confirmation_dialog.get_cancel_button().text,
	}

func _withdrawal_action_button(action_id: String) -> Button:
	return _retreat_button if action_id == "retreat" else _surrender_button if action_id == "surrender" else null

func _focus_withdrawal_cancel_after_popup() -> void:
	await get_tree().process_frame
	if _withdrawal_confirmation_dialog.visible and _pending_withdrawal_action != "":
		_withdrawal_confirmation_dialog.get_cancel_button().grab_focus()

func _restore_withdrawal_focus(focus_origin: Button) -> void:
	if focus_origin != null and is_instance_valid(focus_origin) and focus_origin.is_visible_in_tree() and not focus_origin.disabled:
		focus_origin.call_deferred("grab_focus")
		return
	call_deferred("_configure_battle_keyboard_focus", true)

func _on_speed_normal_pressed() -> void:
	_set_battle_presentation_speed(BattleRules.PRESENTATION_SPEED_NORMAL)

func _on_speed_fast_pressed() -> void:
	_set_battle_presentation_speed(BattleRules.PRESENTATION_SPEED_FAST)

func _on_speed_instant_pressed() -> void:
	_set_battle_presentation_speed(BattleRules.PRESENTATION_SPEED_INSTANT)

func _set_battle_presentation_speed(speed: String) -> Dictionary:
	var requested_speed := _normalize_battle_presentation_speed_id(speed)
	var requesting_button := _battle_presentation_speed_button(requested_speed)
	var prior_session_speed := BattleRules.battle_presentation_speed(_session)
	var prior_committed_speed := SettingsService.battle_playback_speed_id()
	_validation_battle_playback_speed_request_count += 1
	if _session == null or _session.battle.is_empty():
		_validation_battle_playback_speed_failure_count += 1
		var unavailable := {
			"ok": false,
			"saved": false,
			"applied": false,
			"changed": false,
			"reason": "no_active_battle",
			"settings_reason": "",
			"requested_speed": requested_speed,
			"prior_session_speed": prior_session_speed,
			"prior_committed_speed": prior_committed_speed,
			"committed_speed": prior_committed_speed,
			"active_speed": prior_session_speed,
			"session_speed": prior_session_speed,
			"message": "No battle is active.",
			"settings_result": {},
			"rule_result": {},
			"resync_result": {},
		}
		_last_battle_playback_speed_result = unavailable.duplicate(true)
		return unavailable

	var settings_result: Dictionary = SettingsService.set_battle_playback_speed_id(requested_speed)
	var committed_speed := SettingsService.battle_playback_speed_id()
	if not bool(settings_result.get("ok", false)):
		var resync_result := BattleRules.set_battle_presentation_speed(_session, committed_speed)
		_validation_battle_playback_speed_failure_count += 1
		_last_message = BATTLE_PLAYBACK_SPEED_SAVE_FAILURE_MESSAGE
		var failure := {
			"ok": false,
			"saved": false,
			"applied": false,
			"changed": false,
			"reason": "settings_save_failed",
			"settings_reason": String(settings_result.get("reason", "settings_save_failed")),
			"requested_speed": requested_speed,
			"prior_session_speed": prior_session_speed,
			"prior_committed_speed": prior_committed_speed,
			"committed_speed": committed_speed,
			"active_speed": BattleRules.battle_presentation_speed(_session),
			"session_speed": BattleRules.battle_presentation_speed(_session),
			"message": _last_message,
			"settings_result": settings_result.duplicate(true),
			"rule_result": {},
			"resync_result": resync_result.duplicate(true),
		}
		_last_battle_playback_speed_result = failure.duplicate(true)
		_refresh()
		_restore_battle_presentation_speed_focus(requesting_button)
		return failure

	var rule_result := BattleRules.set_battle_presentation_speed(_session, committed_speed)
	var applied := bool(rule_result.get("ok", false))
	if applied:
		_validation_battle_playback_speed_success_count += 1
		_last_message = String(rule_result.get("message", ""))
	else:
		_validation_battle_playback_speed_failure_count += 1
		_last_message = String(rule_result.get("message", "Battle playback speed could not be applied."))
	var result := {
		"ok": applied,
		"saved": true,
		"applied": applied,
		"changed": bool(settings_result.get("changed", false)),
		"reason": "saved" if applied else "apply_failed",
		"settings_reason": String(settings_result.get("reason", "")),
		"requested_speed": requested_speed,
		"prior_session_speed": prior_session_speed,
		"prior_committed_speed": prior_committed_speed,
		"committed_speed": committed_speed,
		"active_speed": BattleRules.battle_presentation_speed(_session),
		"session_speed": BattleRules.battle_presentation_speed(_session),
		"message": _last_message,
		"settings_result": settings_result.duplicate(true),
		"rule_result": rule_result.duplicate(true),
		"resync_result": {},
	}
	_last_battle_playback_speed_result = result.duplicate(true)
	_refresh()
	return result

func _normalize_battle_presentation_speed_id(speed: String) -> String:
	var normalized := speed.strip_edges().to_lower()
	if normalized in [BattleRules.PRESENTATION_SPEED_NORMAL, BattleRules.PRESENTATION_SPEED_FAST, BattleRules.PRESENTATION_SPEED_INSTANT]:
		return normalized
	return BattleRules.PRESENTATION_SPEED_NORMAL

func _battle_presentation_speed_button(speed: String) -> Button:
	match _normalize_battle_presentation_speed_id(speed):
		BattleRules.PRESENTATION_SPEED_FAST:
			return _speed_fast_button
		BattleRules.PRESENTATION_SPEED_INSTANT:
			return _speed_instant_button
	return _speed_normal_button

func _restore_battle_presentation_speed_focus(button: Button) -> void:
	if button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		button.call_deferred("grab_focus")

func _on_spell_action_pressed(action_id: String) -> void:
	if not _battle_resolution_checkpoint_pending.is_empty():
		_apply_battle_resolution_checkpoint_failure_surface()
		return
	if not action_id.begins_with("cast_spell:"):
		return
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var rules_started := ProfileLogScript.begin_usec()
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var result := BattleRules.cast_player_spell(_session, action_id.trim_prefix("cast_spell:"))
	buckets["rules_action"] = ProfileLogScript.elapsed_ms(rules_started)
	_last_message = String(result.get("message", ""))
	_record_action_recap(action_id, result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		ProfileLogScript.emit_general("battle", "action", "spell", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false).merged({
			"action_id": action_id,
			"result_ok": bool(result.get("ok", false)),
			"routed": _last_battle_resolution_routed,
		}, true), _session)
		return
	var refresh_started := ProfileLogScript.begin_usec()
	_refresh()
	call_deferred("_configure_battle_keyboard_focus", true)
	buckets["refresh"] = ProfileLogScript.elapsed_ms(refresh_started)
	ProfileLogScript.emit_general("battle", "action", "spell", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false).merged({
		"action_id": action_id,
		"result_ok": bool(result.get("ok", false)),
		"routed": false,
	}, true), _session)

func _on_save_pressed() -> Dictionary:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _retry_battle_resolution_checkpoint()
	var action := AppRouter.active_manual_save_action()
	if bool(action.get("disabled", true)):
		_last_message = String(action.get("summary", "The battle could not be saved."))
		_refresh()
		return action
	if bool(action.get("requires_confirmation", false)):
		_manual_save_overwrite_dialog.open_action(action)
		return action
	return _commit_manual_save(int(action.get("slot", SaveService.get_selected_manual_slot())))

func _commit_manual_save(manual_slot: int) -> Dictionary:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var briefing_checkpoint_pending := _briefing_consumption_autosave_failure_pending
	var save_started := ProfileLogScript.begin_usec()
	var result := AppRouter.save_active_session_to_manual_slot(manual_slot)
	buckets["save"] = ProfileLogScript.elapsed_ms(save_started)
	if briefing_checkpoint_pending and bool(result.get("ok", false)):
		_briefing_consumption_autosave_failure_pending = false
		_last_message = String(result.get("message", ""))
	elif briefing_checkpoint_pending:
		_last_message = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	else:
		_last_message = String(result.get("message", ""))
	var refresh_started := ProfileLogScript.begin_usec()
	_refresh()
	if bool(result.get("ok", false)):
		_save_written_cue_presenter.present(result, manual_slot)
	if briefing_checkpoint_pending and not bool(result.get("ok", false)):
		_save_button.call_deferred("grab_focus")
	buckets["refresh"] = ProfileLogScript.elapsed_ms(refresh_started)
	ProfileLogScript.emit_general("battle", "action", "save", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false), _session)
	return result

func validation_save_written_cue_snapshot() -> Dictionary:
	return _save_written_cue_presenter.validation_snapshot() if _save_written_cue_presenter != null else {}

func _present_load_resumed_cue() -> void:
	var payload: Dictionary = AppRouter.consume_load_resumed_presentation("battle")
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
	_refresh_save_slot_picker()

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
	_last_message = message
	_refresh()
	_menu_button.call_deferred("grab_focus")
	return _last_return_to_menu_result.duplicate(true)

func _on_settings_pressed() -> void:
	_active_play_settings_dialog.open_dialog()

func _on_active_play_settings_closed() -> void:
	if _settings_button.is_visible_in_tree():
		_settings_button.call_deferred("grab_focus")
		return
	call_deferred("_configure_battle_keyboard_focus", true)

func _on_active_play_setting_changed(setting_id: String) -> void:
	if setting_id == "battle_playback_speed":
		BattleRules.set_battle_presentation_speed(_session, SettingsService.battle_playback_speed_id())
		_refresh()
		return
	if setting_id not in ["ui_scale", "high_contrast", "color_cues"]:
		return
	_apply_visual_theme()
	_apply_responsive_layout()
	_refresh()

func _perform_action(action: String) -> Dictionary:
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _battle_resolution_checkpoint_block_result(action)
	_validation_perform_action_counts[action] = int(_validation_perform_action_counts.get(action, 0)) + 1
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var rules_started := ProfileLogScript.begin_usec()
	var recap_context := BattleRules.post_action_recap_context(_session, action)
	var result := BattleRules.perform_player_action(_session, action)
	buckets["rules_action"] = ProfileLogScript.elapsed_ms(rules_started)
	_last_message = String(result.get("message", ""))
	_record_action_recap(action, result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		ProfileLogScript.emit_general("battle", "action", action, ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false).merged({
			"action_id": action,
			"result_ok": bool(result.get("ok", false)),
			"routed": _last_battle_resolution_routed,
		}, true), _session)
		return result
	var refresh_started := ProfileLogScript.begin_usec()
	_refresh()
	call_deferred("_configure_battle_keyboard_focus", true)
	buckets["refresh"] = ProfileLogScript.elapsed_ms(refresh_started)
	ProfileLogScript.emit_general("battle", "action", action, ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false).merged({
		"action_id": action,
		"result_ok": bool(result.get("ok", false)),
		"routed": false,
	}, true), _session)
	return result

func _handle_battle_resolution(result: Dictionary) -> bool:
	_last_battle_resolution_routed = false
	if _session.scenario_status != "in_progress":
		_record_validation_battle_resolution_attempt(result, "outcome")
		_last_battle_resolution_routed = true
		if _validation_battle_resolution_routing_enabled:
			AppRouter.go_to_scenario_outcome()
		return true
	match String(result.get("state", "continue")):
		"victory", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost":
			_record_validation_battle_resolution_attempt(result, "overworld")
			if not _validation_battle_resolution_routing_enabled:
				_last_battle_resolution_routed = true
				return true
			return _checkpoint_battle_resolution_for_overworld(result, false)
		"defeat":
			_record_validation_battle_resolution_attempt(result, "outcome")
			_last_battle_resolution_routed = true
			if _begin_battle_exit_animation_handoff(result, "outcome"):
				return true
			if _validation_battle_resolution_routing_enabled:
				AppRouter.go_to_scenario_outcome()
			return true
	return false

func _checkpoint_battle_resolution_for_overworld(result: Dictionary, retry: bool) -> bool:
	_validation_battle_resolution_checkpoint_request_count += 1
	if retry:
		_validation_battle_resolution_checkpoint_retry_count += 1
	var checkpoint_value: Variant = AppRouter.checkpoint_battle_resolution_for_overworld(false)
	var checkpoint: Dictionary = checkpoint_value if checkpoint_value is Dictionary else {}
	_last_battle_resolution_checkpoint_result = checkpoint.duplicate(true)
	if not bool(checkpoint.get("ok", false)) or not bool(checkpoint.get("saved", false)):
		_validation_battle_resolution_checkpoint_failure_count += 1
		_battle_resolution_checkpoint_pending = {
			"result": result.duplicate(true),
			"state": String(result.get("state", "")),
			"route_target": "overworld",
		}
		_last_battle_resolution_routed = false
		_apply_battle_resolution_checkpoint_failure_surface()
		return true
	_validation_battle_resolution_checkpoint_success_count += 1
	_battle_resolution_checkpoint_pending = {}
	AppRouter.arm_battle_resolution_overworld_presentation(result)
	_resume_checkpointed_battle_resolution(result, "overworld")
	return true

func _retry_battle_resolution_checkpoint() -> Dictionary:
	if _battle_resolution_checkpoint_pending.is_empty():
		_last_battle_resolution_checkpoint_retry_result = {
			"ok": false,
			"saved": false,
			"routed": false,
			"reason": "no_battle_resolution_checkpoint_pending",
			"message": "No resolved-battle checkpoint retry is pending.",
		}
		return _last_battle_resolution_checkpoint_retry_result.duplicate(true)
	var pending := _battle_resolution_checkpoint_pending.duplicate(true)
	var result_value: Variant = pending.get("result", {})
	var result: Dictionary = result_value if result_value is Dictionary else {}
	_checkpoint_battle_resolution_for_overworld(result, true)
	_last_battle_resolution_checkpoint_retry_result = {
		"ok": bool(_last_battle_resolution_checkpoint_result.get("ok", false)),
		"saved": bool(_last_battle_resolution_checkpoint_result.get("saved", false)),
		"routed": _last_battle_resolution_routed,
		"pending": not _battle_resolution_checkpoint_pending.is_empty(),
		"reason": String(_last_battle_resolution_checkpoint_result.get("reason", "")),
		"message": String(_last_battle_resolution_checkpoint_result.get("message", _last_message)),
		"checkpoint_result": _last_battle_resolution_checkpoint_result.duplicate(true),
		"route_result": _last_battle_resolution_route_result.duplicate(true),
	}
	return _last_battle_resolution_checkpoint_retry_result.duplicate(true)

func _resume_checkpointed_battle_resolution(result: Dictionary, route_target: String) -> void:
	if _begin_battle_exit_animation_handoff(result, route_target):
		_last_battle_resolution_routed = true
		return
	_last_battle_resolution_routed = _route_checkpointed_battle_resolution()

func _route_checkpointed_battle_resolution() -> bool:
	_validation_battle_resolution_durable_route_count += 1
	var route_value: Variant = AppRouter.route_checkpointed_battle_resolution()
	var route_result: Dictionary = route_value if route_value is Dictionary else {}
	_last_battle_resolution_route_result = route_result.duplicate(true)
	if bool(route_result.get("ok", false)):
		return true
	_last_message = String(route_result.get("message", "The resolved battle is saved, but the Overworld could not open.")).strip_edges().left(220)
	_apply_battle_resolution_checkpoint_failure_surface(false, _last_message)
	return false

func _apply_battle_resolution_checkpoint_failure_surface(
	focus_save: bool = true,
	message: String = BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE
) -> void:
	_last_message = message.strip_edges().left(220)
	if _last_message == "":
		_last_message = BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE
	_status_label.text = _last_message
	_event_label.text = _last_message
	_system_body_label.visible = not _compact_layout_active
	_system_body_label.text = _last_message
	_system_body_label.tooltip_text = _last_message
	_save_button.text = "Save Battle"
	_save_button.tooltip_text = "Retry the resolved battle checkpoint, then continue to the Overworld."
	_save_button.disabled = false
	_save_slot_picker.disabled = true
	_disable_battle_exit_handoff_inputs()
	if focus_save:
		_save_button.call_deferred("grab_focus")

func _apply_briefing_consumption_autosave_failure_surface(focus_save: bool = true) -> void:
	_last_message = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	var visible_surface := BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	if _tactical_briefing_text.strip_edges() != "":
		visible_surface = "%s\n%s" % [visible_surface, _tactical_briefing_text.strip_edges()]
	_status_label.text = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	_set_battle_event_compact_label(visible_surface, 3)
	_system_body_label.visible = not _compact_layout_active
	_system_body_label.text = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	_system_body_label.tooltip_text = visible_surface
	_save_button.text = "Save Battle"
	_save_button.tooltip_text = "Save the shown tactical briefing checkpoint to the selected manual slot."
	_save_button.disabled = false
	if focus_save:
		_save_button.call_deferred("grab_focus")

func _record_validation_battle_resolution_attempt(result: Dictionary, target: String) -> void:
	_validation_battle_resolution_attempt_count += 1
	_validation_last_battle_resolution_route = {
		"target": target,
		"state": String(result.get("state", "")),
		"scenario_status": _session.scenario_status if _session != null else "",
	}

func _begin_battle_exit_animation_handoff(result: Dictionary, route_target: String) -> bool:
	if _battle_exit_handoff_in_progress or not _validation_battle_resolution_routing_enabled:
		return false
	var snapshot_value: Variant = result.get("battle_exit_animation_snapshot", {})
	if not (snapshot_value is Dictionary) or snapshot_value.is_empty():
		return false
	var snapshot: Dictionary = snapshot_value
	if _battle_board_view == null or not _battle_board_view.has_method("set_battle_presentation_snapshot"):
		return false
	_battle_exit_handoff_in_progress = true
	_battle_board_view.set_battle_presentation_snapshot(snapshot)
	_last_message = String(result.get("message", _last_message))
	_event_label.text = _last_message
	_disable_battle_exit_handoff_inputs()
	var handoff_seconds: float = max(0.01, float(BattleRules.battle_presentation_playback_msec(snapshot)) / 1000.0)
	var timer := get_tree().create_timer(handoff_seconds)
	timer.timeout.connect(_complete_battle_exit_animation_handoff.bind(route_target))
	return true

func _disable_battle_exit_handoff_inputs() -> void:
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _quick_resolve_button, _retreat_button, _surrender_button, _prev_target_button, _next_target_button]:
		if button != null:
			button.disabled = true
	for child in _spell_actions.get_children():
		if child is BaseButton:
			child.disabled = true
	if _battle_board_view != null:
		_battle_board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle_board_view.focus_mode = Control.FOCUS_NONE

func _battle_resolution_checkpoint_block_result(action: String) -> Dictionary:
	_apply_battle_resolution_checkpoint_failure_surface()
	return {
		"ok": false,
		"saved": false,
		"routed": false,
		"state": "resolved",
		"reason": "battle_resolution_checkpoint_pending",
		"retry_action": "save_battle",
		"action": action,
		"message": BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE,
	}

func _complete_battle_exit_animation_handoff(route_target: String) -> void:
	_battle_exit_handoff_in_progress = false
	if route_target == "outcome":
		AppRouter.go_to_scenario_outcome()
	else:
		_last_battle_resolution_routed = _route_checkpointed_battle_resolution()

func _refresh() -> void:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	_apply_responsive_layout()
	if _session.battle.is_empty():
		return
	var section_started := ProfileLogScript.begin_usec()
	if not BattleRules.normalize_battle_state(_session):
		AppRouter.go_to_overworld()
		return
	buckets["normalize_battle"] = ProfileLogScript.elapsed_ms(section_started)

	section_started = ProfileLogScript.begin_usec()
	_rebuild_spell_actions()
	_refresh_action_buttons()
	_refresh_speed_buttons()
	buckets["actions"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_save_slot_picker()
	buckets["save_surface"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_battle_tab_cues()
	buckets["tabs"] = ProfileLogScript.elapsed_ms(section_started)

	section_started = ProfileLogScript.begin_usec()
	_header_label.text = BattleRules.describe_header(_session)
	_set_battle_status_text(BattleRules.describe_status(_session))
	FrontierVisualKit.set_compact_label(_pressure_label, BattleRules.describe_pressure(_session), 1, 44, false)
	var dispatch_text := BattleRules.describe_dispatch(_session, _last_message)
	if _last_message.strip_edges() == "" and _tactical_briefing_text != "":
		dispatch_text = _tactical_briefing_text
	_battle_presentation_stream_text = BattleRules.describe_battle_presentation_stream(_session, 4)
	var presentation_event := BattleRules.latest_animation_event_presentation_payload(_session)
	var presentation_text := String(presentation_event.get("visible_text", "")).strip_edges()
	var presentation_dispatch_text := dispatch_text
	if _battle_presentation_stream_text != "":
		presentation_dispatch_text = "%s\n%s" % [_battle_presentation_stream_text, presentation_dispatch_text]
	if presentation_text != "":
		presentation_dispatch_text = "%s\n%s" % [presentation_text, presentation_dispatch_text]
	var action_confirmation := BattleRules.action_readiness_confirmation_payload(_session)
	var action_context_surface := _battle_action_context_surface(presentation_dispatch_text, action_confirmation)
	if action_context_surface.is_empty():
		_set_battle_event_compact_label(presentation_dispatch_text, 3)
		if presentation_text != "":
			_event_label.tooltip_text = _join_tooltip_sections([
				String(presentation_event.get("tooltip_text", "")),
				_battle_presentation_stream_text,
				dispatch_text,
			])
	else:
		_set_battle_event_compact_label(
			"%s\n%s" % [String(action_context_surface.get("visible_text", "")), presentation_dispatch_text],
			3
		)
		_event_label.tooltip_text = _join_tooltip_sections([
			String(action_context_surface.get("tooltip_text", _event_label.tooltip_text)),
			String(presentation_event.get("tooltip_text", "")),
			_battle_presentation_stream_text,
		])
	_set_single_line_label(_battle_context_label, BattleRules.describe_entry_context(_session))
	_set_compact_label(_briefing_label, _tactical_briefing_text, 4)
	_briefing_panel.visible = false
	buckets["header_context_payload"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	var risk_board := BattleRules.describe_risk_readiness_board(_session)
	var risk_check := _battle_risk_check_cue_surface(risk_board, action_confirmation)
	if risk_check.is_empty():
		_set_compact_label(_risk_label, risk_board, 4)
	else:
		_set_compact_label(
			_risk_label,
			"%s\n%s" % [String(risk_check.get("visible_text", "")), risk_board],
			4
		)
		_risk_label.tooltip_text = _join_tooltip_sections([
			String(risk_check.get("tooltip_text", "")),
			risk_board,
		])
	_set_compact_label(_consequence_label, _battle_consequence_text(), 4)
	_player_commander_portrait.set_hero_id(_battle_player_hero_id())
	_enemy_commander_portrait.set_hero_id(_battle_enemy_hero_id())
	_set_compact_label(_player_command_label, BattleRules.describe_commander_summary(_session, "player"), 1)
	_set_compact_label(_enemy_command_label, BattleRules.describe_commander_summary(_session, "enemy"), 1)
	buckets["risk_consequence_commanders"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	var initiative_track := BattleRules.describe_initiative_track(_session)
	var initiative_handoff := _battle_initiative_handoff_surface()
	if initiative_handoff.is_empty():
		_set_compact_label(_initiative_label, initiative_track, BATTLE_ORDER_VISIBLE_LINE_COUNT)
	else:
		_set_compact_label(
			_initiative_label,
			String(initiative_handoff.get("visible_text", "")),
			BATTLE_ORDER_VISIBLE_LINE_COUNT
		)
		_initiative_label.tooltip_text = _join_tooltip_sections([
			String(initiative_handoff.get("tooltip_text", "")),
			initiative_track,
		])
	var active_stack_check := _battle_stack_check_cue_surface()
	var active_context := BattleRules.describe_active_context(_session)
	if active_stack_check.is_empty():
		_set_compact_label(_active_label, active_context, 3)
	else:
		_active_label.text = _battle_focus_visible_surface(
			"Active",
			BattleRules.get_active_stack(_session.battle),
			active_stack_check
		)
		_active_label.tooltip_text = _join_tooltip_sections([
			String(active_stack_check.get("tooltip_text", "")),
			active_context,
		])
	var target_context := BattleRules.describe_target_context(_session)
	var engagement_check := _battle_engagement_check_cue_surface()
	if engagement_check.is_empty():
		_set_compact_label(_target_label, target_context, 3)
	else:
		_target_label.text = _battle_focus_visible_surface(
			"Target",
			BattleRules.get_selected_target(_session.battle),
			engagement_check
		)
		_target_label.tooltip_text = _join_tooltip_sections([
			String(engagement_check.get("tooltip_text", "")),
			target_context,
		])
	var spellbook_text := BattleRules.describe_spellbook(_session)
	var spell_actions := BattleRules.get_spell_actions(_session)
	_spell_label.text = _battle_spellbook_visible_surface(spellbook_text, spell_actions)
	_spell_label.tooltip_text = spellbook_text
	buckets["turn_target_spell"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	var effect_board := BattleRules.describe_effect_board(_session)
	var status_check := _battle_status_check_cue_surface()
	if status_check.is_empty():
		_set_compact_label(_effect_label, effect_board, 3)
	else:
		_effect_label.text = _battle_effect_visible_surface(status_check)
		_effect_label.tooltip_text = _join_tooltip_sections([
			String(status_check.get("tooltip_text", "")),
			effect_board,
		])
	var spell_timing_board := BattleRules.describe_spell_timing_board(_session)
	var timing_check := _battle_timing_check_cue_surface(spell_timing_board)
	if timing_check.is_empty():
		_set_compact_label(_timing_label, spell_timing_board, 3)
	else:
		_timing_label.text = _battle_timing_visible_surface(timing_check)
		_timing_label.tooltip_text = _join_tooltip_sections([
			String(timing_check.get("tooltip_text", "")),
			spell_timing_board,
		])
		call_deferred("_refit_battle_timing_visible_surface")
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
	var position_check := _battle_position_check_cue_surface()
	var objective_check := BattleRules.objective_check_cue_payload(_session)
	var intent_forecast := BattleRules.intent_forecast_payload(_session)
	_action_guide.visible = true
	_set_battle_action_guide(
		"%s\n%s\n%s" % [
			String(intent_forecast.get("visible_text", BattleRules.describe_action_surface(_session))),
			String(position_check.get("visible_text", "")),
			String(objective_check.get("visible_text", "")),
		]
	)
	_action_guide.tooltip_text = _join_tooltip_sections([
		String(target_handoff.get("tooltip_text", BattleRules.describe_action_surface(_session))),
		String(intent_forecast.get("tooltip_text", "")),
		String(position_check.get("tooltip_text", "")),
		String(objective_check.get("tooltip_text", "")),
	])
	var action_confirmation_tooltip := String(action_confirmation.get("tooltip_text", "")).strip_edges()
	if action_confirmation_tooltip != "":
		_action_guide.tooltip_text = "%s\n\n%s" % [_action_guide.tooltip_text, action_confirmation_tooltip]
	_battle_board_view.set_battle_state(_session)
	buckets["surface_and_board"] = ProfileLogScript.elapsed_ms(section_started)

	section_started = ProfileLogScript.begin_usec()
	var player_lines = BattleRules.roster_lines(_session.battle, "player")
	var enemy_lines = BattleRules.roster_lines(_session.battle, "enemy")
	_set_compact_label(_player_roster, "\n".join(player_lines) if not player_lines.is_empty() else "No survivors remain.", 6)
	_set_compact_label(_enemy_roster, "\n".join(enemy_lines) if not enemy_lines.is_empty() else "Enemy resistance has collapsed.", 6)
	buckets["rosters"] = ProfileLogScript.elapsed_ms(section_started)
	if _briefing_consumption_autosave_failure_pending:
		_apply_briefing_consumption_autosave_failure_surface(false)
	ProfileLogScript.emit_general("battle", "refresh", "battle_refresh", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false), _session)
	call_deferred("_configure_battle_keyboard_focus", false)

func _set_battle_status_text(full_text: String) -> void:
	_status_label.text = full_text
	_status_label.tooltip_text = full_text
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS

func _battle_focus_visible_surface(prefix: String, stack: Dictionary, cue: Dictionary) -> String:
	var cue_label := "Stack check:" if prefix == "Active" else "Engagement check:"
	if stack.is_empty():
		return "%s\n%s: none\nSide: unavailable\nState: %s" % [cue_label, prefix, String(cue.get("readiness", "Waiting"))]
	var name := String(stack.get("name", stack.get("battle_id", "stack"))).strip_edges()
	if name == "":
		name = "stack"
	var side := _battle_initiative_side_label(String(stack.get("side", "")))
	var readiness := String(cue.get("readiness", "Ready")).strip_edges()
	if readiness == "":
		readiness = "Ready"
	var order := String(cue.get("order", "")).strip_edges()
	if order.contains(" ("):
		order = order.get_slice(" (", 0).strip_edges()
	var state_line := readiness
	if order != "":
		state_line = "%s: %s" % [readiness, _short_text(order, BATTLE_FOCUS_VISIBLE_ORDER_CHAR_LIMIT)]
	return "%s\n%s: %s\n%s | x%d | HP %d\n%s" % [
		cue_label,
		prefix,
		_short_text(name, BATTLE_FOCUS_VISIBLE_NAME_CHAR_LIMIT),
		side,
		max(0, int(stack.get("count", 0))),
		max(0, int(stack.get("total_health", 0))),
		state_line,
	]

func _battle_spellbook_visible_surface(spellbook_text: String, spell_actions: Array) -> String:
	var mana_line := "Mana 0/0"
	var spellbook_lines := spellbook_text.split("\n", false)
	if not spellbook_lines.is_empty():
		for part_value in String(spellbook_lines[0]).split("|", false):
			var part := String(part_value).strip_edges()
			if part.begins_with("Mana "):
				mana_line = part
				break
	var ready_count := 0
	var first_ready := ""
	for action_value in spell_actions:
		if not (action_value is Dictionary) or bool(action_value.get("disabled", false)):
			continue
		ready_count += 1
		if first_ready == "":
			first_ready = String(action_value.get("label", action_value.get("id", "Spell"))).strip_edges()
	var ready_line := "Ready: none"
	if first_ready != "":
		ready_line = "Ready: %s" % _short_text(first_ready, BATTLE_SPELL_VISIBLE_NAME_CHAR_LIMIT)
	return "%s\n%s\nSpells: %d/%d ready" % [mana_line, ready_line, ready_count, spell_actions.size()]

func _battle_effect_visible_surface(status_check: Dictionary) -> String:
	var readiness := String(status_check.get("readiness", "Review")).strip_edges()
	if readiness == "":
		readiness = "Review"
	var effect_count: int = max(0, int(status_check.get("effect_stack_count", 0)))
	return "Status check: %s\nEffects: %d stack%s" % [
		readiness,
		effect_count,
		"" if effect_count == 1 else "s",
	]

func _battle_timing_visible_surface(timing_check: Dictionary) -> String:
	var readiness := String(timing_check.get("readiness", "Review")).strip_edges()
	if readiness == "":
		readiness = "Review"
	var action_prefix := "Next"
	var action_value := readiness
	var ready_spell := String(timing_check.get("ready_spell", "")).strip_edges()
	var ready_order := String(timing_check.get("ready_order", "")).strip_edges()
	if ready_spell != "":
		action_prefix = "Cast"
		action_value = ready_spell.trim_prefix("Cast ").strip_edges()
	elif ready_order != "":
		action_prefix = "Order"
		action_value = ready_order
	var watch_value := _battle_timing_compact_clause(String(timing_check.get("burst_risk", "")))
	if watch_value == "" or watch_value.to_lower().contains("unavailable"):
		watch_value = _battle_timing_compact_clause(String(timing_check.get("protection_need", "")))
	if watch_value == "":
		watch_value = _battle_timing_compact_clause(String(timing_check.get("enemy_pressure", "")))
	if watch_value == "":
		watch_value = "review full detail"
	var lines := [
		"Timing check: %s" % readiness,
		"%s: %s" % [action_prefix, action_value],
		"Watch: %s" % watch_value,
	]
	var visible_lines: Array[String] = []
	for line_value in lines:
		visible_lines.append(_fit_battle_timing_line(String(line_value)))
	return "\n".join(visible_lines)

func _battle_timing_compact_clause(value: String) -> String:
	var clause := value.strip_edges()
	for prefix in [
		"Burst risk:",
		"Incoming burst:",
		"Protection need:",
		"Enemy spell pressure:",
	]:
		if clause.begins_with(prefix):
			clause = clause.trim_prefix(prefix).strip_edges()
			break
	if clause.contains(" | "):
		clause = clause.get_slice(" | ", 0).strip_edges()
	if clause.contains("; "):
		clause = clause.get_slice("; ", 0).strip_edges()
	if clause.contains(" is best placed to cast "):
		clause = clause.get_slice(" is best placed to cast ", 1).strip_edges()
		if clause.contains(" on "):
			clause = clause.get_slice(" on ", 0).strip_edges()
	return clause.trim_suffix(".").strip_edges()

func _refit_battle_timing_visible_surface() -> void:
	if not is_inside_tree() or _session == null or _session.battle.is_empty() or _timing_label == null:
		return
	var timing_board := BattleRules.describe_spell_timing_board(_session)
	var timing_check := _battle_timing_check_cue_surface(timing_board)
	if timing_check.is_empty():
		return
	_timing_label.text = _battle_timing_visible_surface(timing_check)

func _fit_battle_timing_line(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "" or _timing_label == null:
		return normalized
	var font := _timing_label.get_theme_font("font")
	var font_size := _timing_label.get_theme_font_size("font_size")
	var max_width := _timing_label.size.x
	if font == null or font_size <= 0 or max_width < 24.0:
		return normalized
	if font.get_string_size(normalized, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
		return normalized
	var ellipsis := "…"
	if font.get_string_size(ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		return ""
	var prefix := ""
	for word_value in normalized.split(" ", false):
		var word := String(word_value)
		var candidate := word if prefix == "" else "%s %s" % [prefix, word]
		if font.get_string_size("%s%s" % [candidate, ellipsis], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
			break
		prefix = candidate
	return "%s%s" % [prefix, ellipsis] if prefix != "" else ellipsis

func _configure_battle_keyboard_focus(force: bool = false) -> void:
	if not is_inside_tree() or _session == null or _session.battle.is_empty() or (_active_play_settings_dialog != null and _active_play_settings_dialog.is_open()) or (_quick_resolve_confirmation_dialog != null and _quick_resolve_confirmation_dialog.visible) or (_withdrawal_confirmation_dialog != null and _withdrawal_confirmation_dialog.visible):
		return
	var surfaces := [
		_battle_board_view,
		_battle_tabs.get_tab_bar(),
		_prev_target_button,
		_next_target_button,
		_advance_button,
		_strike_button,
		_shoot_button,
		_defend_button,
		_spell_actions,
		_quick_resolve_button,
		_retreat_button,
		_surrender_button,
		_speed_normal_button,
		_speed_fast_button,
		_speed_instant_button,
		_save_slot_picker,
		_save_button,
		_settings_button,
		_menu_button,
	]
	var controls := FrontierVisualKit.configure_focus_cycle(surfaces)
	_last_battle_keyboard_focus_cycle_names = []
	_last_battle_keyboard_focus_tab_bar_occurrences = 0
	var tab_bar := _battle_tabs.get_tab_bar()
	for control in controls:
		if not (control is Control):
			continue
		_last_battle_keyboard_focus_cycle_names.append(String(control.name))
		if control == tab_bar:
			_last_battle_keyboard_focus_tab_bar_occurrences += 1
	FrontierVisualKit.grab_keyboard_focus(self, _preferred_battle_keyboard_focus(), controls, force)

func _preferred_battle_keyboard_focus() -> Control:
	if _briefing_consumption_autosave_failure_pending:
		return _save_button
	var action_id := String(BattleRules.intent_forecast_payload(_session).get("action_id", ""))
	match action_id:
		"advance":
			return _advance_button
		"strike":
			return _strike_button
		"shoot":
			return _shoot_button
		"defend":
			return _defend_button
		"retreat":
			return _retreat_button
		"surrender":
			return _surrender_button
		_:
			if action_id.begins_with("cast_spell:"):
				for child in _spell_actions.get_children():
					if child is Control \
							and not child.is_queued_for_deletion() \
							and String(child.get_meta("battle_action_id", "")) == action_id \
							and FrontierVisualKit.is_keyboard_focusable(child):
						return child
	return _defend_button

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = BattleRules.get_spell_actions(_session)
	if actions.is_empty():
		_spell_actions.visible = false
		return
	_spell_actions.visible = true

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = _battle_spell_action_button_text(action)
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _battle_spell_action_tooltip(action)
		_style_action_button(button, false, 132)
		_apply_spell_action_icon(button, action)
		button.set_meta("battle_action_id", String(action.get("id", "")))
		button.pressed.connect(_on_spell_action_pressed.bind(String(action.get("id", ""))))
		_spell_actions.add_child(button)

func _apply_spell_action_icon(button: Button, action: Dictionary) -> void:
	var spell_id := SpellRules.spell_id_for_action(String(action.get("id", "")))
	var icon_path := SpellRules.spell_icon_path(spell_id)
	if icon_path == "":
		return
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)

func _refresh_action_buttons() -> void:
	var active_stack := BattleRules.get_active_stack(_session.battle)
	var target_stack := BattleRules.get_selected_target(_session.battle)
	var player_turn := not active_stack.is_empty() and String(active_stack.get("side", "")) == "player"
	var enemy_lines = BattleRules.roster_lines(_session.battle, "enemy")
	var surface := BattleRules.get_action_surface(_session)
	var legal_target_ids := BattleRules.legal_attack_target_ids_for_active_stack(_session.battle)
	var cycle_target_count := legal_target_ids.size() if not legal_target_ids.is_empty() else enemy_lines.size()
	var cycle_cue := _battle_target_cycle_cue_surface(player_turn, active_stack, target_stack, legal_target_ids, enemy_lines.size())

	_prev_target_button.text = String(cycle_cue.get("prev_label", "Prev"))
	_next_target_button.text = String(cycle_cue.get("next_label", "Next"))
	_prev_target_button.disabled = not player_turn or cycle_target_count <= 1
	_next_target_button.disabled = not player_turn or cycle_target_count <= 1
	if not player_turn:
		_prev_target_button.tooltip_text = String(cycle_cue.get("prev_tooltip", "Input locked: it is not the player's turn."))
		_next_target_button.tooltip_text = String(cycle_cue.get("next_tooltip", "Input locked: it is not the player's turn."))
	else:
		_prev_target_button.tooltip_text = String(cycle_cue.get("prev_tooltip", "Cycle focus to the previous enemy target."))
		_next_target_button.tooltip_text = String(cycle_cue.get("next_tooltip", "Cycle focus to the next enemy target."))

	_apply_action_surface(_advance_button, surface.get("advance", {}), true)
	_apply_action_surface(_strike_button, surface.get("strike", {}), true)
	_apply_action_surface(_shoot_button, surface.get("shoot", {}), true)
	_apply_action_surface(_defend_button, surface.get("defend", {}), true)
	_quick_resolve_button.text = "Quick Resolve"
	_quick_resolve_button.disabled = _battle_exit_handoff_in_progress or _session.battle.is_empty() or _session.scenario_status != "in_progress"
	_quick_resolve_button.tooltip_text = "Resolve the remaining battle automatically. Confirmation is required because casualties, mana use, and objective consequences are permanent."
	_style_action_button(_quick_resolve_button, true, 112.0)
	_apply_action_surface(_retreat_button, surface.get("retreat", {}))
	_apply_action_surface(_surrender_button, surface.get("surrender", {}))
	_append_battle_exit_order_cues(surface)

	var target_name := String(target_stack.get("name", "No target"))
	_strike_button.tooltip_text = "%s Target: %s." % [_strike_button.tooltip_text, target_name] if player_turn and not target_stack.is_empty() else _strike_button.tooltip_text
	_shoot_button.tooltip_text = "%s Target: %s." % [_shoot_button.tooltip_text, target_name] if player_turn and not target_stack.is_empty() else _shoot_button.tooltip_text
	_append_last_action_tooltips()

func _refresh_speed_buttons() -> void:
	var speed := BattleRules.battle_presentation_speed(_session)
	var buttons := {
		BattleRules.PRESENTATION_SPEED_NORMAL: _speed_normal_button,
		BattleRules.PRESENTATION_SPEED_FAST: _speed_fast_button,
		BattleRules.PRESENTATION_SPEED_INSTANT: _speed_instant_button,
	}
	for speed_id in buttons.keys():
		var button: Button = buttons[speed_id]
		if button == null:
			continue
		var selected := String(speed_id) == speed
		button.disabled = selected
		button.tooltip_text = (
			"Current battle playback speed: %s." % speed.capitalize()
			if selected
			else "Switch battle playback speed to %s." % String(speed_id).capitalize()
		)

func _battle_profile_metadata(first_render: bool) -> Dictionary:
	var battle := _session.battle if _session != null and _session.battle is Dictionary else {}
	var stacks = battle.get("stacks", []) if battle is Dictionary else []
	return {
		"first_render": first_render,
		"active_tab": _battle_tabs.current_tab if _battle_tabs != null else -1,
		"encounter_id": String(battle.get("encounter_id", "")) if battle is Dictionary else "",
		"battle_name": String(battle.get("encounter_name", "")) if battle is Dictionary else "",
		"round": int(battle.get("round", 0)) if battle is Dictionary else 0,
		"turn_index": int(battle.get("turn_index", 0)) if battle is Dictionary else 0,
		"stack_count": stacks.size() if stacks is Array else 0,
	}

func _apply_action_surface(button: Button, action: Dictionary, show_order_cue: bool = false) -> void:
	button.text = _battle_order_button_text(action) if show_order_cue else String(action.get("label", button.text))
	button.disabled = bool(action.get("disabled", false))
	button.tooltip_text = String(action.get("tooltip", action.get("summary", "")))
	if show_order_cue:
		button.tooltip_text = _join_tooltip_sections([
			button.tooltip_text,
			_battle_order_button_tooltip(action),
		])
	_style_action_button(button, true, 112.0)

func _append_battle_exit_order_cues(action_surface: Dictionary) -> void:
	var exit_cue := _battle_exit_order_cue_surface(action_surface)
	if exit_cue.is_empty():
		return
	var retreat_cue := String(exit_cue.get("retreat_tooltip", "")).strip_edges()
	if retreat_cue != "":
		_retreat_button.tooltip_text = _join_tooltip_sections([
			_retreat_button.tooltip_text,
			retreat_cue,
		])
	var surrender_cue := String(exit_cue.get("surrender_tooltip", "")).strip_edges()
	if surrender_cue != "":
		_surrender_button.tooltip_text = _join_tooltip_sections([
			_surrender_button.tooltip_text,
			surrender_cue,
		])

func _battle_exit_order_cue_surface(action_surface: Dictionary) -> Dictionary:
	var retreat: Dictionary = action_surface.get("retreat", {}) if action_surface.get("retreat", {}) is Dictionary else {}
	var surrender: Dictionary = action_surface.get("surrender", {}) if action_surface.get("surrender", {}) is Dictionary else {}
	if retreat.is_empty() and surrender.is_empty():
		return {}
	var retreat_state := _battle_exit_order_state(retreat)
	var surrender_state := _battle_exit_order_state(surrender)
	var route_line := "Route: resolving either exit order leaves this battle and returns to the field after the outcome handoff."
	var save_line := "Save: use Save Battle first to preserve this exact tactical state."
	return {
		"visible_text": "Exit cue: Retreat %s; Surrender %s." % [retreat_state, surrender_state],
		"route": route_line,
		"save": save_line,
		"retreat_state": retreat_state,
		"surrender_state": surrender_state,
		"retreat_tooltip": _battle_exit_order_tooltip("Retreat", retreat, route_line, save_line),
		"surrender_tooltip": _battle_exit_order_tooltip("Surrender", surrender, route_line, save_line),
	}

func _battle_exit_order_state(action: Dictionary) -> String:
	if action.is_empty():
		return "unavailable"
	return "ready" if not bool(action.get("disabled", true)) else "blocked"

func _battle_exit_order_tooltip(label: String, action: Dictionary, route_line: String, save_line: String) -> String:
	if action.is_empty():
		return ""
	var readiness := String(action.get("readiness", "")).strip_edges()
	var summary := String(action.get("summary", "")).strip_edges()
	var consequence := String(action.get("consequence", "")).strip_edges()
	var confirmation := String(action.get("confirmation", "")).strip_edges()
	var lines := [
		"Exit cue: %s is an army-wide battle exit order." % label,
	]
	if readiness != "":
		lines.append("Readiness: %s." % readiness)
	if summary != "":
		lines.append("Result: %s" % summary)
	if consequence != "":
		lines.append("Consequence: %s" % consequence)
	if confirmation != "":
		lines.append("Confirm: %s" % confirmation)
	lines.append(route_line)
	lines.append(save_line)
	return "\n".join(lines)

func _battle_target_cycle_cue_surface(
	player_turn: bool,
	active_stack: Dictionary,
	target_stack: Dictionary,
	legal_target_ids: Array,
	enemy_count: int
) -> Dictionary:
	var target_ids := legal_target_ids.duplicate()
	var scope := "legal targets"
	if target_ids.is_empty():
		target_ids = _living_enemy_target_ids()
		scope = "enemy stacks"
	var target_count := target_ids.size()
	if target_count <= 0 and enemy_count > 0:
		target_count = enemy_count
	var selected_id := String(target_stack.get("battle_id", ""))
	var target_index := target_ids.find(selected_id)
	if target_index < 0 and target_count > 0:
		target_index = 0
	var position_text := "%d/%d" % [target_index + 1, target_count] if target_count > 0 else "0/0"
	var focus := _battle_target_cycle_focus_label(target_stack)
	var active_name := String(active_stack.get("name", "current stack")).strip_edges()
	var state := "Ready"
	if not player_turn:
		state = "Locked"
	elif target_count <= 1:
		state = "Single"
	elif legal_target_ids.is_empty():
		state = "Check"
	var visible := "Target cycle: %s %s (%s)." % [focus, position_text, state]
	var tooltip := _battle_target_cycle_tooltip(
		focus,
		position_text,
		scope,
		active_name,
		state,
		player_turn,
		target_count
	)
	return {
		"visible_text": visible,
		"focus": focus,
		"position": position_text,
		"scope": scope,
		"state": state,
		"target_count": target_count,
		"prev_label": "Prev %s" % position_text,
		"next_label": "Next %s" % position_text,
		"prev_tooltip": tooltip,
		"next_tooltip": tooltip,
	}

func _battle_target_cycle_tooltip(
	focus: String,
	position_text: String,
	scope: String,
	active_name: String,
	state: String,
	player_turn: bool,
	target_count: int
) -> String:
	if not player_turn:
		return "Input locked: it is not the player's turn.\n- Active stack: %s\n- State: %s\n- Prev: input locked until the player stack acts.\n- Next: input locked until the player stack acts." % [
			active_name if active_name != "" else "current stack",
			state,
		]
	var previous_step := "Previous target in the current %s list." % scope
	var next_step := "Next target in the current %s list." % scope
	if target_count <= 1:
		previous_step = "Only one target is available from this stack."
		next_step = previous_step
	return "Target cycle:\n- Focus: %s\n- Position: %s\n- Scope: %s\n- Active stack: %s\n- State: %s\n- Prev: %s\n- Next: %s" % [
		focus,
		position_text,
		scope,
		active_name if active_name != "" else "current stack",
		state,
		previous_step,
		next_step,
	]

func _battle_target_cycle_focus_label(target_stack: Dictionary) -> String:
	if target_stack.is_empty():
		return "no target"
	var name := String(target_stack.get("name", "")).strip_edges()
	if name == "":
		name = String(target_stack.get("battle_id", "target")).strip_edges()
	return _short_text(name, 28)

func _battle_stack_check_cue_surface() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {}
	var active_stack := BattleRules.get_active_stack(_session.battle)
	var consequence := BattleRules.active_consequence_payload(_session)
	var action_surface := BattleRules.get_action_surface(_session)
	var active_name := String(consequence.get("active_stack_name", "")).strip_edges()
	if active_name == "" and not active_stack.is_empty():
		active_name = String(active_stack.get("name", active_stack.get("battle_id", "active stack"))).strip_edges()
	if active_name == "":
		active_name = "no active stack"
	var active_side := String(consequence.get("active_side", active_stack.get("side", ""))).strip_edges()
	var side_label := _battle_initiative_side_label(active_side)
	var role_line := String(consequence.get("active_ability_role", "Role: no active stack.")).strip_edges()
	var status_line := String(consequence.get("status_pressure", "Status pressure: none.")).strip_edges()
	var range_line := String(consequence.get("target_range", "Target/range: no target.")).strip_edges()
	var readiness := "Ready"
	var preferred_action_id := String(consequence.get("preferred_action_id", "")).strip_edges()
	var order_line := "no ready order"
	var next_step := "Choose the next legal battle order."
	if active_stack.is_empty():
		readiness = "Waiting"
		next_step = "Wait for battle resolution."
	elif active_side != "player":
		readiness = "Locked"
		next_step = "Wait for command to return."
	else:
		if preferred_action_id == "":
			preferred_action_id = _battle_first_ready_order_id(action_surface)
		if preferred_action_id != "":
			var preferred_action: Dictionary = action_surface.get(preferred_action_id, {}) if action_surface.get(preferred_action_id, {}) is Dictionary else {}
			var preferred_label := String(preferred_action.get("label", preferred_action_id.capitalize())).strip_edges()
			var preferred_readiness := _battle_order_readiness_label(preferred_action)
			order_line = "%s%s" % [
				preferred_label,
				" (%s)" % preferred_readiness if preferred_readiness != "" else "",
			]
			next_step = String(preferred_action.get("confirmation", preferred_action.get("consequence", ""))).strip_edges()
			if next_step == "":
				next_step = "Confirm %s or inspect another ready order." % preferred_label
		else:
			readiness = "Check"
			next_step = "Retarget, move, or use Defend if the line is stuck."
	var visible := "Stack check: %s; %s." % [
		_short_text(active_name, 30),
		_short_text(_strip_sentence(next_step).trim_suffix("."), 44),
	]
	var tooltip := "Stack Check\n- Active: %s [%s]\n- %s\n- %s\n- %s\n- Readiness: %s\n- Current order: %s\n- Next practical action: %s\n- Inspection: checking this cue does not spend an action or advance initiative." % [
		active_name,
		side_label,
		role_line,
		status_line,
		range_line,
		readiness,
		order_line,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_name,
		"side": side_label,
		"role": role_line,
		"status": status_line,
		"target_range": range_line,
		"readiness": readiness,
		"order": order_line,
		"next_step": next_step,
	}

func _battle_risk_check_cue_surface(risk_board: String = "", action_confirmation: Dictionary = {}) -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {
			"visible_text": "Risk check: no battle is loaded.",
			"tooltip_text": "Battle Risk Check\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var active_label := _battle_position_stack_label(active_stack)
	var board_text := risk_board.strip_edges()
	if board_text == "":
		board_text = BattleRules.describe_risk_readiness_board(_session)
	var outlook := _battle_board_line_with_prefix(board_text, "Outlook:")
	var initiative := _battle_board_line_with_prefix(board_text, "Initiative swing:")
	var integrity := _battle_board_line_with_prefix(board_text, "Line integrity:")
	var objective := _battle_board_line_with_prefix(board_text, "Objective urgency:")
	var readiness := "Review"
	var next_step := "Read the risk rail before committing the next order."
	var outlook_lower := outlook.to_lower()
	if active_stack.is_empty():
		readiness = "Waiting"
		next_step = "Wait for battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		next_step = "Wait for command to return, then recheck the risk rail."
	elif outlook_lower.contains("collapse") or outlook_lower.contains("fragile"):
		readiness = "Brace"
		next_step = "Preserve stacks, use Defend or reposition before trading into the next swing."
	elif outlook_lower.contains("strong") or outlook_lower.contains("ready"):
		readiness = "Press"
		next_step = "Spend the current edge with a ready order before initiative shifts."
	elif outlook_lower.contains("contested"):
		readiness = "Trade"
		next_step = "Confirm the safest ready order or reposition before the exchange worsens."
	else:
		readiness = "Steady"
		next_step = "Use the current order normally, then recheck after the next activation."
	var action_text := String(action_confirmation.get("visible_text", "")).strip_edges()
	var visible := "Risk check: %s; %s" % [
		readiness,
		_short_text(_strip_sentence(next_step).trim_suffix("."), 58),
	]
	var tooltip := "Battle Risk Check\n- Active stack: %s\n- %s\n- %s\n- %s\n- %s\n- Readiness: %s\n- Next practical action: %s\n- Inspection: checking this cue does not spend an action, move, attack, cast, or advance initiative." % [
		active_label,
		outlook,
		initiative,
		integrity,
		objective,
		readiness,
		next_step,
	]
	if action_text != "":
		tooltip = "%s\n- Current order check: %s" % [tooltip, _strip_sentence(action_text)]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_label,
		"outlook": outlook,
		"initiative": initiative,
		"integrity": integrity,
		"objective": objective,
		"readiness": readiness,
		"next_step": next_step,
		"action_check": action_text,
	}

func _battle_position_check_cue_surface() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {
			"visible_text": "Position check: no battle is loaded.",
			"tooltip_text": "Battle Position Check\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var selected_target := BattleRules.get_selected_target(battle)
	var click_intent := BattleRules.selected_target_board_click_intent(battle)
	var movement_intent := BattleRules.active_movement_board_click_intent(battle)
	var movement_options := BattleRules.legal_movement_intents_for_active_stack(battle)
	var legal_target_ids := BattleRules.legal_attack_target_ids_for_active_stack(battle)
	var active_label := _battle_position_stack_label(active_stack)
	var target_label := _battle_position_stack_label(selected_target)
	var readiness := "Ready"
	var reach_line := ""
	var movement_line := String(movement_intent.get("message", "")).strip_edges()
	var next_step := ""
	if active_stack.is_empty():
		readiness = "Waiting"
		reach_line = "no stack is queued"
		next_step = "Wait for battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		reach_line = "enemy initiative is active"
		next_step = "Wait for command to return."
	else:
		var click_label := String(click_intent.get("label", "")).strip_edges()
		if bool(click_intent.get("attackable", false)) and click_label != "":
			reach_line = "%s is reachable from here" % target_label
			next_step = "Click the highlighted target or use %s." % click_label
		elif bool(click_intent.get("blocked", false)) and int(movement_intent.get("destination_count", 0)) > 0:
			readiness = "Move"
			reach_line = "%s needs a move before attacking" % target_label
			next_step = _battle_position_move_next_step(movement_options, target_label)
		elif legal_target_ids.size() > 0:
			readiness = "Retarget"
			reach_line = "selected target is blocked; another highlighted enemy can be attacked"
			next_step = "Cycle target focus or click a highlighted enemy."
		elif int(movement_intent.get("destination_count", 0)) > 0:
			readiness = "Move"
			reach_line = "%d move destination%s open" % [
				int(movement_intent.get("destination_count", 0)),
				"" if int(movement_intent.get("destination_count", 0)) == 1 else "s",
			]
			next_step = _battle_position_move_next_step(movement_options, target_label)
		else:
			readiness = "Hold"
			reach_line = "no attack or move destination is open"
			next_step = "Use Defend, retarget, or wait for the next initiative handoff."
	if movement_line == "":
		movement_line = "No move destination is currently available."
	var visible := "Position check: %s; %s" % [
		_short_text(reach_line, 54),
		_short_text(_strip_sentence(next_step).trim_suffix("."), 46),
	]
	var tooltip := "Battle Position Check\n- Active stack: %s\n- Selected target: %s\n- Reach from current hex: %s\n- Movement: %s\n- Readiness: %s\n- Next practical action: %s\n- Inspection: checking this cue does not move, attack, cast, or advance initiative." % [
		active_label,
		target_label,
		reach_line,
		movement_line,
		readiness,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_label,
		"target": target_label,
		"reach": reach_line,
		"movement": movement_line,
		"movement_option_count": int(movement_intent.get("destination_count", movement_options.size())),
		"legal_target_count": legal_target_ids.size(),
		"readiness": readiness,
		"next_step": next_step,
	}

func _battle_position_move_next_step(movement_options: Array, target_label: String) -> String:
	for option in movement_options:
		if not (option is Dictionary):
			continue
		var option_dict: Dictionary = option
		if bool(option_dict.get("sets_up_selected_target_attack", false)):
			var setup_label := String(option_dict.get("selected_target_setup_label", "attack")).strip_edges()
			var destination := String(option_dict.get("destination_detail", option_dict.get("destination_label", "a move hex"))).strip_edges()
			return "Click %s to set up %s on %s." % [
				destination if destination != "" else "a move hex",
				setup_label.to_lower(),
				target_label,
			]
	for option in movement_options:
		if not (option is Dictionary):
			continue
		var option_dict: Dictionary = option
		if bool(option_dict.get("closes_on_selected_target", false)):
			var destination := String(option_dict.get("destination_detail", option_dict.get("destination_label", "a move hex"))).strip_edges()
			return "Click %s to close on %s." % [
				destination if destination != "" else "a move hex",
				target_label,
			]
	if not movement_options.is_empty():
		return "Click a move hex to reposition before choosing the next order."
	return "Use Defend, retarget, or wait for the next initiative handoff."

func _battle_position_stack_label(stack: Dictionary) -> String:
	if stack.is_empty():
		return "no stack"
	var label := String(stack.get("name", "")).strip_edges()
	if label == "":
		label = String(stack.get("battle_id", "stack")).strip_edges()
	return label

func _battle_engagement_check_cue_surface() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {
			"visible_text": "Engagement check: no battle is loaded.",
			"tooltip_text": "Battle Engagement Check\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var selected_target := BattleRules.get_selected_target(battle)
	var consequence := BattleRules.active_consequence_payload(_session)
	var action_surface := BattleRules.get_action_surface(_session)
	var active_label := _battle_position_stack_label(active_stack)
	var target_label := _battle_position_stack_label(selected_target)
	var target_range := String(consequence.get("target_range", "Target/range: no target selected.")).strip_edges()
	var preferred_action_id := String(consequence.get("preferred_action_id", "")).strip_edges()
	if preferred_action_id == "":
		preferred_action_id = _battle_first_ready_order_id(action_surface)
	var preferred_action: Dictionary = action_surface.get(preferred_action_id, {}) if action_surface.get(preferred_action_id, {}) is Dictionary else {}
	var order_label := String(preferred_action.get("label", preferred_action_id.capitalize())).strip_edges()
	if order_label == "":
		order_label = "no ready order"
	var order_readiness := _battle_order_readiness_label(preferred_action) if not preferred_action.is_empty() else "Waiting"
	var consequence_preview := _battle_engagement_consequence_preview(preferred_action_id, preferred_action, consequence)
	var next_step := ""
	var readiness := order_readiness
	if active_stack.is_empty():
		readiness = "Waiting"
		order_readiness = "Waiting"
		next_step = "Wait for battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		order_readiness = "Locked"
		next_step = "Wait for command to return."
	elif selected_target.is_empty():
		readiness = "Select"
		order_readiness = "Select target"
		next_step = "Cycle or click an enemy stack before confirming an order."
	elif preferred_action.is_empty() or bool(preferred_action.get("disabled", false)):
		readiness = "Blocked"
		next_step = "Move, cycle target focus, or use Defend if no attack opens."
	else:
		next_step = String(preferred_action.get("confirmation", preferred_action.get("consequence", ""))).strip_edges()
		if next_step == "":
			next_step = "Confirming this order spends the active stack's action."
	if consequence_preview == "":
		consequence_preview = "No immediate consequence preview."
	var visible := "Engagement check: %s; %s via %s." % [
		_short_text(target_label, 28),
		readiness,
		_short_text(order_label, 24),
	]
	var tooltip := "Battle Engagement Check\n- Active stack: %s\n- Selected target: %s\n- Order readiness: %s via %s\n- %s\n- Consequence preview: %s\n- Next practical action: %s\n- Inspection: checking this cue does not attack, move, cast, or advance initiative." % [
		active_label,
		target_label,
		order_readiness,
		order_label,
		target_range,
		consequence_preview,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_label,
		"target": target_label,
		"order": order_label,
		"readiness": readiness,
		"order_readiness": order_readiness,
		"target_range": target_range,
		"consequence_preview": consequence_preview,
		"next_step": next_step,
	}

func _battle_engagement_consequence_preview(
	action_id: String,
	action: Dictionary,
	consequence: Dictionary
) -> String:
	var preview := String(action.get("consequence", "")).strip_edges()
	if preview != "":
		return preview
	var previews: Array = consequence.get("action_previews", []) if consequence.get("action_previews", []) is Array else []
	for preview_value in previews:
		if not (preview_value is Dictionary):
			continue
		var preview_dict: Dictionary = preview_value
		if String(preview_dict.get("id", "")) == action_id:
			return String(preview_dict.get("consequence", "")).strip_edges()
	return ""

func _battle_status_check_cue_surface() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {
			"visible_text": "Status check: no battle is loaded.",
			"tooltip_text": "Battle Status Check\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var selected_target := BattleRules.get_selected_target(battle)
	var consequence := BattleRules.active_consequence_payload(_session)
	var effect_board := BattleRules.describe_effect_board(_session)
	var active_label := _battle_position_stack_label(active_stack)
	var target_label := _battle_position_stack_label(selected_target)
	var active_pressure := String(consequence.get("status_pressure", "Status pressure: no stack selected.")).strip_edges()
	var target_pressure := _battle_stack_pressure_for_status_check(selected_target, battle, "Selected pressure")
	var active_effect_count := _battle_stack_active_effect_count(active_stack, battle)
	var target_effect_count := _battle_stack_active_effect_count(selected_target, battle)
	var total_effect_stacks := _battle_effect_stack_count(battle)
	var readiness := "Clear"
	var next_step := "Use orders normally; inspect this rail again after spells or status abilities land."
	if active_stack.is_empty():
		readiness = "Waiting"
		next_step = "Wait for battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		next_step = "Wait for command to return, then recheck status pressure before acting."
	elif active_effect_count > 0 or target_effect_count > 0:
		readiness = "Watch"
		next_step = "Spend ready orders before short effects expire or status pressure shifts."
	elif total_effect_stacks > 0:
		readiness = "Review"
		next_step = "Inspect affected stacks before committing the next order."
	var visible := "Status check: %s; %s" % [
		readiness,
		_short_text(_strip_sentence(next_step).trim_suffix("."), 58),
	]
	var tooltip := "Battle Status Check\n- Active stack: %s\n- Selected target: %s\n- %s\n- %s\n- Effect board: %d stack%s with active spell/status effects\n- Readiness: %s\n- Next practical action: %s\n- Inspection: checking this cue does not spend an action, cast, move, or advance initiative." % [
		active_label,
		target_label,
		active_pressure,
		target_pressure,
		total_effect_stacks,
		"" if total_effect_stacks == 1 else "s",
		readiness,
		next_step,
	]
	if effect_board.strip_edges() != "":
		tooltip = "%s\n- Current board: %s" % [tooltip, _strip_sentence(effect_board)]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_label,
		"target": target_label,
		"active_pressure": active_pressure,
		"target_pressure": target_pressure,
		"active_effect_count": active_effect_count,
		"target_effect_count": target_effect_count,
		"effect_stack_count": total_effect_stacks,
		"readiness": readiness,
		"next_step": next_step,
	}

func _battle_stack_pressure_for_status_check(stack: Dictionary, battle: Dictionary, prefix: String) -> String:
	if stack.is_empty():
		return "%s: no selected target." % prefix
	var pressure := String(BattleRules._stack_status_pressure_line(stack, battle)).strip_edges()
	if pressure.begins_with("Status pressure:"):
		pressure = pressure.trim_prefix("Status pressure:").strip_edges()
	return "%s: %s" % [prefix, pressure]

func _battle_effect_stack_count(battle: Dictionary) -> int:
	var count := 0
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		if _battle_stack_active_effect_count(stack, battle) > 0:
			count += 1
	return count

func _battle_stack_active_effect_count(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty():
		return 0
	var effects: Variant = stack.get("effects", [])
	if not (effects is Array):
		return 0
	var current_round := int(battle.get("round", 1))
	var count := 0
	for effect_value in effects:
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		if int(effect.get("expires_after_round", current_round)) >= current_round:
			count += 1
	return count

func _battle_timing_check_cue_surface(timing_board: String = "") -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {
			"visible_text": "Timing check: no battle is loaded.",
			"tooltip_text": "Battle Timing Check\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var selected_target := BattleRules.get_selected_target(battle)
	var active_label := _battle_position_stack_label(active_stack)
	var target_label := _battle_position_stack_label(selected_target)
	var board_text := timing_board.strip_edges()
	if board_text == "":
		board_text = BattleRules.describe_spell_timing_board(_session)
	var spell_window := _battle_timing_board_line_with_prefix(board_text, "Spell window:")
	var support_payoff := _battle_timing_board_line_with_prefix(board_text, "Support payoff:")
	var protection_need := _battle_timing_board_line_with_prefix(board_text, "Protection need:")
	var burst_risk := _battle_timing_board_line_with_prefix(board_text, "Burst risk:")
	var enemy_initiative := _battle_timing_board_line_with_prefix(board_text, "Enemy initiative:")
	var enemy_spell_pressure := _battle_timing_board_line_with_prefix(board_text, "Enemy spell pressure:")
	var incoming_burst := _battle_timing_board_line_with_prefix(board_text, "Incoming burst:")
	var ready_spell := _battle_first_ready_spell_action()
	var ready_spell_label := String(ready_spell.get("label", "")).strip_edges()
	var action_surface := BattleRules.get_action_surface(_session)
	var first_order_id := _battle_first_ready_order_id(action_surface)
	var first_order: Dictionary = action_surface.get(first_order_id, {}) if action_surface.get(first_order_id, {}) is Dictionary else {}
	var first_order_label := String(first_order.get("label", first_order_id.capitalize())).strip_edges()
	var readiness := "Review"
	var next_step := "Review the timing rail before spending the current stack order."
	if active_stack.is_empty():
		readiness = "Waiting"
		next_step = "Wait for battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		next_step = "Wait for command to return, then recheck spell and order timing."
	elif ready_spell_label != "":
		readiness = "Cast"
		var ready_spell_subject := ready_spell_label.trim_prefix("Cast ").strip_edges()
		if ready_spell_subject == "":
			ready_spell_subject = ready_spell_label
		next_step = "Cast %s now if it improves this exchange, or keep mana and use a stack order." % ready_spell_subject
	elif spell_window.to_lower().contains("cast this round") or spell_window.to_lower().contains("unit timing"):
		readiness = "Order"
		next_step = "Use the best ready stack order; the commander spell window is not the main lever now."
	elif first_order_label != "":
		readiness = "Order"
		next_step = "Use %s or Defend after checking burst and protection needs." % first_order_label
	else:
		readiness = "Hold"
		next_step = "Retarget, reposition, or Defend until a better timing window opens."
	var primary_window := spell_window
	if primary_window == "":
		primary_window = enemy_initiative if enemy_initiative != "" else "Timing board did not expose a spell window."
	var burst_line := burst_risk
	if burst_line == "":
		burst_line = incoming_burst if incoming_burst != "" else "Burst risk unavailable."
	var visible := "Timing check: %s; %s" % [
		readiness,
		_short_text(_strip_sentence(next_step).trim_suffix("."), 58),
	]
	var tooltip := "Battle Timing Check\n- Active stack: %s\n- Selected target: %s\n- Spell window: %s\n- Support payoff: %s\n- Protection need: %s\n- Burst risk: %s\n- Enemy pressure: %s\n- Readiness: %s\n- Next practical action: %s\n- Inspection: checking this cue does not spend an action, cast, move, or advance initiative." % [
		active_label,
		target_label,
		primary_window,
		support_payoff if support_payoff != "" else "No support payoff line in this timing window.",
		protection_need if protection_need != "" else "No protection need line in this timing window.",
		burst_line,
		enemy_spell_pressure if enemy_spell_pressure != "" else "No enemy spell pressure line in this timing window.",
		readiness,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active": active_label,
		"target": target_label,
		"spell_window": primary_window,
		"support_payoff": support_payoff,
		"protection_need": protection_need,
		"burst_risk": burst_line,
		"enemy_pressure": enemy_spell_pressure,
		"ready_spell": ready_spell_label,
		"ready_order": first_order_label,
		"readiness": readiness,
		"next_step": next_step,
	}

func _battle_timing_board_line_with_prefix(board_text: String, prefix: String) -> String:
	for raw_line in board_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with("- "):
			line = line.substr(2).strip_edges()
		if line.begins_with(prefix):
			return line.trim_prefix(prefix).strip_edges()
	return ""

func _battle_first_ready_spell_action() -> Dictionary:
	for action in BattleRules.get_spell_actions(_session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			return (action as Dictionary).duplicate(true)
	return {}

func _battle_first_ready_order_id(action_surface: Dictionary) -> String:
	for action_id in ["shoot", "strike", "advance", "defend"]:
		var action: Dictionary = action_surface.get(action_id, {}) if action_surface.get(action_id, {}) is Dictionary else {}
		if not action.is_empty() and not bool(action.get("disabled", false)):
			return action_id
	return ""

func _battle_board_line_with_prefix(board_text: String, prefix: String) -> String:
	for raw_line in board_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with(prefix):
			return line
	return "%s unavailable." % prefix.trim_suffix(":")

func _battle_initiative_handoff_surface() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {}
	var battle := _session.battle
	var active_stack := BattleRules.get_active_stack(battle)
	var turn_order: Variant = battle.get("turn_order", [])
	if active_stack.is_empty() or not (turn_order is Array) or turn_order.is_empty():
		return {}
	var current_label := _battle_initiative_stack_label(active_stack)
	var current_side := _battle_initiative_side_label(String(active_stack.get("side", "")))
	var turn_index := clampi(int(battle.get("turn_index", 0)), 0, max(0, (turn_order as Array).size() - 1))
	var next_stack := _battle_next_living_stack(turn_order as Array, turn_index + 1)
	var next_round := false
	if next_stack.is_empty():
		next_stack = _battle_next_living_stack(turn_order as Array, 0)
		next_round = not next_stack.is_empty()
	var next_label := _battle_initiative_stack_label(next_stack) if not next_stack.is_empty() else "no queued stack"
	var next_side := _battle_initiative_side_label(String(next_stack.get("side", ""))) if not next_stack.is_empty() else "None"
	var round: int = max(1, int(battle.get("round", 1)))
	var next_round_label: int = round + 1 if next_round else round
	var current_window := "player command window" if String(active_stack.get("side", "")) == "player" else "enemy pressure window"
	var next_window := "next round opens" if next_round else "same round continues"
	var visible := "Initiative cue:\nNow: %s\nNext: %s" % [
		_short_text(current_label, BATTLE_ORDER_VISIBLE_STACK_CHAR_LIMIT),
		_short_text(next_label, BATTLE_ORDER_VISIBLE_STACK_CHAR_LIMIT),
	]
	var tooltip := "Initiative Handoff\n- Round: %d\n- Current: %s [%s]\n- Next: %s [%s], round %d\n- Handoff: %s; %s.\n- Player input: %s." % [
		round,
		current_label,
		current_side,
		next_label,
		next_side,
		next_round_label,
		current_window,
		next_window,
		"orders are open now" if String(active_stack.get("side", "")) == "player" else "wait for command to return",
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"current_stack": current_label,
		"current_side": current_side,
		"next_stack": next_label,
		"next_side": next_side,
		"round": round,
		"next_round": next_round_label,
		"handoff": "%s; %s" % [current_window, next_window],
	}

func _battle_next_living_stack(turn_order: Array, start_index: int) -> Dictionary:
	for index in range(max(0, start_index), turn_order.size()):
		var stack := _stack_by_battle_id(String(turn_order[index]))
		if not stack.is_empty() and int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			return stack
	return {}

func _battle_initiative_stack_label(stack: Dictionary) -> String:
	if stack.is_empty():
		return "no stack"
	var name := String(stack.get("name", "")).strip_edges()
	if name == "":
		name = String(stack.get("battle_id", "stack")).strip_edges()
	var count := int(stack.get("count", 0))
	var hp := int(stack.get("total_health", 0))
	if count > 0 and hp > 0:
		return "%s x%d, %d HP" % [name, count, hp]
	return name

func _battle_initiative_side_label(side: String) -> String:
	match side:
		"player":
			return "Player"
		"enemy":
			return "Enemy"
	return "Neutral"

func _living_enemy_target_ids() -> Array:
	var ids := []
	if _session == null or _session.battle.is_empty():
		return ids
	for stack_value in _session.battle.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		if String(stack.get("side", "")) != "enemy":
			continue
		if int(stack.get("count", 0)) <= 0 or int(stack.get("total_health", 0)) <= 0:
			continue
		var battle_id := String(stack.get("battle_id", "")).strip_edges()
		if battle_id != "":
			ids.append(battle_id)
	return ids

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))

func _refresh_save_slot_picker() -> void:
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
	var save_check := String(surface.get("save_check", ""))
	var save_handoff := String(surface.get("save_handoff", ""))
	var save_handoff_brief := String(surface.get("save_handoff_brief", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	var status_lines := []
	if save_handoff_brief != "":
		status_lines.append(save_handoff_brief)
	if latest_context != "":
		status_lines.append(latest_context)
	if status_lines.is_empty() and return_handoff != "":
		status_lines.append(return_handoff)
	_system_body_label.visible = not _compact_layout_active and not status_lines.is_empty()
	_system_body_label.text = "\n".join(status_lines.slice(0, min(2, status_lines.size())))
	var current_context := String(surface.get("current_context", ""))
	var save_tooltip_lines := [latest_context]
	if save_handoff != "":
		save_tooltip_lines.append(save_handoff)
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_system_body_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Battle"))
	_save_button.tooltip_text = _join_tooltip_sections([
		String(surface.get("save_button_tooltip", "Save the active battle safely.")),
		save_check,
		save_handoff,
	])
	_menu_button.text = String(surface.get("menu_button_label", "Main Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func validation_snapshot() -> Dictionary:
	if _session != null and _session.battle.is_empty() and _battle_board_view != null and _battle_board_view.has_method("set_battle_state"):
		_battle_board_view.set_battle_state(_session)
	var active_stack := BattleRules.get_active_stack(_session.battle)
	var target_stack := BattleRules.get_selected_target(_session.battle)
	var selected_click_intent := BattleRules.selected_target_board_click_intent(_session.battle)
	var selected_continuity_context := BattleRules.selected_target_continuity_context(_session.battle)
	var selected_closing_context := BattleRules.selected_target_closing_context(_session.battle)
	var selected_legality := BattleRules.selected_target_legality(_session.battle)
	var selected_direct_actionable := (
		selected_continuity_context.is_empty()
		and selected_closing_context.is_empty()
		and bool(selected_legality.get("attackable", false))
		and String(selected_click_intent.get("label", "")) != ""
	)
	var movement_click_intent := BattleRules.active_movement_board_click_intent(_session.battle)
	var context_value: Variant = _session.battle.get("context", {})
	var context: Dictionary = context_value if context_value is Dictionary else {}
	var player_roster := _normalize_string_array(BattleRules.roster_lines(_session.battle, "player"))
	var enemy_roster := _normalize_string_array(BattleRules.roster_lines(_session.battle, "enemy"))
	var action_surface := BattleRules.get_action_surface(_session)
	var consequence_payload := BattleRules.active_consequence_payload(_session)
	var action_confirmation := BattleRules.action_readiness_confirmation_payload(_session)
	var risk_board := BattleRules.describe_risk_readiness_board(_session)
	var risk_check := _battle_risk_check_cue_surface(risk_board, action_confirmation)
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
	var position_check := _battle_position_check_cue_surface()
	var engagement_check := _battle_engagement_check_cue_surface()
	var status_check := _battle_status_check_cue_surface()
	var spell_timing_board := BattleRules.describe_spell_timing_board(_session)
	var timing_check := _battle_timing_check_cue_surface(spell_timing_board)
	var objective_check := BattleRules.objective_check_cue_payload(_session)
	var intent_forecast := BattleRules.intent_forecast_payload(_session)
	var stack_check := _battle_stack_check_cue_surface()
	var dispatch_text := BattleRules.describe_dispatch(_session, _last_message)
	if _last_message.strip_edges() == "" and _tactical_briefing_text != "":
		dispatch_text = _tactical_briefing_text
	var presentation_event := BattleRules.latest_animation_event_presentation_payload(_session)
	var presentation_stream_text := BattleRules.describe_battle_presentation_stream(_session, 4)
	var action_context_surface := _battle_action_context_surface(dispatch_text, action_confirmation)
	return {
		"scene_path": scene_file_path,
		"quick_resolve_confirmation": validation_quick_resolve_confirmation_snapshot(),
		"battle_info_tab_navigation": validation_battle_info_tab_navigation_snapshot(),
		"battle_playback_speed": validation_battle_playback_speed_snapshot(),
		"battle_resolution_checkpoint": validation_battle_resolution_checkpoint_snapshot(),
		"briefing_consumption_autosave": validation_briefing_consumption_autosave_snapshot(),
		"manual_save_overwrite_dialog": _manual_save_overwrite_dialog.validation_snapshot(),
		"return_to_menu_last_result": _last_return_to_menu_result.duplicate(true),
		"return_to_menu_visible_message": _last_message,
		"return_to_menu_focus_owner": _return_to_menu_focus_owner_name(),
		"return_to_menu_request_count": _validation_return_to_menu_request_count,
		"withdrawal_pending_action": _pending_withdrawal_action,
		"withdrawal_confirmation_visible": _withdrawal_confirmation_dialog.visible,
		"withdrawal_confirmation_title": _withdrawal_confirmation_dialog.title,
		"withdrawal_confirmation_text": _withdrawal_confirmation_dialog.dialog_text,
		"withdrawal_confirmation_ok_text": _withdrawal_confirmation_dialog.get_ok_button().text,
		"withdrawal_confirmation_cancel_text": _withdrawal_confirmation_dialog.get_cancel_button().text,
		"withdrawal_last_result": _last_withdrawal_confirmation_result.duplicate(true),
		"validation_perform_action_counts": _validation_perform_action_counts.duplicate(true),
		"validation_battle_resolution_attempt_count": _validation_battle_resolution_attempt_count,
		"validation_last_battle_resolution_route": _validation_last_battle_resolution_route.duplicate(true),
		"music_audio": MusicAudio.validation_summary(),
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"scenario_status": _session.scenario_status,
		"game_state": _session.game_state,
		"encounter_id": String(_session.battle.get("encounter_id", "")),
		"encounter_name": String(_session.battle.get("encounter_name", "")),
		"entry_context": BattleRules.describe_entry_context(_session),
		"battle_context_type": String(context.get("type", "")),
		"battle_context_town_placement_id": String(context.get("town_placement_id", "")),
		"battle_context_trigger_faction_id": String(context.get("trigger_faction_id", "")),
		"round": int(_session.battle.get("round", 0)),
		"distance": int(_session.battle.get("distance", 0)),
		"active_side": String(active_stack.get("side", "")),
		"active_stack": String(active_stack.get("name", "")),
		"selected_target_battle_id": String(target_stack.get("battle_id", "")),
		"target_stack": String(target_stack.get("name", "")),
		"selected_target_board_click_intent": selected_click_intent,
		"selected_target_board_click_action": String(selected_click_intent.get("action", "")),
		"selected_target_board_click_label": String(selected_click_intent.get("label", "")),
		"selected_target_direct_actionable": selected_direct_actionable,
		"selected_target_continuity_context": selected_continuity_context,
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_closing_context": selected_closing_context,
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"active_movement_board_click_intent": movement_click_intent,
		"active_movement_board_click_action": String(movement_click_intent.get("action", "")),
		"active_movement_board_click_label": String(movement_click_intent.get("label", "")),
		"target_handoff": target_handoff,
		"target_handoff_visible_text": String(target_handoff.get("visible_text", "")),
		"target_handoff_tooltip_text": String(target_handoff.get("tooltip_text", "")),
		"position_check": position_check,
		"position_check_visible_text": String(position_check.get("visible_text", "")),
		"position_check_tooltip_text": String(position_check.get("tooltip_text", "")),
		"objective_check": objective_check,
		"objective_check_visible_text": String(objective_check.get("visible_text", "")),
		"objective_check_tooltip_text": String(objective_check.get("tooltip_text", "")),
		"intent_forecast": intent_forecast,
		"intent_forecast_visible_text": String(intent_forecast.get("visible_text", "")),
		"intent_forecast_tooltip_text": String(intent_forecast.get("tooltip_text", "")),
		"target_cycle_cue": _battle_target_cycle_cue_surface(
			String(active_stack.get("side", "")) == "player",
			active_stack,
			target_stack,
			BattleRules.legal_attack_target_ids_for_active_stack(_session.battle),
			enemy_roster.size()
		),
		"prev_target_text": _prev_target_button.text,
		"next_target_text": _next_target_button.text,
		"prev_target_tooltip": _prev_target_button.tooltip_text,
		"next_target_tooltip": _next_target_button.tooltip_text,
		"action_surface": action_surface,
		"action_confirmation": action_confirmation,
		"action_confirmation_text": String(action_confirmation.get("visible_text", "")),
		"action_confirmation_tooltip_text": String(action_confirmation.get("tooltip_text", "")),
		"risk_board": risk_board,
		"risk_check": risk_check,
		"risk_check_visible_text": String(risk_check.get("visible_text", "")),
		"risk_check_tooltip_text": String(risk_check.get("tooltip_text", "")),
		"risk_visible_text": _risk_label.text,
		"risk_tooltip_text": _risk_label.tooltip_text,
		"action_guidance": BattleRules.describe_action_surface(_session),
		"visible_action_guidance": _action_guide.text,
		"target_context": BattleRules.describe_target_context(_session),
		"engagement_check": engagement_check,
		"engagement_check_visible_text": String(engagement_check.get("visible_text", "")),
		"engagement_check_tooltip_text": String(engagement_check.get("tooltip_text", "")),
		"target_visible_text": _target_label.text,
		"target_tooltip_text": _target_label.tooltip_text,
		"status_check": status_check,
		"status_check_visible_text": String(status_check.get("visible_text", "")),
		"status_check_tooltip_text": String(status_check.get("tooltip_text", "")),
		"effect_visible_text": _effect_label.text,
		"effect_tooltip_text": _effect_label.tooltip_text,
		"timing_check": timing_check,
		"timing_check_visible_text": String(timing_check.get("visible_text", "")),
		"timing_check_tooltip_text": String(timing_check.get("tooltip_text", "")),
		"stack_check": stack_check,
		"stack_check_visible_text": String(stack_check.get("visible_text", "")),
		"stack_check_tooltip_text": String(stack_check.get("tooltip_text", "")),
		"active_visible_text": _active_label.text,
		"active_tooltip_text": _active_label.tooltip_text,
		"initiative_handoff": _battle_initiative_handoff_surface(),
		"initiative_handoff_visible_text": String(_battle_initiative_handoff_surface().get("visible_text", "")),
		"initiative_handoff_tooltip_text": _initiative_label.tooltip_text,
		"initiative_visible_text": _initiative_label.text,
		"active_consequence_payload": consequence_payload,
		"battle_action_context": action_context_surface,
		"battle_action_context_text": String(action_context_surface.get("visible_text", "")),
		"battle_action_context_tooltip_text": String(action_context_surface.get("tooltip_text", "")),
		"battle_presentation_event": presentation_event,
		"battle_presentation_event_visible_text": String(presentation_event.get("visible_text", "")),
		"battle_presentation_event_tooltip_text": String(presentation_event.get("tooltip_text", "")),
		"battle_presentation_event_source": String(presentation_event.get("source", "")),
		"battle_presentation_event_id": String(presentation_event.get("event_id", "")),
		"battle_presentation_events": BattleRules.battle_presentation_event_stream(_session.battle),
		"battle_presentation_stream_text": presentation_stream_text,
		"battle_presentation_speed": BattleRules.battle_presentation_speed(_session),
		"battle_tab_readiness": _battle_tab_readiness_payload(),
		"battle_tab_titles": _battle_tab_titles(),
		"battle_tab_readiness_tooltip_text": _battle_tabs.tooltip_text,
		"battle_active_tab": _battle_tabs.current_tab,
		"post_action_recap": _last_action_recap_payload.duplicate(true),
		"post_action_recap_text": _last_action_recap_text,
		"event_visible_text": _event_label.text,
		"event_tooltip_text": _event_label.tooltip_text,
		"visible_consequence_text": _consequence_label.text,
		"consequence_tooltip_text": _consequence_label.tooltip_text,
		"active_ability_role": String(consequence_payload.get("active_ability_role", "")),
		"active_status_pressure": String(consequence_payload.get("status_pressure", "")),
		"active_target_range": String(consequence_payload.get("target_range", "")),
		"advance_text": _advance_button.text,
		"strike_text": _strike_button.text,
		"shoot_text": _shoot_button.text,
		"defend_text": _defend_button.text,
		"quick_resolve_text": _quick_resolve_button.text,
		"retreat_text": _retreat_button.text,
		"surrender_text": _surrender_button.text,
		"advance_tooltip": _advance_button.tooltip_text,
		"strike_tooltip": _strike_button.tooltip_text,
		"shoot_tooltip": _shoot_button.tooltip_text,
		"defend_tooltip": _defend_button.tooltip_text,
		"quick_resolve_tooltip": _quick_resolve_button.tooltip_text,
		"quick_resolve_disabled": _quick_resolve_button.disabled,
		"quick_resolve_confirmation_text": _quick_resolve_confirmation_dialog.dialog_text,
		"retreat_tooltip": _retreat_button.tooltip_text,
		"surrender_tooltip": _surrender_button.tooltip_text,
		"battle_exit_order_cues": _battle_exit_order_cue_surface(action_surface),
		"battle_order_button_surfaces": _battle_order_button_surfaces(),
		"player_stack_count": player_roster.size(),
		"enemy_stack_count": enemy_roster.size(),
		"player_roster": player_roster,
		"enemy_roster": enemy_roster,
		"player_commander_text": BattleRules.describe_commander_summary(_session, "player"),
		"player_commander_portrait": _player_commander_portrait.validation_snapshot(),
		"player_commander_visible_text": _player_command_label.text,
		"player_commander_tooltip_text": _player_command_label.tooltip_text,
		"spellbook_text": BattleRules.describe_spellbook(_session),
		"spellbook_visible_text": _spell_label.text,
		"spellbook_tooltip_text": _spell_label.tooltip_text,
		"spell_actions": _duplicate_action_array(BattleRules.get_spell_actions(_session)),
		"spell_action_button_surfaces": _spell_action_button_surfaces(),
		"spell_timing_text": spell_timing_board,
		"spell_timing_visible_text": _timing_label.text,
		"spell_timing_tooltip_text": _timing_label.tooltip_text,
		"enemy_commander_text": BattleRules.describe_commander_summary(_session, "enemy"),
		"enemy_commander_portrait": _enemy_commander_portrait.validation_snapshot(),
		"enemy_commander_visible_text": _enemy_command_label.text,
		"enemy_commander_tooltip_text": _enemy_command_label.tooltip_text,
		"battle_board": _battle_board_view.validation_hex_layout_summary() if _battle_board_view.has_method("validation_hex_layout_summary") else {},
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"save_surface": AppRouter.active_save_surface(),
		"save_handoff_visible_text": _system_body_label.text,
		"save_handoff_visible": _system_body_label.visible,
		"save_button_text": _save_button.text,
		"save_button_tooltip_text": _save_button.tooltip_text,
		"save_status_visible_text": _system_body_label.text,
		"save_status_tooltip_text": _system_body_label.tooltip_text,
	}


func _battle_player_hero_id() -> String:
	var source = _session.battle.get("player_commander_source", {})
	if source is Dictionary and String(source.get("hero_id", "")) != "":
		return String(source.get("hero_id", ""))
	var hero = _session.battle.get("player_commander_state", {})
	return String(hero.get("id", "")) if hero is Dictionary else ""


func _battle_enemy_hero_id() -> String:
	var hero = _session.battle.get("enemy_hero", {})
	return String(hero.get("id", "")) if hero is Dictionary else ""

func validation_reset_battle_info_tab_navigation_state() -> Dictionary:
	_validation_battle_info_tab_resetting = true
	_battle_tabs.current_tab = 0
	_last_battle_info_tab_index = _battle_tabs.current_tab
	_validation_battle_info_tab_resetting = false
	_validation_battle_info_tab_change_sequence = 0
	_validation_battle_info_tab_change_count = 0
	_validation_battle_info_tab_focus_retention_count = 0
	_validation_battle_info_tab_boundary_retain_count = 0
	_last_battle_info_tab_change_result = {}
	return validation_battle_info_tab_navigation_snapshot()

func validation_battle_info_tab_navigation_snapshot() -> Dictionary:
	var tab_bar := _battle_tabs.get_tab_bar()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	return {
		"active_tab": _battle_tabs.current_tab,
		"tab_count": _battle_tabs.get_tab_count(),
		"tab_titles": _battle_tab_titles(),
		"tab_bar_name": String(tab_bar.name) if tab_bar != null else "",
		"tab_bar_focus_mode": tab_bar.focus_mode if tab_bar != null else Control.FOCUS_NONE,
		"tab_bar_boundary_policy": "retain",
		"tab_bar_has_focus": focus_owner == tab_bar,
		"tab_bar_focus_owner": String(focus_owner.name) if focus_owner == tab_bar else "",
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"change_sequence": _validation_battle_info_tab_change_sequence,
		"change_count": _validation_battle_info_tab_change_count,
		"focus_retention_count": _validation_battle_info_tab_focus_retention_count,
		"boundary_retain_count": _validation_battle_info_tab_boundary_retain_count,
		"last_change_result": _last_battle_info_tab_change_result.duplicate(true),
		"focus_cycle_names": _last_battle_keyboard_focus_cycle_names.duplicate(),
		"focus_cycle_count": _last_battle_keyboard_focus_cycle_names.size(),
		"tab_bar_occurrences": _last_battle_keyboard_focus_tab_bar_occurrences,
	}

func validation_briefing_consumption_autosave_snapshot() -> Dictionary:
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var briefing_first_line := ""
	for raw_line in _tactical_briefing_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line != "":
			briefing_first_line = line
			break
	var visible_surface := "%s\n%s" % [_event_label.text, _event_label.tooltip_text]
	var raw_autosave_result := {}
	var raw_result_value: Variant = _last_briefing_consumption_autosave_result.get("save_result", {})
	if raw_result_value is Dictionary:
		raw_autosave_result = raw_result_value.duplicate(true)
	return {
		"briefing_consumed": _validation_briefing_consumption_save_attempt_count > 0,
		"failure_pending": _briefing_consumption_autosave_failure_pending,
		"briefing_shown": _tactical_briefing_is_shown(),
		"briefing_active": _tactical_briefing_text.strip_edges() != "",
		"briefing_visible": briefing_first_line != "" and briefing_first_line in visible_surface,
		"briefing_title": "Briefing",
		"briefing_text": _tactical_briefing_text.strip_edges().left(800),
		"visible_message": _last_message.strip_edges().left(220),
		"visible_action_feedback": _system_body_label.text.left(800),
		"event_visible_text": _event_label.text.left(800),
		"save_button_text": _save_button.text,
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"consumption_count": _validation_briefing_consumption_save_attempt_count,
		"autosave_attempt_count": _validation_briefing_consumption_save_attempt_count,
		"autosave_success_count": _validation_briefing_consumption_save_success_count,
		"autosave_failure_count": _validation_briefing_consumption_save_failure_count,
		"save_attempt_count": _validation_briefing_consumption_save_attempt_count,
		"save_success_count": _validation_briefing_consumption_save_success_count,
		"save_failure_count": _validation_briefing_consumption_save_failure_count,
		"generated_defer_count": 0,
		"last_autosave_result": raw_autosave_result,
		"last_result": _last_briefing_consumption_autosave_result.duplicate(true),
		"last_runtime_issue": _last_briefing_consumption_runtime_issue.duplicate(true),
		"resolution_route_attempt_count": _validation_battle_resolution_attempt_count,
		"last_resolution_route": _validation_last_battle_resolution_route.duplicate(true),
		"scenario_status": _session.scenario_status if _session != null else "",
		"game_state": _session.game_state if _session != null else "",
		"day": _session.day if _session != null else 0,
		"generated_random_map": bool(_session.flags.get("generated_random_map", false)) if _session != null else false,
	}

func validation_set_battle_presentation_speed(speed: String) -> Dictionary:
	return _set_battle_presentation_speed(speed)

func validation_request_quick_resolve_confirmation() -> Dictionary:
	return _on_quick_resolve_pressed()

func validation_cancel_quick_resolve_confirmation() -> Dictionary:
	return _on_quick_resolve_canceled()

func validation_confirm_quick_resolve_confirmation() -> Dictionary:
	if not _quick_resolve_confirmation_pending:
		return {
			"ok": false,
			"confirmed": false,
			"pending": false,
			"performed": false,
			"reason": "no_pending_confirmation",
		}
	_on_quick_resolve_confirmed()
	return _last_quick_resolve_confirmation_result.duplicate(true)

func validation_reset_quick_resolve_confirmation_state() -> void:
	_quick_resolve_confirmation_dialog.hide()
	_quick_resolve_confirmation_pending = false
	_quick_resolve_confirmation_focus_origin = null
	_last_quick_resolve_confirmation_result = {}
	_validation_quick_resolve_confirmation_request_count = 0
	_validation_quick_resolve_confirmation_cancel_count = 0
	_validation_quick_resolve_confirmation_confirm_count = 0
	_validation_quick_resolve_confirmation_perform_count = 0

func validation_quick_resolve_confirmation_snapshot() -> Dictionary:
	var cancel_button := _quick_resolve_confirmation_dialog.get_cancel_button()
	var dialog_viewport := cancel_button.get_viewport() if cancel_button != null else null
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	var root_viewport := get_viewport()
	var origin_focus_owner := root_viewport.gui_get_focus_owner() if root_viewport != null else null
	return {
		"pending": _quick_resolve_confirmation_pending,
		"dialog_visible": _quick_resolve_confirmation_dialog.visible,
		"title": _quick_resolve_confirmation_dialog.title,
		"text": _quick_resolve_confirmation_dialog.dialog_text,
		"confirm_text": _quick_resolve_confirmation_dialog.get_ok_button().text,
		"cancel_text": cancel_button.text if cancel_button != null else "",
		"dialog_focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"focus_owner": String(dialog_focus_owner.name) if dialog_focus_owner != null else "",
		"origin_focus_owner": String(origin_focus_owner.name) if origin_focus_owner != null else "",
		"return_focus_name": String(_quick_resolve_confirmation_focus_origin.name) if is_instance_valid(_quick_resolve_confirmation_focus_origin) else "",
		"dialog_position": _quick_resolve_confirmation_dialog.position,
		"dialog_size": _quick_resolve_confirmation_dialog.size,
		"request_count": _validation_quick_resolve_confirmation_request_count,
		"cancel_count": _validation_quick_resolve_confirmation_cancel_count,
		"confirm_count": _validation_quick_resolve_confirmation_confirm_count,
		"perform_count": _validation_quick_resolve_confirmation_perform_count,
		"session_id": _session.session_id if _session != null else "",
		"scenario_id": _session.scenario_id if _session != null else "",
		"encounter_id": String(_session.battle.get("encounter_id", "")) if _session != null else "",
		"routed": _last_battle_resolution_routed,
		"last_result": _last_quick_resolve_confirmation_result.duplicate(true),
		"checkpoint": validation_battle_resolution_checkpoint_snapshot(),
	}

func validation_reset_battle_playback_speed_state() -> void:
	_last_battle_playback_speed_result = {}
	_validation_battle_playback_speed_request_count = 0
	_validation_battle_playback_speed_success_count = 0
	_validation_battle_playback_speed_failure_count = 0

func validation_battle_playback_speed_snapshot() -> Dictionary:
	var active_speed := BattleRules.battle_presentation_speed(_session)
	var committed_speed := SettingsService.battle_playback_speed_id()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var button_states := {}
	for speed_id in [BattleRules.PRESENTATION_SPEED_NORMAL, BattleRules.PRESENTATION_SPEED_FAST, BattleRules.PRESENTATION_SPEED_INSTANT]:
		var button := _battle_presentation_speed_button(speed_id)
		button_states[String(speed_id)] = {
			"name": String(button.name) if button != null else "",
			"disabled": button.disabled if button != null else true,
			"selected": String(speed_id) == active_speed,
			"tooltip": button.tooltip_text if button != null else "",
		}
	return {
		"request_count": _validation_battle_playback_speed_request_count,
		"success_count": _validation_battle_playback_speed_success_count,
		"failure_count": _validation_battle_playback_speed_failure_count,
		"last_result": _last_battle_playback_speed_result.duplicate(true),
		"requested_speed": String(_last_battle_playback_speed_result.get("requested_speed", "")),
		"active_speed": active_speed,
		"session_speed": active_speed,
		"committed_speed": committed_speed,
		"settings_speed": committed_speed,
		"selected_speed": active_speed,
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"button_states": button_states,
	}

func validation_reset_battle_resolution_checkpoint_state() -> void:
	_battle_resolution_checkpoint_pending = {}
	_last_battle_resolution_checkpoint_result = {}
	_last_battle_resolution_checkpoint_retry_result = {}
	_last_battle_resolution_route_result = {}
	_last_battle_resolution_routed = false
	_validation_battle_resolution_checkpoint_request_count = 0
	_validation_battle_resolution_checkpoint_success_count = 0
	_validation_battle_resolution_checkpoint_failure_count = 0
	_validation_battle_resolution_checkpoint_retry_count = 0
	_validation_battle_resolution_durable_route_count = 0
	if AppRouter.has_method("validation_reset_battle_resolution_checkpoint_state"):
		AppRouter.validation_reset_battle_resolution_checkpoint_state()

func validation_retry_battle_resolution_save() -> Dictionary:
	return _on_save_pressed()

func validation_battle_resolution_checkpoint_snapshot() -> Dictionary:
	var pending_result := {}
	var pending_value: Variant = _battle_resolution_checkpoint_pending.get("result", {})
	if pending_value is Dictionary:
		pending_result = pending_value.duplicate(true)
	var focus_owner := get_viewport().gui_get_focus_owner()
	var router_snapshot := {}
	if AppRouter.has_method("validation_battle_resolution_checkpoint_snapshot"):
		var router_value: Variant = AppRouter.validation_battle_resolution_checkpoint_snapshot()
		if router_value is Dictionary:
			router_snapshot = router_value.duplicate(true)
	return {
		"pending": not _battle_resolution_checkpoint_pending.is_empty(),
		"battle_resolved": _session != null and _session.battle.is_empty(),
		"pending_state": String(_battle_resolution_checkpoint_pending.get("state", "")),
		"pending_route_target": String(_battle_resolution_checkpoint_pending.get("route_target", "")),
		"pending_result": pending_result,
		"route_scheduled": _battle_exit_handoff_in_progress,
		"routed": _last_battle_resolution_routed,
		"checkpoint_request_count": _validation_battle_resolution_checkpoint_request_count,
		"checkpoint_success_count": _validation_battle_resolution_checkpoint_success_count,
		"checkpoint_failure_count": _validation_battle_resolution_checkpoint_failure_count,
		"checkpoint_retry_count": _validation_battle_resolution_checkpoint_retry_count,
		"durable_route_count": _validation_battle_resolution_durable_route_count,
		"visible_message": _last_message,
		"save_button_text": _save_button.text,
		"save_button_tooltip_text": _save_button.tooltip_text,
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"combat_inputs_disabled": _battle_resolution_combat_inputs_disabled(),
		"last_checkpoint_result": _last_battle_resolution_checkpoint_result.duplicate(true),
		"last_retry_result": _last_battle_resolution_checkpoint_retry_result.duplicate(true),
		"last_route_result": _last_battle_resolution_route_result.duplicate(true),
		"router_snapshot": router_snapshot,
	}

func _battle_resolution_combat_inputs_disabled() -> bool:
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _quick_resolve_button, _retreat_button, _surrender_button, _prev_target_button, _next_target_button]:
		if button != null and not button.disabled:
			return false
	for child in _spell_actions.get_children():
		if child is BaseButton and not child.disabled:
			return false
	return _battle_board_view == null or (
		_battle_board_view.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _battle_board_view.focus_mode == Control.FOCUS_NONE
	)

func validation_try_progress_action() -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "message": "No active battle is loaded for validation."}

	var active_stack := BattleRules.get_active_stack(_session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		var ready_result := BattleRules.resolve_if_battle_ready(_session)
		_last_message = String(ready_result.get("message", ""))
		if _handle_battle_resolution(ready_result):
			return {
				"ok": String(ready_result.get("state", "")) != "invalid",
				"action": "resolve_ready_state",
				"state": String(ready_result.get("state", "")),
				"message": _last_message,
			}
		_refresh()
		return {
			"ok": String(ready_result.get("state", "")) != "invalid",
			"action": "resolve_ready_state",
			"state": String(ready_result.get("state", "")),
			"message": _last_message,
		}

	var aligned_target_id := _align_validation_target()
	var spell_action := _preferred_validation_spell_action()
	if not spell_action.is_empty():
		var spell_id := String(spell_action.get("id", "")).trim_prefix("cast_spell:")
		var recap_context := BattleRules.post_action_recap_context(_session, String(spell_action.get("id", "")))
		var spell_result := BattleRules.cast_player_spell(_session, spell_id)
		_last_message = String(spell_result.get("message", ""))
		_record_action_recap(String(spell_action.get("id", "")), spell_result, recap_context)
		if bool(spell_result.get("ok", false)):
			_validation_spell_casts += 1
			_dismiss_tactical_briefing()
		if _handle_battle_resolution(spell_result):
			return {
				"ok": bool(spell_result.get("ok", false)),
				"action": "cast_spell",
				"action_id": String(spell_action.get("id", "")),
				"target_battle_id": aligned_target_id,
				"state": String(spell_result.get("state", "")),
				"message": _last_message,
				"post_action_recap": _last_action_recap_payload.duplicate(true),
				"post_action_recap_text": _last_action_recap_text,
			}
		_refresh()
		return {
			"ok": bool(spell_result.get("ok", false)),
			"action": "cast_spell",
			"action_id": String(spell_action.get("id", "")),
			"target_battle_id": aligned_target_id,
			"state": String(spell_result.get("state", "")),
			"message": _last_message,
			"post_action_recap": _last_action_recap_payload.duplicate(true),
			"post_action_recap_text": _last_action_recap_text,
		}

	var action_id := _preferred_validation_action_id()
	if action_id == "":
		return {"ok": false, "message": "No legal battle validation action is available."}
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var action_result := BattleRules.perform_player_action(_session, action_id)
	_last_message = String(action_result.get("message", ""))
	_record_action_recap(action_id, action_result, recap_context)
	if bool(action_result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(action_result):
		return {
			"ok": bool(action_result.get("ok", false)),
			"action": action_id,
			"target_battle_id": aligned_target_id,
			"state": String(action_result.get("state", "")),
			"message": _last_message,
			"post_action_recap": _last_action_recap_payload.duplicate(true),
			"post_action_recap_text": _last_action_recap_text,
		}
	_refresh()
	return {
		"ok": bool(action_result.get("ok", false)),
		"action": action_id,
		"target_battle_id": aligned_target_id,
		"state": String(action_result.get("state", "")),
		"message": _last_message,
		"post_action_recap": _last_action_recap_payload.duplicate(true),
		"post_action_recap_text": _last_action_recap_text,
	}

func validation_perform_action(action_id: String) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": action_id, "message": "No active battle is loaded for validation.", "state": "invalid"}
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var result := BattleRules.perform_player_action(_session, action_id)
	_last_message = String(result.get("message", ""))
	_record_action_recap(action_id, result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	var handled := _handle_battle_resolution(result)
	if not handled:
		_refresh()
	return _action_validation_response(action_id, result, _last_battle_resolution_routed if handled else false)

func validation_request_withdrawal(action_id: String) -> Dictionary:
	return _request_withdrawal_confirmation(action_id, _withdrawal_action_button(action_id))

func validation_cancel_withdrawal() -> Dictionary:
	return _cancel_withdrawal_confirmation()

func validation_confirm_withdrawal() -> Dictionary:
	return _on_withdrawal_confirmation_confirmed()

func validation_perform_board_stack_click(battle_id: String) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": "", "target_battle_id": battle_id, "message": "No active battle is loaded for validation.", "state": "invalid"}
	return _on_board_stack_focus_requested(battle_id)

func _action_validation_response(action_id: String, result: Dictionary, routed: bool) -> Dictionary:
	var selected_after := {}
	var selected_legality := {}
	var selected_click_intent := {}
	var selected_continuity_context := {}
	var selected_closing_context := {}
	var action_surface := {}
	var action_guidance := ""
	var target_context := ""
	var board_summary := {}
	var scenario_status := ""
	if _session != null:
		scenario_status = _session.scenario_status
		if not _session.battle.is_empty():
			selected_after = BattleRules.get_selected_target(_session.battle)
			selected_legality = BattleRules.selected_target_legality(_session.battle)
			selected_click_intent = BattleRules.selected_target_board_click_intent(_session.battle)
			selected_continuity_context = BattleRules.selected_target_continuity_context(_session.battle)
			selected_closing_context = BattleRules.selected_target_closing_context(_session.battle)
			action_surface = BattleRules.get_action_surface(_session)
			action_guidance = BattleRules.describe_action_surface(_session)
			target_context = BattleRules.describe_target_context(_session)
			if _battle_board_view != null and _battle_board_view.has_method("validation_hex_layout_summary"):
				board_summary = _battle_board_view.validation_hex_layout_summary()
	var selected_direct_actionable := (
		selected_continuity_context.is_empty()
		and selected_closing_context.is_empty()
		and bool(selected_legality.get("attackable", false))
		and String(selected_click_intent.get("label", "")) != ""
	)
	var response := result.duplicate(true)
	response["ok"] = bool(result.get("ok", false))
	response["action"] = action_id
	response["action_result"] = result.duplicate(true)
	if result.has("attack_action"):
		response["attack_result"] = result.duplicate(true)
	response["state"] = String(result.get("state", ""))
	response["scenario_status"] = scenario_status
	response["message"] = _last_message
	response["routed"] = routed
	response["selected_target_after_action_battle_id"] = String(selected_after.get("battle_id", ""))
	response["selected_target_after_action_name"] = String(selected_after.get("name", ""))
	response["selected_target_after_action_legality"] = selected_legality.duplicate(true)
	response["selected_target_after_action_board_click_intent"] = selected_click_intent.duplicate(true)
	response["selected_target_after_action_board_click_action"] = String(selected_click_intent.get("action", ""))
	response["selected_target_after_action_board_click_label"] = String(selected_click_intent.get("label", ""))
	response["selected_target_direct_actionable"] = selected_direct_actionable
	response["selected_target_direct_actionable_after_action"] = selected_direct_actionable
	response["selected_target_continuity_context"] = selected_continuity_context.duplicate(true)
	response["selected_target_preserved_setup"] = not selected_continuity_context.is_empty()
	response["selected_target_closing_context"] = selected_closing_context.duplicate(true)
	response["selected_target_closing_on_target"] = not selected_closing_context.is_empty()
	response["action_surface"] = action_surface
	response["action_guidance"] = action_guidance
	response["target_context"] = target_context
	response["active_consequence_payload"] = BattleRules.active_consequence_payload(_session) if _session != null and not _session.battle.is_empty() else {}
	response["post_action_recap"] = _last_action_recap_payload.duplicate(true)
	response["post_action_recap_text"] = _last_action_recap_text
	response["battle_board"] = board_summary
	return response

func _validation_battle_board_summary() -> Dictionary:
	if _battle_board_view != null and _battle_board_view.has_method("validation_hex_layout_summary"):
		return _battle_board_view.validation_hex_layout_summary()
	return {}

func _duplicate_action_array(actions: Variant) -> Array:
	var duplicated := []
	if not (actions is Array):
		return duplicated
	for action in actions:
		if action is Dictionary:
			duplicated.append(action.duplicate(true))
	return duplicated

func validation_perform_board_hex_click(q: int, r: int) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": "", "q": q, "r": r, "message": "No active battle is loaded for validation.", "state": "invalid"}
	return _on_board_hex_destination_requested(q, r)

func validation_cycle_target(direction: int) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": "cycle_target", "message": "No active battle is loaded for validation.", "state": "invalid"}
	var selected_before := String(BattleRules.get_selected_target(_session.battle).get("battle_id", ""))
	var continuity_before := BattleRules.selected_target_continuity_context(_session.battle)
	BattleRules.cycle_target(_session, direction)
	_refresh()
	var selected_after := BattleRules.get_selected_target(_session.battle)
	var continuity_after := BattleRules.selected_target_continuity_context(_session.battle)
	var closing_after := BattleRules.selected_target_closing_context(_session.battle)
	return {
		"ok": true,
		"action": "cycle_target",
		"direction": direction,
		"selected_target_before": selected_before,
		"selected_target_after": String(selected_after.get("battle_id", "")),
		"selected_target_continuity_before": continuity_before.duplicate(true),
		"selected_target_continuity_context": continuity_after.duplicate(true),
		"selected_target_preserved_setup": not continuity_after.is_empty(),
		"selected_target_closing_context": closing_after.duplicate(true),
		"selected_target_closing_on_target": not closing_after.is_empty(),
		"action_guidance": BattleRules.describe_action_surface(_session),
		"target_context": BattleRules.describe_target_context(_session),
		"battle_board": _battle_board_view.validation_hex_layout_summary() if _battle_board_view.has_method("validation_hex_layout_summary") else {},
		"state": "continue",
		"message": "Target focus cycled.",
	}

func validation_set_support_spell_priority(enabled: bool) -> bool:
	_validation_prioritize_support_spell = enabled
	return _validation_prioritize_support_spell == enabled

func validation_set_spell_casting_enabled(enabled: bool) -> bool:
	_validation_spell_casting_enabled = enabled
	return _validation_spell_casting_enabled == enabled

func validation_set_battle_resolution_routing_enabled(enabled: bool) -> bool:
	_validation_battle_resolution_routing_enabled = enabled
	return _validation_battle_resolution_routing_enabled == enabled

func validation_set_max_spell_casts(max_casts: int) -> bool:
	_validation_max_spell_casts = max(0, int(max_casts))
	return _validation_max_spell_casts == max(0, int(max_casts))

func validation_select_save_slot(slot: int) -> bool:
	var normalized_slot := int(slot)
	if not SaveService.get_manual_slot_ids().has(normalized_slot):
		return false
	SaveService.set_selected_manual_slot(normalized_slot)
	_refresh_save_slot_picker()
	return SaveService.get_selected_manual_slot() == normalized_slot

func validation_save_to_selected_slot() -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot()
	_commit_manual_save(selected_slot)
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_message,
	}

func validation_request_manual_save() -> Dictionary:
	_on_save_pressed()
	return _manual_save_overwrite_dialog.validation_snapshot()

func validation_confirm_manual_save_overwrite() -> Dictionary:
	var pending_slot := int(_manual_save_overwrite_dialog.validation_snapshot().get("pending_slot", 0))
	_on_manual_save_overwrite_confirmed()
	return {
		"pending_slot": pending_slot,
		"summary": SaveService.inspect_manual_slot(pending_slot) if SaveService.get_manual_slot_ids().has(pending_slot) else {},
		"message": _last_message,
	}

func validation_cancel_manual_save_overwrite() -> void:
	_on_manual_save_overwrite_canceled()

func validation_open_active_play_settings() -> Dictionary:
	_on_settings_pressed()
	return _active_play_settings_dialog.validation_snapshot()

func validation_active_play_settings_dialog():
	return _active_play_settings_dialog

func validation_return_to_menu() -> Dictionary:
	return _on_menu_pressed()

func validation_active_play_return_snapshot() -> Dictionary:
	return {
		"last_result": _last_return_to_menu_result.duplicate(true),
		"visible_message": _last_message,
		"focus_owner": _return_to_menu_focus_owner_name(),
		"request_count": _validation_return_to_menu_request_count,
		"scenario_id": _session.scenario_id,
		"resume_target": SaveService.resume_target_for_session(_session),
	}

func _return_to_menu_focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func _make_placeholder_label(text: String) -> Label:
	var label := FrontierVisualKit.placeholder_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size = Vector2(188.0, 24.0)
	label.tooltip_text = text
	return label

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, 96, false)

func _set_battle_action_guide(full_text: String) -> void:
	_action_guide_source_text = full_text
	_refit_battle_action_guide()
	_action_guide.tooltip_text = full_text

func _refit_battle_action_guide() -> void:
	if _action_guide_source_text == "":
		return
	var visible_lines: Array[String] = []
	for raw_line in _action_guide_source_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line != "":
			visible_lines.append(_battle_action_context_word_text(line, 96))
	var line_limit := 2 if _compact_layout_active else 3
	_action_guide.text = "\n".join(visible_lines.slice(0, min(line_limit, visible_lines.size())))

func _set_battle_event_compact_label(full_text: String, max_lines: int) -> void:
	_event_label.tooltip_text = full_text
	_event_label.text = _battle_event_compact_text(full_text, max_lines, 96)

func _battle_event_compact_text(full_text: String, max_lines: int, max_chars: int) -> String:
	var lines: Array[String] = []
	for raw_line in full_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		if line.begins_with("- "):
			line = line.trim_prefix("- ").strip_edges()
		lines.append(_battle_action_context_word_text(line, max_chars))
	if lines.is_empty():
		return full_text.strip_edges()
	if lines.size() > max_lines:
		var hidden := lines.size() - max_lines
		lines = lines.slice(0, max_lines)
		lines.append("+ %d more" % hidden)
	return "\n".join(lines)

func _set_single_line_label(label: Label, full_text: String, max_chars: int = 96) -> void:
	label.tooltip_text = full_text
	var lines := full_text.split("\n", false)
	for raw_line in lines:
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		if line.length() > max_chars:
			line = "%s..." % line.left(max_chars - 3)
		label.text = line
		return
	label.text = full_text.strip_edges()

func _apply_responsive_layout() -> void:
	if _sidebar_shell_panel == null:
		return
	var available_size := size
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		available_size = parent_control.size
	var compact_layout := available_size.x < 1360.0 or available_size.y < 760.0
	_compact_layout_active = compact_layout
	_refit_battle_action_guide()
	_sidebar_shell_panel.visible = not compact_layout
	_battle_context_label.visible = not compact_layout
	_event_label.visible = not compact_layout
	_status_label.visible = not compact_layout
	_pressure_label.visible = not compact_layout
	_footer_row.columns = 1 if compact_layout else 2
	_footer_row.add_theme_constant_override("v_separation", 0 if compact_layout else 8)
	_action_pad.add_theme_constant_override("margin_top", 0 if compact_layout else 6)
	_action_pad.add_theme_constant_override("margin_bottom", 0 if compact_layout else 6)
	if compact_layout:
		_system_panel.add_theme_stylebox_override("panel", _compact_system_panel_style)
	else:
		_system_panel.remove_theme_stylebox_override("panel")
	_system_panel.visible = true
	_system_pad.add_theme_constant_override("margin_top", 0 if compact_layout else 6)
	_system_pad.add_theme_constant_override("margin_bottom", 0 if compact_layout else 6)
	_system_body_label.visible = not compact_layout and not _system_body_label.text.strip_edges().is_empty()
	_speed_bar.visible = not compact_layout
	_prev_target_button.visible = not compact_layout
	_next_target_button.visible = not compact_layout
	_battle_board_view.custom_minimum_size = Vector2(520.0, 240.0) if compact_layout else Vector2(620.0, 300.0)

func _record_action_recap(action_id: String, result: Dictionary, context: Dictionary = {}) -> void:
	if not bool(result.get("ok", false)):
		_last_action_recap_payload = {}
		_last_action_recap_text = ""
		return
	_last_action_recap_payload = BattleRules.post_action_recap_payload(_session, result, action_id, context)
	_last_action_recap_text = String(_last_action_recap_payload.get("text", ""))
	if not _last_action_recap_payload.is_empty():
		_session.flags["last_battle_action_recap"] = _last_action_recap_payload.duplicate(true)

func _battle_consequence_text() -> String:
	if _last_action_recap_text.strip_edges() != "":
		return _last_action_recap_text
	return BattleRules.describe_order_consequence_board(_session)

func _battle_action_context_surface(dispatch_text: String = "", action_confirmation: Dictionary = {}) -> Dictionary:
	if _last_action_recap_payload.is_empty():
		return {}
	var latest_action := String(_last_action_recap_payload.get("happened", "")).strip_edges()
	if latest_action == "":
		latest_action = String(_last_message).strip_edges()
	if latest_action == "":
		return {}
	var next_step := String(_last_action_recap_payload.get("next_step", "")).strip_edges()
	if next_step == "" and not action_confirmation.is_empty():
		next_step = String(action_confirmation.get("next_step", action_confirmation.get("visible_text", ""))).strip_edges()
	if next_step == "":
		next_step = "Choose the next legal battle order."
	var handoff_check := _battle_action_handoff_check(next_step, action_confirmation)
	var visible := "Latest: %s" % _battle_action_context_word_text(latest_action, 38)
	if next_step != "":
		visible = "%s | Next: %s" % [
			visible,
			_battle_action_context_word_text(next_step.trim_suffix("."), 34),
		]
	var tooltip := _join_tooltip_sections([
		"Battle Turn Context\n- Latest action: %s\n- Next practical step: %s\n- Handoff check: %s" % [
			latest_action,
			next_step,
			handoff_check,
		],
		String(_last_action_recap_payload.get("tooltip_text", _last_action_recap_payload.get("tooltip", ""))),
		String(action_confirmation.get("tooltip_text", "")),
		dispatch_text,
	])
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"latest_action": latest_action,
		"next_step": next_step,
		"handoff_check": handoff_check,
		"source": "post_action_recap",
	}

func _battle_action_context_word_text(text: String, max_chars: int) -> String:
	var cleaned := _strip_sentence(text)
	if max_chars <= 0:
		return ""
	if cleaned.length() <= max_chars:
		return cleaned
	if max_chars == 1:
		return "…"
	var prefix := cleaned.left(max_chars - 1).strip_edges()
	var boundary := prefix.rfind(" ")
	if boundary <= 0:
		return "…"
	var fitted := prefix.left(boundary).strip_edges()
	var trailing_connectors := ["a", "an", "the", "to", "of", "and", "or", "for", "with", "from"]
	while fitted.contains(" ") and fitted.get_slice(" ", fitted.get_slice_count(" ") - 1).to_lower() in trailing_connectors:
		fitted = fitted.left(fitted.rfind(" ")).strip_edges()
	return "%s…" % fitted if fitted != "" else "…"

func _battle_action_handoff_check(next_step: String, action_confirmation: Dictionary = {}) -> String:
	var cleaned_next := _strip_sentence(next_step).trim_suffix(".")
	if cleaned_next == "":
		cleaned_next = "choose the next legal battle order"
	var ready_text := _strip_sentence(String(action_confirmation.get("visible_text", ""))).trim_suffix(".")
	if ready_text != "":
		return "%s; %s." % [cleaned_next.capitalize(), ready_text]
	return "%s before returning to field, menu, or outcome flow." % cleaned_next.capitalize()

func _append_last_action_tooltips() -> void:
	var recap_tooltip := String(_last_action_recap_payload.get("tooltip", "")).strip_edges()
	if recap_tooltip == "":
		return
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button]:
		button.tooltip_text = "%s\nLast order: %s" % [button.tooltip_text, recap_tooltip]

func _battle_order_button_text(action: Dictionary) -> String:
	var label := String(action.get("label", "Order")).strip_edges()
	var readiness := _battle_order_readiness_label(action)
	if readiness == "":
		return label
	return "%s | %s" % [_short_text(label, 18), readiness]

func _battle_order_readiness_label(action: Dictionary) -> String:
	var readiness := String(action.get("readiness", "")).strip_edges()
	if readiness.begins_with("Ready"):
		return "Ready"
	if readiness.begins_with("Blocked"):
		return "Blocked"
	return "Blocked" if bool(action.get("disabled", false)) else "Ready"

func _battle_order_button_tooltip(action: Dictionary) -> String:
	var label := String(action.get("label", "Order")).strip_edges()
	var readiness := _battle_order_readiness_label(action)
	var target := String(action.get("target", "")).strip_edges()
	var range_text := String(action.get("range", "")).strip_edges()
	var why := String(action.get("why", "")).strip_edges()
	var next := String(action.get("confirmation", action.get("consequence", ""))).strip_edges()
	return _join_tooltip_sections([
		"Order cue: %s\n- Readiness: %s\n- Target: %s\n- Range: %s\n- Why: %s\n- Next: %s" % [
			label,
			readiness,
			target if target != "" else "Current battle focus",
			range_text if range_text != "" else "Current range",
			why if why != "" else String(action.get("summary", "Use this order when it fits the current exchange.")),
			next if next != "" else "Confirming spends this stack's action.",
		],
	])

func _battle_spell_action_button_text(action: Dictionary) -> String:
	var label := String(action.get("label", action.get("id", "Spell"))).strip_edges()
	if label.begins_with("Cast "):
		label = label.trim_prefix("Cast ")
	var readiness := _spell_action_readiness_label(action)
	if readiness == "":
		return label
	return "%s | %s" % [_short_text(label, 24), readiness]

func _battle_spell_action_tooltip(action: Dictionary) -> String:
	var label := String(action.get("label", action.get("id", "Spell"))).strip_edges()
	var readiness := String(action.get("readiness", "")).strip_edges()
	if readiness == "":
		readiness = "Ready" if not bool(action.get("disabled", false)) else "Blocked"
	var next_step := "Casting consumes the commander spell window for this round and returns to stack orders."
	if bool(action.get("disabled", false)):
		next_step = "Retarget, wait for mana, or use a stack order instead."
	var cost_text := "%d mana" % int(action.get("cost", 0))
	return _join_tooltip_sections([
		"Spell action: %s\n- Readiness: %s\n- Target: %s\n- Cost: %s\n- Use: %s\n- Effect: %s\n- Next: %s" % [
			label,
			readiness,
			String(action.get("target", "current battle focus")),
			cost_text,
			String(action.get("best_use", "Use when this spell improves the current exchange.")),
			String(action.get("effect", "Spell effect is described in the spellbook.")),
			next_step,
		],
		String(action.get("summary", "")),
	])

func _spell_action_readiness_label(action: Dictionary) -> String:
	var readiness := String(action.get("readiness", "")).strip_edges()
	if readiness.begins_with("Blocked"):
		return "Blocked"
	if readiness != "":
		return "Ready"
	return "Ready" if not bool(action.get("disabled", false)) else "Blocked"

func _spell_action_button_surfaces() -> Array:
	var surfaces := []
	for child in _spell_actions.get_children():
		if child is Button:
			var button: Button = child
			surfaces.append({
				"text": button.text,
				"tooltip": button.tooltip_text,
				"disabled": button.disabled,
			})
	return surfaces

func _battle_order_button_surfaces() -> Array:
	var surfaces := []
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button]:
		surfaces.append({
			"text": button.text,
			"tooltip": button.tooltip_text,
			"disabled": button.disabled,
		})
	return surfaces

func _refresh_battle_tab_cues() -> void:
	var payload := _battle_tab_readiness_payload()
	var tabs: Array = payload.get("tabs", [])
	for index in range(min(_battle_tabs.get_tab_count(), BATTLE_INFO_TAB_VISIBLE_TITLES.size())):
		_battle_tabs.set_tab_title(index, String(BATTLE_INFO_TAB_VISIBLE_TITLES[index]))
	_battle_tabs.tooltip_text = String(payload.get("tooltip_text", ""))
	_sync_battle_info_tab_tooltip()

func _battle_tab_readiness_payload() -> Dictionary:
	var action_surface := BattleRules.get_action_surface(_session)
	var active_stack := BattleRules.get_active_stack(_session.battle)
	var target_stack := BattleRules.get_selected_target(_session.battle)
	var selected_legality := BattleRules.selected_target_legality(_session.battle)
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
	var spell_actions := BattleRules.get_spell_actions(_session)
	var order_actions := _battle_core_order_actions(action_surface)
	var focus_ready := 0
	var focus_total := 0
	if not target_stack.is_empty():
		focus_total = 1
		if bool(selected_legality.get("attackable", false)):
			focus_ready = 1
	var active_side := String(active_stack.get("side", ""))
	var timing_ready := 1 if active_side == "player" else 0
	var timing_total := 1 if not active_stack.is_empty() else 0
	var tabs := [
		_battle_tab_readiness_entry("Order", order_actions, "stack orders", _battle_order_tab_focus(order_actions)),
		_battle_tab_readiness_entry_from_counts(
			"Focus",
			focus_ready,
			focus_total,
			"selected target",
			_battle_focus_tab_focus(target_stack, selected_legality, target_handoff)
		),
		_battle_tab_readiness_entry("Spells", spell_actions, "battle spells", _battle_spell_tab_focus(spell_actions)),
		_battle_tab_readiness_entry_from_counts(
			"Timing",
			timing_ready,
			timing_total,
			"turn timing",
			_battle_timing_tab_focus(active_stack)
		),
	]
	var selected_index := clampi(_battle_tabs.current_tab, 0, max(0, tabs.size() - 1))
	var selected: Dictionary = tabs[selected_index] if selected_index < tabs.size() else {}
	var tooltip_lines := ["Battle command tabs:"]
	for tab in tabs:
		tooltip_lines.append("- %s" % String(tab.get("summary", "")))
	if not selected.is_empty():
		tooltip_lines.append("Selected: %s" % String(selected.get("focus", "")))
	return {
		"tabs": tabs,
		"selected_tab": selected.duplicate(true),
		"tooltip_text": "\n".join(tooltip_lines),
	}

func _battle_core_order_actions(action_surface: Dictionary) -> Array:
	var actions := []
	for action_id in ["advance", "strike", "shoot", "defend"]:
		var action_value: Variant = action_surface.get(action_id, {})
		if action_value is Dictionary:
			actions.append((action_value as Dictionary).duplicate(true))
	return actions

func _battle_tab_readiness_entry(base_title: String, actions: Variant, noun: String, focus_detail: String) -> Dictionary:
	var total := 0
	var ready := 0
	if actions is Array:
		for action in actions:
			if not (action is Dictionary):
				continue
			total += 1
			if not bool(action.get("disabled", false)):
				ready += 1
	return _battle_tab_readiness_entry_from_counts(base_title, ready, total, noun, focus_detail)

func _battle_tab_readiness_entry_from_counts(
	base_title: String,
	ready: int,
	total: int,
	noun: String,
	focus_detail: String
) -> Dictionary:
	var title := base_title
	if ready > 0:
		title = "%s %d" % [base_title, ready]
	var summary := "%s: %d ready of %d %s" % [base_title, ready, total, noun]
	var focus := "%s has %d ready %s." % [
		base_title,
		ready,
		noun,
	]
	if ready <= 0 and total > 0:
		focus = "%s has %d blocked or waiting %s." % [
			base_title,
			total,
			noun,
		]
	elif total <= 0:
		focus = "%s has no listed %s." % [base_title, noun]
	if focus_detail.strip_edges() != "":
		focus = "%s %s" % [focus, focus_detail.strip_edges()]
	return {
		"base_title": base_title,
		"title": title,
		"ready_count": ready,
		"total_count": total,
		"summary": summary,
		"focus": focus,
	}

func _battle_order_tab_focus(order_actions: Array) -> String:
	var ready_labels := []
	for action in order_actions:
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var label := String(action.get("label", "")).strip_edges()
		if label != "":
			ready_labels.append(label)
	if ready_labels.is_empty():
		return "Use the visible order buttons to inspect why orders are blocked."
	return "Ready: %s." % ", ".join(ready_labels.slice(0, min(3, ready_labels.size())))

func _battle_focus_tab_focus(target_stack: Dictionary, selected_legality: Dictionary, target_handoff: Dictionary) -> String:
	var target_name := String(target_stack.get("name", "")).strip_edges()
	if target_name == "":
		target_name = "No target selected"
	var state := "attackable" if bool(selected_legality.get("attackable", false)) else "not attackable"
	var cue := String(target_handoff.get("visible_text", "")).strip_edges()
	if cue == "":
		cue = BattleRules.describe_target_context(_session)
	return "Target: %s (%s). %s" % [_short_text(target_name, 28), state, _short_text(cue, 72)]

func _battle_spell_tab_focus(spell_actions: Array) -> String:
	if spell_actions.is_empty():
		return "No battle spell buttons are available for the current commander window."
	for action in spell_actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return "Ready spell: %s." % String(action.get("label", action.get("id", "Spell")))
	return "Spell buttons are present but blocked by mana, timing, or target rules."

func _battle_timing_tab_focus(active_stack: Dictionary) -> String:
	var active_name := String(active_stack.get("name", "")).strip_edges()
	if active_name == "":
		return "No active stack is ready in the current timing window."
	var side := String(active_stack.get("side", "")).strip_edges()
	var side_label := "player" if side == "player" else "enemy"
	return "%s acts in the current %s timing window." % [_short_text(active_name, 28), side_label]

func _battle_tab_titles() -> Array:
	var titles := []
	for index in range(_battle_tabs.get_tab_count()):
		titles.append(_battle_tabs.get_tab_title(index))
	return titles

func _strip_sentence(text: String) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	return cleaned

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n\n".join(lines)

func _short_text(text: String, max_chars: int) -> String:
	var cleaned := _strip_sentence(text)
	if max_chars <= 0 or cleaned.length() <= max_chars:
		return cleaned
	if max_chars <= 1:
		return cleaned.substr(0, max_chars)
	return "%s..." % cleaned.substr(0, max_chars - 1).strip_edges()

func _style_action_button(button: Button, primary: bool = false, width: float = 112.0) -> void:
	FrontierVisualKit.apply_button(button, "primary" if primary else "secondary", width, 32.0, 12)

func _movement_click_response(
	result: Dictionary,
	movement_intent: Dictionary,
	q: int,
	r: int,
	routed: bool
) -> Dictionary:
	var active_after := {}
	var selected_after := {}
	var selected_legality := {}
	var selected_click_intent := {}
	var selected_continuity_context := {}
	var selected_closing_context := {}
	var action_surface := {}
	var action_guidance := ""
	var target_context := ""
	var board_summary := {}
	if _session != null and not _session.battle.is_empty():
		active_after = BattleRules.get_active_stack(_session.battle)
		selected_after = BattleRules.get_selected_target(_session.battle)
		selected_legality = BattleRules.selected_target_legality(_session.battle)
		selected_click_intent = BattleRules.selected_target_board_click_intent(_session.battle)
		selected_continuity_context = BattleRules.selected_target_continuity_context(_session.battle)
		selected_closing_context = BattleRules.selected_target_closing_context(_session.battle)
		action_surface = BattleRules.get_action_surface(_session)
		action_guidance = BattleRules.describe_action_surface(_session)
		target_context = BattleRules.describe_target_context(_session)
		if _battle_board_view != null and _battle_board_view.has_method("validation_hex_layout_summary"):
			board_summary = _battle_board_view.validation_hex_layout_summary()
	return {
		"ok": bool(result.get("ok", false)),
		"action": String(movement_intent.get("action", "")),
		"q": q,
		"r": r,
		"state": String(result.get("state", "")),
		"message": _last_message,
		"routed": routed,
		"movement_intent": movement_intent.duplicate(true),
		"preview_message": String(movement_intent.get("message", "")),
		"destination_detail": String(movement_intent.get("destination_detail", "")),
		"steps": int(movement_intent.get("steps", 0)),
		"step_count": int(movement_intent.get("step_count", movement_intent.get("steps", 0))),
		"sets_up_selected_target_attack": bool(movement_intent.get("sets_up_selected_target_attack", false)),
		"selected_target_setup_label": String(movement_intent.get("selected_target_setup_label", "")),
		"selected_target_after_move_attackable": bool(movement_intent.get("selected_target_after_move_attackable", false)),
		"selected_target_after_move_hex_distance": int(movement_intent.get("selected_target_after_move_hex_distance", -1)),
		"selected_target_closing_before_move": bool(movement_intent.get("selected_target_closing_before_move", false)),
		"closes_on_selected_target": bool(movement_intent.get("closes_on_selected_target", false)),
		"selected_target_continuity_preserved": bool(result.get("selected_target_continuity_preserved", false)),
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"active_stack_after_move_battle_id": String(active_after.get("battle_id", "")),
		"active_stack_after_move_side": String(active_after.get("side", "")),
		"selected_target_after_move_battle_id": String(selected_after.get("battle_id", "")),
		"selected_target_after_move_name": String(selected_after.get("name", "")),
		"selected_target_after_move_legality": selected_legality.duplicate(true),
		"selected_target_after_move_board_click_intent": selected_click_intent.duplicate(true),
		"selected_target_after_move_board_click_action": String(selected_click_intent.get("action", "")),
		"selected_target_after_move_board_click_label": String(selected_click_intent.get("label", "")),
		"selected_target_actionable_after_move": bool(result.get("selected_target_actionable_after_move", false)),
		"selected_target_continuity_context": selected_continuity_context.duplicate(true),
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_closing_context": selected_closing_context.duplicate(true),
		"post_move_target_guidance": String(result.get(
			"post_move_target_guidance",
			selected_continuity_context.get(
				"message",
				selected_closing_context.get("message", selected_click_intent.get("message", ""))
			)
		)),
		"post_move_action_surface": action_surface,
		"post_move_action_guidance": action_guidance,
		"post_move_target_context": target_context,
		"post_move_active_consequence_payload": BattleRules.active_consequence_payload(_session) if _session != null and not _session.battle.is_empty() else {},
		"post_action_recap": _last_action_recap_payload.duplicate(true),
		"post_action_recap_text": _last_action_recap_text,
		"post_move_board_summary": board_summary,
	}

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_banner_panel, "banner")
	FrontierVisualKit.apply_panel(_briefing_panel, "gold")
	FrontierVisualKit.apply_panel(_risk_panel, "teal")
	FrontierVisualKit.apply_panel(_consequence_panel, "earth")
	FrontierVisualKit.apply_panel(_battlefield_panel, "earth")
	FrontierVisualKit.apply_panel(_battlefield_frame_panel, "frame")
	FrontierVisualKit.apply_panel(_sidebar_shell_panel, "ink")
	FrontierVisualKit.apply_panel(_command_panel, "ink")
	FrontierVisualKit.apply_panel(_initiative_panel, "green")
	FrontierVisualKit.apply_panel(_context_panel, "gold")
	FrontierVisualKit.apply_panel(_spell_panel, "blue")
	FrontierVisualKit.apply_panel(_timing_panel, "earth")
	FrontierVisualKit.apply_panel(_player_panel, "teal")
	FrontierVisualKit.apply_panel(_enemy_panel, "red")
	FrontierVisualKit.apply_panel(_footer_panel, "ink")
	FrontierVisualKit.apply_panel(_action_panel, "gold")
	FrontierVisualKit.apply_panel(_system_panel, "ink")
	FrontierVisualKit.apply_art_panel(_banner_panel, UI_ART_BATTLE_INITIATIVE_BAR, "banner", 58, 12, Color(0.76, 0.72, 0.68, 1.0))
	FrontierVisualKit.apply_art_panel(_briefing_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "gold", 54, 10, Color(0.58, 0.52, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_risk_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "teal", 54, 10, Color(0.50, 0.56, 0.58, 1.0))
	FrontierVisualKit.apply_art_panel(_consequence_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "earth", 54, 10, Color(0.52, 0.48, 0.44, 1.0))
	FrontierVisualKit.apply_art_panel(_battlefield_panel, UI_ART_BATTLE_FOOTER_PANEL, "earth", 62, 12, Color(0.58, 0.54, 0.50, 1.0))
	FrontierVisualKit.apply_art_panel(_battlefield_frame_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "frame", 56, 12, Color(0.56, 0.56, 0.54, 1.0))
	FrontierVisualKit.apply_art_panel(_sidebar_shell_panel, UI_ART_BATTLE_UNIT_CARD, "ink", 72, 12, Color(0.72, 0.68, 0.62, 1.0))
	FrontierVisualKit.apply_art_panel(_command_panel, UI_ART_BATTLE_UNIT_CARD, "ink", 72, 12, Color(0.62, 0.60, 0.58, 1.0))
	FrontierVisualKit.apply_art_panel(_initiative_panel, UI_ART_BATTLE_INITIATIVE_BAR, "green", 58, 10, Color(0.74, 0.76, 0.66, 1.0))
	FrontierVisualKit.apply_art_panel(_context_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "gold", 54, 10, Color(0.58, 0.52, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_spell_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "blue", 54, 10, Color(0.50, 0.54, 0.62, 1.0))
	FrontierVisualKit.apply_art_panel(_timing_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "earth", 54, 10, Color(0.54, 0.50, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_player_panel, UI_ART_BATTLE_UNIT_CARD, "teal", 72, 12, Color(0.62, 0.68, 0.68, 1.0))
	FrontierVisualKit.apply_art_panel(_enemy_panel, UI_ART_BATTLE_UNIT_CARD, "red", 72, 12, Color(0.68, 0.58, 0.56, 1.0))
	FrontierVisualKit.apply_art_panel(_footer_panel, UI_ART_BATTLE_FOOTER_PANEL, "ink", 62, 12, Color(0.62, 0.60, 0.56, 1.0))
	FrontierVisualKit.apply_art_panel(_action_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "gold", 54, 10, Color(0.58, 0.52, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_system_panel, UI_ART_BATTLE_COMBAT_LOG_PANEL, "ink", 54, 10, Color(0.50, 0.50, 0.48, 1.0))
	FrontierVisualKit.apply_tab_container(_battle_tabs)
	for index in range(min(_battle_tabs.get_tab_count(), BATTLE_INFO_TAB_VISIBLE_TITLES.size())):
		_battle_tabs.set_tab_title(index, String(BATTLE_INFO_TAB_VISIBLE_TITLES[index]))

	for button in [_prev_target_button, _next_target_button]:
		_style_action_button(button, false, 88)
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _quick_resolve_button, _retreat_button, _surrender_button]:
		_style_action_button(button, true)
	for button in [_speed_normal_button, _speed_fast_button, _speed_instant_button]:
		_style_action_button(button, false, 78)
	for button in [_save_button, _settings_button, _menu_button]:
		_style_action_button(button, true, 104)
	_settings_button.tooltip_text = "Adjust sound, battle pace, and readability without leaving the battle."
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 104.0, 32.0, 12)

	for title_label in find_children("*Title", "Label", true, false):
		if title_label is Label:
			FrontierVisualKit.apply_label(title_label, "title", 13)

	FrontierVisualKit.apply_label(_header_label, "title", 20)
	FrontierVisualKit.apply_label(_status_label, "body", 12)
	FrontierVisualKit.apply_label(_pressure_label, "gold", 12)
	FrontierVisualKit.apply_label(_event_label, "body", 12)
	FrontierVisualKit.apply_label(_battle_context_label, "teal", 12)
	FrontierVisualKit.apply_label(_system_body_label, "muted", 12)

	FrontierVisualKit.apply_labels([
		_briefing_label,
		_risk_label,
		_consequence_label,
		_player_command_label,
		_enemy_command_label,
		_initiative_label,
		_active_label,
		_target_label,
		_spell_label,
		_effect_label,
		_timing_label,
		_player_roster,
		_enemy_roster,
		_action_guide,
	], "body", 12)

func _dismiss_tactical_briefing() -> void:
	_tactical_briefing_text = ""

func _preferred_validation_spell_action() -> Dictionary:
	if _validation_spell_casts >= _validation_max_spell_casts or not _validation_spell_casting_enabled:
		return {}
	var fallback := {}
	var support_fallback := {}
	for action in BattleRules.get_spell_actions(_session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id := String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell := ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var effect_type := String(spell.get("effect", {}).get("type", ""))
		if support_fallback.is_empty() and effect_type in ["defense_buff", "initiative_buff", "attack_buff"]:
			support_fallback = action
		if effect_type == "damage_enemy":
			if not _validation_prioritize_support_spell:
				return action
			if fallback.is_empty():
				fallback = action
		elif fallback.is_empty():
			fallback = action
	if _validation_prioritize_support_spell and not support_fallback.is_empty():
		return support_fallback
	return fallback

func _align_validation_target() -> String:
	var target_id := _preferred_validation_target_id()
	if target_id == "":
		return String(BattleRules.get_selected_target(_session.battle).get("battle_id", ""))
	var current_id := String(BattleRules.get_selected_target(_session.battle).get("battle_id", ""))
	if current_id == target_id:
		return target_id
	for _attempt in range(_enemy_target_count()):
		BattleRules.cycle_target(_session, 1)
		current_id = String(BattleRules.get_selected_target(_session.battle).get("battle_id", ""))
		if current_id == target_id:
			break
	return current_id

func _preferred_validation_target_id() -> String:
	if _session.battle.is_empty():
		return ""
	var legal_target_ids := BattleRules.legal_attack_target_ids_for_active_stack(_session.battle)
	if not legal_target_ids.is_empty():
		return String(legal_target_ids[0])
	var priority_target := BattleRules._priority_enemy_stack_for_briefing(_session.battle)
	if not priority_target.is_empty():
		return String(priority_target.get("battle_id", ""))
	return String(BattleRules.get_selected_target(_session.battle).get("battle_id", ""))

func _preferred_validation_action_id() -> String:
	var surface := BattleRules.get_action_surface(_session)
	for action_id in ["shoot", "strike", "advance", "defend"]:
		var action = surface.get(action_id, {})
		if action is Dictionary and not bool(action.get("disabled", true)):
			return action_id
	return ""

func _enemy_target_count() -> int:
	var count := 0
	for stack in _session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) != "enemy":
			continue
		if int(stack.get("total_health", 0)) <= 0:
			continue
		count += 1
	return count

func _stack_by_battle_id(battle_id: String) -> Dictionary:
	for stack in _session.battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _normalize_string_array(values: Array) -> Array[String]:
	var normalized: Array[String] = []
	for value in values:
		normalized.append(String(value))
	return normalized
