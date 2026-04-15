extends Control

@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _pressure_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Pressure
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _briefing_panel: PanelContainer = $Scroll/ContentMargin/Content/BriefingPanel
@onready var _briefing_label: Label = $Scroll/ContentMargin/Content/BriefingPanel/BriefingPad/BriefingBox/Briefing
@onready var _risk_label: Label = $Scroll/ContentMargin/Content/RiskPanel/RiskPad/RiskBox/Risk
@onready var _consequence_label: Label = $Scroll/ContentMargin/Content/ConsequencePanel/ConsequencePad/ConsequenceBox/Consequence
@onready var _player_command_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/PlayerCommand
@onready var _enemy_command_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/EnemyCommand
@onready var _initiative_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/InitiativePanel/InitiativePad/InitiativeBox/Initiative
@onready var _active_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/ContextPanel/ContextPad/ContextBox/Active
@onready var _target_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/ContextPanel/ContextPad/ContextBox/Target
@onready var _spell_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/SpellPanel/SpellPad/SpellBox/Spellbook
@onready var _effect_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/SpellPanel/SpellPad/SpellBox/Effects
@onready var _timing_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/TimingPanel/TimingPad/TimingBox/Timing
@onready var _player_roster: Label = $Scroll/ContentMargin/Content/ArmyColumns/PlayerPanel/PlayerPad/PlayerBox/PlayerRoster
@onready var _enemy_roster: Label = $Scroll/ContentMargin/Content/ArmyColumns/EnemyPanel/EnemyPad/EnemyBox/EnemyRoster
@onready var _action_guide: Label = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionGuide
@onready var _spell_actions: HFlowContainer = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/SpellBar/Actions
@onready var _prev_target_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/TargetBar/PrevTarget
@onready var _next_target_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/TargetBar/NextTarget
@onready var _advance_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Advance
@onready var _strike_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Strike
@onready var _shoot_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Shoot
@onready var _defend_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Defend
@onready var _retreat_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Retreat
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/Save
@onready var _system_body_label: Label = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/SystemBody
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/Menu

var _session: SessionStateStore.SessionData
var _last_message := ""
var _tactical_briefing_text := ""

func _ready() -> void:
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
		"victory", "retreat", "stalemate", "hero_defeat", "town_lost":
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
		"victory", "retreat", "stalemate", "hero_defeat", "town_lost":
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
	_pressure_label.text = BattleRules.describe_pressure(_session)
	_event_label.text = BattleRules.describe_dispatch(_session, _last_message)
	_briefing_label.text = _tactical_briefing_text
	_briefing_panel.visible = _tactical_briefing_text != ""
	_risk_label.text = BattleRules.describe_risk_readiness_board(_session)
	_consequence_label.text = BattleRules.describe_order_consequence_board(_session)
	_player_command_label.text = BattleRules.describe_commander_summary(_session, "player")
	_enemy_command_label.text = BattleRules.describe_commander_summary(_session, "enemy")
	_initiative_label.text = BattleRules.describe_initiative_track(_session)
	_active_label.text = BattleRules.describe_active_context(_session)
	_target_label.text = BattleRules.describe_target_context(_session)
	_spell_label.text = BattleRules.describe_spellbook(_session)
	_effect_label.text = BattleRules.describe_effect_board(_session)
	_timing_label.text = BattleRules.describe_spell_timing_board(_session)
	_action_guide.text = BattleRules.describe_action_surface(_session)

	var player_lines = BattleRules.roster_lines(_session.battle, "player")
	var enemy_lines = BattleRules.roster_lines(_session.battle, "enemy")
	_player_roster.text = "\n".join(player_lines) if not player_lines.is_empty() else "No survivors remain."
	_enemy_roster.text = "\n".join(enemy_lines) if not enemy_lines.is_empty() else "Enemy resistance has collapsed."

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = BattleRules.get_spell_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No battle spells are ready"
		_spell_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Spell")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button, 180)
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

	var target_name := String(target_stack.get("name", "No target"))
	_strike_button.text = "Strike %s" % target_name if player_turn and not target_stack.is_empty() else "Strike"
	_shoot_button.text = "Shoot %s" % target_name if player_turn and not target_stack.is_empty() else "Shoot"

func _apply_action_surface(button: Button, action: Dictionary) -> void:
	button.text = String(action.get("label", button.text))
	button.disabled = bool(action.get("disabled", false))
	button.tooltip_text = String(action.get("summary", ""))
	_style_action_button(button)

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

	var summary := surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	_system_body_label.text = String(surface.get("latest_context", "Latest ready save: none."))
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Battle"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active battle safely."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _style_action_button(button: Button, width: float = 160.0) -> void:
	button.custom_minimum_size = Vector2(width, 0)

func _dismiss_tactical_briefing() -> void:
	_tactical_briefing_text = ""
