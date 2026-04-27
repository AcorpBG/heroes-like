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
@onready var _battle_context_label: Label = %BattleContext
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
var _validation_spell_casts := 0
var _validation_max_spell_casts := 1
var _validation_prioritize_support_spell := false
var _validation_spell_casting_enabled := true
var _validation_battle_resolution_routing_enabled := true
var _last_action_recap_payload := {}
var _last_action_recap_text := ""

func _ready() -> void:
	_apply_visual_theme()
	if _battle_board_view.has_signal("stack_focus_requested"):
		_battle_board_view.stack_focus_requested.connect(_on_board_stack_focus_requested)
	if _battle_board_view.has_signal("hex_destination_requested"):
		_battle_board_view.hex_destination_requested.connect(_on_board_hex_destination_requested)
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
	_session.game_state = "battle"
	var initial_result := BattleRules.resolve_if_battle_ready(_session)
	_last_message = String(initial_result.get("message", ""))
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

func _on_board_stack_focus_requested(battle_id: String) -> Dictionary:
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
		var routed := _handle_battle_resolution(result)
		if not routed:
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
			if not routed:
				board_summary = _validation_battle_board_summary()
		return {
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
			"routed": routed,
		}

	var legal_target_ids := BattleRules.legal_attack_target_ids_for_active_stack(_session.battle)
	var selected_after := BattleRules.get_selected_target(_session.battle)
	var selected_continuity_context := BattleRules.selected_target_continuity_context(_session.battle)
	var selected_closing_context := BattleRules.selected_target_closing_context(_session.battle)
	if not legal_target_ids.is_empty() and battle_id not in legal_target_ids:
		_last_message = String(board_intent.get("message", "%s is blocked from this hex. Click a highlighted enemy to attack, or move first." % String(clicked_stack.get("name", "That target"))))
		_refresh()
		var blocked_alternative_board_summary := _validation_battle_board_summary()
		return {
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
		}

	_last_message = String(board_intent.get("message", "%s is blocked from this hex. Move to a highlighted hex before attacking." % String(clicked_stack.get("name", "That target"))))
	_refresh()
	var blocked_only_board_summary := _validation_battle_board_summary()
	return {
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
	}

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
	return response

func _on_board_hex_destination_requested(q: int, r: int) -> Dictionary:
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
		return _movement_click_response(result, movement_intent, q, r, true)
	_refresh()
	return _movement_click_response(result, movement_intent, q, r, false)

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
	var recap_context := BattleRules.post_action_recap_context(_session, action_id)
	var result := BattleRules.cast_player_spell(_session, action_id.trim_prefix("cast_spell:"))
	_last_message = String(result.get("message", ""))
	_record_action_recap(action_id, result, recap_context)
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
	var recap_context := BattleRules.post_action_recap_context(_session, action)
	var result := BattleRules.perform_player_action(_session, action)
	_last_message = String(result.get("message", ""))
	_record_action_recap(action, result, recap_context)
	if bool(result.get("ok", false)):
		_dismiss_tactical_briefing()
	if _handle_battle_resolution(result):
		return
	_refresh()

