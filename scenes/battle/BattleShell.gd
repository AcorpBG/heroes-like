extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

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
@onready var _action_panel: PanelContainer = %ActionPanel
@onready var _system_panel: PanelContainer = %SystemPanel
@onready var _header_label: Label = %Header
@onready var _status_label: Label = %Status
@onready var _pressure_label: Label = %Pressure
@onready var _event_label: Label = %Event
@onready var _briefing_label: Label = %Briefing
@onready var _risk_label: Label = %Risk
@onready var _consequence_label: Label = %Consequence
@onready var _battle_board_view = %BattleBoard
@onready var _player_command_label: Label = %PlayerCommand
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
@onready var _retreat_button: Button = %Retreat
@onready var _surrender_button: Button = %Surrender
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _system_body_label: Label = %SystemBody
@onready var _menu_button: Button = %Menu

var _session: SessionStateStore.SessionData
var _last_message := ""
var _tactical_briefing_text := ""

func _ready() -> void:
	_apply_visual_theme()
	_battle_tabs.current_tab = 0
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter battle without an active scenario session.")
		AppRouter.go_to_main_menu()
		return
	if _session.battle.is_empty():
		push_warning("Cannot enter battle without a battle payload.")
		AppRouter.go_to_overworld()
		return

	OverworldRules.normalize_overworld_state(_session)
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return
	if not BattleRules.normalize_battle_state(_session):
		push_warning("Battle payload could not be normalized.")
		AppRouter.go_to_overworld()
		return
	var initial_result := BattleRules.resolve_if_battle_ready(_session)
	match String(initial_result.get("state", "continue")):
		"victory", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost":
			AppRouter.go_to_overworld()
			return
		"defeat":
			AppRouter.go_to_scenario_outcome()
			return

	_configure_save_slot_picker()
	_tactical_briefing_text = BattleRules.consume_tactical_briefing(_session)
	if _tactical_briefing_text != "":
		SaveService.save_runtime_autosave_session(_session)
	_refresh()

func _on_prev_target_pressed() -> void:
	BattleRules.cycle_target(_session, -1)
	_refresh()

func _on_next_target_pressed() -> void:
	BattleRules.cycle_target(_session, 1)
	_refresh()

func _on_advance_pressed() -> void:
	_perform_action("advance")

func _on_strike_pressed() -> void:
	_perform_action("strike")

func _on_shoot_pressed() -> void:
	_perform_action("shoot")

func _on_defend_pressed() -> void:
	_perform_action("defend")

func _on_retreat_pressed() -> void:
	_perform_action("retreat")

func _on_surrender_pressed() -> void:
	_perform_action("surrender")

func _on_spell_action_pressed(action_id: String) -> void:
	if not action_id.begins_with("cast_spell:"):
		return
	var result := BattleRules.cast_player_spell(_session, action_id.trim_prefix("cast_spell:"))
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		return
	_refresh()

func _on_save_pressed() -> void:
	var result := AppRouter.save_active_session_to_selected_manual_slot()
	_last_message = String(result.get("message", ""))
	_refresh()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_slot_picker()

func _on_menu_pressed() -> void:
	AppRouter.return_to_main_menu_from_active_play()

func _perform_action(action: String) -> void:
	var result := BattleRules.perform_player_action(_session, action)
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		return
	_refresh()

func _handle_battle_resolution(result: Dictionary) -> bool:
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return true
	match String(result.get("state", "continue")):
		"victory", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost":
			AppRouter.go_to_overworld()
			return true
		"defeat":
			AppRouter.go_to_scenario_outcome()
			return true
	return false

