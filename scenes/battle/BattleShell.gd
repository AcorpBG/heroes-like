extends Control
## The battle screen. The field fills the window and the heroes stand beside
## their armies with their plates below them; the board draws the turn ribbon
## along the top. A command bar along the bottom holds the orders that are not
## clicks on the field, and Options, the spellbook and the battle log open as
## popovers above it. When the battle ends its result shows over the field.
## docs/battle-rework.md.

func _make_custom_tooltip(for_text: String) -> Object:
	return get_node("/root/ContextualHelp").make_hover_card(self, for_text)

const BattleMessageLog = preload("res://scenes/battle/BattleMessageLog.gd")
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SystemSaveWrittenCuePresenterScript = preload("res://scenes/shared/SystemSaveWrittenCuePresenter.gd")
const SystemLoadResumedCuePresenterScript = preload("res://scenes/shared/SystemLoadResumedCuePresenter.gd")
const BattleArtPrewarmScript = preload("res://scripts/ui/BattleArtPrewarm.gd")
const BattleHeroFigureScript = preload("res://scripts/ui/BattleHeroFigure.gd")
const BattleCommandButtonScript = preload("res://scripts/ui/BattleCommandButton.gd")
const BattleDetailsCardScript = preload("res://scripts/ui/BattleDetailsCard.gd")

const RETURN_TO_MENU_FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."
const BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE := "Battle resolved, but autosave failed. Press Save to retry the checkpoint."
const BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE := "Briefing shown, but autosave failed. Press Save to protect this checkpoint."
const BATTLE_PLAYBACK_SPEED_SAVE_FAILURE_MESSAGE := "Playback speed not saved. Previous speed restored."
const WON_OUTCOMES := ["victory", "enemy_retreat", "enemy_surrender"]

# Colours of the battle HUD (the mockup's palette).
const GOLD := Color(0.878, 0.722, 0.4)
const GOLD_DIM := Color(0.878, 0.722, 0.4, 0.35)
const GOLD_HI := Color(0.965, 0.863, 0.604)
const CREAM := Color(0.953, 0.918, 0.831)
const MUTED := Color(0.737, 0.682, 0.561)
const DIM := Color(0.561, 0.514, 0.420)
const PLAYER_TINT := Color(0.420, 0.659, 0.902)
const ENEMY_TINT := Color(0.839, 0.380, 0.329)
const READY_TEXT := Color(1.0, 0.906, 0.659)
const MANA_TEXT := Color(0.812, 0.890, 1.0)
const PANEL_FILL := Color(0.082, 0.067, 0.043, 0.92)
const BAR_FILL := Color(0.071, 0.059, 0.039, 0.9)
const LOG_FILL := Color(0.0, 0.0, 0.0, 0.28)
const LOG_TEXT := Color(0.914, 0.875, 0.776)

# HUD measurements at the 1920x1080 reference size; _layout_hud() scales them.
const PLATE_WIDTH := 226.0
const PLATE_MAX_WIDTH := 320.0
const PLATE_EDGE := 22.0
const PLATE_BELOW_FOOT := 16.0
const PLATE_GRID_GAP := 10.0
const BAR_WIDTH := 1130.0
const BAR_HEIGHT := 64.0
const BAR_BOTTOM := 12.0
const POPOVER_GAP := 12.0
const OPTIONS_WIDTH := 360.0
const SPELLBOOK_WIDTH := 440.0
const SPELLBOOK_MAX_HEIGHT := 560.0
const LOG_WIDTH := 660.0
const LOG_HEIGHT := 340.0
const BANNER_TOP := 116.0
const RESULT_WIDTH := 780.0
const SMALL_BUTTON := Vector2(46.0, 46.0)
const BIG_BUTTON := Vector2(56.0, 50.0)
const LOG_BUTTON := Vector2(34.0, 34.0)
const LOSS_ICON := 52.0
# How long a hint stays on the log line, and the round banner on the field.
const HINT_SECONDS := 4.5
const BANNER_SECONDS := 1.4
## Past events a battle opened part-way through shows in its log.
const LOG_SEED_EVENTS := 8
# Auto battle waits this long before each order, so the field can be followed.
const AUTO_BATTLE_DELAY_SECONDS := 0.3

@onready var _battle_board_view = %BattleBoard
@onready var _hud: Control = %Hud
@onready var _player_plate: PanelContainer = %PlayerHeroPlate
@onready var _enemy_plate: PanelContainer = %EnemyHeroPlate
@onready var _player_plate_emblem: Control = %PlayerPlateEmblem
@onready var _enemy_plate_emblem: Control = %EnemyPlateEmblem
@onready var _player_commander_portrait: HeroPortraitView = %PlayerCommanderPortrait
@onready var _enemy_commander_portrait: HeroPortraitView = %EnemyCommanderPortrait
@onready var _player_crest: TextureRect = %PlayerCrest
@onready var _enemy_crest: TextureRect = %EnemyCrest
@onready var _player_hero_name: Label = %PlayerHeroName
@onready var _enemy_hero_name: Label = %EnemyHeroName
@onready var _player_mana_bar: ProgressBar = %PlayerManaBar
@onready var _enemy_mana_bar: ProgressBar = %EnemyManaBar
@onready var _player_mana_text: Label = %PlayerManaText
@onready var _enemy_mana_text: Label = %EnemyManaText
@onready var _player_hero_status: Label = %PlayerHeroStatus
@onready var _enemy_hero_status: Label = %EnemyHeroStatus
@onready var _banner: Label = %Banner
@onready var _command_bar: PanelContainer = %CommandBar
@onready var _command_row: HBoxContainer = %CommandRow
@onready var _left_commands: HBoxContainer = %LeftCommands
@onready var _right_commands: HBoxContainer = %RightCommands
@onready var _options_button: Button = %Options
@onready var _surrender_button: Button = %Surrender
@onready var _retreat_button: Button = %Retreat
@onready var _auto_button: Button = %AutoBattle
@onready var _quick_resolve_button: Button = %QuickResolve
@onready var _log_line: Button = %LogLine
@onready var _log_open_button: Button = %LogOpen
@onready var _spellbook_button: Button = %Spellbook
@onready var _wait_button: Button = %Wait
@onready var _defend_button: Button = %Defend
@onready var _options_popover: PanelContainer = %OptionsPopover
@onready var _options_title: Label = %OptionsTitle
@onready var _speed_label: Label = %SpeedLabel
@onready var _speed_bar: HBoxContainer = %SpeedBar
@onready var _speed_normal_button: Button = %SpeedNormal
@onready var _speed_fast_button: Button = %SpeedFast
@onready var _speed_instant_button: Button = %SpeedInstant
@onready var _grid_label: Label = %GridLabel
@onready var _grid_bar: HBoxContainer = %GridBar
@onready var _grid_full_button: Button = %GridFull
@onready var _grid_range_button: Button = %GridRange
@onready var _grid_off_button: Button = %GridOff
@onready var _system_body_label: Label = %SystemBody
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _settings_button: Button = %Settings
@onready var _menu_button: Button = %Menu
@onready var _spellbook_popover: PanelContainer = %SpellbookPopover
@onready var _spellbook_portrait: TextureRect = %SpellbookPortrait
@onready var _spellbook_hero_name: Label = %SpellbookHeroName
@onready var _spellbook_hero_stats: Label = %SpellbookHeroStats
@onready var _spellbook_note: Label = %SpellbookNote
@onready var _spell_scroll: ScrollContainer = %SpellScroll
@onready var _spell_list: VBoxContainer = %SpellList
@onready var _log_popover: PanelContainer = %LogPopover
@onready var _log_box: VBoxContainer = %LogBox
@onready var _log_title: Label = %LogTitle
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_lead: Label = %ResultLead
@onready var _player_losses_title: Label = %PlayerLossesTitle
@onready var _enemy_losses_title: Label = %EnemyLossesTitle
@onready var _player_loss_icons: HFlowContainer = %PlayerLossIcons
@onready var _enemy_loss_icons: HFlowContainer = %EnemyLossIcons
@onready var _result_aftermath: Label = %ResultAftermath
@onready var _result_status: Label = %ResultStatus
@onready var _view_field_button: Button = %ViewField
@onready var _continue_button: Button = %Continue
@onready var _show_result_button: Button = %ShowResult
@onready var _details_card: BattleDetailsCardScript = %DetailsCard
@onready var _quick_resolve_confirmation_dialog: ConfirmationDialog = $QuickResolveConfirmationDialog
@onready var _withdrawal_confirmation_dialog: ConfirmationDialog = $WithdrawalConfirmationDialog
@onready var _manual_save_overwrite_dialog = $ManualSaveOverwriteDialog
@onready var _active_play_settings_dialog = %ActivePlaySettingsDialog

var _session: SessionStateStore.SessionData
var _message_log: PanelContainer
var _last_message := ""
var _spell_targeting_id := ""
var _spell_targeting_hash := 0
# What the details card describes while the right button is held: "stack",
# "chip" (a stack by its ribbon chip) or "hero", its id, and the rect in the
# HUD it stands beside.
var _details_kind := ""
var _details_id := ""
var _details_anchor := Rect2()
var _board_cancel_release_pending := false
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
var _action_playback_in_progress := false
var _action_playback_frames: Array = []
var _action_playback_overlap_contact := false
var _action_playback_result := {}
var _action_playback_feedback := {}
var _action_playback_speed := BattleRules.PRESENTATION_SPEED_NORMAL
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
var _last_battle_keyboard_focus_cycle_names := []
var _save_written_cue_presenter: SystemSaveWrittenCuePresenter
var _load_resumed_cue_presenter: SystemLoadResumedCuePresenter
# The session and battle as the last refresh normalized them; see _refresh().
var _normalized_battle_session = null
var _normalized_battle_snapshot: Dictionary = {}
# The save tooltips copy and describe the whole session, so they are built
# when Options opens or a save control is hovered or focused, not on every
# refresh. Their visible text is cheap and refreshed every time.
var _save_details_stale := true
var _hovered_save_controls := {}
var _save_surface_build_count := 0
var _save_details_build_count := 0
# The HUD scale of the last layout: the board's ui_scale().
var _hud_scale := 1.0
var _hud_layout_queued := false
var _popover_return_focus: Control = null
# A hint shown on the log line for a few seconds (a refused click, a spell
# waiting for its target, the briefing).
var _command_hint := ""
var _command_hint_serial := 0
var _auto_battle_serial := 0
var _last_auto_battle_order := {}
var _validation_auto_battle_order_count := 0
var _banner_tween: Tween
var _last_banner_round := 0
# The battle is over: the result shows over the field, which stays as the last
# exchange left it.
var _battle_over := false
var _result_report: Dictionary = {}
var _result_entry_result: Dictionary = {}
var _result_continue_in_progress := false
var _last_continue_result: Dictionary = {}
var _title_font: SystemFont


