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
	_set_compact_label(_risk_label, BattleRules.describe_risk_readiness_board(_session), 4)
	_set_compact_label(_consequence_label, _battle_consequence_text(), 4)
	_set_compact_label(_player_command_label, BattleRules.describe_commander_summary(_session, "player"), 1)
	_set_compact_label(_enemy_command_label, BattleRules.describe_commander_summary(_session, "enemy"), 1)
	_set_compact_label(_initiative_label, BattleRules.describe_initiative_track(_session), 5)
	_set_compact_label(_active_label, BattleRules.describe_active_context(_session), 3)
	_set_compact_label(_target_label, BattleRules.describe_target_context(_session), 3)
	_set_compact_label(_spell_label, BattleRules.describe_spellbook(_session), 3)
	_set_compact_label(_effect_label, BattleRules.describe_effect_board(_session), 3)
	_set_compact_label(_timing_label, BattleRules.describe_spell_timing_board(_session), 3)
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
	_action_guide.visible = true
	_set_compact_label(_action_guide, String(target_handoff.get("visible_text", BattleRules.describe_action_surface(_session))), 1)
	_action_guide.tooltip_text = String(target_handoff.get("tooltip_text", BattleRules.describe_action_surface(_session)))
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

	_prev_target_button.disabled = not player_turn or cycle_target_count <= 1
	_next_target_button.disabled = not player_turn or cycle_target_count <= 1
	if not player_turn:
		_prev_target_button.tooltip_text = "Input locked: it is not the player's turn."
		_next_target_button.tooltip_text = "Input locked: it is not the player's turn."
	else:
		_prev_target_button.tooltip_text = "Cycle focus to the previous legal enemy target." if not legal_target_ids.is_empty() else "Cycle focus to the previous enemy stack."
		_next_target_button.tooltip_text = "Cycle focus to the next legal enemy target." if not legal_target_ids.is_empty() else "Cycle focus to the next enemy stack."

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
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	_system_body_label.text = latest_context if return_handoff == "" else "%s\n%s" % [latest_context, return_handoff]
	var current_context := String(surface.get("current_context", ""))
	var save_tooltip_lines := [latest_context]
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
	_save_button.tooltip_text = "%s\n%s" % [
		String(surface.get("save_button_tooltip", "Save the active battle safely.")),
		save_check,
	]
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
	var target_handoff := BattleRules.target_handoff_cue_payload(_session)
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
		"action_surface": action_surface,
		"action_confirmation": action_confirmation,
		"action_confirmation_text": String(action_confirmation.get("visible_text", "")),
		"action_confirmation_tooltip_text": String(action_confirmation.get("tooltip_text", "")),
		"action_guidance": BattleRules.describe_action_surface(_session),
		"visible_action_guidance": _action_guide.text,
		"target_context": BattleRules.describe_target_context(_session),
		"active_consequence_payload": consequence_payload,
		"battle_action_context": action_context_surface,
		"battle_action_context_text": String(action_context_surface.get("visible_text", "")),
		"battle_action_context_tooltip_text": String(action_context_surface.get("tooltip_text", "")),
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