func _refresh() -> void:
	if _session.battle.is_empty():
		return
	if not BattleRules.normalize_battle_state(_session):
		AppRouter.go_to_overworld()
		return

	_rebuild_spell_actions()
	_refresh_action_buttons()
	_refresh_save_slot_picker()

	_header_label.text = BattleRules.describe_header(_session)
	_status_label.text = BattleRules.describe_status(_session)
	_set_compact_label(_pressure_label, BattleRules.describe_pressure(_session), 4)
	_set_compact_label(_event_label, BattleRules.describe_dispatch(_session, _last_message), 3)
	_set_compact_label(_briefing_label, _tactical_briefing_text, 4)
	_briefing_panel.visible = _tactical_briefing_text != ""
	_set_compact_label(_risk_label, BattleRules.describe_risk_readiness_board(_session), 4)
	_set_compact_label(_consequence_label, BattleRules.describe_order_consequence_board(_session), 4)
	_set_compact_label(_player_command_label, BattleRules.describe_commander_summary(_session, "player"), 5)
	_set_compact_label(_enemy_command_label, BattleRules.describe_commander_summary(_session, "enemy"), 5)
	_set_compact_label(_initiative_label, BattleRules.describe_initiative_track(_session), 6)
	_set_compact_label(_active_label, BattleRules.describe_active_context(_session), 4)
	_set_compact_label(_target_label, BattleRules.describe_target_context(_session), 5)
	_set_compact_label(_spell_label, BattleRules.describe_spellbook(_session), 4)
	_set_compact_label(_effect_label, BattleRules.describe_effect_board(_session), 4)
	_set_compact_label(_timing_label, BattleRules.describe_spell_timing_board(_session), 4)
	_set_compact_label(_action_guide, BattleRules.describe_action_surface(_session), 5)
	_battle_board_view.set_battle_state(_session)

	var player_lines = BattleRules.roster_lines(_session.battle, "player")
	var enemy_lines = BattleRules.roster_lines(_session.battle, "enemy")
	_set_compact_label(_player_roster, "\n".join(player_lines) if not player_lines.is_empty() else "No survivors remain.", 6)
	_set_compact_label(_enemy_roster, "\n".join(enemy_lines) if not enemy_lines.is_empty() else "Enemy resistance has collapsed.", 6)

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = BattleRules.get_spell_actions(_session)
	if actions.is_empty():
		_spell_actions.add_child(_make_placeholder_label("No battle spells are ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Spell")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button, false, 172)
		button.pressed.connect(_on_spell_action_pressed.bind(String(action.get("id", ""))))
		_spell_actions.add_child(button)

func _refresh_action_buttons() -> void:
	var active_stack := BattleRules.get_active_stack(_session.battle)
	var target_stack := BattleRules.get_selected_target(_session.battle)
	var player_turn := not active_stack.is_empty() and String(active_stack.get("side", "")) == "player"
	var enemy_lines = BattleRules.roster_lines(_session.battle, "enemy")
	var surface := BattleRules.get_action_surface(_session)

	_prev_target_button.disabled = not player_turn or enemy_lines.size() <= 1
	_next_target_button.disabled = not player_turn or enemy_lines.size() <= 1
	_prev_target_button.tooltip_text = "Cycle focus to the previous enemy stack."
	_next_target_button.tooltip_text = "Cycle focus to the next enemy stack."

	_apply_action_surface(_advance_button, surface.get("advance", {}))
	_apply_action_surface(_strike_button, surface.get("strike", {}))
	_apply_action_surface(_shoot_button, surface.get("shoot", {}))
	_apply_action_surface(_defend_button, surface.get("defend", {}))
	_apply_action_surface(_retreat_button, surface.get("retreat", {}))
	_apply_action_surface(_surrender_button, surface.get("surrender", {}))

	var target_name := String(target_stack.get("name", "No target"))
	_strike_button.text = "Strike %s" % target_name if player_turn and not target_stack.is_empty() else "Strike"
	_shoot_button.text = "Shoot %s" % target_name if player_turn and not target_stack.is_empty() else "Shoot"

func _apply_action_surface(button: Button, action: Dictionary) -> void:
	button.text = String(action.get("label", button.text))
	button.disabled = bool(action.get("disabled", false))
	button.tooltip_text = String(action.get("summary", ""))
	_style_action_button(button, true)

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))
	_refresh_save_slot_picker()

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
	_system_body_label.text = String(surface.get("latest_context", "Latest ready save: none."))
	_system_body_label.tooltip_text = SaveService.describe_slot_details(summary)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Battle"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active battle safely."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _make_placeholder_label(text: String) -> Label:
	return FrontierVisualKit.placeholder_label(text)

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, 96, false)

func _style_action_button(button: Button, primary: bool = false, width: float = 160.0) -> void:
	FrontierVisualKit.apply_button(button, "primary" if primary else "secondary", width, 34.0)

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
	FrontierVisualKit.apply_tab_container(_battle_tabs)
	_battle_tabs.set_tab_title(0, "Order")
	_battle_tabs.set_tab_title(1, "Focus")
	_battle_tabs.set_tab_title(2, "Spells")
	_battle_tabs.set_tab_title(3, "Timing")

	for button in [_prev_target_button, _next_target_button]:
		_style_action_button(button, false, 108)
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _retreat_button, _surrender_button, _save_button, _menu_button]:
		_style_action_button(button, true)
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 120.0, 34.0, 13)

	for title_label in find_children("*Title", "Label", true, false):
		if title_label is Label:
			FrontierVisualKit.apply_label(title_label, "title", 14)

	FrontierVisualKit.apply_label(_header_label, "title", 22)
	FrontierVisualKit.apply_label(_status_label, "body", 12)
	FrontierVisualKit.apply_label(_pressure_label, "gold", 12)
	FrontierVisualKit.apply_label(_event_label, "body", 12)
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
	], "body", 13)

func _dismiss_tactical_briefing() -> void:
	_tactical_briefing_text = ""