func _ready() -> void:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var phase_started := ProfileLogScript.begin_usec()
	_message_log = BattleMessageLog.new()
	_message_log.name = "BattleMessageLog"
	_log_box.add_child(_message_log)
	_message_log.set_expanded(true)
	_message_log.toggle.hide()
	_message_log.latest.hide()
	_message_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_log.history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_visual_theme()
	_details_card.configure(_title_font)
	_connect_hud_controls()
	_save_written_cue_presenter = SystemSaveWrittenCuePresenterScript.new()
	_save_written_cue_presenter.name = "SystemSaveWrittenCuePresenter"
	add_child(_save_written_cue_presenter)
	_save_written_cue_presenter.configure(_save_button, _system_body_label, "battle")
	_load_resumed_cue_presenter = SystemLoadResumedCuePresenterScript.new()
	_load_resumed_cue_presenter.name = "SystemLoadResumedCuePresenter"
	add_child(_load_resumed_cue_presenter)
	_load_resumed_cue_presenter.configure(_log_line, _options_button, "battle")
	_configure_quick_resolve_confirmation()
	_configure_withdrawal_confirmation()
	_configure_confirmation_input_forwarding()
	resized.connect(_layout_hud)
	for panel in [_result_panel, _options_popover, _spellbook_popover, _log_popover, _player_plate, _enemy_plate, _show_result_button, _details_card]:
		panel.minimum_size_changed.connect(_queue_hud_layout)
	buckets["theme"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_battle_board_view.stack_focus_requested.connect(_on_board_stack_focus_requested)
	_battle_board_view.stack_order_requested.connect(_on_board_stack_order_requested)
	_battle_board_view.hex_destination_requested.connect(_on_board_hex_destination_requested)
	_battle_board_view.controller_navigation_cancelled.connect(_on_board_controller_navigation_cancelled)
	_battle_board_view.hero_figure_pressed.connect(_on_hero_figure_pressed)
	_battle_board_view.details_pressed.connect(_on_board_details_pressed)
	_battle_board_view.details_released.connect(_close_details)
	buckets["connect_board_signals"] = ProfileLogScript.elapsed_ms(phase_started)
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
	# The router hands over a normalized overworld; normalize only if it changed.
	OverworldRules.normalize_overworld_state_for_runtime(_session)
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
	if int(_session.battle.get("round", 1)) <= 1:
		var battle_audio_key := String(_session.battle.get("resolved_key", _session.battle.get("encounter_id", "")))
		MusicAudio.play_stinger("stinger_battle_enter", "%s:%s:%d:enter" % [_session.session_id, battle_audio_key, _session.day])
	buckets["music_audio"] = ProfileLogScript.elapsed_ms(phase_started)
	_seed_battle_log_from_stream()
	phase_started = ProfileLogScript.begin_usec()
	var initial_result := BattleRules.perform_presented_action(_session, "ready")
	initial_result["entry_playback"] = true
	buckets["resolve_ready"] = ProfileLogScript.elapsed_ms(phase_started)
	_last_message = String(initial_result.get("message", ""))
	if String(initial_result.get("state", "continue")) != "continue" and _handle_battle_resolution(initial_result):
		return
	phase_started = ProfileLogScript.begin_usec()
	_tactical_briefing_text = BattleRules.consume_tactical_briefing(_session)
	buckets["consume_payload_briefing"] = ProfileLogScript.elapsed_ms(phase_started)
	if _tactical_briefing_text != "":
		phase_started = ProfileLogScript.begin_usec()
		_checkpoint_consumed_tactical_briefing()
		buckets["briefing_autosave"] = ProfileLogScript.elapsed_ms(phase_started)
		_publish_briefing()
	phase_started = ProfileLogScript.begin_usec()
	AppRouter.call_after_scene_presented(_release_entry_art_prewarm)
	_refresh()
	if _handle_battle_resolution(initial_result):
		return
	_present_load_resumed_cue()
	buckets["first_refresh"] = ProfileLogScript.elapsed_ms(phase_started)
	ProfileLogScript.emit_general("battle", "entry", "battle_ready", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(true), _session)
	call_deferred("_configure_battle_keyboard_focus", true)


## A card held open by the right button closes when the window loses focus,
## as the release of the button may never arrive.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_close_details()


## The scene connects the buttons and dialogs; these need bound arguments.
func _connect_hud_controls() -> void:
	for save_control in [_save_button, _menu_button, _system_body_label]:
		save_control.mouse_entered.connect(_on_save_control_hover_changed.bind(save_control, true))
		save_control.mouse_exited.connect(_on_save_control_hover_changed.bind(save_control, false))
		save_control.focus_entered.connect(_build_save_details)
	_system_body_label.mouse_filter = Control.MOUSE_FILTER_PASS


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


## A battle opened part-way through, from a save, starts its log with what
## already happened, oldest first.
func _seed_battle_log_from_stream() -> void:
	if _session == null or _session.battle.is_empty():
		return
	var events := BattleRules.battle_presentation_event_stream(_session.battle)
	var lines: Array[String] = []
	for index in range(events.size() - 1, -1, -1):
		if lines.size() >= LOG_SEED_EVENTS:
			break
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		var text := String(event.get("visible_text", event.get("text", ""))).strip_edges()
		if text != "":
			lines.push_front(text)
	for line in lines:
		_message_log.append_message(line)


## The briefing opens the battle log and shows its first line on the log line.
func _publish_briefing() -> void:
	var first_line := ""
	for raw_line in _tactical_briefing_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		if first_line == "":
			first_line = line
		_message_log.append_message(line)
	if first_line != "" and not _briefing_consumption_autosave_failure_pending:
		_set_command_hint(first_line, HINT_SECONDS * 1.5)


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


# --- Keys ----------------------------------------------------------------------

func _configure_confirmation_input_forwarding() -> void:
	var root_window := get_tree().root
	if root_window != null and not root_window.window_input.is_connected(_on_root_window_input):
		root_window.window_input.connect(_on_root_window_input)


## Physical keys while a confirmation is open go to that confirmation. The
## root window sees them before any control does.
func _on_root_window_input(event: InputEvent) -> void:
	if (
		_forwarding_confirmation_root_physical_input
		or not (event is InputEventKey or event is InputEventJoypadButton)
	):
		return
	var dialog := _active_exclusive_confirmation_dialog()
	if dialog == null:
		return
	get_tree().root.set_input_as_handled()
	var detached_event := event.duplicate() as InputEvent
	if detached_event == null:
		return
	call_deferred("_forward_root_physical_input_to_confirmation", dialog, detached_event)


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


## A dialog, the settings or a save file browser owns the keys while open.
func _modal_window_open() -> bool:
	return (
		(_quick_resolve_confirmation_dialog != null and _quick_resolve_confirmation_dialog.visible)
		or (_withdrawal_confirmation_dialog != null and _withdrawal_confirmation_dialog.visible)
		or (_manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible)
		or (_active_play_settings_dialog != null and _active_play_settings_dialog.is_open())
	)


## Esc and the battle hotkeys, before the focused control sees them. Esc
## cancels a spell's targeting, else closes a popover, else opens Options.
## S or C opens the spellbook, W waits, D (or Space on the field) defends,
## A toggles auto battle, R asks to retreat, and Q and E turn the side the
## pointed-at enemy is struck from.
func _input(event: InputEvent) -> void:
	if _session == null or not is_inside_tree():
		return
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		# The card closes when the right button comes up, wherever it is.
		if button_event.button_index == MOUSE_BUTTON_RIGHT and not button_event.pressed:
			_close_details()
		_close_popovers_on_outside_click(button_event)
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if _modal_window_open():
		return
	if _board_cancel_release_pending and event.is_action_released("ui_cancel"):
		_board_cancel_release_pending = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel", false):
		if _handle_cancel_key():
			_board_cancel_release_pending = true
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	if _battle_over:
		return
	var handled := false
	match key_event.keycode:
		KEY_S, KEY_C:
			_on_spellbook_button_pressed()
			handled = true
		KEY_W:
			if not _any_popover_open():
				_press_command(_wait_button, _on_wait_pressed)
				handled = true
		KEY_D:
			if not _any_popover_open():
				_press_command(_defend_button, _on_defend_pressed)
				handled = true
		KEY_SPACE:
			if not _any_popover_open() and (focus_owner == null or focus_owner == _battle_board_view):
				_press_command(_defend_button, _on_defend_pressed)
				handled = true
		KEY_A:
			if not _any_popover_open() and not _auto_button.disabled:
				_auto_button.button_pressed = not _auto_button.button_pressed
				handled = true
		KEY_R:
			if not _any_popover_open():
				_press_command(_retreat_button, _on_retreat_pressed)
				handled = true
		KEY_Q, KEY_E:
			if not _any_popover_open():
				if not _battle_board_view.cycle_approach(1 if key_event.keycode == KEY_E else -1):
					_set_command_hint("Point at an enemy you can strike, then Q and E turn the side your stack strikes from.")
				handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _press_command(button: Button, action: Callable) -> void:
	if button.disabled or not button.is_visible_in_tree():
		UiAudio.play_invalid("BattleShell._press_command", {"command": String(button.name)})
		_set_command_hint(_disabled_command_hint(button))
		return
	action.call()


func _disabled_command_hint(button: Button) -> String:
	var tooltip := button.tooltip_text.strip_edges()
	if tooltip != "":
		return tooltip.get_slice("\n", 0)
	return "%s is not available now." % String(button.accessibility_name if button.accessibility_name != "" else button.name)


func _handle_cancel_key() -> bool:
	if _spell_targeting_id != "":
		_cancel_spell_targeting(true)
		return true
	if _any_popover_open():
		_close_popovers()
		return true
	if _result_overlay.visible:
		_continue_button.grab_focus()
		return true
	if _battle_over:
		_on_show_result_pressed()
		return true
	if _action_playback_in_progress or _battle_exit_handoff_in_progress:
		return false
	_toggle_options_popover()
	return true


func _close_popovers_on_outside_click(event: InputEventMouseButton) -> void:
	if not event.pressed or not _any_popover_open():
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return
	for popover in [_options_popover, _spellbook_popover, _log_popover]:
		if popover.visible and popover.get_global_rect().has_point(event.position):
			return
	# The buttons that open a popover toggle it themselves.
	for opener in [_options_button, _spellbook_button, _log_line, _log_open_button, _player_plate]:
		if opener.is_visible_in_tree() and opener.get_global_rect().has_point(event.position):
			return
	_close_popovers(false)
	get_viewport().set_input_as_handled()

# --- The field -----------------------------------------------------------------

## A click on a stack is the order itself: while a spell waits for its target
## it casts the spell there, otherwise it attacks that enemy.
func _on_board_stack_focus_requested(battle_id: String) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if _battle_over or _battle_exit_handoff_in_progress or _active_exclusive_confirmation_dialog() != null:
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _session == null or _session.battle.is_empty() or not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _spell_targeting_id != "":
		return _cast_targeted_spell(battle_id)
	_stop_auto_battle()
	return _commit_board_stack_focus_requested(battle_id)


## A click (or Enter) on an enemy with the order its cursor showed: a strike
## from the hex the player chose, or a shot.
func _on_board_stack_order_requested(battle_id: String, order: Dictionary) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if _battle_over or _battle_exit_handoff_in_progress or _active_exclusive_confirmation_dialog() != null:
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _session == null or _session.battle.is_empty() or not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _spell_targeting_id != "":
		return _cast_targeted_spell(battle_id)
	_stop_auto_battle()
	return _commit_board_stack_focus_requested(battle_id, order)


func _cast_targeted_spell(battle_id: String) -> Dictionary:
	var spell_id := _spell_targeting_id
	if _spell_targeting_hash != hash(_session.battle):
		_cancel_spell_targeting(false)
		return _reject_order("The battlefield changed. Choose the spell again.", {"action": "cast_spell:" + spell_id, "target_battle_id": battle_id})
	var preview := BattleRules.spell_consequence_preview(_session, spell_id, battle_id)
	if not bool(preview.get("ok", false)):
		var message := String(preview.get("message", "")).strip_edges()
		if message == "":
			message = "That stack is not a target for %s." % _spell_name(spell_id)
		return _reject_order("%s Choose a highlighted stack, or press Esc." % message.get_slice("\n", 0), {"action": "cast_spell:" + spell_id, "target_battle_id": battle_id})
	_stop_auto_battle()
	var result := _perform_action("cast_spell:" + spell_id, {"target_id": battle_id})
	var response := result.duplicate(true)
	response["action"] = "cast_spell:" + spell_id
	response["target_battle_id"] = battle_id
	response["message"] = _last_message
	return _return_board_cursor_action_result(response)


## A refused click or key: why, on the log line, and the refusal sound.
func _reject_order(message: String, extra_fields: Dictionary = {}) -> Dictionary:
	_last_message = message
	_set_command_hint(message)
	var response := {"ok": false, "committed": false, "state": "invalid", "message": message}
	for key in extra_fields.keys():
		response[key] = extra_fields[key]
	return _return_board_cursor_action_result(response)


## order is what the cursor showed ({"action", "approach"}); without one the
## click takes the board's default order for that enemy.
func _commit_board_stack_focus_requested(battle_id: String, order: Dictionary = {}) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result(_battle_resolution_checkpoint_block_result("board_target"))
	if _session == null or _session.battle.is_empty() or battle_id == "":
		return _reject_board_stack_click(battle_id, "No battle target was clicked.")
	var active_stack := BattleRules.get_active_stack(_session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return _reject_board_stack_click(battle_id, "It is not the player's turn.")
	var clicked_stack := _stack_by_battle_id(battle_id)
	if clicked_stack.is_empty() or String(clicked_stack.get("side", "")) != "enemy":
		return _reject_board_stack_click(battle_id, "Only enemy stacks can be attacked. Click a hex to move.")

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
	var approach := {}
	match String(order.get("action", "")):
		"strike":
			if battle_id in BattleRules.legal_attack_targets_for_active_stack(_session.battle, false):
				board_action = "strike"
				approach = order.get("approach", {}) if order.get("approach", {}) is Dictionary else {}
		"shoot":
			if battle_id in BattleRules.legal_attack_targets_for_active_stack(_session.battle, true):
				board_action = "shoot"
	if board_action != "":
		var recap_context := BattleRules.post_action_recap_context(_session, board_action)
		var result := BattleRules.perform_presented_action(_session, board_action, approach)
		_last_message = String(result.get("message", ""))
		_record_action_recap(board_action, result, recap_context)
		if bool(result.get("ok", false)):
			_dismiss_tactical_briefing()
		else:
			_set_command_hint(_last_message)
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

	var selected_after := BattleRules.get_selected_target(_session.battle)
	var selected_continuity_context := BattleRules.selected_target_continuity_context(_session.battle)
	var selected_closing_context := BattleRules.selected_target_closing_context(_session.battle)
	_last_message = String(board_intent.get("message", "%s cannot be reached from here. Move closer first." % String(clicked_stack.get("name", "That target"))))
	_set_command_hint(_last_message)
	_refresh()
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
		"battle_board": _validation_battle_board_summary(),
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
	_set_command_hint(message)
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


## A click on an empty hex moves there when the stack can reach it.
func _on_board_hex_destination_requested(q: int, r: int) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if _battle_over or _battle_exit_handoff_in_progress or _active_exclusive_confirmation_dialog() != null:
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _session == null or _session.battle.is_empty() or not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result({"ok": false, "committed": false})
	if _spell_targeting_id != "":
		return _reject_order(
			"Choose a highlighted stack for %s, or press Esc to put the spell away." % _spell_name(_spell_targeting_id),
			{"action": "cast_spell:" + _spell_targeting_id, "q": q, "r": r}
		)
	var intent := BattleRules.movement_intent_for_destination(_session.battle, q, r)
	if not bool(intent.get("movable", false)):
		var message := String(intent.get("message", "")).strip_edges()
		if message == "":
			message = "That hex cannot be reached."
		return _reject_order(message.get_slice("\n", 0), {"action": "move", "q": q, "r": r, "movement_intent": intent.duplicate(true)})
	_stop_auto_battle()
	return _commit_board_hex_destination_requested(q, r)


func _commit_board_hex_destination_requested(q: int, r: int) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _return_board_cursor_action_result(_battle_resolution_checkpoint_block_result("board_move"))
	var movement_intent := BattleRules.movement_intent_for_destination(_session.battle, q, r)
	var recap_context := BattleRules.post_action_recap_context(_session, "move")
	var result := BattleRules.perform_presented_action(_session, "move", {"q": q, "r": r})
	var result_intent_value: Variant = result.get("movement_intent", movement_intent)
	if result_intent_value is Dictionary:
		movement_intent = result_intent_value
	_last_message = String(result.get("message", ""))
	_record_action_recap("move", result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	else:
		_set_command_hint(_last_message)
	if _handle_battle_resolution(result):
		return _return_board_cursor_action_result(
			_movement_click_response(result, movement_intent, q, r, _last_battle_resolution_routed)
		)
	_refresh()
	call_deferred("_configure_battle_keyboard_focus", true)
	return _return_board_cursor_action_result(_movement_click_response(result, movement_intent, q, r, false))


func _return_board_cursor_action_result(result: Dictionary) -> Dictionary:
	if _action_playback_in_progress:
		if bool(_battle_board_view.get("_controller_dispatch_in_progress")):
			_action_playback_feedback = result.duplicate(true)
		return result
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


## Clicking the player's hero opens the spellbook; holding the right button
## on either hero shows its card (_on_board_details_pressed).
func _on_hero_figure_pressed(side: String) -> void:
	if side == "player":
		_on_spellbook_button_pressed()


func _on_player_plate_gui_input(event: InputEvent) -> void:
	if _hero_plate_details_input(event, "player", _player_plate):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_player_plate.accept_event()
		_on_spellbook_button_pressed()


func _on_enemy_plate_gui_input(event: InputEvent) -> void:
	_hero_plate_details_input(event, "enemy", _enemy_plate)


## Holding the right button on a hero's plate shows the hero's card.
func _hero_plate_details_input(event: InputEvent, side: String, plate: Control) -> bool:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_RIGHT:
		return false
	plate.accept_event()
	if not (event as InputEventMouseButton).pressed:
		_close_details()
	elif _spell_targeting_id != "":
		_cancel_spell_targeting(true)
	else:
		_open_details("hero", side, Rect2(plate.global_position - _hud.global_position, plate.size))
	return true


# --- Details under the right button ---------------------------------------------

## The right button on the field: while a spell waits for its target it puts
## the spell away; otherwise the card of the stack or hero it went down on
## shows until it comes up.
func _on_board_details_pressed(kind: String, id: String, anchor: Rect2) -> void:
	if _spell_targeting_id != "":
		_cancel_spell_targeting(true)
		return
	if kind == "":
		return
	_open_details(kind, id, Rect2(anchor.position + _battle_board_view.global_position - _hud.global_position, anchor.size))


func _open_details(kind: String, id: String, anchor: Rect2) -> void:
	if _session == null or _session.battle.is_empty() or _battle_over:
		return
	if not _fill_details_card(kind, id):
		_close_details()
		return
	_details_kind = kind
	_details_id = id
	_details_anchor = anchor
	_details_card.show()
	_battle_board_view.set_details_subject("hero" if kind == "hero" else "stack", id)
	_layout_details_card()
	_queue_hud_layout()


## Fills the card from the rules for what it describes; false when that stack
## or hero is no longer there.
func _fill_details_card(kind: String, id: String) -> bool:
	if kind == "hero":
		var hero := BattleRules.hero_details(_session.battle, id)
		if hero.is_empty():
			return false
		var portrait_path := BattleHeroFigureScript.portrait_path(String(hero.get("hero_id", "")))
		if portrait_path == "":
			portrait_path = BattleHeroFigureScript.crest_path(String(hero.get("faction_id", "")))
		_details_card.show_hero(hero, load(portrait_path) as Texture2D if portrait_path != "" else null, _hud_scale)
		return true
	var stack := BattleRules.stack_details(_session.battle, id)
	if stack.is_empty() or int(stack.get("count", 0)) <= 0:
		return false
	for effect in stack.get("effects", []):
		effect["icon"] = _battle_board_view.effect_icon_path(String(effect.get("effect_id", "")), String(effect.get("spell_id", "")))
	var icon_path := String(ContentService.get_unit_art(String(stack.get("unit_id", ""))).get("battle_icon", ""))
	var icon: Texture2D = load(icon_path) as Texture2D if icon_path != "" and ResourceLoader.exists(icon_path) else null
	_details_card.show_stack(stack, icon, _hud_scale)
	return true


func _close_details() -> void:
	if _details_kind == "" and not _details_card.visible:
		return
	_details_kind = ""
	_details_id = ""
	_details_card.clear()
	_battle_board_view.set_details_subject("", "")


## The card stands beside what it describes: right of a stack on the field
## (left where the window ends), under its ribbon chip, beside a hero or its
## plate towards the field; always below the ribbon and above the command bar.
func _layout_details_card() -> void:
	if not _details_card.visible:
		return
	var k := _hud_scale
	var view := size
	_details_card.custom_minimum_size.x = minf(BattleDetailsCardScript.WIDTH * k, view.x - 32.0 * k)
	_details_card.reset_size()
	var card := _details_card.size
	var ribbon: Rect2 = _battle_board_view.turn_ribbon_rect()
	var top := maxf(8.0 * k, ribbon.end.y + _battle_board_view.global_position.y - _hud.global_position.y + 8.0 * k)
	var bottom := _command_bar.position.y - 8.0 * k
	var gap := 12.0 * k
	var anchor := _details_anchor
	var x := anchor.end.x + gap
	var y := anchor.get_center().y - card.y * 0.5
	match _details_kind:
		"chip":
			x = anchor.get_center().x - card.x * 0.5
			y = anchor.end.y + gap
		"hero":
			if _details_id == "enemy":
				x = anchor.position.x - gap - card.x
		_:
			if x + card.x > view.x - 16.0 * k:
				x = anchor.position.x - gap - card.x
	x = clampf(x, 16.0 * k, maxf(16.0 * k, view.x - card.x - 16.0 * k))
	y = clampf(y, top, maxf(top, bottom - card.y))
	_details_card.position = Vector2(round(x), round(y))


## The card keeps up with the battle while it stays open.
func _refresh_details() -> void:
	if _details_kind == "":
		return
	if not _fill_details_card(_details_kind, _details_id):
		_close_details()
		return
	_layout_details_card()


# --- Commands ----------------------------------------------------------------

func _on_defend_pressed() -> void:
	_stop_auto_battle()
	_perform_action("defend")


func _on_wait_pressed() -> void:
	_stop_auto_battle()
	_perform_action("wait")


func _on_quick_resolve_pressed() -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
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
	_stop_auto_battle()
	_close_popovers(false)
	_cancel_spell_targeting(false)
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
		return
	_configure_battle_keyboard_focus(true)


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
	FrontierVisualKit.hide_exclusive_dialog(_quick_resolve_confirmation_dialog)
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
	FrontierVisualKit.hide_exclusive_dialog(_quick_resolve_confirmation_dialog)
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
	_set_command_hint(_last_message)
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
	if _action_playback_in_progress: return _action_playback_block_result()
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
		_set_command_hint(_last_message)
		_last_withdrawal_confirmation_result = availability.duplicate(true)
		if _session != null and not _session.battle.is_empty():
			_refresh()
		_restore_withdrawal_focus(focus_origin)
		return availability
	_stop_auto_battle()
	_close_popovers(false)
	_cancel_spell_targeting(false)
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
	FrontierVisualKit.hide_exclusive_dialog(_withdrawal_confirmation_dialog)
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
	FrontierVisualKit.hide_exclusive_dialog(_withdrawal_confirmation_dialog)
	_pending_withdrawal_action = ""
	_withdrawal_focus_origin = null
	var availability := _withdrawal_action_availability(action_id)
	if not bool(availability.get("ok", false)):
		_last_message = "Withdrawal not confirmed: %s" % String(availability.get("message", "the order is no longer available."))
		_set_command_hint(_last_message)
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


# --- Spells ------------------------------------------------------------------

func _on_spellbook_button_pressed() -> void:
	if _spell_targeting_id != "":
		_cancel_spell_targeting(true)
		return
	if _spellbook_popover.visible:
		_close_popovers()
		return
	if _battle_over or _session == null or _session.battle.is_empty():
		return
	if BattleRules.hero_presentation(_session.battle, "player").is_empty():
		_reject_order("No commander leads your army, so there is no spellbook.", {"action": "spellbook"})
		return
	_open_popover(_spellbook_popover)


## Why no spell can be cast now, or "".
func _spellbook_blocked_reason(hero: Dictionary) -> String:
	if _action_playback_in_progress or _battle_exit_handoff_in_progress:
		return "Wait for the current action to finish."
	var active := BattleRules.get_active_stack(_session.battle)
	if active.is_empty() or String(active.get("side", "")) != "player":
		return "Your commander casts on one of your stacks' turns."
	if bool(hero.get("cast_this_round", false)):
		return "Your commander has cast this round. The next spell waits for the next round."
	return ""


## The spellbook lists the commander's battle spells. One that cannot be cast
## now says why; choosing one that can lights its targets on the field.
func _rebuild_spellbook() -> void:
	for child in _spell_list.get_children():
		_spell_list.remove_child(child)
		child.queue_free()
	if _session == null or _session.battle.is_empty():
		return
	var hero_state: Dictionary = BattleRules._player_commander_state(_session)
	var hero := BattleRules.hero_presentation(_session.battle, "player")
	var portrait_path := BattleHeroFigureScript.portrait_path(String(hero.get("hero_id", "")))
	_spellbook_portrait.texture = load(portrait_path) as Texture2D if portrait_path != "" else null
	_spellbook_portrait.visible = _spellbook_portrait.texture != null
	_spellbook_hero_name.text = String(hero.get("name", "Commander"))
	var command: Dictionary = hero_state.get("command", {}) if hero_state.get("command", {}) is Dictionary else {}
	var mana_current := int(hero.get("mana_current", 0))
	_spellbook_hero_stats.text = "Power %d · Knowledge %d · Mana %d/%d" % [
		SpellRules.spell_power(hero_state),
		maxi(0, int(command.get("knowledge", 0))),
		mana_current,
		int(hero.get("mana_max", 0)),
	]
	var blocked_reason := _spellbook_blocked_reason(hero)
	_spellbook_note.text = blocked_reason if blocked_reason != "" else "One spell a round. The stack keeps its turn."
	_spellbook_note.add_theme_color_override("font_color", MUTED if blocked_reason != "" else READY_TEXT)
	var spells := SpellRules.known_spells(hero_state, "battle")
	if spells.is_empty():
		var empty := Label.new()
		empty.text = "Your commander knows no battle spells."
		empty.add_theme_color_override("font_color", MUTED)
		empty.add_theme_font_size_override("font_size", _font_size(14.0))
		_spell_list.add_child(empty)
		return
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		var cost := SpellRules.adjusted_spell_mana_cost(hero_state, spell)
		var reason := blocked_reason
		if reason == "" and cost > mana_current:
			reason = "Needs %d mana; %d left." % [cost, mana_current]
		if reason == "" and BattleRules.spell_target_ids(_session, spell_id).is_empty():
			reason = "No target for it on the field now."
		_spell_list.add_child(_spell_row(spell, hero_state, cost, reason))


func _spell_row(spell: Dictionary, hero_state: Dictionary, cost: int, reason: String) -> Button:
	var k := _hud_scale
	var spell_id := String(spell.get("id", ""))
	var row := Button.new()
	row.name = "Spell_%s" % spell_id
	row.custom_minimum_size = Vector2(0.0, 66.0 * k)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_ALL
	row.disabled = reason != ""
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reason == "" else Control.CURSOR_ARROW
	row.set_meta("spell_id", spell_id)
	row.set_meta("blocked_reason", reason)
	row.accessibility_name = "%s, %d mana" % [String(spell.get("name", spell_id)), cost]
	var effect := SpellRules._spell_effect_summary(spell, hero_state).strip_edges()
	row.tooltip_text = "%s · %s · %d mana\n%s%s" % [
		String(spell.get("name", spell_id)),
		SpellRules.spell_category_label(spell),
		cost,
		effect,
		"\n%s" % reason if reason != "" else "",
	]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(state, _spell_row_style(state, k))
	row.pressed.connect(_on_spell_chosen.bind(spell_id))
	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 8.0 * k
	columns.offset_right = -10.0 * k
	columns.offset_top = 6.0 * k
	columns.offset_bottom = -6.0 * k
	columns.add_theme_constant_override("separation", int(round(12.0 * k)))
	columns.modulate = Color(1.0, 1.0, 1.0, 0.55) if reason != "" else Color.WHITE
	row.add_child(columns)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(48.0, 48.0) * k
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_path := SpellRules.spell_icon_path(spell_id)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	columns.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", int(round(2.0 * k)))
	columns.add_child(text)
	var name_label := Label.new()
	name_label.text = String(spell.get("name", spell_id))
	name_label.add_theme_color_override("font_color", GOLD_HI)
	name_label.add_theme_font_size_override("font_size", _font_size(15.5))
	if _title_font != null:
		name_label.add_theme_font_override("font", _title_font)
	text.add_child(name_label)
	var effect_label := Label.new()
	effect_label.text = reason if reason != "" else effect
	effect_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.62) if reason != "" else MUTED)
	effect_label.add_theme_font_size_override("font_size", _font_size(13.0))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.max_lines_visible = 2
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(effect_label)
	var cost_label := Label.new()
	cost_label.text = str(cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size = Vector2(30.0, 30.0) * k
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_label.add_theme_color_override("font_color", BattleCommandButtonScript.BADGE_TEXT)
	cost_label.add_theme_font_size_override("font_size", _font_size(13.0))
	var cost_style := StyleBoxFlat.new()
	cost_style.bg_color = BattleCommandButtonScript.BADGE_FILL
	cost_style.border_color = BattleCommandButtonScript.BADGE_BORDER
	cost_style.set_border_width_all(maxi(1, int(round(k))))
	cost_style.set_corner_radius_all(int(round(15.0 * k)))
	cost_label.add_theme_stylebox_override("normal", cost_style)
	cost_label.tooltip_text = "%d mana" % cost
	columns.add_child(cost_label)
	return row


func _spell_row_style(state: String, k: float) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(round(10.0 * k)))
	style.set_content_margin_all(0.0)
	match state:
		"hover", "hover_pressed":
			style.bg_color = Color(0.208, 0.173, 0.118, 0.9)
			style.border_color = GOLD
		"pressed":
			style.bg_color = Color(0.110, 0.090, 0.059, 0.95)
			style.border_color = BattleCommandButtonScript.ACTIVE
		"focus":
			style.draw_center = false
			style.border_color = BattleCommandButtonScript.ACTIVE
			style.set_border_width_all(maxi(2, int(round(2.0 * k))))
			return style
		"disabled":
			style.bg_color = Color(0.0, 0.0, 0.0, 0.16)
			style.border_color = Color(GOLD_DIM, 0.12)
		_:
			style.bg_color = Color(0.0, 0.0, 0.0, 0.22)
			style.border_color = Color(GOLD_DIM, 0.25)
	style.set_border_width_all(maxi(1, int(round(k))))
	return style


func _on_spell_chosen(spell_id: String) -> void:
	_close_popovers(false)
	_begin_spell_targeting(spell_id)


## The chosen spell waits for its target: the field lights the stacks it can
## be cast on, and the next click on one of them casts it.
func _begin_spell_targeting(spell_id: String) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if _battle_over or _battle_exit_handoff_in_progress or _active_exclusive_confirmation_dialog() != null:
		return {"ok": false, "state": "invalid"}
	if not _battle_resolution_checkpoint_pending.is_empty():
		_apply_battle_resolution_checkpoint_failure_surface()
		return {"ok": false, "state": "invalid"}
	var ids := BattleRules.spell_target_ids(_session, spell_id)
	if ids.is_empty():
		return _reject_order("%s has no target on the field now." % _spell_name(spell_id), {"action": "cast_spell:" + spell_id})
	_stop_auto_battle()
	_spell_targeting_id = spell_id
	_spell_targeting_hash = hash(_session.battle)
	_refresh_spell_target_surface()
	_set_command_hint("%s: click a highlighted stack. Esc puts the spell away." % _spell_name(spell_id), 0.0)
	_battle_board_view.set_hero_cast_ready(false)
	if _battle_board_view.focus_mode != Control.FOCUS_NONE:
		_battle_board_view.grab_focus()
	return {"ok": true, "state": "targeting", "spell_id": spell_id, "target_ids": ids.duplicate()}


func _cancel_spell_targeting(announce: bool) -> void:
	if _spell_targeting_id == "":
		return
	var spell_id := _spell_targeting_id
	_spell_targeting_id = ""
	_spell_targeting_hash = 0
	if _battle_board_view != null:
		_battle_board_view.set_spell_target_candidates([])
		_battle_board_view.set_hero_cast_ready(_hero_can_cast_now())
	if announce:
		_set_command_hint("%s put away. No mana spent." % _spell_name(spell_id))
	elif _command_hint.begins_with(_spell_name(spell_id) + ":"):
		_set_command_hint("")


func _refresh_spell_target_surface() -> void:
	if _spell_targeting_id == "" or _session == null or _session.battle.is_empty():
		return
	var ids := BattleRules.spell_target_ids(_session, _spell_targeting_id)
	var previews := {}
	for id in ids:
		previews[id] = BattleRules.spell_consequence_preview(_session, _spell_targeting_id, String(id))
	_battle_board_view.set_spell_target_candidates(ids, previews, true)


func _spell_name(spell_id: String) -> String:
	return String(ContentService.get_spell(spell_id).get("name", spell_id.replace("_", " ").capitalize()))


## The player's hero can cast now: one of its stacks has the turn, no spell
## was cast this round, and a spell it can pay for has a target.
func _hero_can_cast_now() -> bool:
	if _battle_over or _action_playback_in_progress or _session == null or _session.battle.is_empty():
		return false
	var active := BattleRules.get_active_stack(_session.battle)
	if active.is_empty() or String(active.get("side", "")) != "player":
		return false
	var hero := BattleRules.hero_presentation(_session.battle, "player")
	if hero.is_empty() or bool(hero.get("cast_this_round", false)):
		return false
	var hero_state: Dictionary = BattleRules._player_commander_state(_session)
	var mana := int(hero.get("mana_current", 0))
	for spell in SpellRules.known_spells(hero_state, "battle"):
		if spell is Dictionary and SpellRules.adjusted_spell_mana_cost(hero_state, spell) <= mana:
			if not BattleRules.spell_target_ids(_session, String(spell.get("id", ""))).is_empty():
				return true
	return false


# --- Auto battle -------------------------------------------------------------

func _on_auto_battle_toggled(on: bool) -> void:
	_auto_battle_serial += 1
	_refresh_auto_button()
	if on:
		_close_popovers(false)
		_cancel_spell_targeting(false)
		_set_command_hint("Auto battle: your stacks fight on their own. A stops it.")
		_schedule_auto_battle_turn()
	else:
		_set_command_hint("Auto battle off. Your orders again.")


func _stop_auto_battle() -> void:
	if not _auto_button.button_pressed:
		return
	_auto_button.set_pressed_no_signal(false)
	_auto_battle_serial += 1
	_refresh_auto_button()


func _refresh_auto_button() -> void:
	_auto_button.tooltip_text = "Auto battle is on: your stacks give their own orders. Click or press A to take over." if _auto_button.button_pressed else "Auto battle: your stacks give their own orders until you take over. A"
	_auto_button.queue_redraw()


## On the player's turn, auto battle gives the turn's order after a short
## pause: the hero's spell first when the battle AI wants one, then the
## stack's own order, chosen as the enemy's stacks choose theirs.
func _schedule_auto_battle_turn() -> void:
	if not _auto_button.button_pressed or _battle_over or _action_playback_in_progress or _battle_exit_handoff_in_progress:
		return
	if _session == null or _session.battle.is_empty() or not is_inside_tree():
		return
	var active := BattleRules.get_active_stack(_session.battle)
	if active.is_empty() or String(active.get("side", "")) != "player":
		return
	_auto_battle_serial += 1
	get_tree().create_timer(AUTO_BATTLE_DELAY_SECONDS).timeout.connect(_run_auto_battle_turn.bind(_auto_battle_serial))


func _run_auto_battle_turn(serial: int) -> void:
	if serial != _auto_battle_serial or not is_inside_tree() or not _auto_button.button_pressed:
		return
	if _battle_over or _action_playback_in_progress or _battle_exit_handoff_in_progress or _modal_window_open():
		return
	if not _battle_resolution_checkpoint_pending.is_empty() or _session == null or _session.battle.is_empty():
		return
	var active := BattleRules.get_active_stack(_session.battle)
	if active.is_empty() or String(active.get("side", "")) != "player":
		return
	var order := validation_auto_battle_order()
	if not bool(order.get("ok", false)):
		_stop_auto_battle()
		_set_command_hint("Auto battle stopped: %s" % String(order.get("message", "no order was possible.")))


## Gives the auto battle order for the player's active stack.
func validation_auto_battle_order() -> Dictionary:
	if _session == null or _session.battle.is_empty():
		return {"ok": false, "message": "no battle is active."}
	var decision: Dictionary = BattleAutoResolveRulesScript.player_autoplay_decision(_session, true)
	_last_auto_battle_order = decision.duplicate(true)
	_validation_auto_battle_order_count += 1
	var action := String(decision.get("action", ""))
	var result := {}
	if action == "cast_spell":
		result = _perform_action("cast_spell:%s" % String(decision.get("spell_id", "")), {"target_id": String(decision.get("target_battle_id", ""))})
	elif action == "strike":
		result = _perform_action("strike", BattleRules.ai_melee_approach(
			_session.battle,
			BattleRules.get_active_stack(_session.battle),
			BattleRules.get_selected_target(_session.battle)
		))
	elif action != "":
		result = _perform_action(action)
	var ok := String(result.get("state", "invalid")) != "invalid"
	return {"ok": ok, "action": action, "decision": decision.duplicate(true), "result": result, "message": String(result.get("message", ""))}


# --- Popovers ------------------------------------------------------------------

func _any_popover_open() -> bool:
	return _options_popover.visible or _spellbook_popover.visible or _log_popover.visible


func _open_popover(popover: PanelContainer) -> void:
	if popover.visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	_close_popovers(false)
	get_node("/root/ContextualHelp").dismiss()
	_popover_return_focus = focus_owner if focus_owner != null and is_ancestor_of(focus_owner) else null
	if popover == _options_popover:
		_build_save_details()
		_refresh_speed_buttons()
		_refresh_grid_buttons()
	elif popover == _spellbook_popover:
		_rebuild_spellbook()
	elif popover == _log_popover:
		_message_log.show_latest()
	popover.show()
	_layout_hud()
	_queue_hud_layout()
	_configure_battle_keyboard_focus(true)


func _close_popovers(restore_focus: bool = true) -> void:
	if not _any_popover_open():
		return
	for popover in [_options_popover, _spellbook_popover, _log_popover]:
		popover.hide()
	var origin := _popover_return_focus
	_popover_return_focus = null
	if not restore_focus:
		call_deferred("_configure_battle_keyboard_focus", false)
		return
	if origin != null and is_instance_valid(origin) and FrontierVisualKit.is_keyboard_focusable(origin):
		origin.grab_focus()
	else:
		_configure_battle_keyboard_focus(true)


func _toggle_options_popover() -> void:
	if _options_popover.visible:
		_close_popovers()
	else:
		_open_popover(_options_popover)


func _toggle_log_popover() -> void:
	if _log_popover.visible:
		_close_popovers()
	else:
		_open_popover(_log_popover)

# --- Speed, saving, settings and the menu ----------------------------------

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
		_set_command_hint(_last_message)
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
		_refresh_speed_buttons()
		_restore_battle_presentation_speed_focus(requesting_button)
		return failure

	var rule_result := BattleRules.set_battle_presentation_speed(_session, committed_speed)
	var applied := bool(rule_result.get("ok", false))
	if applied:
		_validation_battle_playback_speed_success_count += 1
		_action_playback_speed = committed_speed
		_last_message = String(rule_result.get("message", ""))
	else:
		_validation_battle_playback_speed_failure_count += 1
		_last_message = String(rule_result.get("message", "Battle playback speed could not be applied."))
		_set_command_hint(_last_message)
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
	_refresh_speed_buttons()
	if requesting_button != null and requesting_button.has_focus():
		_restore_battle_presentation_speed_focus(_first_enabled_speed_button())
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


func _first_enabled_speed_button() -> Button:
	for button in [_speed_normal_button, _speed_fast_button, _speed_instant_button]:
		if not button.disabled:
			return button
	return null


func _restore_battle_presentation_speed_focus(button: Button) -> void:
	if button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		button.call_deferred("grab_focus")


## The selected speed reads as pressed; the other two switch to themselves.
func _refresh_speed_buttons() -> void:
	var speed := BattleRules.battle_presentation_speed(_session) if _session != null else SettingsService.battle_playback_speed_id()
	for speed_id in [BattleRules.PRESENTATION_SPEED_NORMAL, BattleRules.PRESENTATION_SPEED_FAST, BattleRules.PRESENTATION_SPEED_INSTANT]:
		var button := _battle_presentation_speed_button(speed_id)
		var selected := String(speed_id) == speed
		button.disabled = selected
		button.tooltip_text = (
			"Current battle playback speed: %s." % speed.capitalize()
			if selected
			else "Switch battle playback speed to %s." % String(speed_id).capitalize()
		)
		button.add_theme_color_override("font_disabled_color", BattleCommandButtonScript.ACTIVE if selected else DIM)


func _on_grid_full_pressed() -> void:
	_set_battle_hex_grid(SettingsService.BATTLE_HEX_GRID_FULL)


func _on_grid_range_pressed() -> void:
	_set_battle_hex_grid(SettingsService.BATTLE_HEX_GRID_RANGE)


func _on_grid_off_pressed() -> void:
	_set_battle_hex_grid(SettingsService.BATTLE_HEX_GRID_OFF)


## Saves the hex grid with the settings and redraws the field with it.
func _set_battle_hex_grid(mode_id: String) -> Dictionary:
	var requesting_button := _hex_grid_button(mode_id)
	var had_focus := requesting_button.has_focus()
	var result: Dictionary = SettingsService.set_battle_hex_grid_mode_id(mode_id)
	if not bool(result.get("ok", false)):
		_last_message = "The hex grid setting could not be saved."
		_set_command_hint(_last_message)
	_battle_board_view.queue_redraw()
	_refresh_grid_buttons()
	if had_focus:
		_restore_battle_presentation_speed_focus(_first_enabled_grid_button())
	return result


func _hex_grid_button(mode_id: String) -> Button:
	match mode_id:
		SettingsService.BATTLE_HEX_GRID_RANGE:
			return _grid_range_button
		SettingsService.BATTLE_HEX_GRID_OFF:
			return _grid_off_button
	return _grid_full_button


func _first_enabled_grid_button() -> Button:
	for button in [_grid_full_button, _grid_range_button, _grid_off_button]:
		if not button.disabled:
			return button
	return null


## The selected grid reads as pressed, like the speed.
func _refresh_grid_buttons() -> void:
	var mode := SettingsService.battle_hex_grid_mode_id()
	for option in SettingsService.BATTLE_HEX_GRID_OPTIONS:
		var mode_id := String(option.get("id", ""))
		var button := _hex_grid_button(mode_id)
		var selected := mode_id == mode
		button.disabled = selected
		button.tooltip_text = {
			SettingsService.BATTLE_HEX_GRID_FULL: "Outline every hex of the field.",
			SettingsService.BATTLE_HEX_GRID_RANGE: "Outline only the hexes your stack can move to.",
			SettingsService.BATTLE_HEX_GRID_OFF: "No grid, and no movement range.",
		}[mode_id]
		button.add_theme_color_override("font_disabled_color", BattleCommandButtonScript.ACTIVE if selected else DIM)


func _on_save_pressed(legacy_slot: bool = false) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _retry_battle_resolution_checkpoint()
	if not legacy_slot:
		var opened: bool = _manual_save_overwrite_dialog.open_file_browser(_session, _commit_file_save)
		return {"ok": opened, "saved": false, "pending": opened, "reason": "file_browser", "message": "Choose a save file."}
	var action := AppRouter.active_manual_save_action()
	if bool(action.get("disabled", true)):
		_last_message = String(action.get("summary", "The battle could not be saved."))
		_set_command_hint(_last_message)
		_refresh()
		return action
	if bool(action.get("requires_confirmation", false)):
		_manual_save_overwrite_dialog.open_action(action)
		return action
	return _commit_manual_save(int(action.get("slot", SaveService.get_selected_manual_slot())))


func _commit_file_save(file_name: String, expected_sha256: String) -> Dictionary:
	return _commit_manual_save(SaveService.get_selected_manual_slot(), file_name, expected_sha256)


func _commit_manual_save(manual_slot: int, file_name: String = "", expected_sha256: String = "") -> Dictionary:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var briefing_checkpoint_pending := _briefing_consumption_autosave_failure_pending
	var save_started := ProfileLogScript.begin_usec()
	var result := AppRouter.save_active_session_to_file(file_name, expected_sha256) if file_name != "" else AppRouter.save_active_session_to_manual_slot(manual_slot)
	buckets["save"] = ProfileLogScript.elapsed_ms(save_started)
	if briefing_checkpoint_pending and bool(result.get("ok", false)):
		_briefing_consumption_autosave_failure_pending = false
		_last_message = String(result.get("message", ""))
	elif briefing_checkpoint_pending:
		_last_message = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	else:
		_last_message = String(result.get("message", ""))
	_set_command_hint(_last_message)
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
	if _action_playback_in_progress: return _action_playback_block_result()
	_validation_return_to_menu_request_count += 1
	_stop_auto_battle()
	var result: Dictionary = AppRouter.return_to_main_menu_from_active_play()
	_last_return_to_menu_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		return _last_return_to_menu_result.duplicate(true)
	var message := String(result.get("message", "")).strip_edges().left(180)
	if message == "":
		message = RETURN_TO_MENU_FAILURE_MESSAGE
	_last_return_to_menu_result["message"] = message
	_last_message = message
	_set_command_hint(message)
	_system_body_label.text = message
	_system_body_label.show()
	_refresh()
	if not _options_popover.visible:
		_open_popover(_options_popover)
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
		if _session != null and not _session.battle.is_empty():
			BattleRules.set_battle_presentation_speed(_session, SettingsService.battle_playback_speed_id())
		_action_playback_speed = SettingsService.battle_playback_speed_id()
		_refresh()
		_refresh_speed_buttons()
		return
	if setting_id not in ["ui_scale", "high_contrast", "color_cues"]:
		return
	_apply_visual_theme()
	_apply_hud_scale(_hud_scale)
	_refresh()


# --- Orders and their playback -----------------------------------------------

func _perform_action(action: String, order_parameters: Dictionary = {}) -> Dictionary:
	if _action_playback_in_progress: return _action_playback_block_result()
	if _battle_over or _battle_exit_handoff_in_progress or _active_exclusive_confirmation_dialog() != null: return {"ok": false, "committed": false}
	if not _battle_resolution_checkpoint_pending.is_empty():
		return _battle_resolution_checkpoint_block_result(action)
	_validation_perform_action_counts[action] = int(_validation_perform_action_counts.get(action, 0)) + 1
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var rules_started := ProfileLogScript.begin_usec()
	var recap_context := BattleRules.post_action_recap_context(_session, action)
	_cancel_spell_targeting(false)
	var result := BattleRules.perform_presented_action(_session, action, order_parameters)
	buckets["rules_action"] = ProfileLogScript.elapsed_ms(rules_started)
	_last_message = String(result.get("message", ""))
	_record_action_recap(action, result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	elif String(result.get("state", "")) == "invalid":
		_set_command_hint(_last_message)
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
	if not _validation_battle_resolution_routing_enabled or DisplayServer.get_name() == "headless":
		for frame in result.get("playback_frames", []): _record_battle_log_frame(frame)
		result.erase("playback_frames")
	if String(result.get("state", "continue")) == "continue" and _session.scenario_status == "in_progress" and not bool(result.get("playback_completed", false)) and _begin_action_playback(result):
		return true
	_last_battle_resolution_routed = false
	if _session.scenario_status != "in_progress":
		_record_validation_battle_resolution_attempt(result, "battle_report")
		_last_battle_resolution_routed = true
		if _begin_battle_exit_animation_handoff(result, "battle_report"):
			return true
		if _validation_battle_resolution_routing_enabled:
			_open_battle_report_in_place()
		return true
	match String(result.get("state", "continue")):
		"victory", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost":
			_record_validation_battle_resolution_attempt(result, "overworld")
			if not _validation_battle_resolution_routing_enabled:
				_last_battle_resolution_routed = true
				return true
			return _checkpoint_battle_resolution_for_overworld(result, false)
		"defeat":
			_record_validation_battle_resolution_attempt(result, "battle_report")
			_last_battle_resolution_routed = true
			if _begin_battle_exit_animation_handoff(result, "battle_report"):
				return true
			if _validation_battle_resolution_routing_enabled:
				_open_battle_report_in_place()
			return true
	return false


func _action_playback_block_result() -> Dictionary:
	return {"ok": false, "state": "invalid", "reason": "battle_playback_pending", "message": "Wait for the current battle action to finish."}


func _begin_action_playback(result: Dictionary, route_target: String = "") -> bool:
	var frames: Array = result.get("playback_frames", [])
	result.erase("playback_frames")
	if frames.is_empty() or not _validation_battle_resolution_routing_enabled or DisplayServer.get_name() == "headless":
		return false
	_action_playback_speed = String(frames[0].get(BattleRules.PRESENTATION_SPEED_KEY, BattleRules.PRESENTATION_SPEED_NORMAL))
	if _action_playback_speed == BattleRules.PRESENTATION_SPEED_INSTANT:
		for frame in frames: _record_battle_log_frame(frame)
		return false
	_action_playback_frames = frames.duplicate()
	_action_playback_overlap_contact = false
	_action_playback_result = result.duplicate()
	_action_playback_result.erase("playback_frames")
	_action_playback_result["playback_completed"] = true
	_action_playback_result["playback_route_target"] = route_target
	_action_playback_in_progress = true
	_disable_battle_exit_handoff_inputs()
	_play_next_action_frame()
	return true


func _play_next_action_frame() -> void:
	if not is_inside_tree(): return
	if _action_playback_speed == BattleRules.PRESENTATION_SPEED_INSTANT:
		for frame in _action_playback_frames: _record_battle_log_frame(frame)
		_action_playback_frames.clear()
	if _action_playback_frames.is_empty():
		_action_playback_in_progress = false
		var completed := _action_playback_result
		_action_playback_result = {}
		var route_target := String(completed.get("playback_route_target", ""))
		if route_target == "overworld":
			_battle_board_view.settle_final_field()
			_last_battle_resolution_routed = _route_checkpointed_battle_resolution()
			return
		if route_target == "battle_report":
			_battle_board_view.settle_final_field()
			_open_battle_report_in_place()
			return
		_battle_board_view.mouse_filter = Control.MOUSE_FILTER_STOP
		_battle_board_view.focus_mode = Control.FOCUS_ALL
		_battle_board_view.finish_action_playback(_session)
		if not _handle_battle_resolution(completed):
			_refresh()
			if bool(completed.get("entry_playback", false)): _present_load_resumed_cue()
			call_deferred("_configure_battle_keyboard_focus", true)
			call_deferred("_publish_completed_action_feedback")
		return
	var frame: Dictionary = _action_playback_frames.pop_front()
	frame[BattleRules.PRESENTATION_SPEED_KEY] = _action_playback_speed
	var caption := _record_battle_log_frame(frame)
	_announce_hero_cast(frame)
	frame["playback_caption"] = caption
	_battle_board_view.set_battle_presentation_snapshot(frame, _action_playback_overlap_contact)
	_battle_board_view.tooltip_text = caption
	var next_event: Dictionary = _action_playback_frames[0].get("playback_event", {}) if not _action_playback_frames.is_empty() else {}
	_action_playback_overlap_contact = _battle_board_view.can_overlap_action_contact(next_event)
	var timer := get_tree().create_timer(float(_battle_board_view.action_playback_wait_msec(_action_playback_overlap_contact)) / 1000.0)
	timer.timeout.connect(_play_next_action_frame)


func _record_battle_log_frame(frame: Dictionary) -> String:
	var caption := _battle_log_caption(frame)
	_message_log.append_message("Round %d · %s" % [int(frame.get("round", 1)), caption])
	if _command_hint == "":
		_refresh_log_line()
	return caption


## A played event as the log reads it: what happened, to whom, and the cost.
## "Kind: who → whom" keeps the words right for any stack name.
func _battle_log_caption(frame: Dictionary) -> String:
	var event: Dictionary = frame.get("playback_event", {}) if frame.get("playback_event", {}) is Dictionary else {}
	var actor := _battle_log_name(frame, String(event.get("battle_id", "")))
	var target := _battle_log_name(frame, String(event.get("target_battle_id", "")))
	var onto := " → %s" % target if target != "" else ""
	var spell_id := String(event.get("spell_id", "")).strip_edges()
	var spell := String(ContentService.get_spell(spell_id).get("name", spell_id)) if spell_id != "" else ""
	var damage := int(event.get("damage", 0))
	var cost := ", %d damage, %d lost" % [damage, int(event.get("casualties", 0))] if damage > 0 else ""
	match String(event.get("event_id", "")):
		"battle_unit_move":
			return "Move: %s" % actor
		"battle_unit_melee_attack":
			return "Strike: %s%s" % [actor, onto]
		"battle_unit_ranged_attack":
			return "Shot: %s%s" % [actor, onto]
		"battle_retaliation":
			return "Strike-back: %s%s" % [actor, onto]
		"battle_unit_hit":
			return "Hit: %s%s" % [actor, cost]
		"battle_status_applied":
			if cost != "":
				return "Hit: %s%s%s" % [actor, cost, ", %s" % spell if spell != "" else ", and an effect"]
			return "Effect: %s%s" % [actor, ", %s" % spell if spell != "" else ""]
		"battle_status_expired":
			return "Effect ends: %s%s" % [actor, ", %s" % spell if spell != "" else ""]
		"battle_unit_death":
			return "Fallen: %s%s" % [actor, cost]
		"battle_unit_cast":
			return "Spell: %s, %s%s" % [actor, spell if spell != "" else "a spell", onto]
		"battle_unit_defend":
			return "Defend: %s" % actor
		"battle_unit_wait":
			return "Wait: %s" % actor
		"battle_unit_retreat":
			return "Retreat: %s" % actor
		"battle_unit_surrender":
			return "Surrender: %s" % actor
	var kind := String(event.get("event_id", "action")).trim_prefix("battle_unit_").trim_prefix("battle_").replace("_", " ").capitalize()
	return "%s: %s%s%s" % [kind, actor, onto, cost]


## "your River Guard", "enemy Bog Brutes", or a hero's name.
func _battle_log_name(frame: Dictionary, actor_id: String) -> String:
	if actor_id == "":
		return ""
	var name := BattleRules.battle_actor_label(frame, actor_id).strip_edges()
	if name == "" or BattleRules.is_hero_actor_id(actor_id):
		return name
	return "%s %s" % ["your" if BattleRules.battle_actor_side(frame, actor_id) == "player" else "enemy", name]


## A hero's cast shows as a banner over the field while it plays.
func _announce_hero_cast(frame: Dictionary) -> void:
	var event: Dictionary = frame.get("playback_event", {}) if frame.get("playback_event", {}) is Dictionary else {}
	var actor_id := String(event.get("battle_id", ""))
	if not BattleRules.is_hero_actor_id(actor_id):
		return
	var spell_id := String(event.get("spell_id", ""))
	var hero_name := BattleRules.battle_actor_label(frame, actor_id)
	_show_banner("%s casts %s" % [hero_name, _spell_name(spell_id)] if spell_id != "" else "%s casts a spell" % hero_name)


func _publish_completed_action_feedback() -> void:
	if not _action_playback_feedback.is_empty():
		var feedback := _action_playback_feedback
		_action_playback_feedback = {}
		# This was a controller-origin order; publish only after playback has
		# restored its live session and command focus. The Board still validates
		# the session/turn/focus guards before announcing the deferred result.
		_battle_board_view.publish_controller_action_result(feedback, true)


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
		result.erase("playback_frames")
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


## The resolved battle is saved: its result shows over the field.
func _route_checkpointed_battle_resolution() -> bool:
	_validation_battle_resolution_durable_route_count += 1
	var route_value: Variant = AppRouter.route_checkpointed_battle_resolution(true)
	var route_result: Dictionary = route_value if route_value is Dictionary else {}
	_last_battle_resolution_route_result = route_result.duplicate(true)
	if bool(route_result.get("ok", false)):
		_show_result_overlay(route_result)
		return true
	_last_message = String(route_result.get("message", "The resolved battle is saved, but the Overworld could not open.")).strip_edges().left(220)
	_apply_battle_resolution_checkpoint_failure_surface(false, _last_message)
	return false


## A battle that ended the scenario, or a defeat: its report is saved and
## shows over the field. Without a pending report the router opens the next
## screen itself.
func _open_battle_report_in_place() -> void:
	var entry_value: Variant = AppRouter.go_to_battle_report(false, true)
	var entry_result: Dictionary = entry_value if entry_value is Dictionary else {}
	if String(entry_result.get("target", "")) == "battle_report":
		_show_result_overlay(entry_result)


func _apply_battle_resolution_checkpoint_failure_surface(
	focus_save: bool = true,
	message: String = BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE
) -> void:
	_last_message = message.strip_edges().left(220)
	if _last_message == "":
		_last_message = BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE
	_set_command_hint(_last_message, 0.0)
	_disable_battle_exit_handoff_inputs()
	if not _options_popover.visible:
		_open_popover(_options_popover)
	_system_body_label.visible = true
	_system_body_label.text = _last_message
	_system_body_label.tooltip_text = _last_message
	_save_button.text = "Save Battle"
	_save_button.tooltip_text = "Retry the resolved battle checkpoint, then continue to the Overworld."
	_save_button.disabled = false
	_save_slot_picker.disabled = true
	if focus_save:
		_save_button.call_deferred("grab_focus")


func _apply_briefing_consumption_autosave_failure_surface(focus_save: bool = true) -> void:
	_last_message = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	var visible_surface := BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	if _tactical_briefing_text.strip_edges() != "":
		visible_surface = "%s\n%s" % [visible_surface, _tactical_briefing_text.strip_edges()]
	_set_command_hint(BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE, 0.0)
	_log_line.tooltip_text = visible_surface
	_system_body_label.visible = true
	_system_body_label.text = BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_MESSAGE
	_system_body_label.tooltip_text = visible_surface
	_save_button.text = "Save Battle"
	_save_button.tooltip_text = "Create a named save file for the shown tactical briefing checkpoint."
	_save_button.disabled = false
	if focus_save:
		if not _options_popover.visible:
			_open_popover(_options_popover)
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
	# Terminal outcomes reach this hook only after their existing durable
	# checkpoint. Play the complete exchange before the already-authorized route.
	if _begin_action_playback(result, route_target):
		return true
	var snapshot_value: Variant = result.get("battle_exit_animation_snapshot", {})
	if not (snapshot_value is Dictionary) or snapshot_value.is_empty():
		return false
	var snapshot: Dictionary = snapshot_value
	if _battle_board_view == null or not _battle_board_view.has_method("set_battle_presentation_snapshot"):
		return false
	_battle_exit_handoff_in_progress = true
	_battle_board_view.set_battle_presentation_snapshot(snapshot)
	_last_message = String(result.get("message", _last_message))
	_refresh_log_line()
	_disable_battle_exit_handoff_inputs()
	var handoff_seconds: float = max(0.01, float(BattleRules.battle_presentation_playback_msec(snapshot)) / 1000.0)
	var timer := get_tree().create_timer(handoff_seconds)
	timer.timeout.connect(_complete_battle_exit_animation_handoff.bind(route_target))
	return true


func _disable_battle_exit_handoff_inputs() -> void:
	for button in _combat_input_buttons():
		button.disabled = true
	_battle_board_view.set_hero_cast_ready(false)
	_battle_board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_board_view.focus_mode = Control.FOCUS_NONE


## The buttons that give orders; playback and a pending checkpoint disable them.
func _combat_input_buttons() -> Array:
	return [_wait_button, _defend_button, _quick_resolve_button, _retreat_button, _surrender_button, _spellbook_button]


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
	_battle_board_view.settle_final_field()
	if route_target == "battle_report":
		_open_battle_report_in_place()
	else:
		_last_battle_resolution_routed = _route_checkpointed_battle_resolution()

# --- Refresh -------------------------------------------------------------------

func _refresh() -> void:
	if _spell_targeting_id != "" and (_session == null or _spell_targeting_hash != hash(_session.battle)):
		_cancel_spell_targeting(false)
	if _action_playback_in_progress:
		_disable_battle_exit_handoff_inputs()
		return
	if _session == null or _session.battle.is_empty():
		_layout_hud()
		return
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var section_started := ProfileLogScript.begin_usec()
	# Normalization rebuilds every stack from content and is idempotent, so a
	# refresh that finds the battle exactly as the last one left it skips it.
	if not (_normalized_battle_session == _session and _normalized_battle_snapshot == _session.battle):
		if not BattleRules.normalize_battle_state(_session):
			_normalized_battle_session = null
			_normalized_battle_snapshot = {}
			AppRouter.go_to_overworld()
			return
		_normalized_battle_session = _session
		_normalized_battle_snapshot = _session.battle.duplicate(true)
	buckets["normalize_battle"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_command_bar()
	_refresh_speed_buttons()
	_refresh_grid_buttons()
	buckets["actions"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_save_bar_status()
	_save_details_stale = true
	# A save control under the pointer or focused shows its tooltip again
	# without a new hover, so it needs the current one now.
	if _save_bar_in_view():
		_build_save_details()
	buckets["save_surface"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_hero_plates()
	buckets["commanders"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_battle_board_view.set_battle_state(_session)
	_refresh_spell_target_surface()
	_battle_board_view.set_hero_cast_ready(_spell_targeting_id == "" and _hero_can_cast_now())
	if _spellbook_popover.visible:
		_rebuild_spellbook()
	buckets["surface_and_board"] = ProfileLogScript.elapsed_ms(section_started)
	_refresh_log_line()
	_announce_round()
	if _briefing_consumption_autosave_failure_pending:
		_apply_briefing_consumption_autosave_failure_surface(false)
	_refresh_details()
	_layout_hud()
	ProfileLogScript.emit_general("battle", "refresh", "battle_refresh", ProfileLogScript.elapsed_ms(profile_started), buckets, _battle_profile_metadata(false), _session)
	call_deferred("_configure_battle_keyboard_focus", false)
	_schedule_auto_battle_turn()


## The command bar follows the action surface: what the active stack can do,
## and why not when it cannot.
func _refresh_command_bar() -> void:
	var surface := BattleRules.get_action_surface(_session)
	_apply_command_surface(_wait_button, surface.get("wait", {}), "Wait", "W")
	_apply_command_surface(_defend_button, surface.get("defend", {}), "Defend", "D or Space")
	_apply_command_surface(_retreat_button, surface.get("retreat", {}), "Retreat", "R")
	_apply_command_surface(_surrender_button, surface.get("surrender", {}), "Surrender", "")
	_append_battle_exit_order_cues(surface)
	# Quick Resolve plays the whole battle out, so it is offered only before
	# the player's first order.
	_quick_resolve_button.visible = not BattleRules.player_has_given_orders(_session.battle)
	_quick_resolve_button.disabled = _battle_exit_handoff_in_progress or _session.battle.is_empty() or _session.scenario_status != "in_progress"
	_quick_resolve_button.tooltip_text = "Quick Resolve: play the whole battle out at once. Only before your first order. Casualties, mana and the outcome are final."
	var hero := BattleRules.hero_presentation(_session.battle, "player")
	_spellbook_button.disabled = hero.is_empty()
	_spellbook_button.set_badge(str(int(hero.get("mana_current", 0))) if not hero.is_empty() else "")
	_spellbook_button.tooltip_text = (
		"No commander leads your army."
		if hero.is_empty()
		else "Spellbook (S or C): %s's spells. Mana %d/%d. One spell a round; the stack keeps its turn." % [
			String(hero.get("name", "Commander")),
			int(hero.get("mana_current", 0)),
			int(hero.get("mana_max", 0)),
		]
	)
	_auto_button.disabled = _session.scenario_status != "in_progress"
	_refresh_auto_button()


func _apply_command_surface(button: Button, action_value: Variant, label: String, key_text: String) -> void:
	var action: Dictionary = action_value if action_value is Dictionary else {}
	button.disabled = action.is_empty() or bool(action.get("disabled", false))
	var detail := String(action.get("tooltip", action.get("summary", ""))).strip_edges()
	var title := label if key_text == "" else "%s (%s)" % [label, key_text]
	button.tooltip_text = title if detail == "" else "%s\n%s" % [title, detail]
	button.accessibility_name = label
	button.accessibility_description = detail
	button.set_meta("battle_action_label", String(action.get("label", label)))


func _append_battle_exit_order_cues(action_surface: Dictionary) -> void:
	var exit_cue := _battle_exit_order_cue_surface(action_surface)
	if exit_cue.is_empty():
		return
	var retreat_cue := String(exit_cue.get("retreat_tooltip", "")).strip_edges()
	if retreat_cue != "":
		_retreat_button.tooltip_text = _join_tooltip_sections([_retreat_button.tooltip_text, retreat_cue])
	var surrender_cue := String(exit_cue.get("surrender_tooltip", "")).strip_edges()
	if surrender_cue != "":
		_surrender_button.tooltip_text = _join_tooltip_sections([_surrender_button.tooltip_text, surrender_cue])


## Each hero's plate under its feet: portrait and crest, name, mana and
## whether it can cast. A side without a commander, or a guard's commander
## with neither a figure nor battle spells, has no plate.
func _refresh_hero_plates() -> void:
	for side: String in ["player", "enemy"]:
		var hero := BattleRules.hero_presentation(_session.battle, side)
		var plate := _player_plate if side == "player" else _enemy_plate
		var shown := not hero.is_empty() and (bool(hero.get("has_figure", false)) or int(hero.get("battle_spell_count", 0)) > 0)
		plate.visible = shown
		var portrait: HeroPortraitView = _player_commander_portrait if side == "player" else _enemy_commander_portrait
		var hero_id := String(hero.get("hero_id", ""))
		if hero_id == "":
			hero_id = _battle_player_hero_id() if side == "player" else _battle_enemy_hero_id()
		var has_portrait := portrait.set_hero_id(hero_id) if shown else portrait.set_hero_id("")
		var crest: TextureRect = _player_crest if side == "player" else _enemy_crest
		var crest_path := BattleHeroFigureScript.crest_path(String(hero.get("faction_id", "")))
		crest.texture = load(crest_path) as Texture2D if crest_path != "" else null
		crest.visible = crest.texture != null
		crest.set_meta("has_portrait", has_portrait)
		if not shown:
			continue
		var name_label: Label = _player_hero_name if side == "player" else _enemy_hero_name
		var mana_bar: ProgressBar = _player_mana_bar if side == "player" else _enemy_mana_bar
		var mana_text: Label = _player_mana_text if side == "player" else _enemy_mana_text
		var status_label: Label = _player_hero_status if side == "player" else _enemy_hero_status
		name_label.text = String(hero.get("name", "Commander"))
		var mana_max := maxi(0, int(hero.get("mana_max", 0)))
		var mana_current := clampi(int(hero.get("mana_current", 0)), 0, maxi(mana_max, int(hero.get("mana_current", 0))))
		mana_bar.max_value = maxf(1.0, float(mana_max))
		mana_bar.value = float(mana_current)
		mana_text.text = "%d/%d" % [mana_current, mana_max]
		var ready := side == "player" and _spell_targeting_id == "" and _hero_can_cast_now()
		status_label.text = _hero_status_text(side, hero, ready)
		status_label.add_theme_color_override("font_color", READY_TEXT if ready else MUTED)
		var tooltip := PackedStringArray([String(hero.get("name", "Commander"))])
		var role := String(hero.get("role", "")).strip_edges()
		if role != "":
			tooltip.append(role)
		tooltip.append("Mana %d/%d" % [mana_current, mana_max])
		tooltip.append(status_label.text)
		if side == "player":
			tooltip.append("Click: spellbook (S). One spell a round; the stack keeps its turn.")
		plate.tooltip_text = "\n".join(tooltip)
		plate.accessibility_name = "%s, %s commander" % [name_label.text, "your" if side == "player" else "enemy"]
		plate.accessibility_description = plate.tooltip_text


func _hero_status_text(side: String, hero: Dictionary, ready: bool) -> String:
	if bool(hero.get("cast_this_round", false)):
		return "Spell cast this round"
	var spell_count := int(hero.get("battle_spell_count", 0))
	if spell_count <= 0:
		return "Knows no battle spells"
	if side == "enemy":
		return "Knows %d battle spell%s" % [spell_count, "" if spell_count == 1 else "s"]
	if ready:
		return "Ready to cast"
	if _spell_targeting_id != "":
		return "Choosing a target"
	return "Casts on your turn"


## The log line: a hint while one stands, else the latest entry of the battle
## log, else what to do.
func _refresh_log_line() -> void:
	if _log_line == null:
		return
	var text := _command_hint
	var hint := text != ""
	if text == "" and _message_log != null and not _message_log.entries.is_empty():
		text = String(_message_log.entries.back())
	if text == "":
		text = _last_message.strip_edges().get_slice("\n", 0)
	if text == "":
		text = _idle_log_text()
	_log_line.text = text
	_log_line.tooltip_text = "%s\n\nClick for the battle log." % text
	_log_line.add_theme_color_override("font_color", GOLD_HI if hint else LOG_TEXT)
	_log_line.add_theme_color_override("font_hover_color", GOLD_HI if hint else CREAM)
	_log_line.add_theme_color_override("font_focus_color", GOLD_HI if hint else CREAM)


func _idle_log_text() -> String:
	if _session == null or _session.battle.is_empty():
		return "The battle is over."
	var active := BattleRules.get_active_stack(_session.battle)
	if active.is_empty():
		return "The battle begins."
	if String(active.get("side", "")) == "player":
		var stack_name := String(active.get("name", "Your stack"))
		if bool(active.get("ranged", false)) and int(active.get("shots_remaining", 0)) > 0:
			return "%s: click an enemy to shoot (Ctrl: strike), or a hex to move." % stack_name
		return "%s: click an enemy to attack, or a hex to move." % stack_name
	return "The enemy's %s acts." % String(active.get("name", "stack"))


func _set_command_hint(text: String, seconds: float = HINT_SECONDS) -> void:
	_command_hint = text.strip_edges().get_slice("\n", 0) if text.strip_edges() != "" else ""
	_command_hint_serial += 1
	_refresh_log_line()
	if seconds > 0.0 and _command_hint != "" and is_inside_tree():
		get_tree().create_timer(seconds).timeout.connect(_expire_command_hint.bind(_command_hint_serial))


func _expire_command_hint(serial: int) -> void:
	if serial != _command_hint_serial or _spell_targeting_id != "":
		return
	_command_hint = ""
	_refresh_log_line()


## A new round shows its number over the field for a moment.
func _announce_round() -> void:
	var round_number := int(_session.battle.get("round", 1))
	if round_number == _last_banner_round:
		return
	_last_banner_round = round_number
	_show_banner("Round %d" % round_number)


func _show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.accessibility_name = text
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_layout_hud()
	if SettingsService.reduced_motion_enabled() or DisplayServer.get_name() == "headless":
		_banner.modulate.a = 1.0
		_banner_tween = create_tween()
		_banner_tween.tween_interval(BANNER_SECONDS)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.01)
		return
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_interval(BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.45)


# --- Layout ------------------------------------------------------------------

## Places the HUD around the field the board lays out: the plates under the
## heroes' feet, the command bar along the bottom, popovers above it.
func _layout_hud() -> void:
	if not is_inside_tree() or _battle_board_view == null:
		return
	var k: float = _battle_board_view.ui_scale()
	if not is_equal_approx(k, _hud_scale):
		_apply_hud_scale(k)
	var view := size
	var bar_size := Vector2(minf(BAR_WIDTH * k, view.x - 24.0 * k), BAR_HEIGHT * k)
	_command_bar.custom_minimum_size = bar_size
	_command_bar.size = bar_size
	_command_bar.position = Vector2(round((view.x - _command_bar.size.x) * 0.5), round(view.y - BAR_BOTTOM * k - _command_bar.size.y))
	var bar_rect := Rect2(_command_bar.position, _command_bar.size)
	_layout_plate(_player_plate, "player", k)
	_layout_plate(_enemy_plate, "enemy", k)
	_layout_popover(_options_popover, OPTIONS_WIDTH * k, bar_rect, "left", k)
	_spell_scroll.custom_minimum_size.y = minf(_spell_list.get_combined_minimum_size().y, SPELLBOOK_MAX_HEIGHT * k - 110.0 * k)
	_layout_popover(_spellbook_popover, SPELLBOOK_WIDTH * k, bar_rect, "right", k)
	_log_popover.custom_minimum_size = Vector2(minf(LOG_WIDTH * k, view.x - 24.0 * k), LOG_HEIGHT * k)
	_layout_popover(_log_popover, _log_popover.custom_minimum_size.x, bar_rect, "center", k)
	_banner.size = Vector2(view.x, 0.0)
	_banner.reset_size()
	_banner.size.x = view.x
	_banner.position = Vector2(0.0, BANNER_TOP * k)
	var result_width := minf(RESULT_WIDTH * k, view.x - 32.0 * k)
	_result_panel.custom_minimum_size = Vector2(result_width, 0.0)
	_result_panel.reset_size()
	_result_panel.position = ((view - _result_panel.size) * 0.5).round()
	_show_result_button.reset_size()
	_show_result_button.position = Vector2(round((view.x - _show_result_button.size.x) * 0.5), round(view.y - BAR_BOTTOM * k - _show_result_button.size.y))
	_layout_details_card()


## Panels sized by their content settle over a frame as wrapped labels learn
## their width, and a Control only grows to its minimum size by itself: each
## change lays the HUD out again, once per frame.
func _queue_hud_layout() -> void:
	if _hud_layout_queued:
		return
	_hud_layout_queued = true
	call_deferred("_run_queued_hud_layout")


func _run_queued_hud_layout() -> void:
	_hud_layout_queued = false
	_layout_hud()


func _layout_plate(plate: PanelContainer, side: String, k: float) -> void:
	var emblem: Control = _player_plate_emblem if side == "player" else _enemy_plate_emblem
	var portrait: Control = _player_commander_portrait if side == "player" else _enemy_commander_portrait
	var crest: TextureRect = _player_crest if side == "player" else _enemy_crest
	var emblem_size := Vector2(42.0, 56.0) * k
	emblem.custom_minimum_size = emblem_size
	portrait.position = Vector2.ZERO
	portrait.size = emblem_size
	if portrait.visible:
		# The crest is a small badge on the portrait's lower corner.
		crest.size = Vector2(20.0, 20.0) * k
		crest.position = emblem_size - crest.size + Vector2(5.0, 5.0) * k
	else:
		crest.size = Vector2(42.0, 42.0) * k
		crest.position = Vector2(0.0, (emblem_size.y - crest.size.y) * 0.5)
	var layout: Dictionary = _battle_board_view.hero_figure_layout(side)
	var grid: Rect2 = layout.get("grid_rect", Rect2())
	var edge := PLATE_EDGE * k
	# Wide enough for the commander's whole name where the field leaves room
	# beside the hexes; a long name in a narrow space gets a smaller font.
	var name_label: Label = _player_hero_name if side == "player" else _enemy_hero_name
	var name_font_size := _font_size(15.0)
	var name_width := name_label.get_theme_font("font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_font_size).x
	var chrome := emblem_size.x + 12.0 * k + plate.get_theme_stylebox("panel").get_minimum_size().x
	var room := PLATE_MAX_WIDTH * k
	if not layout.is_empty():
		room = minf(room, grid.position.x - PLATE_GRID_GAP * k - edge if side == "player" else size.x - edge - grid.end.x - PLATE_GRID_GAP * k)
	var width := clampf(name_width + chrome, PLATE_WIDTH * k, maxf(PLATE_WIDTH * k, room))
	if name_width + chrome > width and name_width > 0.0:
		name_font_size = maxi(int(round(name_font_size * 0.8)), int(floor(name_font_size * (width - chrome) / name_width)))
	name_label.add_theme_font_size_override("font_size", name_font_size)
	plate.custom_minimum_size = Vector2(width, 0.0)
	plate.reset_size()
	if layout.is_empty():
		return
	var foot: Vector2 = layout.get("foot", Vector2.ZERO)
	# Centred below the hero's feet, between the window's edge and the hexes.
	var far_edge := size.x - edge - plate.size.x
	var x := foot.x - plate.size.x * 0.5
	if side == "player":
		x = clampf(x, edge, maxf(edge, grid.position.x - PLATE_GRID_GAP * k - plate.size.x))
	else:
		x = clampf(x, minf(far_edge, grid.end.x + PLATE_GRID_GAP * k), far_edge)
	var y := clampf(foot.y + PLATE_BELOW_FOOT * k, 0.0, maxf(0.0, size.y - plate.size.y - (BAR_HEIGHT + BAR_BOTTOM + 8.0) * k))
	plate.position = Vector2(round(x), round(y))


func _layout_popover(popover: PanelContainer, width: float, bar_rect: Rect2, align: String, k: float) -> void:
	popover.custom_minimum_size.x = width
	popover.reset_size()
	var x := bar_rect.position.x
	if align == "right":
		x = bar_rect.end.x - popover.size.x
	elif align == "center":
		x = bar_rect.position.x + (bar_rect.size.x - popover.size.x) * 0.5
	x = clampf(x, 8.0 * k, maxf(8.0 * k, size.x - popover.size.x - 8.0 * k))
	popover.position = Vector2(round(x), round(maxf(8.0 * k, bar_rect.position.y - POPOVER_GAP * k - popover.size.y)))


## Sizes, fonts and styles of the HUD for a window scaled by k.
func _apply_hud_scale(k: float) -> void:
	_hud_scale = k
	for button in [_options_button, _surrender_button, _retreat_button, _auto_button, _quick_resolve_button]:
		button.apply_scale(k, SMALL_BUTTON)
	for button in [_spellbook_button, _wait_button, _defend_button]:
		button.apply_scale(k, BIG_BUTTON)
	_log_open_button.apply_scale(k, LOG_BUTTON)
	_command_row.add_theme_constant_override("separation", int(round(10.0 * k)))
	for row in [_left_commands, _right_commands]:
		row.add_theme_constant_override("separation", int(round(8.0 * k)))
	_command_bar.add_theme_stylebox_override("panel", _hud_panel_style(BAR_FILL, 14.0, Vector4(12.0, 7.0, 12.0, 7.0), k))
	_log_line.custom_minimum_size = Vector2(120.0 * k, 46.0 * k)
	_log_line.add_theme_font_size_override("font_size", _font_size(16.0))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_log_line.add_theme_stylebox_override(state, _log_line_style(state, k))
	for side: String in ["player", "enemy"]:
		var plate := _player_plate if side == "player" else _enemy_plate
		var tint := PLAYER_TINT if side == "player" else ENEMY_TINT
		plate.add_theme_stylebox_override("panel", _plate_style(tint, k))
		var row := plate.get_child(0) as HBoxContainer
		row.add_theme_constant_override("separation", int(round(10.0 * k)))
		var name_label: Label = _player_hero_name if side == "player" else _enemy_hero_name
		name_label.add_theme_font_size_override("font_size", _font_size(15.0))
		name_label.add_theme_color_override("font_color", GOLD_HI)
		if _title_font != null:
			name_label.add_theme_font_override("font", _title_font)
		var mana_bar: ProgressBar = _player_mana_bar if side == "player" else _enemy_mana_bar
		mana_bar.custom_minimum_size = Vector2(60.0 * k, 7.0 * k)
		mana_bar.add_theme_stylebox_override("background", _bar_style(Color(0.0, 0.0, 0.0, 0.5), k))
		mana_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.373, 0.627, 0.941), k))
		var mana_text: Label = _player_mana_text if side == "player" else _enemy_mana_text
		mana_text.add_theme_font_size_override("font_size", _font_size(12.0))
		mana_text.add_theme_color_override("font_color", MANA_TEXT)
		var mana_row := mana_bar.get_parent() as HBoxContainer
		mana_row.add_theme_constant_override("separation", int(round(7.0 * k)))
		var status_label: Label = _player_hero_status if side == "player" else _enemy_hero_status
		status_label.add_theme_font_size_override("font_size", _font_size(12.5))
		(plate.get_child(0).get_child(1) as VBoxContainer).add_theme_constant_override("separation", int(round(3.0 * k)))
	for popover in [_options_popover, _spellbook_popover, _log_popover]:
		popover.add_theme_stylebox_override("panel", _hud_panel_style(PANEL_FILL, 12.0, Vector4(14.0, 14.0, 14.0, 14.0), k))
		var box := popover.get_child(0) as VBoxContainer
		box.add_theme_constant_override("separation", int(round(10.0 * k)))
	for title in [_options_title, _log_title, _spellbook_hero_name]:
		title.add_theme_font_size_override("font_size", _font_size(15.0 if title != _spellbook_hero_name else 16.0))
		title.add_theme_color_override("font_color", GOLD_HI)
		if _title_font != null:
			title.add_theme_font_override("font", _title_font)
	_spellbook_portrait.custom_minimum_size = Vector2(54.0, 72.0) * k
	_spellbook_hero_stats.add_theme_font_size_override("font_size", _font_size(13.0))
	_spellbook_hero_stats.add_theme_color_override("font_color", MANA_TEXT)
	_spellbook_note.add_theme_font_size_override("font_size", _font_size(13.0))
	(_spellbook_portrait.get_parent() as HBoxContainer).add_theme_constant_override("separation", int(round(12.0 * k)))
	_spell_list.add_theme_constant_override("separation", int(round(6.0 * k)))
	for label in [_speed_label, _grid_label]:
		label.add_theme_font_size_override("font_size", _font_size(13.5))
		label.add_theme_color_override("font_color", CREAM)
	for button in [_speed_normal_button, _speed_fast_button, _speed_instant_button, _grid_full_button, _grid_range_button, _grid_off_button]:
		_style_popover_button(button, Vector2(72.0, 32.0) * k, k)
	for bar in [_speed_bar, _grid_bar]:
		bar.add_theme_constant_override("separation", int(round(4.0 * k)))
	for button in [_save_button, _settings_button, _menu_button]:
		_style_popover_button(button, Vector2(96.0, 36.0) * k, k)
	(_save_button.get_parent() as HBoxContainer).add_theme_constant_override("separation", int(round(8.0 * k)))
	_system_body_label.add_theme_font_size_override("font_size", _font_size(12.5))
	_system_body_label.add_theme_color_override("font_color", MUTED)
	_message_log.history.add_theme_font_size_override("normal_font_size", _font_size(14.0))
	_message_log.history.custom_minimum_size.y = 220.0 * k
	_banner.add_theme_font_size_override("font_size", _font_size(30.0))
	_banner.add_theme_color_override("font_color", GOLD_HI)
	_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	_banner.add_theme_constant_override("shadow_offset_x", int(round(2.0 * k)))
	_banner.add_theme_constant_override("shadow_offset_y", int(round(2.0 * k)))
	if _title_font != null:
		_banner.add_theme_font_override("font", _title_font)
	_apply_result_scale(k)


func _apply_result_scale(k: float) -> void:
	_result_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.075, 0.059, 0.039, 0.96), 16.0, Vector4(30.0, 26.0, 30.0, 24.0), k))
	(_result_panel.get_child(0) as VBoxContainer).add_theme_constant_override("separation", int(round(14.0 * k)))
	_result_title.add_theme_font_size_override("font_size", _font_size(32.0))
	if _title_font != null:
		_result_title.add_theme_font_override("font", _title_font)
	_result_lead.add_theme_font_size_override("font_size", _font_size(17.0))
	_result_lead.add_theme_color_override("font_color", CREAM)
	for title in [_player_losses_title, _enemy_losses_title]:
		title.add_theme_font_size_override("font_size", _font_size(14.0))
		title.add_theme_color_override("font_color", GOLD)
		if _title_font != null:
			title.add_theme_font_override("font", _title_font)
	(_player_loss_icons.get_parent().get_parent() as HBoxContainer).add_theme_constant_override("separation", int(round(24.0 * k)))
	for flow in [_player_loss_icons, _enemy_loss_icons]:
		flow.add_theme_constant_override("h_separation", int(round(8.0 * k)))
		flow.add_theme_constant_override("v_separation", int(round(8.0 * k)))
	_result_aftermath.add_theme_font_size_override("font_size", _font_size(14.0))
	_result_aftermath.add_theme_color_override("font_color", MUTED)
	_result_status.add_theme_font_size_override("font_size", _font_size(13.5))
	_result_status.add_theme_color_override("font_color", Color(0.95, 0.70, 0.62))
	(_continue_button.get_parent() as HBoxContainer).add_theme_constant_override("separation", int(round(10.0 * k)))
	_style_popover_button(_view_field_button, Vector2(150.0, 42.0) * k, k)
	_style_popover_button(_continue_button, Vector2(170.0, 42.0) * k, k, true)
	_style_popover_button(_show_result_button, Vector2(170.0, 42.0) * k, k, true)


