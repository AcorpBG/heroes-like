extends Control

@onready var _banner_panel: PanelContainer = $Scroll/ContentMargin/Content/Banner
@onready var _briefing_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/BriefingPanel
@onready var _risk_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/RiskPanel
@onready var _consequence_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/ConsequencePanel
@onready var _battlefield_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/BattlefieldPanel
@onready var _battlefield_frame_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/BattlefieldPanel/BattlefieldPad/BattlefieldBox/BattlefieldFrame
@onready var _command_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel
@onready var _initiative_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/InitiativePanel
@onready var _context_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel
@onready var _spell_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/SpellPanel
@onready var _timing_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/TimingPanel
@onready var _player_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/ArmyColumns/PlayerPanel
@onready var _enemy_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/BattleColumn/ArmyColumns/EnemyPanel
@onready var _footer_panel: PanelContainer = $Scroll/ContentMargin/Content/Footer
@onready var _action_panel: PanelContainer = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel
@onready var _system_panel: PanelContainer = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel
@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _pressure_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Pressure
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _briefing_label: Label = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/BriefingPanel/BriefingPad/BriefingBox/Briefing
@onready var _risk_label: Label = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/RiskPanel/RiskPad/RiskBox/Risk
@onready var _consequence_label: Label = $Scroll/ContentMargin/Content/Columns/BattleColumn/SituationRow/ConsequencePanel/ConsequencePad/ConsequenceBox/Consequence
@onready var _battle_board_view = $Scroll/ContentMargin/Content/Columns/BattleColumn/BattlefieldPanel/BattlefieldPad/BattlefieldBox/BattlefieldFrame/BattlefieldInset/BattleBoard
@onready var _player_command_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/PlayerCommand
@onready var _enemy_command_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/EnemyCommand
@onready var _initiative_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/InitiativePanel/InitiativePad/InitiativeBox/Initiative
@onready var _active_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel/ContextPad/ContextBox/Active
@onready var _target_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel/ContextPad/ContextBox/Target
@onready var _spell_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/SpellPanel/SpellPad/SpellBox/Spellbook
@onready var _effect_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/SpellPanel/SpellPad/SpellBox/Effects
@onready var _timing_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/TimingPanel/TimingPad/TimingBox/Timing
@onready var _player_roster: Label = $Scroll/ContentMargin/Content/Columns/BattleColumn/ArmyColumns/PlayerPanel/PlayerPad/PlayerBox/PlayerRoster
@onready var _enemy_roster: Label = $Scroll/ContentMargin/Content/Columns/BattleColumn/ArmyColumns/EnemyPanel/EnemyPad/EnemyBox/EnemyRoster
@onready var _action_guide: Label = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionGuide
@onready var _spell_actions: HFlowContainer = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/SpellBar/Actions
@onready var _prev_target_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/TargetBar/PrevTarget
@onready var _next_target_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/TargetBar/NextTarget
@onready var _advance_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Advance
@onready var _strike_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Strike
@onready var _shoot_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Shoot
@onready var _defend_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Defend
@onready var _retreat_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Retreat
@onready var _surrender_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/ActionPanel/ActionPad/ActionBox/ActionBar/Surrender
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/Save
@onready var _system_body_label: Label = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/SystemBody
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/FooterPad/FooterColumns/SystemPanel/SystemPad/SystemBox/Menu

var _session: SessionStateStore.SessionData
var _last_message := ""
var _tactical_briefing_text := ""

func _ready() -> void:
	_apply_visual_theme()
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
	var placeholder := Label.new()
	placeholder.text = text
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	return placeholder

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	label.tooltip_text = full_text
	label.text = _compact_text(full_text, max_lines)