func _handle_battle_resolution(result: Dictionary) -> bool:
	if _session.scenario_status != "in_progress":
		if _validation_battle_resolution_routing_enabled:
			AppRouter.go_to_scenario_outcome()
		return true
	match String(result.get("state", "continue")):
		"victory", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost":
			if _validation_battle_resolution_routing_enabled:
				AppRouter.go_to_overworld()
			return true
		"defeat":
			if _validation_battle_resolution_routing_enabled:
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
	_refresh_battle_tab_cues()

	_header_label.text = BattleRules.describe_header(_session)
	FrontierVisualKit.set_compact_label(_status_label, BattleRules.describe_status(_session), 1, 62, false)
	FrontierVisualKit.set_compact_label(_pressure_label, BattleRules.describe_pressure(_session), 1, 44, false)
	var dispatch_text := BattleRules.describe_dispatch(_session, _last_message)
	if _last_message.strip_edges() == "" and _tactical_briefing_text != "":
		dispatch_text = _tactical_briefing_text
	var action_confirmation := BattleRules.action_readiness_confirmation_payload(_session)
	var action_context_surface := _battle_action_context_surface(dispatch_text, action_confirmation)
	if action_context_surface.is_empty():
		_set_compact_label(_event_label, dispatch_text, 1)
	else:
		_set_compact_label(_event_label, "%s\n%s" % [String(action_context_surface.get("visible_text", "")), dispatch_text], 1)
		_event_label.tooltip_text = String(action_context_surface.get("tooltip_text", _event_label.tooltip_text))
	_set_compact_label(_battle_context_label, BattleRules.describe_entry_context(_session), 3)
	_set_compact_label(_briefing_label, _tactical_briefing_text, 4)
	_briefing_panel.visible = false
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
	_set_compact_label(_player_command_label, BattleRules.describe_commander_summary(_session, "player"), 1)
	_set_compact_label(_enemy_command_label, BattleRules.describe_commander_summary(_session, "enemy"), 1)
	var initiative_track := BattleRules.describe_initiative_track(_session)
	var initiative_handoff := _battle_initiative_handoff_surface()
	if initiative_handoff.is_empty():
		_set_compact_label(_initiative_label, initiative_track, 5)
	else:
		_set_compact_label(
			_initiative_label,
			"%s\n%s" % [String(initiative_handoff.get("visible_text", "")), initiative_track],
			5
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
		_set_compact_label(
			_active_label,
			"%s\n%s" % [String(active_stack_check.get("visible_text", "")), active_context],
			3
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
		_set_compact_label(
			_target_label,
			"%s\n%s" % [String(engagement_check.get("visible_text", "")), target_context],
			3
		)
		_target_label.tooltip_text = _join_tooltip_sections([
			String(engagement_check.get("tooltip_text", "")),
			target_context,
		])
	_set_compact_label(_spell_label, BattleRules.describe_spellbook(_session), 3)
	var effect_board := BattleRules.describe_effect_board(_session)
	var status_check := _battle_status_check_cue_surface()
	if status_check.is_empty():
		_set_compact_label(_effect_label, effect_board, 3)
	else:
		_set_compact_label(
			_effect_label,
			"%s\n%s" % [String(status_check.get("visible_text", "")), effect_board],
			3
		)
		_effect_label.tooltip_text = _join_tooltip_sections([
			String(status_check.get("tooltip_text", "")),
			effect_board,
		])
	_set_compact_label(_timing_label, BattleRules.describe_spell_timing_board(_session), 3)
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
	var position_check := _battle_position_check_cue_surface()
	var objective_check := BattleRules.objective_check_cue_payload(_session)
	_action_guide.visible = true
	_set_compact_label(
		_action_guide,
		"%s\n%s\n%s" % [
			String(target_handoff.get("visible_text", BattleRules.describe_action_surface(_session))),
			String(position_check.get("visible_text", "")),
			String(objective_check.get("visible_text", "")),
		],
		3
	)
	_action_guide.tooltip_text = _join_tooltip_sections([
		String(target_handoff.get("tooltip_text", BattleRules.describe_action_surface(_session))),
		String(position_check.get("tooltip_text", "")),
		String(objective_check.get("tooltip_text", "")),
	])
	var action_confirmation_tooltip := String(action_confirmation.get("tooltip_text", "")).strip_edges()
	if action_confirmation_tooltip != "":
		_action_guide.tooltip_text = "%s\n\n%s" % [_action_guide.tooltip_text, action_confirmation_tooltip]
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
		button.pressed.connect(_on_spell_action_pressed.bind(String(action.get("id", ""))))
		_spell_actions.add_child(button)

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
	_apply_action_surface(_retreat_button, surface.get("retreat", {}))
	_apply_action_surface(_surrender_button, surface.get("surrender", {}))
	_append_battle_exit_order_cues(surface)

	var target_name := String(target_stack.get("name", "No target"))
	_strike_button.tooltip_text = "%s Target: %s." % [_strike_button.tooltip_text, target_name] if player_turn and not target_stack.is_empty() else _strike_button.tooltip_text
	_shoot_button.tooltip_text = "%s Target: %s." % [_shoot_button.tooltip_text, target_name] if player_turn and not target_stack.is_empty() else _shoot_button.tooltip_text
	_append_last_action_tooltips()

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
	var previous_step := "Previous target in the current %s list." % scope
	var next_step := "Next target in the current %s list." % scope
	if not player_turn:
		previous_step = "Input locked until the player stack acts."
		next_step = previous_step
	elif target_count <= 1:
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
			reach_line = "%s needs a green hex move" % target_label
			next_step = _battle_position_move_next_step(movement_options, target_label)
		elif legal_target_ids.size() > 0:
			readiness = "Retarget"
			reach_line = "selected target is blocked; another highlighted enemy can be attacked"
			next_step = "Cycle target focus or click a highlighted enemy."
		elif int(movement_intent.get("destination_count", 0)) > 0:
			readiness = "Move"
			reach_line = "%d green hex move%s open" % [
				int(movement_intent.get("destination_count", 0)),
				"" if int(movement_intent.get("destination_count", 0)) == 1 else "s",
			]
			next_step = _battle_position_move_next_step(movement_options, target_label)
		else:
			readiness = "Hold"
			reach_line = "no attack or green hex move is open"
			next_step = "Use Defend, retarget, or wait for the next initiative handoff."
	if movement_line == "":
		movement_line = "Green hex movement is not currently available."
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
			var destination := String(option_dict.get("destination_detail", option_dict.get("destination_label", "a green hex"))).strip_edges()
			return "Click %s to set up %s on %s." % [
				destination if destination != "" else "a green hex",
				setup_label.to_lower(),
				target_label,
			]
	for option in movement_options:
		if not (option is Dictionary):
			continue
		var option_dict: Dictionary = option
		if bool(option_dict.get("closes_on_selected_target", false)):
			var destination := String(option_dict.get("destination_detail", option_dict.get("destination_label", "a green hex"))).strip_edges()
			return "Click %s to close on %s." % [
				destination if destination != "" else "a green hex",
				target_label,
			]
	if not movement_options.is_empty():
		return "Click a green hex to reposition before choosing the next order."
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
	var visible := "Initiative cue: Now: %s; Next: %s." % [
		_short_text(current_label, 30),
		_short_text(next_label, 30),
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
	_system_body_label.visible = not status_lines.is_empty()
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
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
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
	var objective_check := BattleRules.objective_check_cue_payload(_session)
	var stack_check := _battle_stack_check_cue_surface()
	var dispatch_text := BattleRules.describe_dispatch(_session, _last_message)
	if _last_message.strip_edges() == "" and _tactical_briefing_text != "":
		dispatch_text = _tactical_briefing_text
	var action_context_surface := _battle_action_context_surface(dispatch_text, action_confirmation)
	return {
		"scene_path": scene_file_path,
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
		"retreat_text": _retreat_button.text,
		"surrender_text": _surrender_button.text,
		"advance_tooltip": _advance_button.tooltip_text,
		"strike_tooltip": _strike_button.tooltip_text,
		"shoot_tooltip": _shoot_button.tooltip_text,
		"defend_tooltip": _defend_button.tooltip_text,
		"retreat_tooltip": _retreat_button.tooltip_text,
		"surrender_tooltip": _surrender_button.tooltip_text,
		"battle_exit_order_cues": _battle_exit_order_cue_surface(action_surface),
		"battle_order_button_surfaces": _battle_order_button_surfaces(),
		"player_stack_count": player_roster.size(),
		"enemy_stack_count": enemy_roster.size(),
		"player_roster": player_roster,
		"enemy_roster": enemy_roster,
		"player_commander_text": BattleRules.describe_commander_summary(_session, "player"),
		"player_commander_visible_text": _player_command_label.text,
		"player_commander_tooltip_text": _player_command_label.tooltip_text,
		"spellbook_text": BattleRules.describe_spellbook(_session),
		"spellbook_visible_text": _spell_label.text,
		"spellbook_tooltip_text": _spell_label.tooltip_text,
		"spell_actions": _duplicate_action_array(BattleRules.get_spell_actions(_session)),
		"spell_action_button_surfaces": _spell_action_button_surfaces(),
		"spell_timing_text": BattleRules.describe_spell_timing_board(_session),
		"spell_timing_visible_text": _timing_label.text,
		"spell_timing_tooltip_text": _timing_label.tooltip_text,
		"enemy_commander_text": BattleRules.describe_commander_summary(_session, "enemy"),
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
	var routed := _handle_battle_resolution(result)
	if not routed:
		_refresh()
	return _action_validation_response(action_id, result, routed)

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
	_on_save_pressed()
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_message,
	}

func validation_return_to_menu() -> Dictionary:
	_on_menu_pressed()
	return {
		"ok": true,
		"encounter_id": String(_session.battle.get("encounter_id", "")),
		"encounter_name": String(_session.battle.get("encounter_name", "")),
		"message": "Battle route returned to the main menu.",
	}

func _make_placeholder_label(text: String) -> Label:
	var label := FrontierVisualKit.placeholder_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size = Vector2(188.0, 24.0)
	label.tooltip_text = text
	return label

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, 96, false)

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
	var visible := "Latest: %s" % _short_text(_strip_sentence(latest_action), 38)
	if next_step != "":
		visible = "%s | Next: %s" % [
			visible,
			_short_text(_strip_sentence(next_step).trim_suffix("."), 34),
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
	for index in range(min(_battle_tabs.get_tab_count(), tabs.size())):
		var tab: Dictionary = tabs[index]
		_battle_tabs.set_tab_title(index, String(tab.get("title", "")))
	_battle_tabs.tooltip_text = String(payload.get("tooltip_text", ""))

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
	FrontierVisualKit.apply_tab_container(_battle_tabs)
	_battle_tabs.set_tab_title(0, "Order")
	_battle_tabs.set_tab_title(1, "Focus")
	_battle_tabs.set_tab_title(2, "Spells")
	_battle_tabs.set_tab_title(3, "Timing")

	for button in [_prev_target_button, _next_target_button]:
		_style_action_button(button, false, 88)
	for button in [_advance_button, _strike_button, _shoot_button, _defend_button, _retreat_button, _surrender_button]:
		_style_action_button(button, true)
	for button in [_save_button, _menu_button]:
		_style_action_button(button, true, 104)
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