func _font_size(base: float) -> int:
	return maxi(8, int(round(base * _hud_scale)))


func _hud_panel_style(fill: Color, radius: float, padding: Vector4, k: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = GOLD_DIM
	style.set_border_width_all(maxi(1, int(round(k))))
	style.set_corner_radius_all(int(round(radius * k)))
	style.content_margin_left = padding.x * k
	style.content_margin_top = padding.y * k
	style.content_margin_right = padding.z * k
	style.content_margin_bottom = padding.w * k
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = int(round(10.0 * k))
	style.shadow_offset = Vector2(0.0, 3.0) * k
	return style


func _plate_style(tint: Color, k: float) -> StyleBoxFlat:
	var style := _hud_panel_style(PANEL_FILL, 10.0, Vector4(8.0, 8.0, 10.0, 9.0), k)
	# The side's colour runs along the plate's outer edge.
	style.border_color = GOLD_DIM
	style.border_width_left = int(round(3.0 * k)) if tint == PLAYER_TINT else maxi(1, int(round(k)))
	style.border_width_right = int(round(3.0 * k)) if tint == ENEMY_TINT else maxi(1, int(round(k)))
	style.border_blend = false
	return style


func _bar_style(fill: Color, k: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(round(3.5 * k)))
	style.content_margin_top = 3.5 * k
	style.content_margin_bottom = 3.5 * k
	return style


func _log_line_style(state: String, k: float) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(round(8.0 * k)))
	style.content_margin_left = 14.0 * k
	style.content_margin_right = 14.0 * k
	match state:
		"hover", "hover_pressed":
			style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
		"pressed":
			style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		"focus":
			style.draw_center = false
			style.border_color = BattleCommandButtonScript.ACTIVE
			style.set_border_width_all(maxi(2, int(round(2.0 * k))))
			return style
		_:
			style.bg_color = LOG_FILL
	return style