func _compact_text(full_text: String, max_lines: int) -> String:
	var raw_lines := full_text.split("\n", false)
	var lines := []
	for raw_line in raw_lines:
		var line := raw_line.strip_edges()
		if line == "":
			continue
		if line.begins_with("- "):
			line = line.trim_prefix("- ").strip_edges()
		if line.length() > 96:
			line = "%s..." % line.left(93)
		lines.append(line)
	if lines.is_empty():
		return full_text.strip_edges()
	if lines.size() > max_lines:
		var hidden := lines.size() - max_lines
		lines = lines.slice(0, max_lines)
		lines.append("+ %d more" % hidden)
	return "\n".join(lines)

func _style_action_button(button: Button, primary: bool = false, width: float = 160.0) -> void:
	button.custom_minimum_size = Vector2(width, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(button, primary)

func _apply_button_theme(button: Button, primary: bool) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.40, 0.20, 0.15, 0.98) if primary else Color(0.18, 0.22, 0.26, 0.96)
	normal.border_color = Color(0.91, 0.69, 0.39, 0.96) if primary else Color(0.55, 0.63, 0.71, 0.95)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	normal.shadow_size = 3
	var hover = normal.duplicate()
	hover.bg_color = Color(0.48, 0.24, 0.18, 1.0) if primary else Color(0.24, 0.28, 0.33, 1.0)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.28, 0.14, 0.12, 1.0) if primary else Color(0.14, 0.17, 0.20, 1.0)
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.12, 0.14, 0.15, 0.92)
	disabled.border_color = Color(0.28, 0.32, 0.35, 0.72)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.50, 0.53))

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _apply_visual_theme() -> void:
	_banner_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.12, 0.10, 0.97), Color(0.88, 0.68, 0.38, 0.95)))
	_briefing_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.15, 0.11, 0.97), Color(0.90, 0.73, 0.42, 0.95)))
	_risk_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.16, 0.18, 0.97), Color(0.45, 0.69, 0.76, 0.95)))
	_consequence_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.13, 0.12, 0.97), Color(0.86, 0.55, 0.38, 0.95)))
	_battlefield_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.11, 0.10, 0.97), Color(0.78, 0.64, 0.36, 0.95)))
	_battlefield_frame_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.08, 0.09, 1.0), Color(0.56, 0.66, 0.71, 0.95)))
	_command_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.13, 0.15, 0.97), Color(0.49, 0.60, 0.67, 0.95)))
	_initiative_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.15, 0.17, 0.97), Color(0.62, 0.72, 0.42, 0.95)))
	_context_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.15, 0.12, 0.10, 0.97), Color(0.86, 0.67, 0.37, 0.95)))
	_spell_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.14, 0.20, 0.97), Color(0.54, 0.62, 0.89, 0.95)))
	_timing_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.15, 0.11, 0.97), Color(0.74, 0.68, 0.35, 0.95)))
	_player_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.16, 0.20, 0.97), Color(0.42, 0.68, 0.90, 0.95)))
	_enemy_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.19, 0.12, 0.11, 0.97), Color(0.86, 0.39, 0.34, 0.95)))
	_footer_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.14, 0.97), Color(0.42, 0.48, 0.55, 0.95)))
	_action_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.15, 0.12, 0.10, 0.97), Color(0.86, 0.66, 0.36, 0.95)))
	_system_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.13, 0.16, 0.97), Color(0.50, 0.61, 0.69, 0.95)))

	for button in [_prev_target_button, _next_target_button]:
		_style_action_button(button, false, 126)
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _retreat_button, _surrender_button, _save_button, _menu_button]:
		_style_action_button(button, true)
	_save_slot_picker.custom_minimum_size = Vector2(150, 36)
	_apply_button_theme(_save_slot_picker, false)

	_header_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_status_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
	_pressure_label.add_theme_color_override("font_color", Color(0.97, 0.88, 0.61))
	_event_label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.93))
	_system_body_label.add_theme_color_override("font_color", Color(0.79, 0.83, 0.87))

	for label in [
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
	]:
		label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.93))
		label.add_theme_font_size_override("font_size", 13)

func _dismiss_tactical_briefing() -> void:
	_tactical_briefing_text = ""