func _style_popover_button(button: Button, minimum: Vector2, k: float, primary: bool = false) -> void:
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_size(14.0))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(round(8.0 * k)))
		style.set_border_width_all(maxi(1, int(round(k))))
		style.content_margin_left = 12.0 * k
		style.content_margin_right = 12.0 * k
		match state:
			"hover", "hover_pressed":
				style.bg_color = Color(0.36, 0.27, 0.13, 0.95) if primary else Color(0.208, 0.173, 0.118, 0.95)
				style.border_color = GOLD
			"pressed":
				style.bg_color = Color(0.110, 0.090, 0.059, 0.98)
				style.border_color = BattleCommandButtonScript.ACTIVE
			"disabled":
				style.bg_color = Color(0.0, 0.0, 0.0, 0.25)
				style.border_color = Color(BattleCommandButtonScript.ACTIVE, 0.5)
			"focus":
				style.draw_center = false
				style.border_color = BattleCommandButtonScript.ACTIVE
				style.set_border_width_all(maxi(2, int(round(2.0 * k))))
				style.set_expand_margin_all(2.0 * k)
			_:
				style.bg_color = Color(0.30, 0.22, 0.10, 0.95) if primary else Color(0.157, 0.129, 0.090, 0.95)
				style.border_color = GOLD if primary else GOLD_DIM
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", GOLD_HI if primary else CREAM)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.953, 0.816))
	button.add_theme_color_override("font_pressed_color", BattleCommandButtonScript.ACTIVE)
	button.add_theme_color_override("font_focus_color", GOLD_HI if primary else CREAM)


func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_confirmation_dialog(_quick_resolve_confirmation_dialog, "primary")
	FrontierVisualKit.apply_confirmation_dialog(_withdrawal_confirmation_dialog, "danger")
	FrontierVisualKit.apply_confirmation_dialog(_manual_save_overwrite_dialog as ConfirmationDialog, "danger")
	if _title_font == null:
		_title_font = SystemFont.new()
		_title_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "DejaVu Serif", "Liberation Serif", "Noto Serif", "serif"])
		_title_font.font_weight = 600
	_settings_button.tooltip_text = "Adjust sound, battle pace, and readability without leaving the battle."
	_menu_button.tooltip_text = "Return to the main menu after updating autosave."
	_view_field_button.tooltip_text = "Hide the result and look at the field as the battle ended."
	_show_result_button.tooltip_text = "Show the battle result again."
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_hud_scale(maxf(0.3, _hud_scale))


# --- Result --------------------------------------------------------------------

## The battle is over and its report saved: the result shows over the still
## field. Continue acknowledges it and goes on; View the field hides it.
func _show_result_overlay(entry_result: Dictionary = {}) -> void:
	_battle_over = true
	_result_entry_result = entry_result.duplicate(true)
	_stop_auto_battle()
	_cancel_spell_targeting(false)
	_close_popovers(false)
	_close_details()
	_set_command_hint("")
	_result_report = BattleRules.pending_battle_report(_session) if _session != null else {}
	if _result_report.is_empty():
		# No report to show: the router opens the next screen itself.
		AppRouter.go_to_battle_report()
		return
	_battle_board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_board_view.focus_mode = Control.FOCUS_NONE
	_battle_board_view.set_hero_cast_ready(false)
	_command_bar.hide()
	for status_label in [_player_hero_status, _enemy_hero_status]:
		status_label.text = "The battle is over"
		status_label.add_theme_color_override("font_color", MUTED)
	_populate_result()
	_result_overlay.show()
	_show_result_button.hide()
	var won := String(_result_report.get("outcome", "")) in WON_OUTCOMES
	MusicAudio.sync_context("outcome", "battle_report_ready", {
		"scenario_id": _session.scenario_id if _session != null else "",
		"status": "victory" if won else "defeat",
	})
	if _session != null:
		MusicAudio.play_stinger("stinger_battle_win" if won else "stinger_battle_loss", "%s:report:%s" % [_session.session_id, String(_result_report.get("report_id", ""))])
	_layout_hud()
	_queue_hud_layout()
	call_deferred("_configure_battle_keyboard_focus", true)


func _populate_result() -> void:
	var outcome := String(_result_report.get("outcome", "resolved"))
	var won := outcome in WON_OUTCOMES
	_result_title.text = _result_title_text(outcome)
	_result_title.add_theme_color_override("font_color", GOLD_HI if won else Color(0.92, 0.62, 0.55))
	_result_title.accessibility_name = "Battle result: %s" % _result_title.text
	var lead_parts := PackedStringArray()
	var battle_name := String(_result_report.get("battle_name", "")).strip_edges()
	if battle_name != "":
		lead_parts.append(battle_name)
	var rounds := int(_result_report.get("rounds", 0))
	if rounds > 0:
		lead_parts.append("%d round%s" % [rounds, "" if rounds == 1 else "s"])
	var summary := String(_result_report.get("summary", "")).strip_edges()
	_result_lead.text = "%s\n%s" % [" · ".join(lead_parts), summary] if summary != "" else " · ".join(lead_parts)
	var casualties: Dictionary = _result_report.get("casualties", {}) if _result_report.get("casualties", {}) is Dictionary else {}
	_fill_loss_icons(_player_loss_icons, casualties.get("player", {}))
	_fill_loss_icons(_enemy_loss_icons, casualties.get("enemy", {}))
	var aftermath_lines: Array[String] = []
	for key in ["result_summary", "reward_summary", "artifact_summary", "force_summary", "world_summary"]:
		var line := String(_result_report.get(key, "")).strip_edges()
		# The lead already says how the battle ended.
		if summary != "" and line.contains(summary):
			continue
		_append_distinct_line(aftermath_lines, line)
	_result_aftermath.text = "\n".join(aftermath_lines)
	_result_aftermath.visible = not aftermath_lines.is_empty()
	var terminal := _session != null and _session.scenario_status != "in_progress"
	if String(_result_entry_result.get("reason", "")) == "autosave_failed":
		_result_status.text = String(_result_entry_result.get("message", "The result is not saved yet. Continue will retry."))
		_result_status.show()
	else:
		_result_status.hide()
	_continue_button.disabled = false
	_continue_button.text = "Continue"
	_continue_button.tooltip_text = "Save the result and continue to %s." % ("the scenario outcome" if terminal else "the adventure map")
	_continue_button.accessibility_name = "Continue from the battle result"
	_continue_button.accessibility_description = _continue_button.tooltip_text


func _result_title_text(outcome: String) -> String:
	match outcome:
		"victory":
			return "Victory"
		"enemy_retreat":
			return "The enemy fled"
		"enemy_surrender":
			return "The enemy surrendered"
		"defeat":
			return "Defeat"
		"retreat":
			return "You retreated"
		"surrender":
			return "You surrendered"
		"stalemate":
			return "Stalemate"
		"hero_defeat":
			return "Your commander fell"
		"town_lost":
			return "The town is lost"
	return outcome.replace("_", " ").capitalize() if outcome != "" else "The battle is over"


func _append_distinct_line(lines: Array[String], text: String) -> void:
	if text == "":
		return
	for existing in lines:
		if existing == text or existing.contains(text) or text.contains(existing):
			return
	lines.append(text)


## One round icon per company that lost men, with how many.
func _fill_loss_icons(flow: HFlowContainer, side_value: Variant) -> void:
	for child in flow.get_children():
		flow.remove_child(child)
		child.queue_free()
	var side: Dictionary = side_value if side_value is Dictionary else {}
	var rows: Variant = side.get("rows", [])
	var k := _hud_scale
	if rows is Array:
		for row_value in rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			var lost := maxi(0, int(row.get("lost", 0)))
			if lost <= 0:
				continue
			flow.add_child(_loss_icon(row, lost, k))
	if flow.get_child_count() == 0:
		var none := Label.new()
		none.text = "None"
		none.add_theme_color_override("font_color", MUTED)
		none.add_theme_font_size_override("font_size", _font_size(14.0))
		flow.add_child(none)


func _loss_icon(row: Dictionary, lost: int, k: float) -> Control:
	var unit_id := String(row.get("unit_id", ""))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(LOSS_ICON, LOSS_ICON) * k
	holder.tooltip_text = "%s: %d lost of %d" % [String(row.get("name", unit_id)), lost, maxi(lost, int(row.get("starting", lost)))]
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var disc := Panel.new()
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc_style := StyleBoxFlat.new()
	disc_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	disc_style.border_color = GOLD_DIM
	disc_style.set_border_width_all(maxi(1, int(round(k))))
	disc_style.set_corner_radius_all(int(round(LOSS_ICON * 0.5 * k)))
	disc.add_theme_stylebox_override("panel", disc_style)
	holder.add_child(disc)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4.0 * k
	icon.offset_top = 4.0 * k
	icon.offset_right = -4.0 * k
	icon.offset_bottom = -4.0 * k
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := String(ContentService.get_unit_art(unit_id).get("battle_icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	holder.add_child(icon)
	var badge := Label.new()
	badge.text = "-%d" % lost
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", _font_size(12.0))
	badge.add_theme_color_override("font_color", CREAM)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.45, 0.13, 0.10, 0.95)
	badge_style.set_corner_radius_all(int(round(8.0 * k)))
	badge_style.content_margin_left = 5.0 * k
	badge_style.content_margin_right = 5.0 * k
	badge.add_theme_stylebox_override("normal", badge_style)
	# Hangs off the disc's lower right corner at whatever size the flow gives
	# the disc, growing up and to the left from there.
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_left = 4.0 * k
	badge.offset_right = 4.0 * k
	badge.offset_top = 2.0 * k
	badge.offset_bottom = 2.0 * k
	holder.add_child(badge)
	return holder


func _on_result_continue_pressed() -> Dictionary:
	if _result_continue_in_progress:
		return {"ok": false, "reason": "continue_in_progress"}
	_result_continue_in_progress = true
	_continue_button.disabled = true
	var result_value: Variant = AppRouter.complete_battle_report()
	var result: Dictionary = result_value if result_value is Dictionary else {}
	_last_continue_result = result.duplicate(true)
	_result_continue_in_progress = false
	if bool(result.get("ok", false)):
		return result
	_continue_button.disabled = false
	_continue_button.text = "Retry Continue"
	_result_status.text = String(result.get("message", "The result could not be saved. Continue will retry."))
	_result_status.show()
	_layout_hud()
	_continue_button.grab_focus()
	return result


func _on_view_field_pressed() -> void:
	if not _battle_over:
		return
	_result_overlay.hide()
	_show_result_button.show()
	_layout_hud()
	_show_result_button.grab_focus()


func _on_show_result_pressed() -> void:
	if not _battle_over:
		return
	_show_result_button.hide()
	_result_overlay.show()
	_layout_hud()
	_continue_button.grab_focus()


# --- Keyboard focus ------------------------------------------------------------

## Tab cycles the field and the command bar, or the open popover's controls,
## or the result's buttons. The field is where keys act first.
func _configure_battle_keyboard_focus(force: bool = false) -> void:
	if not is_inside_tree() or _session == null or _modal_window_open():
		return
	var surfaces: Array = []
	if _result_overlay.visible:
		surfaces = [_continue_button, _view_field_button]
	elif _any_popover_open():
		for popover in [_options_popover, _spellbook_popover, _log_popover]:
			if popover.visible:
				surfaces.append(popover)
	elif _battle_over:
		surfaces = [_show_result_button]
	else:
		surfaces = [_battle_board_view, _left_commands, _log_line, _log_open_button, _right_commands]
	var controls := FrontierVisualKit.configure_focus_cycle(surfaces)
	_last_battle_keyboard_focus_cycle_names = []
	for control in controls:
		if control is Control:
			_last_battle_keyboard_focus_cycle_names.append(String(control.name))
	FrontierVisualKit.grab_keyboard_focus(self, _preferred_battle_keyboard_focus(), controls, force)


func _preferred_battle_keyboard_focus() -> Control:
	if _result_overlay.visible:
		return _continue_button
	if _battle_over:
		return _show_result_button
	if _options_popover.visible:
		if _briefing_consumption_autosave_failure_pending or not _battle_resolution_checkpoint_pending.is_empty():
			return _save_button
		return _first_enabled_speed_button()
	if _spellbook_popover.visible:
		for row in _spell_list.get_children():
			if row is Button and FrontierVisualKit.is_keyboard_focusable(row):
				return row
		return null
	if _log_popover.visible:
		return _message_log.history
	return _battle_board_view


func _battle_profile_metadata(first_render: bool) -> Dictionary:
	var battle := _session.battle if _session != null and _session.battle is Dictionary else {}
	var stacks = battle.get("stacks", []) if battle is Dictionary else []
	return {
		"first_render": first_render,
		"encounter_id": String(battle.get("encounter_id", "")) if battle is Dictionary else "",
		"battle_name": String(battle.get("encounter_name", "")) if battle is Dictionary else "",
		"round": int(battle.get("round", 0)) if battle is Dictionary else 0,
		"turn_index": int(battle.get("turn_index", 0)) if battle is Dictionary else 0,
		"stack_count": stacks.size() if stacks is Array else 0,
	}


# --- Save surface ------------------------------------------------------------

func _configure_save_slot_picker() -> void:
	_save_slot_picker.hide()
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))


func _refresh_save_slot_picker() -> void:
	if _save_slot_picker.get_item_count() <= 0:
		return
	_save_surface_build_count += 1
	_save_details_stale = false
	var surface := AppRouter.active_save_surface({}, false)
	var selected_slot := SaveService.get_selected_manual_slot()
	_apply_save_bar_status(surface, selected_slot)
	var summary_value: Variant = surface.get("slot_summary")
	var summary: Dictionary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	# This summary was just inspected by SaveService and already owns its exact
	# stored-state copy. Rebuilding it twice reconstructs old worlds per action.
	var summary_detail := String(summary.get("detail", ""))
	if summary_detail == "":
		summary_detail = SaveService.describe_slot_details(summary)
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var save_check := String(surface.get("save_check", ""))
	var save_handoff := String(surface.get("save_handoff", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
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
	save_tooltip_lines.append("Selected slot:\n%s" % summary_detail)
	_system_body_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = summary_detail
	_save_button.tooltip_text = _join_tooltip_sections([
		"Create or replace a named file for the current battle.",
		save_check,
		save_handoff,
	])
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))


## The save rows' visible part: slot selection, the status lines and the
## button labels. The full save surface and SaveService.in_session_save_bar_status()
## both carry these fields.
func _apply_save_bar_status(surface: Dictionary, selected_slot: int) -> void:
	for index in range(_save_slot_picker.get_item_count()):
		if _save_slot_picker.get_item_id(index) == selected_slot:
			_save_slot_picker.select(index)
			break
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var save_handoff_brief := String(surface.get("save_handoff_brief", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var status_lines := []
	if save_handoff_brief != "":
		status_lines.append(save_handoff_brief)
	if latest_context != "":
		status_lines.append(latest_context)
	if status_lines.is_empty() and return_handoff != "":
		status_lines.append(return_handoff)
	_system_body_label.visible = not status_lines.is_empty()
	_system_body_label.text = "\n".join(status_lines.slice(0, min(2, status_lines.size())))
	_save_button.text = "Save game"
	# "Editor" when the battle plays from the map editor's working copy.
	_menu_button.text = String(surface.get("menu_button_label", "Main Menu"))


## Every refresh: the visible save rows without copying the session. Their
## tooltips come from _refresh_save_slot_picker() when a save control shows.
func _refresh_save_bar_status() -> void:
	if _save_slot_picker.get_item_count() <= 0 or not _battle_resolution_checkpoint_pending.is_empty():
		return
	var selected_slot := SaveService.get_selected_manual_slot()
	_apply_save_bar_status(SaveService.in_session_save_bar_status(_session, selected_slot), selected_slot)


## Builds the save tooltips when they are stale. A failed battle checkpoint
## owns the save rows until it is retried.
func _build_save_details() -> void:
	if not _save_details_stale or not is_inside_tree() or _session == null or _session.battle.is_empty():
		return
	if _action_playback_in_progress or _battle_exit_handoff_in_progress or not _battle_resolution_checkpoint_pending.is_empty():
		return
	var profile_started := ProfileLogScript.begin_usec()
	_save_details_build_count += 1
	_refresh_save_slot_picker()
	if _briefing_consumption_autosave_failure_pending:
		_apply_briefing_consumption_autosave_failure_surface(false)
	ProfileLogScript.emit_general("battle", "refresh", "battle_lazy_surfaces", ProfileLogScript.elapsed_ms(profile_started), {"save_bar_details": ProfileLogScript.elapsed_ms(profile_started)}, _battle_profile_metadata(false), _session)


func _on_save_control_hover_changed(control: Control, hovered: bool) -> void:
	if hovered:
		_hovered_save_controls[control.get_instance_id()] = true
		_build_save_details()
	else:
		_hovered_save_controls.erase(control.get_instance_id())


func _save_bar_in_view() -> bool:
	if not _hovered_save_controls.is_empty() or _options_popover.visible:
		return true
	for control in [_save_button, _menu_button, _system_body_label]:
		if control.has_focus():
			return true
	return false


## Once the battle is on screen its board has drawn and holds its own art.
func _release_entry_art_prewarm() -> void:
	BattleArtPrewarmScript.release()


# --- Helpers -------------------------------------------------------------------

func _record_action_recap(action_id: String, result: Dictionary, context: Dictionary = {}) -> void:
	if not bool(result.get("ok", false)):
		_last_action_recap_payload = {}
		_last_action_recap_text = ""
		return
	_last_action_recap_payload = BattleRules.post_action_recap_payload(_session, result, action_id, context)
	_last_action_recap_text = String(_last_action_recap_payload.get("text", ""))
	if not _last_action_recap_payload.is_empty():
		_session.flags["last_battle_action_recap"] = _last_action_recap_payload.duplicate(true)


func _dismiss_tactical_briefing() -> void:
	_tactical_briefing_text = ""


func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n\n".join(lines)


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
		board_summary = _validation_battle_board_summary()
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


func _battle_player_hero_id() -> String:
	var source = _session.battle.get("player_commander_source", {})
	if source is Dictionary and String(source.get("hero_id", "")) != "":
		return String(source.get("hero_id", ""))
	var hero = _session.battle.get("player_commander_state", {})
	return String(hero.get("id", "")) if hero is Dictionary else ""


func _battle_enemy_hero_id() -> String:
	var hero = _session.battle.get("enemy_hero", {})
	return String(hero.get("id", "")) if hero is Dictionary else ""


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

# --- Validation ----------------------------------------------------------------

func validation_snapshot() -> Dictionary:
	_build_save_details()
	var battle: Dictionary = _session.battle if _session != null else {}
	var has_battle := not battle.is_empty()
	var active_stack := BattleRules.get_active_stack(battle) if has_battle else {}
	var target_stack := BattleRules.get_selected_target(battle) if has_battle else {}
	var selected_click_intent := BattleRules.selected_target_board_click_intent(battle) if has_battle else {}
	var selected_continuity_context := BattleRules.selected_target_continuity_context(battle) if has_battle else {}
	var selected_closing_context := BattleRules.selected_target_closing_context(battle) if has_battle else {}
	var selected_legality := BattleRules.selected_target_legality(battle) if has_battle else {}
	var selected_direct_actionable := (
		selected_continuity_context.is_empty()
		and selected_closing_context.is_empty()
		and bool(selected_legality.get("attackable", false))
		and String(selected_click_intent.get("label", "")) != ""
	)
	var movement_click_intent := BattleRules.active_movement_board_click_intent(battle) if has_battle else {}
	var context: Dictionary = battle.get("context", {}) if battle.get("context", {}) is Dictionary else {}
	var player_roster := _normalize_string_array(BattleRules.roster_lines(battle, "player") if has_battle else [])
	var enemy_roster := _normalize_string_array(BattleRules.roster_lines(battle, "enemy") if has_battle else [])
	var action_surface := BattleRules.get_action_surface(_session) if has_battle else {}
	var intent_forecast := BattleRules.intent_forecast_payload(_session) if has_battle else {}
	var presentation_event := BattleRules.latest_animation_event_presentation_payload(_session) if has_battle else {}
	return {
		"scene_path": scene_file_path,
		"hud": validation_hud_snapshot(),
		"result": validation_result_snapshot(),
		"battle_over": _battle_over,
		"last_continue_result": _last_continue_result.duplicate(true),
		"quick_resolve_confirmation": validation_quick_resolve_confirmation_snapshot(),
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
		"encounter_id": String(battle.get("encounter_id", "")),
		"encounter_name": String(battle.get("encounter_name", "")),
		"entry_context": BattleRules.describe_entry_context(_session) if has_battle else "",
		"battle_context_type": String(context.get("type", "")),
		"battle_context_town_placement_id": String(context.get("town_placement_id", "")),
		"battle_context_trigger_faction_id": String(context.get("trigger_faction_id", "")),
		"round": int(battle.get("round", 0)),
		"distance": int(battle.get("distance", 0)),
		"active_side": String(active_stack.get("side", "")),
		"active_stack": String(active_stack.get("name", "")),
		"active_stack_battle_id": String(active_stack.get("battle_id", "")),
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
		"intent_forecast": intent_forecast,
		"intent_forecast_visible_text": String(intent_forecast.get("visible_text", "")),
		"intent_forecast_tooltip_text": String(intent_forecast.get("tooltip_text", "")),
		"action_surface": action_surface,
		"action_guidance": BattleRules.describe_action_surface(_session) if has_battle else "",
		"target_context": BattleRules.describe_target_context(_session) if has_battle else "",
		"active_consequence_payload": BattleRules.active_consequence_payload(_session) if has_battle else {},
		"battle_presentation_event": presentation_event,
		"battle_presentation_event_id": String(presentation_event.get("event_id", "")),
		"battle_presentation_event_source": String(presentation_event.get("source", "")),
		"battle_presentation_event_visible_text": String(presentation_event.get("visible_text", "")),
		"battle_presentation_event_tooltip_text": String(presentation_event.get("tooltip_text", "")),
		"battle_presentation_events": BattleRules.battle_presentation_event_stream(battle) if has_battle else [],
		# What the battle log holds: past events, the briefing and each order played.
		"battle_presentation_stream_text": "
".join(_message_log.entries),
		"battle_presentation_speed": BattleRules.battle_presentation_speed(_session),
		"event_visible_text": _log_line.text,
		"event_tooltip_text": _log_line.tooltip_text,
		"post_action_recap": _last_action_recap_payload.duplicate(true),
		"post_action_recap_text": _last_action_recap_text,
		"log_line_text": _log_line.text,
		"command_hint": _command_hint,
		"message_log_entries": _message_log.entries.duplicate(),
		"quick_resolve_visible": _quick_resolve_button.visible,
		"quick_resolve_disabled": _quick_resolve_button.disabled,
		"quick_resolve_tooltip": _quick_resolve_button.tooltip_text,
		"quick_resolve_confirmation_text": _quick_resolve_confirmation_dialog.dialog_text,
		"player_has_given_orders": BattleRules.player_has_given_orders(battle) if has_battle else false,
		"wait_tooltip": _wait_button.tooltip_text,
		"defend_tooltip": _defend_button.tooltip_text,
		"retreat_tooltip": _retreat_button.tooltip_text,
		"surrender_tooltip": _surrender_button.tooltip_text,
		"spellbook_tooltip": _spellbook_button.tooltip_text,
		"battle_exit_order_cues": _battle_exit_order_cue_surface(action_surface),
		"player_stack_count": player_roster.size(),
		"enemy_stack_count": enemy_roster.size(),
		"player_roster": player_roster,
		"enemy_roster": enemy_roster,
		"player_hero": BattleRules.hero_presentation(battle, "player") if has_battle else {},
		"enemy_hero": BattleRules.hero_presentation(battle, "enemy") if has_battle else {},
		"player_commander_text": BattleRules.describe_commander_summary(_session, "player") if has_battle else "",
		"enemy_commander_text": BattleRules.describe_commander_summary(_session, "enemy") if has_battle else "",
		"player_commander_portrait": _player_commander_portrait.validation_snapshot(),
		"enemy_commander_portrait": _enemy_commander_portrait.validation_snapshot(),
		"spellbook_text": BattleRules.describe_spellbook(_session) if has_battle else "",
		"spell_actions": _duplicate_action_array(BattleRules.get_spell_actions(_session)) if has_battle else [],
		"spell_targeting_id": _spell_targeting_id,
		"hero_can_cast_now": _hero_can_cast_now(),
		"auto_battle": _auto_button.button_pressed,
		"battle_board": _validation_battle_board_summary(),
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"save_surface": AppRouter.active_save_surface(),
		"save_handoff_visible_text": _system_body_label.text,
		"save_handoff_visible": _system_body_label.visible,
		"save_button_text": _save_button.text,
		"save_button_tooltip_text": _save_button.tooltip_text,
		"save_status_visible_text": _system_body_label.text,
		"save_status_tooltip_text": _system_body_label.tooltip_text,
		"focus_owner": _return_to_menu_focus_owner_name(),
		"focus_cycle_names": _last_battle_keyboard_focus_cycle_names.duplicate(),
	}


## The details card: whether it shows, what for, where, and what it says.
func validation_details_card() -> Dictionary:
	return {
		"visible": _details_card.visible,
		"kind": _details_kind,
		"id": _details_id,
		"rect": Rect2(_details_card.position, _details_card.size),
		"anchor": _details_anchor,
		"shown": _details_card.shown.duplicate(true),
		"board_subject": _battle_board_view.details_subject(),
	}


## Where the HUD sits and what it shows: rects in this control's space, what
## is visible, what spills out of the window and what overlaps.
func validation_hud_snapshot() -> Dictionary:
	var view_rect := Rect2(Vector2.ZERO, size)
	var parts := {
		"command_bar": _command_bar,
		"player_plate": _player_plate,
		"enemy_plate": _enemy_plate,
		"options_popover": _options_popover,
		"spellbook_popover": _spellbook_popover,
		"log_popover": _log_popover,
		"banner": _banner,
		"result_panel": _result_panel,
		"show_result": _show_result_button,
		"log_line": _log_line,
	}
	var rects := {}
	var visible := {}
	var clipped: Array[String] = []
	for key in parts:
		var control: Control = parts[key]
		var shown := control.is_visible_in_tree()
		visible[key] = shown
		if not shown:
			continue
		var rect := Rect2(control.global_position - global_position, control.size)
		rects[key] = rect
		if not view_rect.grow(0.5).encloses(rect):
			clipped.append(String(key))
	var overlaps: Array[String] = []
	var solid_keys := ["command_bar", "player_plate", "enemy_plate", "options_popover", "spellbook_popover", "log_popover"]
	for i in range(solid_keys.size()):
		for j in range(i + 1, solid_keys.size()):
			var a := String(solid_keys[i])
			var b := String(solid_keys[j])
			if rects.has(a) and rects.has(b) and (rects[a] as Rect2).grow(-0.5).intersects((rects[b] as Rect2).grow(-0.5)):
				overlaps.append("%s/%s" % [a, b])
	var buttons := {}
	for button in [_options_button, _surrender_button, _retreat_button, _auto_button, _quick_resolve_button, _log_open_button, _spellbook_button, _wait_button, _defend_button]:
		buttons[String(button.name)] = {
			"visible": button.is_visible_in_tree(),
			"disabled": button.disabled,
			"pressed": button.button_pressed,
			"tooltip": button.tooltip_text,
			"badge": String(button.get("badge_text")),
			"glyph": String(button.get("glyph")),
			"key_hint": String(button.get("key_hint")),
			"rect": Rect2(button.global_position - global_position, button.size),
		}
	var plates := {}
	for side: String in ["player", "enemy"]:
		var plate := _player_plate if side == "player" else _enemy_plate
		var name_label: Label = _player_hero_name if side == "player" else _enemy_hero_name
		var name_width := name_label.get_theme_font("font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_label.get_theme_font_size("font_size")).x
		plates[side] = {
			"visible": plate.visible,
			"rect": Rect2(plate.global_position - global_position, plate.size),
			"name": name_label.text,
			"name_fits": name_width <= name_label.size.x + 1.0,
			"mana_text": (_player_mana_text if side == "player" else _enemy_mana_text).text,
			"status": (_player_hero_status if side == "player" else _enemy_hero_status).text,
			"portrait_visible": (_player_commander_portrait if side == "player" else _enemy_commander_portrait).visible,
			"crest_visible": (_player_crest if side == "player" else _enemy_crest).visible,
			"figure": _battle_board_view.hero_figure_layout(side),
		}
	var spell_rows := []
	for row in _spell_list.get_children():
		if row is Button:
			spell_rows.append({
				"spell_id": String(row.get_meta("spell_id", "")),
				"disabled": row.disabled,
				"blocked_reason": String(row.get_meta("blocked_reason", "")),
			})
	var popover := ""
	if _options_popover.visible:
		popover = "options"
	elif _spellbook_popover.visible:
		popover = "spellbook"
	elif _log_popover.visible:
		popover = "log"
	return {
		"viewport_size": size,
		"hud_scale": _hud_scale,
		"rects": rects,
		"visible": visible,
		"clipped": clipped,
		"overlaps": overlaps,
		"buttons": buttons,
		"plates": plates,
		"popover": popover,
		"spell_rows": spell_rows,
		"log_line_text": _log_line.text,
		"command_hint": _command_hint,
		"banner_text": _banner.text,
		"banner_alpha": _banner.modulate.a,
		"message_log_entry_count": _message_log.entries.size(),
		"auto_battle": _auto_button.button_pressed,
		"auto_battle_order_count": _validation_auto_battle_order_count,
		"last_auto_battle_order": _last_auto_battle_order.duplicate(true),
		"spell_targeting_id": _spell_targeting_id,
		"board_has_focus": _battle_board_view.has_focus(),
		"board_input_enabled": _battle_board_view.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"focus_owner": _return_to_menu_focus_owner_name(),
		"focus_cycle_names": _last_battle_keyboard_focus_cycle_names.duplicate(),
		"save_details_build_count": _save_details_build_count,
		"save_surface_build_count": _save_surface_build_count,
	}


func validation_result_snapshot() -> Dictionary:
	var loss_counts := {}
	for side: String in ["player", "enemy"]:
		var flow := _player_loss_icons if side == "player" else _enemy_loss_icons
		var count := 0
		for child in flow.get_children():
			if not (child is Label):
				count += 1
		loss_counts[side] = count
	return {
		"battle_over": _battle_over,
		"pending": validation_result_pending(),
		"overlay_visible": _result_overlay.visible,
		"show_result_visible": _show_result_button.visible,
		"command_bar_visible": _command_bar.visible,
		"title": _result_title.text,
		"lead": _result_lead.text,
		"outcome": String(_result_report.get("outcome", "")),
		"report_id": String(_result_report.get("report_id", "")),
		"player_loss_icon_count": int(loss_counts.get("player", 0)),
		"enemy_loss_icon_count": int(loss_counts.get("enemy", 0)),
		"aftermath": _result_aftermath.text,
		"status_visible": _result_status.visible,
		"status": _result_status.text,
		"continue_text": _continue_button.text,
		"continue_disabled": _continue_button.disabled,
		"continue_has_focus": _continue_button.has_focus(),
		"continue_accessibility_name": _continue_button.accessibility_name,
		"panel_rect": Rect2(_result_panel.global_position - global_position, _result_panel.size) if _result_overlay.visible else Rect2(),
		"entry_result": _result_entry_result.duplicate(true),
		"last_continue_result": _last_continue_result.duplicate(true),
	}


## The battle is over and its result waits for Continue.
func validation_result_pending() -> bool:
	return _battle_over and not _result_report.is_empty() and not bool(_last_continue_result.get("ok", false))


func validation_press_continue(skip_required_save: bool = true) -> Dictionary:
	_last_continue_result = AppRouter.complete_battle_report(skip_required_save)
	return _last_continue_result.duplicate(true)


func validation_begin_spell_targeting(spell_id: String) -> Dictionary:
	return _begin_spell_targeting(spell_id)


func validation_briefing_consumption_autosave_snapshot() -> Dictionary:
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var briefing_first_line := ""
	for raw_line in _tactical_briefing_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line != "":
			briefing_first_line = line
			break
	var visible_surface := "%s\n%s\n%s" % [_log_line.text, _log_line.tooltip_text, "\n".join(_message_log.entries)]
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
		"event_visible_text": _log_line.text.left(800),
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
	FrontierVisualKit.hide_exclusive_dialog(_quick_resolve_confirmation_dialog)
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
	return _on_save_pressed(true)


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
		"route_scheduled": _battle_exit_handoff_in_progress or (_action_playback_in_progress and String(_action_playback_result.get("playback_route_target", "")) != ""),
		"routed": _last_battle_resolution_routed,
		"result_shown": _battle_over,
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
	for button in _combat_input_buttons():
		if button != null and not button.disabled:
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
		BattleRules.record_player_order(_session.battle, spell_result)
		_last_message = String(spell_result.get("message", ""))
		_record_action_recap(String(spell_action.get("id", "")), spell_result, recap_context)
		if bool(spell_result.get("ok", false)):
			_validation_spell_casts += 1
			_dismiss_tactical_briefing()
		var spell_response := {
			"ok": bool(spell_result.get("ok", false)),
			"action": "cast_spell",
			"action_id": String(spell_action.get("id", "")),
			"target_battle_id": aligned_target_id,
			"state": String(spell_result.get("state", "")),
			"message": _last_message,
			"post_action_recap": _last_action_recap_payload.duplicate(true),
			"post_action_recap_text": _last_action_recap_text,
		}
		if not _handle_battle_resolution(spell_result):
			_refresh()
		return spell_response

	var action_id := _preferred_validation_action_id()
	if action_id == "":
		return {"ok": false, "message": "No legal battle validation action is available."}
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var action_result := BattleRules.perform_player_action(_session, action_id)
	BattleRules.record_player_order(_session.battle, action_result)
	_last_message = String(action_result.get("message", ""))
	_record_action_recap(action_id, action_result, recap_context)
	if bool(action_result.get("ok", false)):
		_dismiss_tactical_briefing()
	var response := {
		"ok": bool(action_result.get("ok", false)),
		"action": action_id,
		"target_battle_id": aligned_target_id,
		"state": String(action_result.get("state", "")),
		"message": _last_message,
		"post_action_recap": _last_action_recap_payload.duplicate(true),
		"post_action_recap_text": _last_action_recap_text,
	}
	if not _handle_battle_resolution(action_result):
		_refresh()
	return response


func validation_perform_action(action_id: String) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": action_id, "message": "No active battle is loaded for validation.", "state": "invalid"}
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var result := BattleRules.perform_player_action(_session, action_id)
	BattleRules.record_player_order(_session.battle, result)
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


func validation_perform_board_hex_click(q: int, r: int) -> Dictionary:
	if _session.battle.is_empty():
		return {"ok": false, "action": "", "q": q, "r": r, "message": "No active battle is loaded for validation.", "state": "invalid"}
	return _on_board_hex_destination_requested(q, r)


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
			board_summary = _validation_battle_board_summary()
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
		"battle_board": _validation_battle_board_summary(),
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
	_on_save_pressed(true)
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
