extends Control

const TARGET_VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1024.0, 600.0),
]
const BATTLE_SCENE_PATH := "res://scenes/battle/BattleShell.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/menus/MainMenu.tscn"
const OVERWORLD_SCENE_PATH := "res://scenes/overworld/OverworldShell.tscn"
const SCENARIO_OUTCOME_SCENE_PATH := "res://scenes/results/ScenarioOutcomeShell.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in TARGET_VIEWPORT_SIZES:
		if not await _run_layout_case(viewport_size):
			return
	get_tree().quit(0)

func _run_layout_case(viewport_size: Vector2) -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var target_town := _first_enemy_town(session)
	if target_town.is_empty():
		push_error("Battle layout smoke: could not find an enemy town assault target.")
		get_tree().quit(1)
		return false

	session.battle = BattleRules.create_town_assault_payload(session, String(target_town.get("placement_id", "")))
	if session.battle.is_empty():
		push_error("Battle layout smoke: could not stage a town-assault battle.")
		get_tree().quit(1)
		return false
	var board_click_setup := _stage_board_click_dispatch_state(session.battle)
	if board_click_setup.is_empty():
		push_error("Battle layout smoke: could not stage a legal board-click attack case.")
		get_tree().quit(1)
		return false
	SessionState.set_active_session(session)

	var frame := Control.new()
	frame.name = "BattleLayoutFrame"
	frame.size = viewport_size
	add_child(frame)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_rect := frame.get_global_rect()
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null:
		push_error("Battle layout smoke: battle board did not load.")
		get_tree().quit(1)
		return false

	var board_rect := board.get_global_rect()
	if board_rect.size.x < 520.0 or board_rect.size.y < 240.0:
		push_error("Battle layout smoke: tactical board collapsed below a usable surface at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if board_rect.position.x < viewport_rect.position.x - 1.0 or board_rect.position.y < viewport_rect.position.y - 1.0:
		push_error("Battle layout smoke: tactical board rendered outside the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if board_rect.end.x > viewport_rect.end.x + 1.0 or board_rect.end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: tactical board overflowed the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if not board.has_method("validation_hex_layout_summary"):
		push_error("Battle layout smoke: tactical board does not expose the hex layout validation surface.")
		get_tree().quit(1)
		return false
	var hex_summary: Dictionary = board.call("validation_hex_layout_summary")
	if String(hex_summary.get("presentation", "")) != "hex" or int(hex_summary.get("columns", 0)) < 9 or int(hex_summary.get("rows", 0)) < 5:
		push_error("Battle layout smoke: tactical board is not presenting a real hex field at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("terrain_hex_snapped", false)) or bool(hex_summary.get("terrain_single_board_backdrop", true)):
		push_error("Battle layout smoke: terrain rendering is not snapped to the tactical hex grid at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	if not board.has_method("validation_terrain_rendering_summary"):
		push_error("Battle layout smoke: tactical board does not expose terrain rendering validation at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var terrain_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if String(terrain_summary.get("rendering_mode", "")) != "hex_snapped_texture" or int(terrain_summary.get("hex_tile_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle layout smoke: terrain rendering validation did not prove per-hex texture layout at %s: terrain=%s hex=%s." % [viewport_size, terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	var stack_cells: Array = hex_summary.get("stack_cells", [])
	var expected_stack_count := int(hex_summary.get("player_stack_count", 0)) + int(hex_summary.get("enemy_stack_count", 0))
	if stack_cells.size() < expected_stack_count:
		push_error("Battle layout smoke: live stacks were not all projected onto the hex field at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var occupied_hexes: Dictionary = hex_summary.get("occupied_hexes", {})
	if occupied_hexes.size() != expected_stack_count:
		push_error("Battle layout smoke: occupied hex map did not match live stack cells at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("has_active_cell", false)) or not bool(hex_summary.get("has_selected_target_cell", false)):
		push_error("Battle layout smoke: active and selected target stacks must have on-board hex cells at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var selected_legality: Dictionary = hex_summary.get("selected_target_legality", {})
	if not selected_legality.has("attackable") or not selected_legality.has("blocked"):
		push_error("Battle layout smoke: selected target legality did not expose attackable/blocked state at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var selected_click_action := String(hex_summary.get("selected_target_board_click_action", ""))
	var selected_click_label := String(hex_summary.get("selected_target_board_click_label", ""))
	if selected_click_action not in ["strike", "shoot"] or selected_click_label not in ["Strike", "Shoot"]:
		push_error("Battle layout smoke: selected legal target did not expose Strike/Shoot board-click intent at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var selected_click_intent: Dictionary = hex_summary.get("selected_target_board_click_intent", {})
	var selected_click_message := String(selected_click_intent.get("message", ""))
	if selected_click_label not in selected_click_message:
		push_error("Battle layout smoke: selected legal target intent message did not name the click order at %s: %s." % [viewport_size, selected_click_intent])
		get_tree().quit(1)
		return false
	var movement_click_action := String(hex_summary.get("active_movement_board_click_action", ""))
	var movement_click_label := String(hex_summary.get("active_movement_board_click_label", ""))
	var movement_click_intent: Dictionary = hex_summary.get("active_movement_board_click_intent", {})
	var movement_click_message := String(movement_click_intent.get("message", "")).to_lower()
	if movement_click_action != "move" or movement_click_label != "Move" or "green hex click: move" not in movement_click_message:
		push_error("Battle layout smoke: legal movement hexes did not expose compact Move intent at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var legal_movement_intents: Array = hex_summary.get("legal_movement_intents", [])
	if legal_movement_intents.size() != int(hex_summary.get("legal_destination_count", -1)):
		push_error("Battle layout smoke: legal movement intent count did not match legal destination count at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var movement_preview: Dictionary = {}
	for intent_value in legal_movement_intents:
		if intent_value is Dictionary and String(intent_value.get("action", "")) == "move":
			movement_preview = intent_value
			break
	var movement_preview_detail := String(movement_preview.get("destination_detail", "")).to_lower()
	if movement_preview.is_empty() or "hex " not in movement_preview_detail or "step" not in movement_preview_detail:
		push_error("Battle layout smoke: legal movement intent did not expose exact destination/step detail at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	if int(movement_preview.get("steps", 0)) <= 0:
		push_error("Battle layout smoke: legal movement intent did not expose a positive step count at %s: %s." % [viewport_size, movement_preview])
		get_tree().quit(1)
		return false
	if not board.has_method("validation_preview_hex_destination"):
		push_error("Battle layout smoke: battle board does not expose destination preview validation.")
		get_tree().quit(1)
		return false
	var hovered_preview: Dictionary = board.call(
		"validation_preview_hex_destination",
		int(movement_preview.get("q", -1)),
		int(movement_preview.get("r", -1))
	)
	if String(hovered_preview.get("destination_detail", "")) != String(movement_preview.get("destination_detail", "")):
		push_error("Battle layout smoke: destination hover preview lost exact movement detail at %s: preview=%s hovered=%s." % [viewport_size, movement_preview, hovered_preview])
		get_tree().quit(1)
		return false
	hex_summary = board.call("validation_hex_layout_summary")
	if String(hex_summary.get("hovered_destination_detail", "")) != String(movement_preview.get("destination_detail", "")):
		push_error("Battle layout smoke: hovered destination summary did not retain the compact movement detail at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false
	var legal_melee_targets: Array = hex_summary.get("legal_melee_targets", [])
	var legal_ranged_targets: Array = hex_summary.get("legal_ranged_targets", [])
	if int(hex_summary.get("legal_attack_target_count", -1)) != _unique_target_count(legal_melee_targets, legal_ranged_targets):
		push_error("Battle layout smoke: legal attack target count did not match highlighted target ids at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false

	if not await _run_invalid_friendly_board_stack_click_feedback_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_enemy_turn_active_stack_tooltip_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_invalid_empty_board_hex_click_feedback_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not _run_board_hex_click_movement_case(shell, SessionState.ensure_active_session(), movement_preview, viewport_size):
		return false
	if not await _run_setup_move_target_continuity_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_direct_actionable_after_move_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_overlapped_friendly_shape_movement_click_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_overlapped_enemy_shape_movement_click_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	if not await _run_overlapped_enemy_shape_enemy_hex_attack_click_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	board_click_setup = _stage_board_click_dispatch_state(SessionState.ensure_active_session().battle)
	if board_click_setup.is_empty():
		push_error("Battle layout smoke: could not restage the legal board-click attack case after movement validation.")
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame

	if not _run_board_click_dispatch_case(shell, SessionState.ensure_active_session(), board_click_setup, viewport_size):
		return false
	if not await _run_ranged_board_hex_click_dispatch_case(shell, SessionState.ensure_active_session(), viewport_size):
		return false
	for cell_value in stack_cells:
		if not (cell_value is Dictionary):
			continue
		var q := int(cell_value.get("q", -1))
		var r := int(cell_value.get("r", -1))
		if q < 0 or q >= int(hex_summary.get("columns", 0)) or r < 0 or r >= int(hex_summary.get("rows", 0)):
			push_error("Battle layout smoke: stack projected outside the hex grid at %s: %s." % [viewport_size, cell_value])
			get_tree().quit(1)
			return false

	var banner: Control = shell.get_node_or_null("%Banner")
	if banner == null or banner.get_global_rect().position.y < viewport_rect.position.y - 1.0:
		push_error("Battle layout smoke: battle header is clipped above the viewport at %s: banner=%s viewport=%s." % [viewport_size, banner.get_global_rect() if banner != null else Rect2(), viewport_rect])
		get_tree().quit(1)
		return false

	var footer: Control = shell.get_node_or_null("%Footer")
	if footer == null or footer.get_global_rect().end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: battle command footer overflowed the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	var advance_button: Button = shell.get_node_or_null("%Advance")
	if advance_button == null or not viewport_rect.intersects(advance_button.get_global_rect()):
		push_error("Battle layout smoke: primary battle controls are not visible at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if not await _run_direct_actionable_after_move_empty_handoff_case(frame, viewport_size, false):
		return false
	if not await _run_direct_actionable_after_move_empty_handoff_case(frame, viewport_size, true):
		return false

	frame.queue_free()
	await get_tree().process_frame
	if not await _run_direct_actionable_after_move_routed_resolution_case(viewport_size, false):
		return false
	if not await _run_direct_actionable_after_move_routed_resolution_case(viewport_size, true):
		return false
	if viewport_size == TARGET_VIEWPORT_SIZES[0]:
		if not await _run_direct_actionable_after_move_routed_resolution_case(viewport_size, false, true):
			return false
		if not await _run_direct_actionable_after_move_routed_resolution_case(viewport_size, true, true):
			return false
	return true

func _first_enemy_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			return town
	return {}

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _stage_board_click_dispatch_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var legal_target := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or legal_target.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var legal_target_id := String(legal_target.get("battle_id", ""))
	var blocked_target_id := "board_click_blocked_target"
	_ensure_enemy_stack_for_test(battle, legal_target, blocked_target_id)
	_set_stack_hex_for_test(battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(battle, legal_target_id, {"q": 5, "r": 3})
	_set_stack_hex_for_test(battle, blocked_target_id, {"q": 8, "r": 3})
	battle["distance"] = 0
	battle["turn_order"] = [player_id, legal_target_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = legal_target_id
	return {
		"player_id": player_id,
		"legal_target_id": legal_target_id,
		"blocked_target_id": blocked_target_id,
	}

func _stage_ranged_board_hex_click_dispatch_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var legal_target := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or legal_target.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var legal_target_id := String(legal_target.get("battle_id", ""))
	_set_stack_combat_profile_for_test(battle, player_id, 5, true, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, legal_target_id, 999)
	_set_stack_hex_for_test(battle, player_id, {"q": 4, "r": 2})
	_set_stack_hex_for_test(battle, legal_target_id, {"q": 6, "r": 2})
	battle["distance"] = 0
	battle["turn_order"] = [player_id, legal_target_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = legal_target_id
	return {
		"player_id": player_id,
		"legal_target_id": legal_target_id,
		"target_q": 6,
		"target_r": 2,
	}

func _run_invalid_friendly_board_stack_click_feedback_case(shell, session, viewport_size: Vector2) -> bool:
	if shell == null or not shell.has_method("validation_perform_board_stack_click") or not shell.has_method("validation_snapshot"):
		push_error("Battle layout smoke: battle shell does not expose board stack-click validation.")
		get_tree().quit(1)
		return false
	var event_label: Label = shell.get_node_or_null("%Event")
	if event_label == null:
		push_error("Battle layout smoke: battle dispatch label is missing for invalid board-click feedback.")
		get_tree().quit(1)
		return false
	var active_stack := BattleRules.get_active_stack(session.battle)
	var selected_before := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var active_id := String(active_stack.get("battle_id", ""))
	if active_id == "" or String(active_stack.get("side", "")) != "player" or selected_before == "":
		push_error("Battle layout smoke: could not stage a friendly board-click rejection with a player stack and selected enemy at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	shell.set("_tactical_briefing_text", "Opening tactical briefing still visible.")
	shell.set("_last_message", "")
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	var click_result: Dictionary = shell.call("validation_perform_board_stack_click", active_id)
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var event_text := "%s\n%s" % [String(event_label.text), String(event_label.tooltip_text)]
	if (
		bool(click_result.get("ok", false))
		or String(click_result.get("state", "")) != "invalid"
		or "only enemy stacks" not in String(click_result.get("message", "")).to_lower()
		or "only enemy stacks" not in event_text.to_lower()
		or String(shell.get("_tactical_briefing_text")) == ""
		or String(BattleRules.get_selected_target(session.battle).get("battle_id", "")) != selected_before
		or String(snapshot.get("selected_target_battle_id", "")) != selected_before
	):
		push_error("Battle layout smoke: invalid friendly board click did not surface a visible rejection over the opening briefing without changing target focus at %s: click=%s event=%s snapshot=%s." % [viewport_size, click_result, event_text, snapshot])
		get_tree().quit(1)
		return false
	return true

func _run_enemy_turn_active_stack_tooltip_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if (
		board == null
		or not board.has_method("validation_perform_hex_cell_mouse_click")
		or not board.has_method("validation_hex_layout_summary")
		or not board.has_method("validation_preview_hex_destination")
		or not board.has_method("validation_board_fallback_tooltip")
		or not board.has_method("_movement_state_label")
	):
		push_error("Battle layout smoke: battle board does not expose enemy-turn active-stack tooltip validation.")
		get_tree().quit(1)
		return false
	var event_label: Label = shell.get_node_or_null("%Event")
	if event_label == null:
		push_error("Battle layout smoke: battle dispatch label is missing for enemy-turn click feedback.")
		get_tree().quit(1)
		return false
	var enemy_stack := _first_stack_for_side(session.battle, "enemy")
	var player_stack := _first_stack_for_side(session.battle, "player")
	if enemy_stack.is_empty() or player_stack.is_empty():
		push_error("Battle layout smoke: could not stage enemy-turn active-stack tooltip coverage at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var enemy_id := String(enemy_stack.get("battle_id", ""))
	var player_id := String(player_stack.get("battle_id", ""))
	var original_stacks: Array = session.battle.get("stacks", []).duplicate(true) if session.battle.get("stacks", []) is Array else []
	var original_turn_order: Array = session.battle.get("turn_order", []).duplicate(true) if session.battle.get("turn_order", []) is Array else []
	var original_turn_index := int(session.battle.get("turn_index", 0))
	var original_active_id := String(session.battle.get("active_stack_id", ""))
	var original_selected_id := String(session.battle.get("selected_target_id", ""))
	var original_retreat_allowed := bool(session.battle.get("retreat_allowed", true))
	var original_surrender_allowed := bool(session.battle.get("surrender_allowed", true))
	for extra_enemy_id in _stack_ids_for_side_except_for_test(session.battle, "enemy", enemy_id):
		_remove_battle_stack_for_test(session.battle, extra_enemy_id)
	for extra_player_id in _stack_ids_for_side_except_for_test(session.battle, "player", player_id):
		_remove_battle_stack_for_test(session.battle, extra_player_id)
	_set_stack_combat_profile_for_test(session.battle, enemy_id, 5, false, [])
	_set_stack_combat_profile_for_test(session.battle, player_id, 5, false, [])
	_set_stack_health_for_test(session.battle, enemy_id, 999)
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_hex_for_test(session.battle, enemy_id, {"q": 5, "r": 3})
	_set_stack_hex_for_test(session.battle, player_id, {"q": 6, "r": 3})
	var enemy_hex := {"q": 5, "r": 3}
	session.battle["turn_order"] = [enemy_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = enemy_id
	session.battle["selected_target_id"] = player_id
	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	var enemy_destinations := BattleRules.legal_destinations_for_active_stack(session.battle)
	if enemy_destinations.is_empty():
		push_error("Battle layout smoke: could not stage an enemy-turn empty-hex tooltip coverage destination at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var enemy_destination: Dictionary = enemy_destinations[0]
	var enemy_destination_intent: Dictionary = BattleRules.movement_intent_for_destination(
		session.battle,
		int(enemy_destination.get("q", -1)),
		int(enemy_destination.get("r", -1))
	)
	var enemy_movement_intent: Dictionary = BattleRules.active_movement_board_click_intent(session.battle)
	if (
		"not the player's turn" not in String(enemy_destination_intent.get("message", "")).to_lower()
		or "green hex" in String(enemy_destination_intent.get("message", "")).to_lower()
		or "not the player's turn" not in String(enemy_movement_intent.get("message", "")).to_lower()
		or "green hex" in String(enemy_movement_intent.get("message", "")).to_lower()
	):
		push_error("Battle layout smoke: enemy-turn movement intents advertised green-hex input instead of locked initiative at %s: destination=%s active=%s." % [viewport_size, enemy_destination_intent, enemy_movement_intent])
		get_tree().quit(1)
		return false

	shell.set("_last_message", "")
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	var pressure_label: Label = shell.get_node_or_null("%Pressure")
	if pressure_label == null:
		push_error("Battle layout smoke: enemy-turn pressure label is missing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var enemy_turn_pressure := BattleRules.describe_pressure(session)
	var visible_pressure_text := "%s\n%s\n%s" % [
		enemy_turn_pressure,
		String(pressure_label.text),
		String(pressure_label.tooltip_text),
	]
	var visible_pressure_lower := visible_pressure_text.to_lower()
	if (
		"retreat: window closed" not in visible_pressure_lower
		or "surrender: window closed" not in visible_pressure_lower
		or "retreat: open" in visible_pressure_lower
		or "surrender: open" in visible_pressure_lower
	):
		push_error("Battle layout smoke: enemy-turn pressure surface advertised open withdrawal while input was locked at %s: pressure=%s." % [viewport_size, visible_pressure_text])
		get_tree().quit(1)
		return false
	var risk_label: Label = shell.get_node_or_null("%Risk")
	if risk_label == null:
		push_error("Battle layout smoke: enemy-turn risk board is missing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var enemy_turn_risk := BattleRules.describe_risk_readiness_board(session)
	var visible_risk_text := "%s\n%s\n%s" % [
		enemy_turn_risk,
		String(risk_label.text),
		String(risk_label.tooltip_text),
	]
	var visible_risk_lower := visible_risk_text.to_lower()
	if (
		"retargeting is locked" not in visible_risk_lower
		or "shift focus" in visible_risk_lower
		or "cycle focus" in visible_risk_lower
	):
		push_error("Battle layout smoke: enemy-turn risk board advertised retargeting while input was locked at %s: risk=%s." % [viewport_size, visible_risk_text])
		get_tree().quit(1)
		return false
	var spell_actions: Control = shell.get_node_or_null("%SpellActions")
	var enemy_turn_spell_actions := BattleRules.get_spell_actions(session)
	if spell_actions == null:
		push_error("Battle layout smoke: enemy-turn spell action row is missing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if not enemy_turn_spell_actions.is_empty() or spell_actions.visible:
		push_error("Battle layout smoke: enemy-turn spell actions advertised player casting while input was locked at %s: actions=%s visible=%s children=%d." % [viewport_size, enemy_turn_spell_actions, spell_actions.visible, spell_actions.get_child_count()])
		get_tree().quit(1)
		return false
	var timing_label: Label = shell.get_node_or_null("%Timing")
	if timing_label == null:
		push_error("Battle layout smoke: enemy-turn timing panel is missing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var enemy_turn_timing := BattleRules.describe_spell_timing_board(session)
	var visible_timing_text := "%s\n%s\n%s" % [
		enemy_turn_timing,
		String(timing_label.text),
		String(timing_label.tooltip_text),
	]
	var visible_timing_lower := visible_timing_text.to_lower()
	if (
		"player spell and order windows are closed" not in visible_timing_lower
		or "trade this turn" in visible_timing_lower
		or "next player order" in visible_timing_lower
	):
		push_error("Battle layout smoke: enemy-turn timing guidance advertised player timing while input was locked at %s: timing=%s." % [viewport_size, visible_timing_text])
		get_tree().quit(1)
		return false
	var prev_target_button: Button = shell.get_node_or_null("%PrevTarget")
	var next_target_button: Button = shell.get_node_or_null("%NextTarget")
	if prev_target_button == null or next_target_button == null:
		push_error("Battle layout smoke: enemy-turn target-cycle controls are missing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var target_cycle_tooltips := "%s\n%s" % [
		String(prev_target_button.tooltip_text),
		String(next_target_button.tooltip_text),
	]
	var target_cycle_lower := target_cycle_tooltips.to_lower()
	if (
		not prev_target_button.disabled
		or not next_target_button.disabled
		or "not the player's turn" not in target_cycle_lower
		or "cycle focus" in target_cycle_lower
		or "legal enemy target" in target_cycle_lower
	):
		push_error("Battle layout smoke: enemy-turn target-cycle controls advertised target cycling while input was locked at %s: prev_disabled=%s next_disabled=%s tooltips=%s." % [viewport_size, prev_target_button.disabled, next_target_button.disabled, target_cycle_tooltips])
		get_tree().quit(1)
		return false
	var locked_action_surface := BattleRules.get_action_surface(session)
	var locked_action_text := ""
	var locked_action_failures := []
	for action_id in ["advance", "strike", "shoot", "defend", "retreat", "surrender"]:
		var action: Dictionary = locked_action_surface.get(action_id, {}) if locked_action_surface.get(action_id, {}) is Dictionary else {}
		var button: Button = shell.get_node_or_null("%" + String(action_id).capitalize())
		if button == null:
			locked_action_failures.append("%s button missing" % action_id)
			continue
		var action_text := "%s\n%s" % [
			String(action.get("summary", "")),
			String(button.tooltip_text),
		]
		var action_lower := action_text.to_lower()
		locked_action_text += "\n%s: %s" % [action_id, action_text]
		if not bool(action.get("disabled", false)):
			locked_action_failures.append("%s surface enabled" % action_id)
		if not button.disabled:
			locked_action_failures.append("%s button enabled" % action_id)
		if "not the player's turn" not in action_lower:
			locked_action_failures.append("%s missing input-lock wording" % action_id)
		if "await the enemy move" in action_lower:
			locked_action_failures.append("%s kept generic await wording" % action_id)
	if not locked_action_failures.is_empty():
		push_error("Battle layout smoke: enemy-turn primary command controls did not surface locked input truthfully at %s: failures=%s text=%s surface=%s." % [viewport_size, locked_action_failures, locked_action_text, locked_action_surface])
		get_tree().quit(1)
		return false
	var enemy_turn_board: Dictionary = board.call("validation_hex_layout_summary")
	var footer_label := String(enemy_turn_board.get("selected_target_footer_label", ""))
	var footer_lower := footer_label.to_lower()
	if (
		footer_label != "Input locked"
		or String(enemy_turn_board.get("selected_target_battle_id", "")) != player_id
		or "target:" in footer_lower
		or "green" in footer_lower
		or "click" in footer_lower
	):
		push_error("Battle layout smoke: enemy-turn board footer advertised target/action legality while input was locked at %s: footer=%s board=%s." % [viewport_size, footer_label, enemy_turn_board])
		get_tree().quit(1)
		return false
	var selected_intent: Dictionary = enemy_turn_board.get("selected_target_board_click_intent", {}) if enemy_turn_board.get("selected_target_board_click_intent", {}) is Dictionary else {}
	var selected_legality: Dictionary = enemy_turn_board.get("selected_target_legality", {}) if enemy_turn_board.get("selected_target_legality", {}) is Dictionary else {}
	var highlighted_stack_ids := []
	for stack_entry_value in enemy_turn_board.get("stack_cells", []):
		if stack_entry_value is Dictionary and bool(stack_entry_value.get("legal_attack_target", false)):
			highlighted_stack_ids.append(String(stack_entry_value.get("battle_id", "")))
	if (
		int(enemy_turn_board.get("legal_attack_target_count", 0)) != 0
		or not enemy_turn_board.get("legal_melee_targets", []).is_empty()
		or not enemy_turn_board.get("legal_ranged_targets", []).is_empty()
		or not highlighted_stack_ids.is_empty()
		or bool(enemy_turn_board.get("selected_target_attackable", false))
		or not bool(selected_legality.get("input_locked", false))
		or bool(selected_legality.get("attackable", false))
		or "board click" in String(selected_intent.get("message", "")).to_lower()
	):
		push_error("Battle layout smoke: enemy-turn board presentation still exposed attack affordances while input was locked at %s: highlighted=%s selected_legality=%s selected_intent=%s board=%s." % [viewport_size, highlighted_stack_ids, selected_legality, selected_intent, enemy_turn_board])
		get_tree().quit(1)
		return false
	var enemy_hover_preview: Dictionary = board.call(
		"validation_preview_hex_destination",
		int(enemy_destination.get("q", -1)),
		int(enemy_destination.get("r", -1))
	)
	var enemy_hover_footer := String(board.call("_movement_state_label"))
	if (
		"not the player's turn" not in String(enemy_hover_preview.get("message", "")).to_lower()
		or enemy_hover_footer != ""
		or "green" in enemy_hover_footer.to_lower()
	):
		push_error("Battle layout smoke: enemy-turn hover footer still advertised green movement while input was locked at %s: preview=%s footer=%s board=%s." % [viewport_size, enemy_hover_preview, enemy_hover_footer, enemy_turn_board])
		get_tree().quit(1)
		return false
	var click: Dictionary = board.call(
		"validation_perform_hex_cell_mouse_click",
		int(enemy_hex.get("q", -1)),
		int(enemy_hex.get("r", -1))
	)
	await get_tree().process_frame
	var tooltip_before := String(click.get("tooltip_before", ""))
	var tooltip_lower := tooltip_before.to_lower()
	var event_text := "%s\n%s" % [String(event_label.text), String(event_label.tooltip_text)]
	if (
		not bool(click.get("accepted", false))
		or String(click.get("battle_id", "")) != enemy_id
		or "not the player's turn" not in tooltip_lower
		or "green hex" in tooltip_lower
		or "highlighted enemies" in tooltip_lower
		or "not the player's turn" not in event_text.to_lower()
		or String(session.battle.get("active_stack_id", "")) != enemy_id
	):
		push_error("Battle layout smoke: enemy-turn active stack hover/click advertised player actions or failed to surface the rejection at %s: click=%s tooltip=%s event=%s battle=%s." % [viewport_size, click, tooltip_before, event_text, session.battle])
		get_tree().quit(1)
		return false
	var empty_click: Dictionary = board.call(
		"validation_perform_hex_cell_mouse_click",
		int(enemy_destination.get("q", -1)),
		int(enemy_destination.get("r", -1))
	)
	await get_tree().process_frame
	var empty_tooltip_before := String(empty_click.get("tooltip_before", ""))
	var empty_tooltip_lower := empty_tooltip_before.to_lower()
	event_text = "%s\n%s" % [String(event_label.text), String(event_label.tooltip_text)]
	if (
		not bool(empty_click.get("accepted", false))
		or String(empty_click.get("dispatch", "")) != "destination"
		or "not the player's turn" not in empty_tooltip_lower
		or "green hex" in empty_tooltip_lower
		or "not the player's turn" not in event_text.to_lower()
		or "green hex" in event_text.to_lower()
		or String(session.battle.get("active_stack_id", "")) != enemy_id
	):
		push_error("Battle layout smoke: enemy-turn empty hex hover/click advertised green-hex movement or failed to surface locked initiative at %s: click=%s tooltip=%s event=%s battle=%s." % [viewport_size, empty_click, empty_tooltip_before, event_text, session.battle])
		get_tree().quit(1)
		return false
	var fallback_tooltip_result: Dictionary = board.call("validation_board_fallback_tooltip")
	var fallback_tooltip := String(fallback_tooltip_result.get("tooltip", ""))
	var fallback_tooltip_lower := fallback_tooltip.to_lower()
	if (
		not bool(fallback_tooltip_result.get("ok", false))
		or int(fallback_tooltip_result.get("resolved_q", 0)) >= 0
		or String(fallback_tooltip_result.get("shape_target", "")) != ""
		or "not the player's turn" not in fallback_tooltip_lower
		or "green hex" in fallback_tooltip_lower
		or "highlighted enemies" in fallback_tooltip_lower
	):
		push_error("Battle layout smoke: enemy-turn board fallback tooltip advertised player actions while input was locked at %s: fallback=%s battle=%s." % [viewport_size, fallback_tooltip_result, session.battle])
		get_tree().quit(1)
		return false

	session.battle["stacks"] = original_stacks
	session.battle["turn_order"] = original_turn_order
	session.battle["turn_index"] = original_turn_index
	session.battle["active_stack_id"] = original_active_id
	session.battle["selected_target_id"] = original_selected_id
	session.battle["retreat_allowed"] = original_retreat_allowed
	session.battle["surrender_allowed"] = original_surrender_allowed
	shell.set("_last_message", "")
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	return true

func _run_invalid_empty_board_hex_click_feedback_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if (
		board == null
		or not board.has_method("validation_perform_hex_cell_mouse_click")
		or not shell.has_method("validation_snapshot")
	):
		push_error("Battle layout smoke: battle board does not expose invalid empty-hex click validation.")
		get_tree().quit(1)
		return false
	var event_label: Label = shell.get_node_or_null("%Event")
	if event_label == null:
		push_error("Battle layout smoke: battle dispatch label is missing for invalid empty-hex feedback.")
		get_tree().quit(1)
		return false
	var invalid_cell := _invalid_empty_destination_hex_for_test(session.battle)
	if invalid_cell.is_empty():
		push_error("Battle layout smoke: could not find an empty non-green battlefield hex for rejection coverage at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var active_before := BattleRules.get_active_stack(session.battle)
	var active_before_hex := _stack_hex_for_test(active_before)
	var selected_before := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var expected_intent := BattleRules.movement_intent_for_destination(
		session.battle,
		int(invalid_cell.get("q", -1)),
		int(invalid_cell.get("r", -1))
	)
	var expected_message := String(expected_intent.get("message", ""))
	if (
		String(expected_intent.get("action", "")) == "move"
		or not bool(expected_intent.get("blocked", false))
		or "not a legal move destination" not in expected_message.to_lower()
	):
		push_error("Battle layout smoke: invalid empty-hex coverage staged a truthful move instead of a blocked destination: cell=%s intent=%s." % [invalid_cell, expected_intent])
		get_tree().quit(1)
		return false

	shell.set("_tactical_briefing_text", "Opening tactical briefing still visible.")
	shell.set("_last_message", "")
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	var click: Dictionary = board.call(
		"validation_perform_hex_cell_mouse_click",
		int(invalid_cell.get("q", -1)),
		int(invalid_cell.get("r", -1))
	)
	await get_tree().process_frame
	var active_after := BattleRules.get_active_stack(session.battle)
	var active_after_hex := _stack_hex_for_test(active_after)
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var event_text := "%s\n%s" % [String(event_label.text), String(event_label.tooltip_text)]
	if (
		not bool(click.get("accepted", false))
		or String(click.get("dispatch", "")) != "destination_blocked"
		or String(click.get("message", "")) != expected_message
		or String(click.get("tooltip_before", "")) != expected_message
		or "green hex click blocked" not in event_text.to_lower()
		or "not a legal move destination" not in event_text.to_lower()
		or String(shell.get("_tactical_briefing_text")) == ""
		or _hex_key_for_test(active_after_hex) != _hex_key_for_test(active_before_hex)
		or String(BattleRules.get_selected_target(session.battle).get("battle_id", "")) != selected_before
		or String(snapshot.get("selected_target_battle_id", "")) != selected_before
	):
		push_error("Battle layout smoke: invalid empty battlefield hex click did not surface a visible blocked Move rejection without moving or retargeting at %s: cell=%s click=%s event=%s before=%s after=%s snapshot=%s." % [viewport_size, invalid_cell, click, event_text, active_before_hex, active_after_hex, snapshot])
		get_tree().quit(1)
		return false
	return true

func _stage_overlapped_friendly_shape_movement_click_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var enemy_stack := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or enemy_stack.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var enemy_id := String(enemy_stack.get("battle_id", ""))
	for extra_player_id in _stack_ids_for_side_except_for_test(battle, "player", player_id):
		_remove_battle_stack_for_test(battle, extra_player_id)
	for extra_enemy_id in _stack_ids_for_side_except_for_test(battle, "enemy", enemy_id):
		_remove_battle_stack_for_test(battle, extra_enemy_id)
	_set_stack_combat_profile_for_test(battle, player_id, 5, false, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, enemy_id, 999)
	_set_stack_hex_for_test(battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(battle, enemy_id, {"q": 9, "r": 3})
	battle["distance"] = 0
	battle["round"] = 1
	battle["max_rounds"] = 12
	battle["turn_order"] = [player_id, enemy_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = enemy_id
	battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	var movement_intent := BattleRules.movement_intent_for_destination(battle, 5, 3)
	if String(movement_intent.get("action", "")) != "move":
		return {}
	return {
		"player_id": player_id,
		"enemy_id": enemy_id,
		"destination_q": 5,
		"destination_r": 3,
		"intent": movement_intent,
	}

func _stage_overlapped_enemy_shape_movement_click_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var enemy_stack := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or enemy_stack.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var enemy_id := String(enemy_stack.get("battle_id", ""))
	for extra_player_id in _stack_ids_for_side_except_for_test(battle, "player", player_id):
		_remove_battle_stack_for_test(battle, extra_player_id)
	for extra_enemy_id in _stack_ids_for_side_except_for_test(battle, "enemy", enemy_id):
		_remove_battle_stack_for_test(battle, extra_enemy_id)
	_set_stack_combat_profile_for_test(battle, player_id, 5, false, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, enemy_id, 999)
	_set_stack_hex_for_test(battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(battle, enemy_id, {"q": 6, "r": 3})
	battle["distance"] = 0
	battle["round"] = 1
	battle["max_rounds"] = 12
	battle["turn_order"] = [player_id, enemy_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = enemy_id
	battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	var movement_intent := BattleRules.movement_intent_for_destination(battle, 5, 3)
	if (
		String(movement_intent.get("action", "")) != "move"
		or not bool(movement_intent.get("selected_target_blocked", false))
	):
		return {}
	return {
		"player_id": player_id,
		"enemy_id": enemy_id,
		"destination_q": 5,
		"destination_r": 3,
		"intent": movement_intent,
	}

func _stage_overlapped_enemy_shape_enemy_hex_attack_click_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var enemy_stack := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or enemy_stack.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var target_id := String(enemy_stack.get("battle_id", ""))
	var overlap_enemy_id := "enemy_hex_overlap_neighbor"
	for extra_player_id in _stack_ids_for_side_except_for_test(battle, "player", player_id):
		_remove_battle_stack_for_test(battle, extra_player_id)
	for extra_enemy_id in _stack_ids_for_side_except_for_test(battle, "enemy", target_id):
		_remove_battle_stack_for_test(battle, extra_enemy_id)
	_ensure_enemy_stack_for_test(battle, enemy_stack, overlap_enemy_id)
	_set_stack_combat_profile_for_test(battle, player_id, 5, true, [])
	_set_stack_combat_profile_for_test(battle, target_id, 5, false, [])
	_set_stack_combat_profile_for_test(battle, overlap_enemy_id, 5, false, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, target_id, 999)
	_set_stack_health_for_test(battle, overlap_enemy_id, 999)
	_set_stack_hex_for_test(battle, player_id, {"q": 3, "r": 3})
	_set_stack_hex_for_test(battle, target_id, {"q": 5, "r": 3})
	_set_stack_hex_for_test(battle, overlap_enemy_id, {"q": 6, "r": 3})
	battle["distance"] = 0
	battle["round"] = 1
	battle["max_rounds"] = 12
	battle["turn_order"] = [player_id, target_id, overlap_enemy_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = target_id
	battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	var target_intent := BattleRules.board_click_attack_intent_for_target(battle, target_id)
	var overlap_intent := BattleRules.board_click_attack_intent_for_target(battle, overlap_enemy_id)
	if String(target_intent.get("action", "")) != "shoot" or String(overlap_intent.get("action", "")) != "shoot":
		return {}
	return {
		"player_id": player_id,
		"target_id": target_id,
		"overlap_enemy_id": overlap_enemy_id,
		"target_q": 5,
		"target_r": 3,
		"target_intent": target_intent,
		"overlap_intent": overlap_intent,
	}

func _stage_setup_move_target_continuity_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var default_enemy := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or default_enemy.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var default_enemy_id := String(default_enemy.get("battle_id", ""))
	var continuity_target_id := "setup_move_continuity_target"
	_ensure_enemy_stack_for_test(battle, default_enemy, continuity_target_id)
	_set_stack_hex_for_test(battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(battle, default_enemy_id, {"q": 5, "r": 3})
	_set_stack_health_for_test(battle, player_id, 999)
	battle["distance"] = 0
	battle["turn_order"] = [player_id, default_enemy_id, continuity_target_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = continuity_target_id

	var setup_case := _stage_later_attack_destination_for_test(battle, player_id, continuity_target_id)
	if setup_case.is_empty():
		return {}
	var destination: Dictionary = setup_case.get("destination", {})
	var target_hex: Dictionary = setup_case.get("target_hex", {})
	var default_enemy_hex := _open_neighbor_for_test(battle, destination, [_hex_key_for_test(target_hex)])
	if default_enemy_hex.is_empty():
		return {}
	_set_stack_hex_for_test(battle, default_enemy_id, default_enemy_hex)
	battle["selected_target_id"] = continuity_target_id
	var movement_intent := BattleRules.movement_intent_for_destination(
		battle,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(movement_intent.get("sets_up_selected_target_attack", false)):
		return {}
	var pre_move_legality: Dictionary = BattleRules.selected_target_legality(battle)
	if not bool(pre_move_legality.get("blocked", false)):
		return {}
	return {
		"player_id": player_id,
		"default_enemy_id": default_enemy_id,
		"target_id": continuity_target_id,
		"destination": destination,
		"intent": movement_intent,
	}

func _stage_direct_actionable_after_move_state(
	battle: Dictionary,
	target_health: int = 999,
	include_handoff_target: bool = false,
	handoff_direct_actionable: bool = false
) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var source_enemy := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or source_enemy.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var target_id := "direct_actionable_after_move_target"
	var handoff_target_id := "direct_actionable_after_move_handoff_target"
	_ensure_enemy_stack_for_test(battle, source_enemy, target_id)
	for enemy_id in _enemy_stack_ids_except_for_test(battle, target_id):
		_remove_battle_stack_for_test(battle, enemy_id)
	if include_handoff_target:
		_ensure_enemy_stack_for_test(battle, source_enemy, handoff_target_id)
	_set_stack_combat_profile_for_test(battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(battle, target_id, 1, false, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, target_id, target_health)
	_set_stack_hex_for_test(battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(battle, target_id, {"q": 4, "r": 3})
	if include_handoff_target:
		_set_stack_combat_profile_for_test(battle, handoff_target_id, 1, false, [])
		_set_stack_health_for_test(battle, handoff_target_id, 999)
		_set_stack_hex_for_test(
			battle,
			handoff_target_id,
			{"q": 4, "r": 2} if handoff_direct_actionable else {"q": 7, "r": 3}
		)
	battle["distance"] = 0
	battle["turn_order"] = [player_id, player_id, player_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = target_id
	battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var first_intent := BattleRules.movement_intent_for_destination(battle, 1, 3)
	if (
		String(first_intent.get("action", "")) != "move"
		or not bool(first_intent.get("closes_on_selected_target", false))
		or bool(first_intent.get("sets_up_selected_target_attack", false))
	):
		return {}
	return {
		"player_id": player_id,
		"target_id": target_id,
		"handoff_target_id": handoff_target_id if include_handoff_target else "",
		"handoff_direct_actionable": handoff_direct_actionable,
		"first_destination": {"q": 1, "r": 3},
		"destination": {"q": 2, "r": 3},
		"first_intent": first_intent,
	}

func _stage_direct_actionable_after_move_preferred_handoff_state(battle: Dictionary) -> Dictionary:
	var player_stack := _first_stack_for_side(battle, "player")
	var source_enemy := _first_stack_for_side(battle, "enemy")
	if player_stack.is_empty() or source_enemy.is_empty():
		return {}
	var player_id := String(player_stack.get("battle_id", ""))
	var target_id := "direct_actionable_after_move_preferred_target"
	var blocked_handoff_id := "direct_actionable_after_move_blocked_handoff_candidate"
	var attackable_handoff_id := "direct_actionable_after_move_attackable_handoff_candidate"
	_ensure_enemy_stack_for_test(battle, source_enemy, target_id)
	for enemy_id in _enemy_stack_ids_except_for_test(battle, target_id):
		_remove_battle_stack_for_test(battle, enemy_id)
	_ensure_enemy_stack_for_test(battle, source_enemy, blocked_handoff_id)
	_ensure_enemy_stack_for_test(battle, source_enemy, attackable_handoff_id)
	_set_stack_combat_profile_for_test(battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(battle, target_id, 1, false, [])
	_set_stack_combat_profile_for_test(battle, blocked_handoff_id, 1, false, [])
	_set_stack_combat_profile_for_test(battle, attackable_handoff_id, 1, false, [])
	_set_stack_health_for_test(battle, player_id, 999)
	_set_stack_health_for_test(battle, target_id, 1)
	_set_stack_health_for_test(battle, blocked_handoff_id, 999)
	_set_stack_health_for_test(battle, attackable_handoff_id, 999)
	_set_stack_hex_for_test(battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(battle, target_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(battle, blocked_handoff_id, {"q": 7, "r": 3})
	_set_stack_hex_for_test(battle, attackable_handoff_id, {"q": 4, "r": 2})
	battle["distance"] = 0
	battle["turn_order"] = [player_id, player_id, player_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = target_id
	battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var enemy_order := []
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			enemy_order.append(String(stack.get("battle_id", "")))
	var first_intent := BattleRules.movement_intent_for_destination(battle, 1, 3)
	if (
		enemy_order.find(blocked_handoff_id) < 0
		or enemy_order.find(attackable_handoff_id) < 0
		or enemy_order.find(blocked_handoff_id) > enemy_order.find(attackable_handoff_id)
		or String(first_intent.get("action", "")) != "move"
		or not bool(first_intent.get("closes_on_selected_target", false))
		or bool(first_intent.get("sets_up_selected_target_attack", false))
	):
		return {}
	return {
		"player_id": player_id,
		"target_id": target_id,
		"blocked_handoff_id": blocked_handoff_id,
		"attackable_handoff_id": attackable_handoff_id,
		"enemy_order": enemy_order,
		"first_destination": {"q": 1, "r": 3},
		"destination": {"q": 2, "r": 3},
		"first_intent": first_intent,
	}

func _run_board_hex_click_movement_case(shell, session, movement_preview: Dictionary, viewport_size: Vector2) -> bool:
	if not shell.has_method("validation_perform_board_hex_click"):
		push_error("Battle layout smoke: battle shell does not expose board-hex click validation.")
		get_tree().quit(1)
		return false
	if movement_preview.is_empty():
		push_error("Battle layout smoke: no movement preview was available for board-hex click validation at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	var moved_stack_id := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	var click_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(movement_preview.get("q", -1)),
		int(movement_preview.get("r", -1))
	)
	var click_message := String(click_result.get("message", ""))
	var preview_message := String(movement_preview.get("message", ""))
	if not bool(click_result.get("ok", false)) or String(click_result.get("action", "")) != "move":
		push_error("Battle layout smoke: legal green-hex click did not execute a move at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if not click_message.begins_with(preview_message):
		push_error("Battle layout smoke: green-hex click result did not preserve preview language at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if String(click_result.get("preview_message", "")) != preview_message:
		push_error("Battle layout smoke: green-hex click validation did not retain preview message at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if String(click_result.get("destination_detail", "")) != String(movement_preview.get("destination_detail", "")) or int(click_result.get("steps", -1)) != int(movement_preview.get("steps", -2)):
		push_error("Battle layout smoke: green-hex click validation lost destination detail at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if bool(click_result.get("sets_up_selected_target_attack", false)) != bool(movement_preview.get("sets_up_selected_target_attack", false)) or String(click_result.get("selected_target_setup_label", "")) != String(movement_preview.get("selected_target_setup_label", "")):
		push_error("Battle layout smoke: green-hex click validation lost later-attack setup truth at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if moved_stack_id != "" and _hex_key_for_test(_stack_hex_for_test(_battle_stack_by_id(session.battle, moved_stack_id))) != _hex_key_for_test(movement_preview):
		push_error("Battle layout smoke: green-hex click result did not place the active stack on the previewed destination at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	return true

func _run_setup_move_target_continuity_case(shell, session, viewport_size: Vector2) -> bool:
	if not shell.has_method("validation_perform_board_hex_click"):
		push_error("Battle layout smoke: battle shell does not expose board-hex click validation for setup-move continuity.")
		get_tree().quit(1)
		return false
	var setup := _stage_setup_move_target_continuity_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage setup-move target continuity at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_hex_layout_summary"):
		push_error("Battle layout smoke: battle board does not expose continuity validation at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if board.has_method("set_battle_state"):
		board.call("set_battle_state", session)
	await get_tree().process_frame
	var hex_summary: Dictionary = board.call("validation_hex_layout_summary")
	var legal_movement_intents: Array = hex_summary.get("legal_movement_intents", [])
	var movement_preview: Dictionary = {}
	var target_id := String(setup.get("target_id", ""))
	for intent_value in legal_movement_intents:
		if not (intent_value is Dictionary):
			continue
		var intent: Dictionary = intent_value
		if bool(intent.get("sets_up_selected_target_attack", false)) and String(intent.get("selected_target_battle_id", "")) == target_id:
			movement_preview = intent
			break
	if movement_preview.is_empty():
		push_error("Battle layout smoke: board summary did not expose the setup-move continuity preview at %s: %s." % [viewport_size, hex_summary])
		get_tree().quit(1)
		return false

	var click_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(movement_preview.get("q", -1)),
		int(movement_preview.get("r", -1))
	)
	if not bool(click_result.get("ok", false)) or String(click_result.get("action", "")) != "move":
		push_error("Battle layout smoke: setup-move continuity click did not execute movement at %s: preview=%s result=%s." % [viewport_size, movement_preview, click_result])
		get_tree().quit(1)
		return false
	if String(session.battle.get("selected_target_id", "")) != target_id:
		push_error("Battle layout smoke: setup-move continuity did not keep the selected target at %s: setup=%s result=%s." % [viewport_size, setup, click_result])
		get_tree().quit(1)
		return false
	if String(click_result.get("selected_target_after_move_battle_id", "")) != target_id or not bool(click_result.get("selected_target_continuity_preserved", false)):
		push_error("Battle layout smoke: setup-move continuity result did not report the preserved target at %s: setup=%s result=%s." % [viewport_size, setup, click_result])
		get_tree().quit(1)
		return false
	var post_move_legal_targets: Array = BattleRules.legal_attack_target_ids_for_active_stack(session.battle)
	if String(setup.get("default_enemy_id", "")) not in post_move_legal_targets:
		push_error("Battle layout smoke: setup-move continuity did not retain the competing legal default target at %s: legal=%s setup=%s result=%s." % [viewport_size, post_move_legal_targets, setup, click_result])
		get_tree().quit(1)
		return false
	var result_legality: Dictionary = click_result.get("selected_target_after_move_legality", {})
	var post_click_intent: Dictionary = click_result.get("selected_target_after_move_board_click_intent", {})
	var continuity_context: Dictionary = click_result.get("selected_target_continuity_context", {})
	var guidance := String(click_result.get("post_move_target_guidance", "")).to_lower()
	var action_guidance := String(click_result.get("post_move_action_guidance", "")).to_lower()
	var target_context := String(click_result.get("post_move_target_context", "")).to_lower()
	var post_board_summary: Dictionary = click_result.get("post_move_board_summary", {})
	if continuity_context.is_empty() or not bool(continuity_context.get("preserved_setup_target", false)):
		push_error("Battle layout smoke: setup-move continuity did not surface preserved setup context at %s: result=%s." % [viewport_size, click_result])
		get_tree().quit(1)
		return false
	if "preserved setup target" not in action_guidance or "preserved setup target" not in target_context:
		push_error("Battle layout smoke: setup-move continuity did not surface preserved target guidance through compact labels at %s: result=%s." % [viewport_size, click_result])
		get_tree().quit(1)
		return false
	if not bool(post_board_summary.get("selected_target_preserved_setup", false)) or String(post_board_summary.get("selected_target_footer_label", "")).find("Setup:") != 0:
		push_error("Battle layout smoke: setup-move continuity did not mark the preserved target on the board footer/summary at %s: result=%s." % [viewport_size, click_result])
		get_tree().quit(1)
		return false
	var target_cell_entry := _stack_cell_entry(post_board_summary.get("stack_cells", []), target_id)
	if target_cell_entry.is_empty() or not bool(target_cell_entry.get("preserved_setup_target", false)) or not bool(target_cell_entry.get("selected_target", false)):
		push_error("Battle layout smoke: setup-move continuity board emphasis did not stay on the preserved target at %s: target=%s board=%s result=%s." % [viewport_size, target_id, target_cell_entry, click_result])
		get_tree().quit(1)
		return false
	if bool(result_legality.get("attackable", false)):
		if (
			String(post_click_intent.get("action", "")) not in ["strike", "shoot"]
			or "board click" not in guidance
			or "board click will" not in action_guidance
			or not bool(target_cell_entry.get("legal_attack_target", false))
		):
			push_error("Battle layout smoke: setup-move continuity did not expose the post-move legal attack guidance at %s: result=%s." % [viewport_size, click_result])
			get_tree().quit(1)
			return false
	elif bool(result_legality.get("blocked", false)):
		if not bool(post_click_intent.get("blocked", false)) or "still blocked" not in guidance or "still blocked" not in action_guidance or not bool(target_cell_entry.get("selected_target_blocked", false)):
			push_error("Battle layout smoke: setup-move continuity did not expose the post-move blocked guidance at %s: result=%s." % [viewport_size, click_result])
			get_tree().quit(1)
			return false
	else:
		push_error("Battle layout smoke: setup-move continuity post state was neither attackable nor blocked at %s: result=%s." % [viewport_size, click_result])
		get_tree().quit(1)
		return false
	var post_snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = post_snapshot.get("selected_target_continuity_context", {})
	var snapshot_action_guidance := String(post_snapshot.get("action_guidance", "")).to_lower()
	if snapshot_context.is_empty() or "preserved setup target" not in snapshot_action_guidance:
		push_error("Battle layout smoke: setup-move continuity was not visible in the immediate shell snapshot at %s: snapshot=%s." % [viewport_size, post_snapshot])
		get_tree().quit(1)
		return false
	if not shell.has_method("validation_cycle_target"):
		push_error("Battle layout smoke: battle shell does not expose target-cycle validation for preserved setup retarget clearing at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var cycle_result: Dictionary = shell.call("validation_cycle_target", 1)
	var cycle_action_guidance := String(cycle_result.get("action_guidance", "")).to_lower()
	var cycle_target_context := String(cycle_result.get("target_context", "")).to_lower()
	var cycle_board: Dictionary = cycle_result.get("battle_board", {})
	var cycle_continuity_context: Dictionary = cycle_result.get("selected_target_continuity_context", {}) if cycle_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	if (
		String(cycle_result.get("selected_target_before", "")) != target_id
		or String(cycle_result.get("selected_target_after", "")) == target_id
		or bool(cycle_result.get("selected_target_preserved_setup", false))
		or not cycle_continuity_context.is_empty()
		or "preserved setup target" in cycle_action_guidance
		or "preserved setup target" in cycle_target_context
		or bool(cycle_board.get("selected_target_preserved_setup", false))
		or String(cycle_board.get("selected_target_footer_label", "")).find("Setup:") == 0
	):
		push_error("Battle layout smoke: explicit target cycling did not clear preserved setup context at %s: cycle=%s." % [viewport_size, cycle_result])
		get_tree().quit(1)
		return false
	var old_target_cell_entry := _stack_cell_entry(cycle_board.get("stack_cells", []), target_id)
	if not old_target_cell_entry.is_empty() and bool(old_target_cell_entry.get("preserved_setup_target", false)):
		push_error("Battle layout smoke: old setup target kept preserved board emphasis after retargeting at %s: target=%s cycle=%s." % [viewport_size, old_target_cell_entry, cycle_result])
		get_tree().quit(1)
		return false
	var active_after_clear := BattleRules.get_active_stack(session.battle)
	var blocked_refocus_hex := _far_open_hex_for_test(session.battle, _stack_hex_for_test(active_after_clear), 3)
	if blocked_refocus_hex.is_empty():
		push_error("Battle layout smoke: could not place the old setup target for blocked refocus validation at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	_set_stack_hex_for_test(session.battle, target_id, blocked_refocus_hex)
	var old_target_click: Dictionary = shell.call("validation_perform_board_stack_click", target_id)
	var old_target_click_context: Dictionary = old_target_click.get("selected_target_continuity_context", {}) if old_target_click.get("selected_target_continuity_context", {}) is Dictionary else {}
	var old_target_action_guidance := String(old_target_click.get("action_guidance", "")).to_lower()
	var old_target_context := String(old_target_click.get("target_context", "")).to_lower()
	var old_target_board: Dictionary = old_target_click.get("battle_board", {}) if old_target_click.get("battle_board", {}) is Dictionary else {}
	var old_target_board_cell := _stack_cell_entry(old_target_board.get("stack_cells", []), target_id)
	if (
		bool(old_target_click.get("ok", false))
		or String(old_target_click.get("action", "")) != "blocked_target"
		or String(old_target_click.get("selected_target_after_click", "")) != target_id
		or bool(old_target_click.get("selected_target_preserved_setup", false))
		or not old_target_click_context.is_empty()
		or "preserved setup target" in old_target_action_guidance
		or "preserved setup target" in old_target_context
		or bool(old_target_board.get("selected_target_preserved_setup", false))
		or String(old_target_board.get("selected_target_footer_label", "")).find("Setup:") == 0
		or (not old_target_board_cell.is_empty() and bool(old_target_board_cell.get("preserved_setup_target", false)))
	):
		push_error("Battle layout smoke: selecting back to the old setup target resurrected preserved context at %s: click=%s." % [viewport_size, old_target_click])
		get_tree().quit(1)
		return false
	var refocus_snapshot: Dictionary = shell.call("validation_snapshot")
	var refocus_snapshot_context: Dictionary = refocus_snapshot.get("selected_target_continuity_context", {}) if refocus_snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	if (
		bool(refocus_snapshot.get("selected_target_preserved_setup", false))
		or not refocus_snapshot_context.is_empty()
		or "preserved setup target" in String(refocus_snapshot.get("action_guidance", "")).to_lower()
		or "preserved setup target" in String(refocus_snapshot.get("target_context", "")).to_lower()
	):
		push_error("Battle layout smoke: old-target refocus left preserved setup context in the shell snapshot at %s: snapshot=%s." % [viewport_size, refocus_snapshot])
		get_tree().quit(1)
		return false
	if not _run_post_clear_old_target_normal_move_case(shell, session, target_id, viewport_size):
		return false
	return true

func _run_direct_actionable_after_move_case(shell, session, viewport_size: Vector2) -> bool:
	if not shell.has_method("validation_perform_board_hex_click"):
		push_error("Battle layout smoke: battle shell does not expose board-hex click validation for direct actionable movement.")
		get_tree().quit(1)
		return false
	var setup := _stage_direct_actionable_after_move_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage direct actionable post-move target state at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_hex_layout_summary"):
		push_error("Battle layout smoke: battle board does not expose direct actionable validation at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	if board.has_method("set_battle_state"):
		board.call("set_battle_state", session)
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing_context: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or not bool(first_click.get("closes_on_selected_target", false))
		or bool(first_click.get("sets_up_selected_target_attack", false))
		or first_closing_context.is_empty()
		or not bool(first_closing_context.get("ordinary_closing_target", false))
	):
		push_error("Battle layout smoke: direct actionable setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [viewport_size, setup, first_click])
		get_tree().quit(1)
		return false
	var second_preview := BattleRules.movement_intent_for_destination(
		session.battle,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if (
		String(second_preview.get("action", "")) != "move"
		or not bool(second_preview.get("selected_target_closing_before_move", false))
		or not bool(second_preview.get("sets_up_selected_target_attack", false))
		or not bool(second_preview.get("selected_target_after_move_attackable", false))
	):
		push_error("Battle layout smoke: direct actionable second move did not preview closing-to-actionable state at %s: setup=%s preview=%s." % [viewport_size, setup, second_preview])
		get_tree().quit(1)
		return false
	var click_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var result_context: Dictionary = click_result.get("selected_target_continuity_context", {}) if click_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_closing_context: Dictionary = click_result.get("selected_target_closing_context", {}) if click_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_legality: Dictionary = click_result.get("selected_target_after_move_legality", {}) if click_result.get("selected_target_after_move_legality", {}) is Dictionary else {}
	var action_id := String(click_result.get("selected_target_after_move_board_click_action", ""))
	var guidance := String(click_result.get("post_move_target_guidance", "")).to_lower()
	var action_guidance := String(click_result.get("post_move_action_guidance", "")).to_lower()
	var target_context := String(click_result.get("post_move_target_context", "")).to_lower()
	var post_board: Dictionary = click_result.get("post_move_board_summary", {}) if click_result.get("post_move_board_summary", {}) is Dictionary else {}
	var post_cell := _stack_cell_entry(post_board.get("stack_cells", []), target_id)
	if (
		not bool(click_result.get("ok", false))
		or String(click_result.get("action", "")) != "move"
		or String(click_result.get("selected_target_after_move_battle_id", "")) != target_id
		or not bool(result_legality.get("attackable", false))
		or action_id not in ["strike", "shoot"]
		or not bool(click_result.get("selected_target_actionable_after_move", false))
		or not bool(click_result.get("selected_target_closing_before_move", false))
		or bool(click_result.get("selected_target_continuity_preserved", false))
		or bool(click_result.get("selected_target_preserved_setup", false))
		or not result_context.is_empty()
		or bool(click_result.get("selected_target_closing_on_target", false))
		or not result_closing_context.is_empty()
		or "board click will" not in guidance
		or "board click will" not in action_guidance
		or "board click will" not in target_context
		or "preserved setup target" in guidance
		or "preserved setup target" in action_guidance
		or "preserved setup target" in target_context
		or "closing on target" in guidance
		or "closing on target" in action_guidance
		or "closing on target" in target_context
		or not bool(post_board.get("selected_target_direct_actionable", false))
		or bool(post_board.get("selected_target_preserved_setup", false))
		or bool(post_board.get("selected_target_closing_on_target", false))
		or String(post_board.get("selected_target_footer_label", "")).find("Click:") != 0
		or post_cell.is_empty()
		or not bool(post_cell.get("legal_attack_target", false))
		or bool(post_cell.get("preserved_setup_target", false))
		or bool(post_cell.get("ordinary_closing_target", false))
	):
		push_error("Battle layout smoke: direct actionable post-move state did not replace setup/closing guidance with board-click action at %s: setup=%s result=%s." % [viewport_size, setup, click_result])
		get_tree().quit(1)
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing_context: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	if (
		not bool(snapshot.get("selected_target_direct_actionable", false))
		or bool(snapshot.get("selected_target_preserved_setup", false))
		or not snapshot_context.is_empty()
		or bool(snapshot.get("selected_target_closing_on_target", false))
		or not snapshot_closing_context.is_empty()
		or "board click will" not in String(snapshot.get("action_guidance", "")).to_lower()
		or "board click will" not in String(snapshot.get("target_context", "")).to_lower()
		or "preserved setup target" in String(snapshot.get("action_guidance", "")).to_lower()
		or "closing on target" in String(snapshot.get("action_guidance", "")).to_lower()
		or not bool(snapshot_board.get("selected_target_direct_actionable", false))
		or String(snapshot_board.get("selected_target_footer_label", "")).find("Click:") != 0
	):
		push_error("Battle layout smoke: direct actionable shell snapshot did not stay on normal board-click guidance at %s: snapshot=%s." % [viewport_size, snapshot])
		get_tree().quit(1)
		return false

	var health_before_attack := int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0))
	var attack_click: Dictionary = shell.call("validation_perform_board_stack_click", target_id)
	var attack_result: Dictionary = attack_click.get("attack_result", {}) if attack_click.get("attack_result", {}) is Dictionary else {}
	var attack_context: Dictionary = attack_click.get("selected_target_continuity_context", {}) if attack_click.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_result_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing_context: Dictionary = attack_click.get("selected_target_closing_context", {}) if attack_click.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_result_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_board: Dictionary = attack_click.get("battle_board", {}) if attack_click.get("battle_board", {}) is Dictionary else {}
	var attack_board_context: Dictionary = attack_board.get("selected_target_continuity_context", {}) if attack_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_board_closing: Dictionary = attack_board.get("selected_target_closing_context", {}) if attack_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_cell := _stack_cell_entry(attack_board.get("stack_cells", []), target_id)
	var attack_action_guidance := String(attack_click.get("action_guidance", "")).to_lower()
	var attack_target_context := String(attack_click.get("target_context", "")).to_lower()
	if (
		not bool(attack_click.get("ok", false))
		or String(attack_click.get("action", "")) != action_id
		or not bool(attack_click.get("selected_before", false))
		or String(attack_click.get("attack_target_battle_id", "")) != target_id
		or String(attack_click.get("selected_target_after_click", "")) != target_id
		or String(attack_click.get("selected_target_after_attack_battle_id", "")) != target_id
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) >= health_before_attack
		or attack_click.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_actionable_after_move")
		or bool(attack_click.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or not attack_context.is_empty()
		or not attack_result_context.is_empty()
		or bool(attack_click.get("selected_target_closing_on_target", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not attack_closing_context.is_empty()
		or not attack_result_closing.is_empty()
		or bool(attack_board.get("selected_target_preserved_setup", false))
		or bool(attack_board.get("selected_target_closing_on_target", false))
		or not attack_board_context.is_empty()
		or not attack_board_closing.is_empty()
		or not bool(attack_board.get("selected_target_direct_actionable", false))
		or String(attack_board.get("selected_target_footer_label", "")).find("Click:") != 0
		or attack_cell.is_empty()
		or not bool(attack_cell.get("legal_attack_target", false))
		or bool(attack_cell.get("preserved_setup_target", false))
		or bool(attack_cell.get("ordinary_closing_target", false))
		or "board click will" not in attack_action_guidance
		or "board click will" not in attack_target_context
		or "direct actionable after move" in attack_action_guidance
		or "direct actionable after move" in attack_target_context
		or "preserved setup target" in attack_action_guidance
		or "preserved setup target" in attack_target_context
		or "closing on target" in attack_action_guidance
		or "closing on target" in attack_target_context
	):
		push_error("Battle layout smoke: immediate board-click attack after direct actionable move left stale transition state at %s: attack=%s." % [viewport_size, attack_click])
		get_tree().quit(1)
		return false

	var attack_snapshot: Dictionary = shell.call("validation_snapshot")
	var attack_snapshot_context: Dictionary = attack_snapshot.get("selected_target_continuity_context", {}) if attack_snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_snapshot_closing: Dictionary = attack_snapshot.get("selected_target_closing_context", {}) if attack_snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_snapshot_board: Dictionary = attack_snapshot.get("battle_board", {}) if attack_snapshot.get("battle_board", {}) is Dictionary else {}
	var attack_snapshot_board_context: Dictionary = attack_snapshot_board.get("selected_target_continuity_context", {}) if attack_snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_snapshot_board_closing: Dictionary = attack_snapshot_board.get("selected_target_closing_context", {}) if attack_snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		bool(attack_snapshot.get("selected_target_preserved_setup", false))
		or not attack_snapshot_context.is_empty()
		or bool(attack_snapshot.get("selected_target_closing_on_target", false))
		or not attack_snapshot_closing.is_empty()
		or bool(attack_snapshot_board.get("selected_target_preserved_setup", false))
		or bool(attack_snapshot_board.get("selected_target_closing_on_target", false))
		or not attack_snapshot_board_context.is_empty()
		or not attack_snapshot_board_closing.is_empty()
		or not bool(attack_snapshot_board.get("selected_target_direct_actionable", false))
		or String(attack_snapshot_board.get("selected_target_footer_label", "")).find("Click:") != 0
		or "board click will" not in String(attack_snapshot.get("action_guidance", "")).to_lower()
		or "board click will" not in String(attack_snapshot.get("target_context", "")).to_lower()
		or "preserved setup target" in String(attack_snapshot.get("action_guidance", "")).to_lower()
		or "closing on target" in String(attack_snapshot.get("action_guidance", "")).to_lower()
	):
		push_error("Battle layout smoke: shell snapshot after immediate board-click attack did not stay on the normal attack path at %s: snapshot=%s." % [viewport_size, attack_snapshot])
		get_tree().quit(1)
		return false
	if not await _run_direct_actionable_after_move_button_attack_case(shell, session, viewport_size):
		return false
	if not await _run_direct_actionable_after_move_invalidation_case(shell, session, viewport_size, false, false):
		return false
	if not await _run_direct_actionable_after_move_invalidation_case(shell, session, viewport_size, true, false):
		return false
	if not await _run_direct_actionable_after_move_invalidation_case(shell, session, viewport_size, false, true):
		return false
	if not await _run_direct_actionable_after_move_invalidation_case(shell, session, viewport_size, true, true):
		return false
	if not await _run_direct_actionable_after_move_preferred_handoff_case(shell, session, viewport_size, false):
		return false
	if not await _run_direct_actionable_after_move_preferred_handoff_case(shell, session, viewport_size, true):
		return false
	return true

func _run_direct_actionable_after_move_invalidation_case(
	shell,
	session,
	viewport_size: Vector2,
	use_button: bool,
	handoff_direct_actionable: bool
) -> bool:
	if not shell.has_method("validation_perform_action") or not shell.has_method("validation_perform_board_hex_click") or not shell.has_method("validation_perform_board_stack_click"):
		push_error("Battle layout smoke: battle shell does not expose invalidating direct-action validation.")
		get_tree().quit(1)
		return false
	var setup := _stage_direct_actionable_after_move_state(session.battle, 1, true, handoff_direct_actionable)
	var route_label := "%s %s" % [
		"direct handoff" if handoff_direct_actionable else "blocked handoff",
		"button" if use_button else "board click",
	]
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage invalidating direct actionable %s attack at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var handoff_target_id := String(setup.get("handoff_target_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or first_closing.is_empty()
		or not bool(first_closing.get("ordinary_closing_target", false))
		or bool(first_click.get("selected_target_preserved_setup", false))
	):
		push_error("Battle layout smoke: invalidating %s setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [route_label, viewport_size, setup, first_click])
		get_tree().quit(1)
		return false

	var move_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var move_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
		or not move_context.is_empty()
		or not move_closing.is_empty()
	):
		push_error("Battle layout smoke: invalidating %s move did not reach clean direct actionable state at %s: setup=%s result=%s." % [route_label, viewport_size, setup, move_result])
		get_tree().quit(1)
		return false

	var attack_response: Dictionary = {}
	if use_button:
		attack_response = shell.call("validation_perform_action", action_id)
	else:
		attack_response = shell.call("validation_perform_board_stack_click", target_id)
	var action_result: Dictionary = attack_response.get("action_result", {}) if attack_response.get("action_result", {}) is Dictionary else {}
	var attack_result: Dictionary = attack_response.get("attack_result", {}) if attack_response.get("attack_result", {}) is Dictionary else action_result
	var response_context: Dictionary = attack_response.get("selected_target_continuity_context", {}) if attack_response.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var response_closing: Dictionary = attack_response.get("selected_target_closing_context", {}) if attack_response.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_board: Dictionary = attack_response.get("battle_board", {}) if attack_response.get("battle_board", {}) is Dictionary else {}
	var board_context: Dictionary = attack_board.get("selected_target_continuity_context", {}) if attack_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var board_closing: Dictionary = attack_board.get("selected_target_closing_context", {}) if attack_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var board_legality: Dictionary = attack_board.get("selected_target_legality", {}) if attack_board.get("selected_target_legality", {}) is Dictionary else {}
	var handoff_cell := _stack_cell_entry(attack_board.get("stack_cells", []), handoff_target_id)
	var dead_target_cell := _stack_cell_entry(attack_board.get("stack_cells", []), target_id)
	var action_guidance := String(attack_response.get("action_guidance", "")).to_lower()
	var target_context := String(attack_response.get("target_context", "")).to_lower()
	var response_direct_actionable := bool(attack_response.get("selected_target_direct_actionable", false))
	var response_direct_after_attack := bool(attack_response.get("selected_target_direct_actionable_after_attack", false))
	var response_direct_after_action := bool(attack_response.get("selected_target_direct_actionable_after_action", false))
	var result_direct_after_attack := bool(attack_result.get("selected_target_direct_actionable_after_attack", false))
	var board_direct_actionable := bool(attack_board.get("selected_target_direct_actionable", false))
	var board_footer_label := String(attack_board.get("selected_target_footer_label", ""))
	var board_click_action := String(attack_board.get("selected_target_board_click_action", ""))
	if (
		not bool(attack_response.get("ok", false))
		or String(attack_response.get("action", "")) != action_id
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) > 0
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
		or bool(attack_result.get("attack_target_alive_after_attack", true))
		or String(attack_response.get("selected_target_after_attack_battle_id", attack_result.get("selected_target_after_attack_battle_id", ""))) != handoff_target_id
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != handoff_target_id
		or not bool(attack_result.get("selected_target_valid_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_after_attack", false))
		or not bool(attack_response.get("selected_target_handoff_after_attack", false))
		or bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", false)) != handoff_direct_actionable
		or bool(attack_response.get("selected_target_handoff_direct_actionable_after_attack", false)) != handoff_direct_actionable
		or bool(attack_result.get("selected_target_handoff_blocked_after_attack", false)) != (not handoff_direct_actionable)
		or bool(attack_response.get("selected_target_handoff_blocked_after_attack", false)) != (not handoff_direct_actionable)
		or response_direct_after_attack != handoff_direct_actionable
		or result_direct_after_attack != handoff_direct_actionable
		or response_direct_actionable != handoff_direct_actionable
		or (attack_response.has("selected_target_direct_actionable_after_action") and response_direct_after_action != handoff_direct_actionable)
		or bool(attack_response.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or bool(attack_response.get("selected_target_closing_on_target", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not response_context.is_empty()
		or not result_context.is_empty()
		or not response_closing.is_empty()
		or not result_closing.is_empty()
		or attack_response.has("selected_target_actionable_after_move")
		or action_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
		or board_direct_actionable != handoff_direct_actionable
		or bool(attack_board.get("selected_target_preserved_setup", false))
		or bool(attack_board.get("selected_target_closing_on_target", false))
		or not board_context.is_empty()
		or not board_closing.is_empty()
		or bool(board_legality.get("blocked", false)) != (not handoff_direct_actionable)
		or bool(board_legality.get("attackable", false)) != handoff_direct_actionable
		or (handoff_direct_actionable and board_click_action not in ["strike", "shoot"])
		or (not handoff_direct_actionable and board_click_action != "")
		or (handoff_direct_actionable and board_footer_label.find("Click:") != 0)
		or (not handoff_direct_actionable and board_footer_label != "Target: blocked")
		or not bool(attack_board.get("has_selected_target_cell", false))
		or handoff_cell.is_empty()
		or not bool(handoff_cell.get("selected_target", false))
		or bool(handoff_cell.get("legal_attack_target", false)) != handoff_direct_actionable
		or bool(handoff_cell.get("preserved_setup_target", false))
		or bool(handoff_cell.get("ordinary_closing_target", false))
		or not dead_target_cell.is_empty()
		or (handoff_direct_actionable and "board click will" not in action_guidance)
		or (handoff_direct_actionable and "board click will" not in target_context)
		or (not handoff_direct_actionable and "board click will" in action_guidance)
		or (not handoff_direct_actionable and "board click will" in target_context)
		or "direct actionable after move" in action_guidance
		or "direct actionable after move" in target_context
		or "preserved setup target" in action_guidance
		or "preserved setup target" in target_context
		or "closing on target" in action_guidance
		or "closing on target" in target_context
	):
		push_error("Battle layout smoke: invalidating %s attack after direct actionable move did not clear transition state or hand off to the normal target at %s: attack=%s." % [route_label, viewport_size, attack_response])
		get_tree().quit(1)
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	var snapshot_board_context: Dictionary = snapshot_board.get("selected_target_continuity_context", {}) if snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_board_closing: Dictionary = snapshot_board.get("selected_target_closing_context", {}) if snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board_legality: Dictionary = snapshot_board.get("selected_target_legality", {}) if snapshot_board.get("selected_target_legality", {}) is Dictionary else {}
	var snapshot_handoff_cell := _stack_cell_entry(snapshot_board.get("stack_cells", []), handoff_target_id)
	var snapshot_action_guidance := String(snapshot.get("action_guidance", "")).to_lower()
	var snapshot_target_context := String(snapshot.get("target_context", "")).to_lower()
	var snapshot_footer_label := String(snapshot_board.get("selected_target_footer_label", ""))
	var snapshot_board_click_action := String(snapshot_board.get("selected_target_board_click_action", ""))
	if (
		bool(snapshot.get("selected_target_direct_actionable", false)) != handoff_direct_actionable
		or bool(snapshot.get("selected_target_preserved_setup", false))
		or bool(snapshot.get("selected_target_closing_on_target", false))
		or not snapshot_context.is_empty()
		or not snapshot_closing.is_empty()
		or bool(snapshot_board.get("selected_target_direct_actionable", false)) != handoff_direct_actionable
		or bool(snapshot_board.get("selected_target_preserved_setup", false))
		or bool(snapshot_board.get("selected_target_closing_on_target", false))
		or not snapshot_board_context.is_empty()
		or not snapshot_board_closing.is_empty()
		or bool(snapshot_board_legality.get("blocked", false)) != (not handoff_direct_actionable)
		or bool(snapshot_board_legality.get("attackable", false)) != handoff_direct_actionable
		or (handoff_direct_actionable and snapshot_board_click_action not in ["strike", "shoot"])
		or (not handoff_direct_actionable and snapshot_board_click_action != "")
		or (handoff_direct_actionable and snapshot_footer_label.find("Click:") != 0)
		or (not handoff_direct_actionable and snapshot_footer_label != "Target: blocked")
		or snapshot_handoff_cell.is_empty()
		or not bool(snapshot_handoff_cell.get("selected_target", false))
		or bool(snapshot_handoff_cell.get("legal_attack_target", false)) != handoff_direct_actionable
		or (handoff_direct_actionable and "board click will" not in snapshot_action_guidance)
		or (handoff_direct_actionable and "board click will" not in snapshot_target_context)
		or (not handoff_direct_actionable and "board click will" in snapshot_action_guidance)
		or (not handoff_direct_actionable and "board click will" in snapshot_target_context)
		or "preserved setup target" in snapshot_action_guidance
		or "closing on target" in snapshot_action_guidance
	):
		push_error("Battle layout smoke: snapshot after invalidating %s attack did not settle onto the normal target at %s: snapshot=%s." % [route_label, viewport_size, snapshot])
		get_tree().quit(1)
		return false
	return true

func _run_direct_actionable_after_move_preferred_handoff_case(shell, session, viewport_size: Vector2, use_button: bool) -> bool:
	if (
		not shell.has_method("validation_snapshot")
		or not shell.has_method("validation_perform_board_hex_click")
		or not shell.has_method("validation_perform_board_stack_click")
		or (use_button and not shell.has_method("validation_perform_action"))
	):
		push_error("Battle layout smoke: battle shell does not expose actionable-preferred handoff validation.")
		get_tree().quit(1)
		return false
	var route_label := "button" if use_button else "board click"
	var setup := _stage_direct_actionable_after_move_preferred_handoff_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage actionable-preferred %s post-attack handoff at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var blocked_handoff_id := String(setup.get("blocked_handoff_id", ""))
	var attackable_handoff_id := String(setup.get("attackable_handoff_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or first_closing.is_empty()
		or not bool(first_closing.get("ordinary_closing_target", false))
		or bool(first_click.get("selected_target_preserved_setup", false))
	):
		push_error("Battle layout smoke: actionable-preferred %s handoff setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [route_label, viewport_size, setup, first_click])
		get_tree().quit(1)
		return false

	var move_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var move_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
		or not move_context.is_empty()
		or not move_closing.is_empty()
	):
		push_error("Battle layout smoke: actionable-preferred %s handoff move did not reach clean direct actionable state at %s: setup=%s result=%s." % [route_label, viewport_size, setup, move_result])
		get_tree().quit(1)
		return false

	var blocked_candidate_before: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, blocked_handoff_id)
	var attackable_candidate_before: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, attackable_handoff_id)
	if (
		not bool(blocked_candidate_before.get("blocked", false))
		or bool(blocked_candidate_before.get("attackable", false))
		or String(attackable_candidate_before.get("action", "")) not in ["strike", "shoot"]
		or not bool(attackable_candidate_before.get("attackable", false))
	):
		push_error("Battle layout smoke: actionable-preferred %s handoff setup did not keep one blocked and one attackable survivor before the attack at %s: blocked=%s attackable=%s battle=%s." % [route_label, viewport_size, blocked_candidate_before, attackable_candidate_before, session.battle])
		get_tree().quit(1)
		return false

	if use_button:
		var button: Button = shell.get_node_or_null("%" + action_id.capitalize())
		if button == null or button.disabled:
			push_error("Battle layout smoke: actionable-preferred %s button was not enabled before the invalidating handoff at %s." % [action_id, viewport_size])
			get_tree().quit(1)
			return false
	var attack_response: Dictionary = shell.call("validation_perform_action", action_id) if use_button else shell.call("validation_perform_board_stack_click", target_id)
	var action_result: Dictionary = attack_response.get("action_result", {}) if attack_response.get("action_result", {}) is Dictionary else {}
	var attack_result: Dictionary = attack_response.get("attack_result", {}) if attack_response.get("attack_result", {}) is Dictionary else {}
	var response_selected_after := String(attack_response.get(
		"selected_target_after_click",
		attack_response.get("selected_target_after_action_battle_id", "")
	))
	var selected_after_state := BattleRules.get_selected_target(session.battle)
	var selected_after_state_id := String(selected_after_state.get("battle_id", ""))
	var response_context: Dictionary = attack_response.get("selected_target_continuity_context", {}) if attack_response.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var response_closing: Dictionary = attack_response.get("selected_target_closing_context", {}) if attack_response.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_board: Dictionary = attack_response.get("battle_board", {}) if attack_response.get("battle_board", {}) is Dictionary else {}
	var board_context: Dictionary = attack_board.get("selected_target_continuity_context", {}) if attack_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var board_closing: Dictionary = attack_board.get("selected_target_closing_context", {}) if attack_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var board_legality: Dictionary = attack_board.get("selected_target_legality", {}) if attack_board.get("selected_target_legality", {}) is Dictionary else {}
	var blocked_candidate_after: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, blocked_handoff_id)
	var attackable_cell := _stack_cell_entry(attack_board.get("stack_cells", []), attackable_handoff_id)
	var blocked_cell := _stack_cell_entry(attack_board.get("stack_cells", []), blocked_handoff_id)
	var dead_target_cell := _stack_cell_entry(attack_board.get("stack_cells", []), target_id)
	var action_guidance := String(attack_response.get("action_guidance", "")).to_lower()
	var target_context := String(attack_response.get("target_context", "")).to_lower()
	var board_footer_label := String(attack_board.get("selected_target_footer_label", ""))
	var board_click_action := String(attack_board.get("selected_target_board_click_action", ""))
	if (
		not bool(attack_response.get("ok", false))
		or String(attack_response.get("action", "")) != action_id
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) > 0
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
		or bool(attack_result.get("attack_target_alive_after_attack", true))
		or selected_after_state_id != attackable_handoff_id
		or response_selected_after != attackable_handoff_id
		or (use_button and String(attack_response.get("selected_target_after_action_battle_id", "")) != attackable_handoff_id)
		or String(attack_response.get("selected_target_after_attack_battle_id", "")) != attackable_handoff_id
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != attackable_handoff_id
		or not bool(attack_result.get("selected_target_valid_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_after_attack", false))
		or not bool(attack_response.get("selected_target_handoff_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", false))
		or not bool(attack_response.get("selected_target_handoff_direct_actionable_after_attack", false))
		or bool(attack_result.get("selected_target_handoff_blocked_after_attack", false))
		or bool(attack_response.get("selected_target_handoff_blocked_after_attack", false))
		or not bool(attack_result.get("selected_target_direct_actionable_after_attack", false))
		or not bool(attack_response.get("selected_target_direct_actionable", false))
		or bool(attack_response.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or bool(attack_response.get("selected_target_closing_on_target", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not response_context.is_empty()
		or not result_context.is_empty()
		or not response_closing.is_empty()
		or not result_closing.is_empty()
		or attack_response.has("selected_target_actionable_after_move")
		or action_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
		or String(attack_board.get("selected_target_battle_id", "")) != attackable_handoff_id
		or not bool(attack_board.get("selected_target_direct_actionable", false))
		or bool(attack_board.get("selected_target_preserved_setup", false))
		or bool(attack_board.get("selected_target_closing_on_target", false))
		or not board_context.is_empty()
		or not board_closing.is_empty()
		or not bool(board_legality.get("attackable", false))
		or bool(board_legality.get("blocked", false))
		or board_click_action not in ["strike", "shoot"]
		or board_footer_label.find("Click:") != 0
		or attackable_cell.is_empty()
		or not bool(attackable_cell.get("selected_target", false))
		or not bool(attackable_cell.get("legal_attack_target", false))
		or bool(attackable_cell.get("preserved_setup_target", false))
		or bool(attackable_cell.get("ordinary_closing_target", false))
		or blocked_cell.is_empty()
		or bool(blocked_cell.get("selected_target", false))
		or bool(blocked_cell.get("legal_attack_target", false))
		or not bool(blocked_candidate_after.get("blocked", false))
		or bool(blocked_candidate_after.get("attackable", false))
		or not dead_target_cell.is_empty()
		or "board click will" not in action_guidance
		or "board click will" not in target_context
		or "direct actionable after move" in action_guidance
		or "direct actionable after move" in target_context
		or "preserved setup target" in action_guidance
		or "preserved setup target" in target_context
		or "closing on target" in action_guidance
		or "closing on target" in target_context
	):
		push_error("Battle layout smoke: actionable-preferred %s invalidating attack did not land response/result/board state on the attackable survivor at %s: setup=%s attack=%s." % [route_label, viewport_size, setup, attack_response])
		get_tree().quit(1)
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	var snapshot_board_context: Dictionary = snapshot_board.get("selected_target_continuity_context", {}) if snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_board_closing: Dictionary = snapshot_board.get("selected_target_closing_context", {}) if snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board_legality: Dictionary = snapshot_board.get("selected_target_legality", {}) if snapshot_board.get("selected_target_legality", {}) is Dictionary else {}
	var snapshot_attackable_cell := _stack_cell_entry(snapshot_board.get("stack_cells", []), attackable_handoff_id)
	var snapshot_blocked_cell := _stack_cell_entry(snapshot_board.get("stack_cells", []), blocked_handoff_id)
	var snapshot_action_guidance := String(snapshot.get("action_guidance", "")).to_lower()
	var snapshot_target_context := String(snapshot.get("target_context", "")).to_lower()
	var snapshot_footer_label := String(snapshot_board.get("selected_target_footer_label", ""))
	var snapshot_board_click_action := String(snapshot_board.get("selected_target_board_click_action", ""))
	if (
		String(snapshot.get("selected_target_battle_id", "")) != attackable_handoff_id
		or String(snapshot_board.get("selected_target_battle_id", "")) != attackable_handoff_id
		or not bool(snapshot.get("selected_target_direct_actionable", false))
		or bool(snapshot.get("selected_target_preserved_setup", false))
		or bool(snapshot.get("selected_target_closing_on_target", false))
		or not snapshot_context.is_empty()
		or not snapshot_closing.is_empty()
		or not bool(snapshot_board.get("selected_target_direct_actionable", false))
		or bool(snapshot_board.get("selected_target_preserved_setup", false))
		or bool(snapshot_board.get("selected_target_closing_on_target", false))
		or not snapshot_board_context.is_empty()
		or not snapshot_board_closing.is_empty()
		or not bool(snapshot_board_legality.get("attackable", false))
		or bool(snapshot_board_legality.get("blocked", false))
		or snapshot_board_click_action not in ["strike", "shoot"]
		or snapshot_footer_label.find("Click:") != 0
		or snapshot_attackable_cell.is_empty()
		or not bool(snapshot_attackable_cell.get("selected_target", false))
		or not bool(snapshot_attackable_cell.get("legal_attack_target", false))
		or snapshot_blocked_cell.is_empty()
		or bool(snapshot_blocked_cell.get("selected_target", false))
		or bool(snapshot_blocked_cell.get("legal_attack_target", false))
		or "board click will" not in snapshot_action_guidance
		or "board click will" not in snapshot_target_context
		or "direct actionable after move" in snapshot_action_guidance
		or "direct actionable after move" in snapshot_target_context
		or "preserved setup target" in snapshot_action_guidance
		or "preserved setup target" in snapshot_target_context
		or "closing on target" in snapshot_action_guidance
		or "closing on target" in snapshot_target_context
	):
		push_error("Battle layout smoke: actionable-preferred %s shell snapshot did not land on the attackable survivor at %s: snapshot=%s." % [route_label, viewport_size, snapshot])
		get_tree().quit(1)
		return false
	return true

func _run_direct_actionable_after_move_empty_handoff_case(frame: Control, viewport_size: Vector2, use_button: bool) -> bool:
	var route_label := "button" if use_button else "board click"
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Battle layout smoke: could not find an encounter for final-kill %s empty-handoff proof at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Battle layout smoke: could not stage a battle for final-kill %s empty-handoff proof at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)
	var setup := _stage_direct_actionable_after_move_state(session.battle, 1, false, false)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage final-kill %s direct actionable empty-handoff state at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	session = SessionState.set_active_session(session)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if (
		not shell.has_method("validation_set_battle_resolution_routing_enabled")
		or not shell.has_method("validation_snapshot")
		or not shell.has_method("validation_perform_board_hex_click")
		or not shell.has_method("validation_perform_board_stack_click")
		or (use_button and not shell.has_method("validation_perform_action"))
	):
		push_error("Battle layout smoke: battle shell does not expose final-kill %s empty-handoff validation hooks." % route_label)
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_set_battle_resolution_routing_enabled", false)):
		push_error("Battle layout smoke: could not keep final-kill %s validation inside the battle shell at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or first_closing.is_empty()
		or not bool(first_closing.get("ordinary_closing_target", false))
		or bool(first_click.get("selected_target_preserved_setup", false))
	):
		push_error("Battle layout smoke: final-kill %s setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [route_label, viewport_size, setup, first_click])
		get_tree().quit(1)
		return false

	var move_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var move_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
		or not move_context.is_empty()
		or not move_closing.is_empty()
	):
		push_error("Battle layout smoke: final-kill %s move did not reach clean direct actionable state at %s: setup=%s result=%s." % [route_label, viewport_size, setup, move_result])
		get_tree().quit(1)
		return false

	if use_button:
		var button: Button = shell.get_node_or_null("%" + action_id.capitalize())
		if button == null or button.disabled:
			push_error("Battle layout smoke: final-kill %s button was not enabled before empty-handoff proof at %s." % [action_id, viewport_size])
			get_tree().quit(1)
			return false
	var attack_response: Dictionary = shell.call("validation_perform_action", action_id) if use_button else shell.call("validation_perform_board_stack_click", target_id)
	var action_result: Dictionary = attack_response.get("action_result", {}) if attack_response.get("action_result", {}) is Dictionary else {}
	var attack_result: Dictionary = attack_response.get("attack_result", {}) if attack_response.get("attack_result", {}) is Dictionary else action_result
	var result_legality: Dictionary = attack_result.get("selected_target_after_attack_legality", {}) if attack_result.get("selected_target_after_attack_legality", {}) is Dictionary else {}
	var result_click_intent: Dictionary = attack_result.get("selected_target_after_attack_board_click_intent", {}) if attack_result.get("selected_target_after_attack_board_click_intent", {}) is Dictionary else {}
	var response_context: Dictionary = attack_response.get("selected_target_continuity_context", {}) if attack_response.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var response_closing: Dictionary = attack_response.get("selected_target_closing_context", {}) if attack_response.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var response_board: Dictionary = attack_response.get("battle_board", {}) if attack_response.get("battle_board", {}) is Dictionary else {}
	var response_selected_after := String(attack_response.get(
		"selected_target_after_click",
		attack_response.get("selected_target_after_action_battle_id", "")
	))
	var response_action_guidance := String(attack_response.get("action_guidance", "")).to_lower()
	var response_target_context := String(attack_response.get("target_context", "")).to_lower()
	var attack_message := String(attack_response.get("message", "")).to_lower()
	var response_failures := []
	var response_checks := {
		"response not ok": not bool(attack_response.get("ok", false)),
		"wrong action": String(attack_response.get("action", "")) != action_id,
		"state not victory": String(attack_response.get("state", "")) != "victory",
		"not routed": not bool(attack_response.get("routed", false)),
		"battle still active": not session.battle.is_empty(),
		"attack action mismatch": String(attack_result.get("attack_action", "")) != action_id,
		"attack target mismatch": String(attack_result.get("attack_target_battle_id", "")) != target_id,
		"target not invalidated": not bool(attack_result.get("attack_target_invalidated_after_attack", false)),
		"target still selected": bool(attack_result.get("attack_target_still_selected_after_attack", true)),
		"target still alive": bool(attack_result.get("attack_target_alive_after_attack", true)),
		"active stack residue": String(attack_result.get("active_stack_after_attack_battle_id", "")) != "",
		"response selected target residue": response_selected_after != "",
		"response selected after attack residue": String(attack_response.get("selected_target_after_attack_battle_id", attack_result.get("selected_target_after_attack_battle_id", ""))) != "",
		"result selected after attack residue": String(attack_result.get("selected_target_after_attack_battle_id", "")) != "",
		"result target still valid": bool(attack_result.get("selected_target_valid_after_attack", true)),
		"response handoff residue": bool(attack_response.get("selected_target_handoff_after_attack", false)),
		"result handoff residue": bool(attack_result.get("selected_target_handoff_after_attack", true)),
		"response direct handoff residue": bool(attack_response.get("selected_target_handoff_direct_actionable_after_attack", false)),
		"result direct handoff residue": bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", true)),
		"response blocked handoff residue": bool(attack_response.get("selected_target_handoff_blocked_after_attack", false)),
		"result blocked handoff residue": bool(attack_result.get("selected_target_handoff_blocked_after_attack", true)),
		"response direct actionable residue": bool(attack_response.get("selected_target_direct_actionable", false)),
		"response direct actionable after attack residue": bool(attack_response.get("selected_target_direct_actionable_after_attack", false)),
		"result direct actionable after attack residue": bool(attack_result.get("selected_target_direct_actionable_after_attack", true)),
		"response direct actionable after action residue": attack_response.has("selected_target_direct_actionable_after_action") and bool(attack_response.get("selected_target_direct_actionable_after_action", true)),
		"response preserved setup residue": bool(attack_response.get("selected_target_preserved_setup", false)),
		"result preserved setup residue": bool(attack_result.get("selected_target_preserved_setup", true)),
		"response closing residue": bool(attack_response.get("selected_target_closing_on_target", false)),
		"result closing residue": bool(attack_result.get("selected_target_closing_on_target", true)),
		"response continuity context residue": not response_context.is_empty(),
		"result continuity context residue": not result_context.is_empty(),
		"response closing context residue": not response_closing.is_empty(),
		"result closing context residue": not result_closing.is_empty(),
		"result attackable legality residue": bool(result_legality.get("attackable", false)),
		"result blocked legality residue": bool(result_legality.get("blocked", false)),
		"result board action residue": String(result_click_intent.get("action", "")) != "",
		"response board residue": not response_board.is_empty(),
		"response after-move field residue": attack_response.has("selected_target_actionable_after_move"),
		"action result after-move field residue": action_result.has("selected_target_actionable_after_move"),
		"attack result after-move field residue": attack_result.has("selected_target_actionable_after_move"),
		"attack result after-move id residue": attack_result.has("selected_target_after_move_battle_id"),
		"response action board-click wording residue": "board click will" in response_action_guidance,
		"response target board-click wording residue": "board click will" in response_target_context,
		"response action direct-actionable wording residue": "direct actionable after move" in response_action_guidance,
		"response target direct-actionable wording residue": "direct actionable after move" in response_target_context,
		"message direct-actionable wording residue": "direct actionable after move" in attack_message,
		"response action preserved wording residue": "preserved setup target" in response_action_guidance,
		"response target preserved wording residue": "preserved setup target" in response_target_context,
		"message preserved wording residue": "preserved setup target" in attack_message,
		"response action closing wording residue": "closing on target" in response_action_guidance,
		"response target closing wording residue": "closing on target" in response_target_context,
		"message closing wording residue": "closing on target" in attack_message,
	}
	for check_name in response_checks:
		if bool(response_checks[check_name]):
			response_failures.append(String(check_name))
	if not response_failures.is_empty():
		push_error("Battle layout smoke: final-kill %s empty-handoff response/result did not clear selected-target residue at %s: failures=%s attack=%s result=%s." % [route_label, viewport_size, response_failures, attack_response, attack_result])
		get_tree().quit(1)
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	var snapshot_board_context: Dictionary = snapshot_board.get("selected_target_continuity_context", {}) if snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_board_closing: Dictionary = snapshot_board.get("selected_target_closing_context", {}) if snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board_legality: Dictionary = snapshot_board.get("selected_target_legality", {}) if snapshot_board.get("selected_target_legality", {}) is Dictionary else {}
	var snapshot_stack_cells: Array = snapshot_board.get("stack_cells", []) if snapshot_board.get("stack_cells", []) is Array else []
	var snapshot_action_guidance := String(snapshot.get("action_guidance", "")).to_lower()
	var snapshot_target_context := String(snapshot.get("target_context", "")).to_lower()
	var snapshot_board_action := String(snapshot_board.get("selected_target_board_click_action", ""))
	if (
		String(snapshot.get("selected_target_battle_id", "")) != ""
		or String(snapshot.get("target_stack", "")) != ""
		or String(snapshot.get("selected_target_board_click_action", "")) != ""
		or bool(snapshot.get("selected_target_direct_actionable", false))
		or bool(snapshot.get("selected_target_preserved_setup", false))
		or bool(snapshot.get("selected_target_closing_on_target", false))
		or not snapshot_context.is_empty()
		or not snapshot_closing.is_empty()
		or int(snapshot.get("player_stack_count", -1)) != 0
		or int(snapshot.get("enemy_stack_count", -1)) != 0
		or int(snapshot_board.get("player_stack_count", -1)) != 0
		or int(snapshot_board.get("enemy_stack_count", -1)) != 0
		or not snapshot_stack_cells.is_empty()
		or bool(snapshot_board.get("has_selected_target_cell", false))
		or bool(snapshot_board.get("selected_target_direct_actionable", false))
		or bool(snapshot_board.get("selected_target_preserved_setup", false))
		or bool(snapshot_board.get("selected_target_closing_on_target", false))
		or not snapshot_board_context.is_empty()
		or not snapshot_board_closing.is_empty()
		or bool(snapshot_board_legality.get("attackable", false))
		or bool(snapshot_board_legality.get("blocked", false))
		or snapshot_board_action != ""
		or String(snapshot_board.get("selected_target_footer_label", "")) != ""
		or "board click will" in snapshot_action_guidance
		or "board click will" in snapshot_target_context
		or "direct actionable after move" in snapshot_action_guidance
		or "direct actionable after move" in snapshot_target_context
		or "preserved setup target" in snapshot_action_guidance
		or "preserved setup target" in snapshot_target_context
		or "closing on target" in snapshot_action_guidance
		or "closing on target" in snapshot_target_context
	):
		push_error("Battle layout smoke: final-kill %s empty-handoff snapshot did not settle onto empty battle state at %s: snapshot=%s." % [route_label, viewport_size, snapshot])
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _run_direct_actionable_after_move_routed_resolution_case(
	viewport_size: Vector2,
	use_button: bool,
	complete_scenario_after_kill: bool = false
) -> bool:
	var route_label := "button" if use_button else "board click"
	if complete_scenario_after_kill:
		route_label = "%s outcome" % route_label
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Battle layout smoke: could not find an encounter for routed final-kill %s proof at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	if complete_scenario_after_kill:
		_stage_river_pass_final_kill_outcome_prereqs(session)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Battle layout smoke: could not stage a battle for routed final-kill %s proof at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)
	var setup := _stage_direct_actionable_after_move_state(session.battle, 1, false, false)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage routed final-kill %s direct actionable state at %s." % [route_label, viewport_size])
		get_tree().quit(1)
		return false
	session = SessionState.set_active_session(session)

	var previous_current = get_tree().current_scene
	var shell = load(BATTLE_SCENE_PATH).instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene = shell
	await get_tree().process_frame
	await get_tree().process_frame
	if (
		not shell.has_method("validation_snapshot")
		or not shell.has_method("validation_perform_board_hex_click")
		or not shell.has_method("validation_perform_board_stack_click")
		or (use_button and not shell.has_method("validation_perform_action"))
	):
		push_error("Battle layout smoke: battle shell does not expose routed final-kill %s validation hooks." % route_label)
		get_tree().quit(1)
		return false

	var target_id := String(setup.get("target_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or first_closing.is_empty()
		or not bool(first_closing.get("ordinary_closing_target", false))
		or bool(first_click.get("selected_target_preserved_setup", false))
	):
		push_error("Battle layout smoke: routed final-kill %s setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [route_label, viewport_size, setup, first_click])
		get_tree().quit(1)
		return false

	var move_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var move_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
		or not move_context.is_empty()
		or not move_closing.is_empty()
	):
		push_error("Battle layout smoke: routed final-kill %s move did not reach clean direct actionable state at %s: setup=%s result=%s." % [route_label, viewport_size, setup, move_result])
		get_tree().quit(1)
		return false

	if use_button:
		var button: Button = shell.get_node_or_null("%" + action_id.capitalize())
		if button == null or button.disabled:
			push_error("Battle layout smoke: routed final-kill %s button was not enabled before resolution proof at %s." % [action_id, viewport_size])
			get_tree().quit(1)
			return false

	var attack_response: Dictionary = shell.call("validation_perform_action", action_id) if use_button else shell.call("validation_perform_board_stack_click", target_id)
	var immediate_snapshot := {}
	if is_instance_valid(shell) and shell.has_method("validation_snapshot"):
		immediate_snapshot = shell.call("validation_snapshot")
	var expected_scene_path := SCENARIO_OUTCOME_SCENE_PATH if session.scenario_status != "in_progress" else OVERWORLD_SCENE_PATH
	var response_failures := _final_kill_routed_response_failures(attack_response, session, action_id, target_id)
	if not response_failures.is_empty():
		push_error("Battle layout smoke: routed final-kill %s response exposed stale selected-target guidance at %s: failures=%s response=%s." % [route_label, viewport_size, response_failures, attack_response])
		get_tree().quit(1)
		return false
	var immediate_failures := _final_kill_empty_shell_snapshot_failures(immediate_snapshot)
	if not immediate_failures.is_empty():
		push_error("Battle layout smoke: routed final-kill %s immediate shell snapshot exposed stale battle guidance at %s: failures=%s snapshot=%s." % [route_label, viewport_size, immediate_failures, immediate_snapshot])
		get_tree().quit(1)
		return false

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var routed_scene = get_tree().current_scene
	var routed_scene_path := String(routed_scene.scene_file_path) if routed_scene != null else ""
	var routed_snapshot: Dictionary = routed_scene.call("validation_snapshot") if routed_scene != null and routed_scene.has_method("validation_snapshot") else {}
	var routed_failures := []
	if routed_scene_path != expected_scene_path:
		routed_failures.append("wrong routed scene")
	if not session.battle.is_empty():
		routed_failures.append("session battle residue")
	if expected_scene_path == OVERWORLD_SCENE_PATH:
		if session.game_state != "overworld":
			routed_failures.append("session game_state not overworld")
		if String(routed_snapshot.get("scene_path", "")) != OVERWORLD_SCENE_PATH:
			routed_failures.append("overworld snapshot path mismatch")
		if String(routed_snapshot.get("scenario_status", "")) != "in_progress":
			routed_failures.append("overworld snapshot status mismatch")
		if String(routed_snapshot.get("game_state", "")) != "overworld":
			routed_failures.append("overworld snapshot game_state mismatch")
	else:
		if session.scenario_status == "in_progress":
			routed_failures.append("outcome route without resolved scenario")
		if session.game_state != "outcome":
			routed_failures.append("session game_state not outcome")
		if String(routed_snapshot.get("scene_path", "")) != SCENARIO_OUTCOME_SCENE_PATH:
			routed_failures.append("outcome snapshot path mismatch")
		if String(routed_snapshot.get("scenario_status", "")) == "in_progress":
			routed_failures.append("outcome snapshot status still in progress")
		if String(routed_snapshot.get("game_state", "")) != "outcome":
			routed_failures.append("outcome snapshot game_state mismatch")
		if String(routed_snapshot.get("resume_target", "")) != "outcome":
			routed_failures.append("outcome snapshot resume target mismatch")
	for stale_key in ["selected_target_battle_id", "target_stack", "selected_target_board_click_action", "action_guidance", "target_context", "battle_board"]:
		if routed_snapshot.has(stale_key):
			routed_failures.append("routed snapshot battle key residue: %s" % stale_key)
	routed_failures.append_array(_final_kill_routed_save_resume_failures(routed_scene, routed_snapshot, session, expected_scene_path))
	if not routed_failures.is_empty():
		push_error("Battle layout smoke: routed final-kill %s did not land on the truthful routed state at %s: failures=%s scene=%s snapshot=%s response=%s." % [route_label, viewport_size, routed_failures, routed_scene_path, routed_snapshot, attack_response])
		get_tree().quit(1)
		return false
	var expected_resume_target := "outcome" if expected_scene_path == SCENARIO_OUTCOME_SCENE_PATH else "overworld"
	var expected_game_state := "outcome" if expected_resume_target == "outcome" else "overworld"
	var menu_failures := await _final_kill_menu_save_browser_failures(
		expected_resume_target,
		expected_game_state
	)
	if not menu_failures.is_empty():
		push_error("Battle layout smoke: routed final-kill %s menu save-browser surface was not truthful at %s: failures=%s." % [route_label, viewport_size, menu_failures])
		get_tree().quit(1)
		return false
	if expected_scene_path == SCENARIO_OUTCOME_SCENE_PATH:
		var outcome_action_failures := await _final_kill_outcome_action_execution_failures(route_label)
		if not outcome_action_failures.is_empty():
			push_error("Battle layout smoke: routed final-kill %s outcome action execution was not truthful at %s: failures=%s." % [route_label, viewport_size, outcome_action_failures])
			get_tree().quit(1)
			return false

	await _restore_layout_current_scene(previous_current)
	return true

func _stage_river_pass_final_kill_outcome_prereqs(session) -> void:
	_set_town_owner_for_test(session, "duskfen_bastion", "player")
	session.flags["mire_cleared"] = true
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	for placement_id in ["river_pass_reed_totemists"]:
		if placement_id not in resolved:
			resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved

func _set_town_owner_for_test(session, placement_id: String, owner: String) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["owner"] = owner
		towns[index] = town
		break
	session.overworld["towns"] = towns

func _final_kill_routed_save_resume_failures(
	routed_scene,
	routed_snapshot: Dictionary,
	session,
	expected_scene_path: String
) -> Array:
	var failures := []
	var expected_resume_target := "outcome" if expected_scene_path == SCENARIO_OUTCOME_SCENE_PATH else "overworld"
	var expected_game_state := "outcome" if expected_resume_target == "outcome" else "overworld"
	if SaveService.resume_target_for_session(session) != expected_resume_target:
		failures.append("session resume target mismatch")
	if String(session.game_state) != expected_game_state:
		failures.append("session save-facing game_state mismatch")

	var active_surface: Dictionary = AppRouter.active_save_surface()
	failures.append_array(_final_kill_save_surface_failures(active_surface, expected_resume_target, "active surface"))
	failures.append_array(_final_kill_save_summary_failures(SaveService.inspect_autosave(), expected_resume_target, expected_game_state, "autosave"))
	failures.append_array(_final_kill_save_summary_failures(SaveService.latest_loadable_summary(), expected_resume_target, expected_game_state, "latest"))
	var snapshot_latest: Dictionary = routed_snapshot.get("latest_save_summary", {}) if routed_snapshot.get("latest_save_summary", {}) is Dictionary else {}
	failures.append_array(_final_kill_save_summary_failures(snapshot_latest, expected_resume_target, expected_game_state, "snapshot latest"))
	if routed_snapshot.has("save_surface"):
		var snapshot_surface: Dictionary = routed_snapshot.get("save_surface", {}) if routed_snapshot.get("save_surface", {}) is Dictionary else {}
		failures.append_array(_final_kill_save_surface_failures(snapshot_surface, expected_resume_target, "snapshot surface"))

	if routed_scene == null or not routed_scene.has_method("validation_select_save_slot") or not routed_scene.has_method("validation_save_to_selected_slot"):
		failures.append("routed scene missing save validation hooks")
		return failures
	var save_slot := 2 if expected_resume_target == "outcome" else 1
	if not bool(routed_scene.call("validation_select_save_slot", save_slot)):
		failures.append("manual save slot selection failed")
		return failures
	var manual_save: Dictionary = routed_scene.call("validation_save_to_selected_slot")
	if not bool(manual_save.get("ok", false)):
		failures.append("manual save response not loadable")
	var manual_summary: Dictionary = manual_save.get("summary", {}) if manual_save.get("summary", {}) is Dictionary else {}
	failures.append_array(_final_kill_save_summary_failures(manual_summary, expected_resume_target, expected_game_state, "manual"))
	var restored = SaveService.restore_session_from_summary(manual_summary)
	if restored == null:
		failures.append("manual summary did not restore")
	else:
		if SaveService.resume_target_for_session(restored) != expected_resume_target:
			failures.append("restored resume target mismatch")
		if String(restored.game_state) != expected_game_state:
			failures.append("restored game_state mismatch")
		if not restored.battle.is_empty():
			failures.append("restored battle payload residue")
		if expected_resume_target == "outcome" and restored.scenario_status == "in_progress":
			failures.append("restored outcome status still in progress")
		if expected_resume_target == "overworld" and restored.scenario_status != "in_progress":
			failures.append("restored overworld status resolved unexpectedly")
	return failures

func _final_kill_menu_save_browser_failures(
	expected_resume_target: String,
	expected_game_state: String
) -> Array:
	var failures := []
	AppRouter.go_to_main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var menu_scene = get_tree().current_scene
	var menu_scene_path := String(menu_scene.scene_file_path) if menu_scene != null else ""
	if menu_scene_path != MAIN_MENU_SCENE_PATH:
		return ["main menu scene mismatch: %s" % menu_scene_path]
	if (
		not menu_scene.has_method("validation_open_saves_stage")
		or not menu_scene.has_method("validation_snapshot")
		or not menu_scene.has_method("validation_resume_latest")
		or not menu_scene.has_method("validation_resume_selected_save")
	):
		return ["main menu missing save-browser validation hooks"]

	menu_scene.call("validation_open_saves_stage")
	await get_tree().process_frame
	var menu_snapshot: Dictionary = menu_scene.call("validation_snapshot")
	if menu_snapshot.is_empty():
		return ["main menu validation snapshot unavailable"]

	var latest_summary: Dictionary = menu_snapshot.get("latest_save_summary", {}) if menu_snapshot.get("latest_save_summary", {}) is Dictionary else {}
	var selected_summary: Dictionary = menu_snapshot.get("selected_save_summary", {}) if menu_snapshot.get("selected_save_summary", {}) is Dictionary else {}
	failures.append_array(_final_kill_save_summary_failures(latest_summary, expected_resume_target, expected_game_state, "menu latest"))
	failures.append_array(_final_kill_save_summary_failures(selected_summary, expected_resume_target, expected_game_state, "menu selected save"))
	if not bool(menu_snapshot.get("continue_enabled", false)):
		failures.append("menu continue disabled")
	if not bool(menu_snapshot.get("load_selected_enabled", false)):
		failures.append("menu selected save load disabled")

	var latest_key := "%s:%s" % [
		String(latest_summary.get("slot_type", "")),
		String(latest_summary.get("slot_id", "")),
	]
	if latest_key == ":":
		latest_key = ""
	if String(menu_snapshot.get("selected_save_key", "")) != latest_key:
		failures.append("menu save browser did not select latest save")

	var expected_resume_label := "outcome review" if expected_resume_target == "outcome" else "overworld resume"
	var expected_load_label := "Review Outcome" if expected_resume_target == "outcome" else "Resume Expedition"
	var continue_text := String(menu_snapshot.get("continue_text", ""))
	var continue_tooltip := String(menu_snapshot.get("continue_tooltip", ""))
	var load_selected_text := String(menu_snapshot.get("load_selected_text", ""))
	var save_details := String(menu_snapshot.get("save_details_full", menu_snapshot.get("save_details", "")))
	var save_pulse := String(menu_snapshot.get("save_pulse_full", menu_snapshot.get("save_pulse", "")))
	var latest_item_label := ""
	var item_labels: Array = menu_snapshot.get("save_browser_items", []) if menu_snapshot.get("save_browser_items", []) is Array else []
	for label_value in item_labels:
		var item_label := String(label_value)
		if "Latest" in item_label:
			latest_item_label = item_label
			break
	var latest_surface_text := " ".join([
		continue_text,
		continue_tooltip,
		save_pulse,
		latest_item_label,
	])
	var save_browser_text := " ".join([
		load_selected_text,
		String(menu_snapshot.get("load_selected_tooltip", "")),
		save_details,
	])
	if expected_resume_label not in latest_surface_text.to_lower():
		failures.append("menu latest surface did not show %s" % expected_resume_label)
	if expected_resume_label not in save_browser_text.to_lower():
		failures.append("menu save browser did not show %s" % expected_resume_label)
	if load_selected_text != expected_load_label:
		failures.append("menu load action label mismatch")
	if expected_resume_target == "outcome":
		if "outcome" not in continue_text.to_lower():
			failures.append("menu continue action did not advertise outcome review")
		if "review" not in continue_tooltip.to_lower():
			failures.append("menu continue tooltip did not advertise outcome review")
	else:
		if "expedition" not in continue_tooltip.to_lower():
			failures.append("menu continue tooltip did not advertise expedition resume")

	var text_fields := {
		"menu summary": String(menu_snapshot.get("summary", "")),
		"menu continue text": continue_text,
		"menu continue tooltip": continue_tooltip,
		"menu save pulse": save_pulse,
		"menu latest save item": latest_item_label,
		"menu selected save details": save_details,
		"menu load text": load_selected_text,
		"menu load tooltip": String(menu_snapshot.get("load_selected_tooltip", "")),
		"menu latest summary text": String(latest_summary.get("summary", "")),
		"menu latest summary detail": String(latest_summary.get("detail", "")),
		"menu selected summary text": String(selected_summary.get("summary", "")),
		"menu selected summary detail": String(selected_summary.get("detail", "")),
	}
	for field_name in text_fields.keys():
		var residue := _final_kill_menu_text_residue(String(text_fields[field_name]))
		if residue != "":
			failures.append("%s retains %s" % [field_name, residue])
	var continue_failures := await _final_kill_menu_action_execution_failures(
		menu_scene,
		"continue latest",
		expected_resume_target,
		expected_game_state
	)
	failures.append_array(continue_failures)
	if not continue_failures.is_empty():
		return failures

	AppRouter.go_to_main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	menu_scene = get_tree().current_scene
	menu_scene_path = String(menu_scene.scene_file_path) if menu_scene != null else ""
	if menu_scene_path != MAIN_MENU_SCENE_PATH:
		failures.append("main menu scene mismatch before selected load action: %s" % menu_scene_path)
		return failures
	if (
		not menu_scene.has_method("validation_open_saves_stage")
		or not menu_scene.has_method("validation_snapshot")
		or not menu_scene.has_method("validation_resume_selected_save")
	):
		failures.append("main menu missing selected-save execution validation hooks")
		return failures
	menu_scene.call("validation_open_saves_stage")
	await get_tree().process_frame
	var selected_action_snapshot: Dictionary = menu_scene.call("validation_snapshot")
	if selected_action_snapshot.is_empty():
		failures.append("main menu selected-save action snapshot unavailable")
		return failures
	if not bool(selected_action_snapshot.get("load_selected_enabled", false)):
		failures.append("menu selected save load disabled before action execution")
	var selected_action_summary: Dictionary = selected_action_snapshot.get("selected_save_summary", {}) if selected_action_snapshot.get("selected_save_summary", {}) is Dictionary else {}
	failures.append_array(_final_kill_save_summary_failures(selected_action_summary, expected_resume_target, expected_game_state, "menu selected save before action"))
	var load_failures := await _final_kill_menu_action_execution_failures(
		menu_scene,
		"selected save load",
		expected_resume_target,
		expected_game_state
	)
	failures.append_array(load_failures)
	return failures

func _final_kill_menu_action_execution_failures(
	menu_scene,
	action_label: String,
	expected_resume_target: String,
	expected_game_state: String
) -> Array:
	var failures := []
	if menu_scene == null:
		return ["%s action menu scene unavailable" % action_label]
	var action_result := {}
	if action_label == "continue latest":
		if not menu_scene.has_method("validation_resume_latest"):
			return ["main menu missing Continue Latest execution hook"]
		action_result = menu_scene.call("validation_resume_latest")
	else:
		if not menu_scene.has_method("validation_resume_selected_save"):
			return ["main menu missing selected-save execution hook"]
		action_result = menu_scene.call("validation_resume_selected_save")
	if not bool(action_result.get("ok", false)):
		failures.append("%s action did not restore expected session: %s" % [action_label, action_result])
	if String(action_result.get("resume_target", "")) != expected_resume_target:
		failures.append("%s action expected resume target mismatch" % action_label)
	if String(action_result.get("game_state", "")) != expected_game_state:
		failures.append("%s action expected game_state mismatch" % action_label)
	if String(action_result.get("active_resume_target", "")) != expected_resume_target:
		failures.append("%s action active resume target mismatch" % action_label)
	if String(action_result.get("active_game_state", "")) != expected_game_state:
		failures.append("%s action active game_state mismatch" % action_label)
	if not bool(action_result.get("active_battle_empty", false)):
		failures.append("%s action left active battle payload residue" % action_label)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var expected_scene_path := SCENARIO_OUTCOME_SCENE_PATH if expected_resume_target == "outcome" else OVERWORLD_SCENE_PATH
	var routed_scene = get_tree().current_scene
	var routed_scene_path := String(routed_scene.scene_file_path) if routed_scene != null else ""
	if routed_scene_path != expected_scene_path:
		failures.append("%s action routed to wrong scene: %s" % [action_label, routed_scene_path])
	var session := SessionState.ensure_active_session()
	if SaveService.resume_target_for_session(session) != expected_resume_target:
		failures.append("%s action session resume target mismatch after route" % action_label)
	if String(session.game_state) != expected_game_state:
		failures.append("%s action session game_state mismatch after route" % action_label)
	if not session.battle.is_empty():
		failures.append("%s action session battle payload residue after route" % action_label)
	if expected_resume_target == "outcome" and session.scenario_status == "in_progress":
		failures.append("%s action routed outcome with in-progress scenario" % action_label)
	if expected_resume_target == "overworld" and session.scenario_status != "in_progress":
		failures.append("%s action routed overworld with resolved scenario" % action_label)

	var routed_snapshot: Dictionary = routed_scene.call("validation_snapshot") if routed_scene != null and routed_scene.has_method("validation_snapshot") else {}
	if routed_snapshot.is_empty():
		failures.append("%s action routed snapshot unavailable" % action_label)
	else:
		if String(routed_snapshot.get("scene_path", "")) != expected_scene_path:
			failures.append("%s action routed snapshot path mismatch" % action_label)
		if String(routed_snapshot.get("game_state", "")) != expected_game_state:
			failures.append("%s action routed snapshot game_state mismatch" % action_label)
		if expected_resume_target == "outcome":
			if String(routed_snapshot.get("scenario_status", "")) == "in_progress":
				failures.append("%s action outcome snapshot status still in progress" % action_label)
			if String(routed_snapshot.get("resume_target", "")) != "outcome":
				failures.append("%s action outcome snapshot resume target mismatch" % action_label)
		else:
			if String(routed_snapshot.get("scenario_status", "")) != "in_progress":
				failures.append("%s action overworld snapshot status mismatch" % action_label)
		for stale_key in ["selected_target_battle_id", "target_stack", "selected_target_board_click_action", "action_guidance", "target_context", "battle_board"]:
			if routed_snapshot.has(stale_key):
				failures.append("%s action routed snapshot battle key residue: %s" % [action_label, stale_key])
	failures.append_array(_final_kill_save_summary_failures(SaveService.latest_loadable_summary(), expected_resume_target, expected_game_state, "%s latest after route" % action_label))
	return failures

func _final_kill_outcome_action_execution_failures(route_label: String) -> Array:
	var failures := []
	var outcome_scene = get_tree().current_scene
	var outcome_scene_path := String(outcome_scene.scene_file_path) if outcome_scene != null else ""
	if outcome_scene_path != SCENARIO_OUTCOME_SCENE_PATH:
		return ["%s outcome action proof did not start on outcome scene: %s" % [route_label, outcome_scene_path]]
	if outcome_scene == null or not outcome_scene.has_method("validation_snapshot") or not outcome_scene.has_method("validation_perform_action"):
		return ["%s outcome scene missing action validation hooks" % route_label]

	var outcome_snapshot: Dictionary = outcome_scene.call("validation_snapshot")
	var source_scenario_id := String(outcome_snapshot.get("scenario_id", ""))
	var source_status := String(outcome_snapshot.get("scenario_status", ""))
	var action_ids: Array = outcome_snapshot.get("action_ids", []) if outcome_snapshot.get("action_ids", []) is Array else []
	var retry_action_id := "skirmish_start:%s" % source_scenario_id
	if source_scenario_id == "":
		failures.append("%s outcome snapshot missing scenario id" % route_label)
	if source_status == "in_progress":
		failures.append("%s outcome snapshot status still in progress" % route_label)
	if "return_to_menu" not in action_ids:
		failures.append("%s outcome action row missing return_to_menu" % route_label)
	if retry_action_id not in action_ids:
		failures.append("%s outcome action row missing retry action %s" % [route_label, retry_action_id])
	if not failures.is_empty():
		return failures

	var return_result: Dictionary = outcome_scene.call("validation_perform_action", "return_to_menu")
	failures.append_array(_final_kill_outcome_action_result_failures(
		return_result,
		"return_to_menu",
		"main_menu",
		"outcome",
		"outcome",
		source_scenario_id,
		source_status,
		"%s return-to-menu" % route_label
	))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var menu_scene = get_tree().current_scene
	var menu_scene_path := String(menu_scene.scene_file_path) if menu_scene != null else ""
	if menu_scene_path != MAIN_MENU_SCENE_PATH:
		failures.append("%s return-to-menu routed to wrong scene: %s" % [route_label, menu_scene_path])
	else:
		var menu_snapshot: Dictionary = menu_scene.call("validation_snapshot") if menu_scene.has_method("validation_snapshot") else {}
		var menu_latest: Dictionary = menu_snapshot.get("latest_save_summary", {}) if menu_snapshot.get("latest_save_summary", {}) is Dictionary else SaveService.inspect_autosave()
		failures.append_array(_final_kill_save_summary_failures(menu_latest, "outcome", "outcome", "%s menu latest after outcome return" % route_label))
		if not menu_scene.has_method("validation_resume_latest"):
			failures.append("%s main menu missing Continue Latest validation after outcome return" % route_label)
		else:
			var continue_result: Dictionary = menu_scene.call("validation_resume_latest")
			if not bool(continue_result.get("ok", false)):
				failures.append("%s Continue Latest did not restore the returned outcome: %s" % [route_label, continue_result])
			if String(continue_result.get("resume_target", "")) != "outcome" or String(continue_result.get("active_resume_target", "")) != "outcome":
				failures.append("%s Continue Latest did not target outcome review after outcome return" % route_label)
			if String(continue_result.get("game_state", "")) != "outcome" or String(continue_result.get("active_game_state", "")) != "outcome":
				failures.append("%s Continue Latest did not restore outcome game_state after outcome return" % route_label)
			if not bool(continue_result.get("active_battle_empty", false)):
				failures.append("%s Continue Latest restored battle residue after outcome return" % route_label)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	outcome_scene = get_tree().current_scene
	outcome_scene_path = String(outcome_scene.scene_file_path) if outcome_scene != null else ""
	if outcome_scene_path != SCENARIO_OUTCOME_SCENE_PATH:
		failures.append("%s Continue Latest after outcome return did not route back to outcome: %s" % [route_label, outcome_scene_path])
		return failures
	var resumed_outcome_snapshot: Dictionary = outcome_scene.call("validation_snapshot") if outcome_scene != null and outcome_scene.has_method("validation_snapshot") else {}
	if String(resumed_outcome_snapshot.get("scenario_id", "")) != source_scenario_id:
		failures.append("%s resumed outcome scenario mismatch before retry" % route_label)
	if String(resumed_outcome_snapshot.get("scenario_status", "")) != source_status:
		failures.append("%s resumed outcome status mismatch before retry" % route_label)
	for stale_key in ["selected_target_battle_id", "target_stack", "selected_target_board_click_action", "action_guidance", "target_context", "battle_board"]:
		if resumed_outcome_snapshot.has(stale_key):
			failures.append("%s resumed outcome snapshot battle key residue before retry: %s" % [route_label, stale_key])

	var retry_result: Dictionary = outcome_scene.call("validation_perform_action", retry_action_id)
	failures.append_array(_final_kill_outcome_action_result_failures(
		retry_result,
		retry_action_id,
		"overworld",
		"overworld",
		"overworld",
		source_scenario_id,
		"in_progress",
		"%s retry-skirmish" % route_label
	))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var overworld_scene = get_tree().current_scene
	var overworld_scene_path := String(overworld_scene.scene_file_path) if overworld_scene != null else ""
	if overworld_scene_path != OVERWORLD_SCENE_PATH:
		failures.append("%s retry-skirmish routed to wrong scene: %s" % [route_label, overworld_scene_path])
		return failures
	var restarted_session := SessionState.ensure_active_session()
	if restarted_session.scenario_id != source_scenario_id:
		failures.append("%s retry-skirmish active scenario mismatch" % route_label)
	if restarted_session.scenario_status != "in_progress":
		failures.append("%s retry-skirmish active status not in progress" % route_label)
	if restarted_session.game_state != "overworld":
		failures.append("%s retry-skirmish active game_state not overworld" % route_label)
	if SaveService.resume_target_for_session(restarted_session) != "overworld":
		failures.append("%s retry-skirmish active resume target not overworld" % route_label)
	if not restarted_session.battle.is_empty():
		failures.append("%s retry-skirmish active battle residue" % route_label)
	var restarted_snapshot: Dictionary = overworld_scene.call("validation_snapshot") if overworld_scene != null and overworld_scene.has_method("validation_snapshot") else {}
	if String(restarted_snapshot.get("scene_path", "")) != OVERWORLD_SCENE_PATH:
		failures.append("%s retry-skirmish snapshot path mismatch" % route_label)
	if String(restarted_snapshot.get("scenario_id", "")) != source_scenario_id:
		failures.append("%s retry-skirmish snapshot scenario mismatch" % route_label)
	if String(restarted_snapshot.get("scenario_status", "")) != "in_progress":
		failures.append("%s retry-skirmish snapshot status not in progress" % route_label)
	if String(restarted_snapshot.get("game_state", "")) != "overworld":
		failures.append("%s retry-skirmish snapshot game_state not overworld" % route_label)
	for stale_key in ["selected_target_battle_id", "target_stack", "selected_target_board_click_action", "action_guidance", "target_context", "battle_board"]:
		if restarted_snapshot.has(stale_key):
			failures.append("%s retry-skirmish snapshot battle key residue: %s" % [route_label, stale_key])
	failures.append_array(_final_kill_save_summary_failures(SaveService.inspect_autosave(), "overworld", "overworld", "%s retry-skirmish autosave" % route_label))
	return failures

func _final_kill_outcome_action_result_failures(
	result: Dictionary,
	action_id: String,
	expected_route: String,
	expected_resume_target: String,
	expected_game_state: String,
	expected_scenario_id: String,
	expected_status: String,
	label: String
) -> Array:
	var failures := []
	if result.is_empty():
		return ["%s action result unavailable" % label]
	if not bool(result.get("ok", false)):
		failures.append("%s action result not ok: %s" % [label, result])
	if String(result.get("action_id", "")) != action_id:
		failures.append("%s action id mismatch" % label)
	if String(result.get("expected_route", "")) != expected_route:
		failures.append("%s expected route mismatch" % label)
	if String(result.get("route", "")) != expected_route:
		failures.append("%s actual route mismatch" % label)
	var action_result: Dictionary = result.get("action_result", {}) if result.get("action_result", {}) is Dictionary else {}
	if not bool(action_result.get("ok", false)):
		failures.append("%s underlying action result not ok" % label)
	if String(action_result.get("route", "")) != expected_route:
		failures.append("%s underlying action route mismatch" % label)
	if String(result.get("active_scenario_id", "")) != expected_scenario_id:
		failures.append("%s active scenario mismatch" % label)
	if String(result.get("active_scenario_status", "")) != expected_status:
		failures.append("%s active status mismatch" % label)
	if String(result.get("active_resume_target", "")) != expected_resume_target:
		failures.append("%s active resume target mismatch" % label)
	if String(result.get("active_game_state", "")) != expected_game_state:
		failures.append("%s active game_state mismatch" % label)
	if not bool(result.get("active_battle_empty", false)):
		failures.append("%s active battle residue" % label)
	return failures

func _final_kill_menu_text_residue(text: String) -> String:
	var lowered := text.to_lower()
	for token in [
		"battle",
		"selected target",
		"board click",
		"direct actionable",
		"after move",
		"preserved setup",
		"closing on target",
	]:
		if token in lowered:
			return token
	return ""

func _final_kill_save_surface_failures(surface: Dictionary, expected_resume_target: String, label: String) -> Array:
	var failures := []
	if surface.is_empty():
		return ["%s unavailable" % label]
	var save_label := String(surface.get("save_button_label", "")).to_lower()
	var save_tooltip := String(surface.get("save_button_tooltip", "")).to_lower()
	var latest_context := String(surface.get("latest_context", "")).to_lower()
	var expected_word := "outcome" if expected_resume_target == "outcome" else "expedition"
	if expected_word not in save_label:
		failures.append("%s save label does not advertise %s" % [label, expected_word])
	if "battle" in save_label:
		failures.append("%s save label advertises battle" % label)
	if "active battle" in save_tooltip or "battle snapshot" in save_tooltip or "battle state" in save_tooltip:
		failures.append("%s save tooltip advertises battle resume" % label)
	if "battle resume" in latest_context or "resume battle" in latest_context or "active battle" in latest_context:
		failures.append("%s latest context advertises battle resume" % label)
	var latest_summary: Dictionary = surface.get("latest_summary", {}) if surface.get("latest_summary", {}) is Dictionary else {}
	if not latest_summary.is_empty() and String(latest_summary.get("resume_target", "")) != expected_resume_target:
		failures.append("%s latest summary resume target mismatch" % label)
	return failures

func _final_kill_save_summary_failures(
	summary: Dictionary,
	expected_resume_target: String,
	expected_game_state: String,
	label: String
) -> Array:
	var failures := []
	if summary.is_empty():
		return ["%s summary unavailable" % label]
	if not SaveService.can_load_summary(summary):
		failures.append("%s summary not loadable" % label)
	if String(summary.get("resume_target", "")) != expected_resume_target:
		failures.append("%s summary resume target mismatch" % label)
	if String(summary.get("battle_name", "")) != "":
		failures.append("%s summary battle name residue" % label)
	if String(summary.get("game_state", "")) != expected_game_state:
		failures.append("%s summary game_state mismatch" % label)
	if String(summary.get("saved_from_game_state", "")) != expected_game_state:
		failures.append("%s saved-from game_state mismatch" % label)
	if expected_resume_target == "outcome" and String(summary.get("scenario_status", "")) == "in_progress":
		failures.append("%s outcome summary status still in progress" % label)
	if expected_resume_target == "overworld" and String(summary.get("scenario_status", "")) != "in_progress":
		failures.append("%s overworld summary status resolved unexpectedly" % label)

	var payload: Dictionary = summary.get("payload", {}) if summary.get("payload", {}) is Dictionary else {}
	if payload.is_empty():
		failures.append("%s summary payload missing" % label)
	else:
		if String(payload.get("game_state", "")) != expected_game_state:
			failures.append("%s payload game_state mismatch" % label)
		var payload_battle = payload.get("battle", {})
		if payload_battle is Dictionary and not payload_battle.is_empty():
			failures.append("%s payload battle residue" % label)
		elif payload.has("battle") and not (payload_battle is Dictionary):
			failures.append("%s payload battle field malformed" % label)
	var summary_text := " ".join([
		String(summary.get("summary", "")),
		String(summary.get("detail", "")),
		String(summary.get("status_text", "")),
	]).to_lower()
	if "battle resume" in summary_text or "resume battle" in summary_text or "active battle" in summary_text:
		failures.append("%s summary text advertises battle resume" % label)
	return failures

func _final_kill_routed_response_failures(
	attack_response: Dictionary,
	session,
	action_id: String,
	target_id: String
) -> Array:
	var failures := []
	var action_result: Dictionary = attack_response.get("action_result", {}) if attack_response.get("action_result", {}) is Dictionary else {}
	var attack_result: Dictionary = attack_response.get("attack_result", {}) if attack_response.get("attack_result", {}) is Dictionary else action_result
	var result_legality: Dictionary = attack_result.get("selected_target_after_attack_legality", {}) if attack_result.get("selected_target_after_attack_legality", {}) is Dictionary else {}
	var result_click_intent: Dictionary = attack_result.get("selected_target_after_attack_board_click_intent", {}) if attack_result.get("selected_target_after_attack_board_click_intent", {}) is Dictionary else {}
	var response_context: Dictionary = attack_response.get("selected_target_continuity_context", {}) if attack_response.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var response_closing: Dictionary = attack_response.get("selected_target_closing_context", {}) if attack_response.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var response_board: Dictionary = attack_response.get("battle_board", {}) if attack_response.get("battle_board", {}) is Dictionary else {}
	var response_selected_after := String(attack_response.get(
		"selected_target_after_click",
		attack_response.get("selected_target_after_action_battle_id", "")
	))
	var response_action_guidance := String(attack_response.get("action_guidance", "")).to_lower()
	var response_target_context := String(attack_response.get("target_context", "")).to_lower()
	var attack_message := String(attack_response.get("message", "")).to_lower()
	var checks := {
		"response not ok": not bool(attack_response.get("ok", false)),
		"wrong action": String(attack_response.get("action", "")) != action_id,
		"state not victory": String(attack_response.get("state", "")) != "victory",
		"not routed": not bool(attack_response.get("routed", false)),
		"session battle still active": not session.battle.is_empty(),
		"attack result missing": attack_result.is_empty(),
		"attack action mismatch": String(attack_result.get("attack_action", "")) != action_id,
		"attack target mismatch": String(attack_result.get("attack_target_battle_id", "")) != target_id,
		"target not invalidated": not bool(attack_result.get("attack_target_invalidated_after_attack", false)),
		"target still selected": bool(attack_result.get("attack_target_still_selected_after_attack", true)),
		"target still alive": bool(attack_result.get("attack_target_alive_after_attack", true)),
		"active stack residue": String(attack_result.get("active_stack_after_attack_battle_id", "")) != "",
		"response selected target residue": response_selected_after != "",
		"response selected after attack residue": String(attack_response.get("selected_target_after_attack_battle_id", attack_result.get("selected_target_after_attack_battle_id", ""))) != "",
		"result selected after attack residue": String(attack_result.get("selected_target_after_attack_battle_id", "")) != "",
		"result target still valid": bool(attack_result.get("selected_target_valid_after_attack", true)),
		"response handoff residue": bool(attack_response.get("selected_target_handoff_after_attack", false)),
		"result handoff residue": bool(attack_result.get("selected_target_handoff_after_attack", true)),
		"response direct handoff residue": bool(attack_response.get("selected_target_handoff_direct_actionable_after_attack", false)),
		"result direct handoff residue": bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", true)),
		"response blocked handoff residue": bool(attack_response.get("selected_target_handoff_blocked_after_attack", false)),
		"result blocked handoff residue": bool(attack_result.get("selected_target_handoff_blocked_after_attack", true)),
		"response direct actionable residue": bool(attack_response.get("selected_target_direct_actionable", false)),
		"response direct actionable after attack residue": bool(attack_response.get("selected_target_direct_actionable_after_attack", false)),
		"result direct actionable after attack residue": bool(attack_result.get("selected_target_direct_actionable_after_attack", true)),
		"response direct actionable after action residue": attack_response.has("selected_target_direct_actionable_after_action") and bool(attack_response.get("selected_target_direct_actionable_after_action", true)),
		"response preserved setup residue": bool(attack_response.get("selected_target_preserved_setup", false)),
		"result preserved setup residue": bool(attack_result.get("selected_target_preserved_setup", true)),
		"response closing residue": bool(attack_response.get("selected_target_closing_on_target", false)),
		"result closing residue": bool(attack_result.get("selected_target_closing_on_target", true)),
		"response continuity context residue": not response_context.is_empty(),
		"result continuity context residue": not result_context.is_empty(),
		"response closing context residue": not response_closing.is_empty(),
		"result closing context residue": not result_closing.is_empty(),
		"result attackable legality residue": bool(result_legality.get("attackable", false)),
		"result blocked legality residue": bool(result_legality.get("blocked", false)),
		"result board action residue": String(result_click_intent.get("action", "")) != "",
		"response board residue": not response_board.is_empty(),
		"response after-move field residue": attack_response.has("selected_target_actionable_after_move"),
		"action result after-move field residue": action_result.has("selected_target_actionable_after_move"),
		"attack result after-move field residue": attack_result.has("selected_target_actionable_after_move"),
		"attack result after-move id residue": attack_result.has("selected_target_after_move_battle_id"),
		"response action board-click wording residue": "board click will" in response_action_guidance,
		"response target board-click wording residue": "board click will" in response_target_context,
		"response action direct-actionable wording residue": "direct actionable after move" in response_action_guidance,
		"response target direct-actionable wording residue": "direct actionable after move" in response_target_context,
		"message direct-actionable wording residue": "direct actionable after move" in attack_message,
		"response action preserved wording residue": "preserved setup target" in response_action_guidance,
		"response target preserved wording residue": "preserved setup target" in response_target_context,
		"message preserved wording residue": "preserved setup target" in attack_message,
		"response action closing wording residue": "closing on target" in response_action_guidance,
		"response target closing wording residue": "closing on target" in response_target_context,
		"message closing wording residue": "closing on target" in attack_message,
	}
	for check_name in checks:
		if bool(checks[check_name]):
			failures.append(String(check_name))
	return failures

func _final_kill_empty_shell_snapshot_failures(snapshot: Dictionary) -> Array:
	var failures := []
	if snapshot.is_empty():
		return ["snapshot unavailable"]
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	var snapshot_board_context: Dictionary = snapshot_board.get("selected_target_continuity_context", {}) if snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_board_closing: Dictionary = snapshot_board.get("selected_target_closing_context", {}) if snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board_legality: Dictionary = snapshot_board.get("selected_target_legality", {}) if snapshot_board.get("selected_target_legality", {}) is Dictionary else {}
	var snapshot_stack_cells: Array = snapshot_board.get("stack_cells", []) if snapshot_board.get("stack_cells", []) is Array else []
	var snapshot_action_guidance := String(snapshot.get("action_guidance", "")).to_lower()
	var snapshot_target_context := String(snapshot.get("target_context", "")).to_lower()
	var snapshot_board_action := String(snapshot_board.get("selected_target_board_click_action", ""))
	var checks := {
		"selected target residue": String(snapshot.get("selected_target_battle_id", "")) != "",
		"target stack residue": String(snapshot.get("target_stack", "")) != "",
		"snapshot board action residue": String(snapshot.get("selected_target_board_click_action", "")) != "",
		"direct actionable residue": bool(snapshot.get("selected_target_direct_actionable", false)),
		"preserved setup residue": bool(snapshot.get("selected_target_preserved_setup", false)),
		"closing residue": bool(snapshot.get("selected_target_closing_on_target", false)),
		"continuity context residue": not snapshot_context.is_empty(),
		"closing context residue": not snapshot_closing.is_empty(),
		"player stack count residue": int(snapshot.get("player_stack_count", -1)) != 0,
		"enemy stack count residue": int(snapshot.get("enemy_stack_count", -1)) != 0,
		"board player count residue": int(snapshot_board.get("player_stack_count", -1)) != 0,
		"board enemy count residue": int(snapshot_board.get("enemy_stack_count", -1)) != 0,
		"board stack cell residue": not snapshot_stack_cells.is_empty(),
		"board selected cell residue": bool(snapshot_board.get("has_selected_target_cell", false)),
		"board direct actionable residue": bool(snapshot_board.get("selected_target_direct_actionable", false)),
		"board preserved setup residue": bool(snapshot_board.get("selected_target_preserved_setup", false)),
		"board closing residue": bool(snapshot_board.get("selected_target_closing_on_target", false)),
		"board continuity context residue": not snapshot_board_context.is_empty(),
		"board closing context residue": not snapshot_board_closing.is_empty(),
		"board attackable legality residue": bool(snapshot_board_legality.get("attackable", false)),
		"board blocked legality residue": bool(snapshot_board_legality.get("blocked", false)),
		"board action residue": snapshot_board_action != "",
		"board footer residue": String(snapshot_board.get("selected_target_footer_label", "")) != "",
		"action board-click wording residue": "board click will" in snapshot_action_guidance,
		"target board-click wording residue": "board click will" in snapshot_target_context,
		"action direct-actionable wording residue": "direct actionable after move" in snapshot_action_guidance,
		"target direct-actionable wording residue": "direct actionable after move" in snapshot_target_context,
		"action preserved wording residue": "preserved setup target" in snapshot_action_guidance,
		"target preserved wording residue": "preserved setup target" in snapshot_target_context,
		"action closing wording residue": "closing on target" in snapshot_action_guidance,
		"target closing wording residue": "closing on target" in snapshot_target_context,
	}
	for check_name in checks:
		if bool(checks[check_name]):
			failures.append(String(check_name))
	return failures

func _restore_layout_current_scene(previous_current) -> void:
	var current = get_tree().current_scene
	if current != null and current != previous_current:
		get_tree().current_scene = null
		current.queue_free()
		await get_tree().process_frame
	if previous_current != null and is_instance_valid(previous_current):
		get_tree().current_scene = previous_current

func _run_direct_actionable_after_move_button_attack_case(shell, session, viewport_size: Vector2) -> bool:
	if not shell.has_method("validation_perform_action") or not shell.has_method("validation_perform_board_hex_click"):
		push_error("Battle layout smoke: battle shell does not expose button-action validation for direct actionable movement.")
		get_tree().quit(1)
		return false
	var setup := _stage_direct_actionable_after_move_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not restage direct actionable button-attack state at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var first_destination: Dictionary = setup.get("first_destination", {})
	var destination: Dictionary = setup.get("destination", {})
	var first_click: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(first_destination.get("q", -1)),
		int(first_destination.get("r", -1))
	)
	var first_closing_context: Dictionary = first_click.get("selected_target_closing_context", {}) if first_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(first_click.get("ok", false))
		or first_closing_context.is_empty()
		or not bool(first_closing_context.get("ordinary_closing_target", false))
		or bool(first_click.get("selected_target_preserved_setup", false))
	):
		push_error("Battle layout smoke: button-attack setup did not create ordinary closing lead-in at %s: setup=%s result=%s." % [viewport_size, setup, first_click])
		get_tree().quit(1)
		return false

	var move_result: Dictionary = shell.call(
		"validation_perform_board_hex_click",
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	var move_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing_context: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	var move_guidance := String(move_result.get("post_move_target_guidance", "")).to_lower()
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or not move_context.is_empty()
		or bool(move_result.get("selected_target_closing_on_target", false))
		or not move_closing_context.is_empty()
		or "board click will" not in move_guidance
		or "preserved setup target" in move_guidance
		or "closing on target" in move_guidance
	):
		push_error("Battle layout smoke: button-attack move did not reach clean direct actionable state at %s: setup=%s result=%s." % [viewport_size, setup, move_result])
		get_tree().quit(1)
		return false

	var button: Button = shell.get_node_or_null("%" + action_id.capitalize())
	if button == null or button.disabled:
		push_error("Battle layout smoke: direct actionable %s button was not enabled at %s." % [action_id, viewport_size])
		get_tree().quit(1)
		return false
	var health_before_attack := int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0))
	var button_attack: Dictionary = shell.call("validation_perform_action", action_id)
	var action_result: Dictionary = button_attack.get("action_result", {}) if button_attack.get("action_result", {}) is Dictionary else {}
	var attack_result: Dictionary = button_attack.get("attack_result", {}) if button_attack.get("attack_result", {}) is Dictionary else action_result
	var button_context: Dictionary = button_attack.get("selected_target_continuity_context", {}) if button_attack.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_context: Dictionary = action_result.get("selected_target_continuity_context", {}) if action_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var button_closing: Dictionary = button_attack.get("selected_target_closing_context", {}) if button_attack.get("selected_target_closing_context", {}) is Dictionary else {}
	var result_closing: Dictionary = action_result.get("selected_target_closing_context", {}) if action_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var button_board: Dictionary = button_attack.get("battle_board", {}) if button_attack.get("battle_board", {}) is Dictionary else {}
	var board_context: Dictionary = button_board.get("selected_target_continuity_context", {}) if button_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var board_closing: Dictionary = button_board.get("selected_target_closing_context", {}) if button_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var button_cell := _stack_cell_entry(button_board.get("stack_cells", []), target_id)
	var action_guidance := String(button_attack.get("action_guidance", "")).to_lower()
	var target_context := String(button_attack.get("target_context", "")).to_lower()
	if (
		not bool(button_attack.get("ok", false))
		or String(button_attack.get("action", "")) != action_id
		or not bool(action_result.get("ok", false))
		or String(button_attack.get("attack_action", "")) != action_id
		or String(action_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_action", "")) != action_id
		or String(button_attack.get("attack_target_battle_id", "")) != target_id
		or String(action_result.get("attack_target_battle_id", "")) != target_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) >= health_before_attack
		or String(button_attack.get("selected_target_after_action_battle_id", "")) != target_id
		or String(button_attack.get("selected_target_after_attack_battle_id", "")) != target_id
		or bool(button_attack.get("selected_target_preserved_setup", false))
		or bool(action_result.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or not button_context.is_empty()
		or not result_context.is_empty()
		or not attack_context.is_empty()
		or bool(button_attack.get("selected_target_closing_on_target", false))
		or bool(action_result.get("selected_target_closing_on_target", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not button_closing.is_empty()
		or not result_closing.is_empty()
		or not attack_closing.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or button_attack.has("selected_target_actionable_after_move")
		or action_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_actionable_after_move")
		or not bool(button_attack.get("selected_target_direct_actionable", false))
		or not bool(button_attack.get("selected_target_direct_actionable_after_action", false))
		or bool(button_board.get("selected_target_preserved_setup", false))
		or bool(button_board.get("selected_target_closing_on_target", false))
		or not board_context.is_empty()
		or not board_closing.is_empty()
		or not bool(button_board.get("selected_target_direct_actionable", false))
		or String(button_board.get("selected_target_footer_label", "")).find("Click:") != 0
		or button_cell.is_empty()
		or not bool(button_cell.get("legal_attack_target", false))
		or bool(button_cell.get("preserved_setup_target", false))
		or bool(button_cell.get("ordinary_closing_target", false))
		or "board click will" not in action_guidance
		or "board click will" not in target_context
		or "direct actionable after move" in action_guidance
		or "direct actionable after move" in target_context
		or "preserved setup target" in action_guidance
		or "preserved setup target" in target_context
		or "closing on target" in action_guidance
		or "closing on target" in target_context
	):
		push_error("Battle layout smoke: immediate Strike/Shoot button attack after direct actionable move left stale transition state at %s: attack=%s." % [viewport_size, button_attack])
		get_tree().quit(1)
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_context: Dictionary = snapshot.get("selected_target_continuity_context", {}) if snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_closing: Dictionary = snapshot.get("selected_target_closing_context", {}) if snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var snapshot_board: Dictionary = snapshot.get("battle_board", {}) if snapshot.get("battle_board", {}) is Dictionary else {}
	var snapshot_board_context: Dictionary = snapshot_board.get("selected_target_continuity_context", {}) if snapshot_board.get("selected_target_continuity_context", {}) is Dictionary else {}
	var snapshot_board_closing: Dictionary = snapshot_board.get("selected_target_closing_context", {}) if snapshot_board.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		bool(snapshot.get("selected_target_preserved_setup", false))
		or not snapshot_context.is_empty()
		or bool(snapshot.get("selected_target_closing_on_target", false))
		or not snapshot_closing.is_empty()
		or bool(snapshot_board.get("selected_target_preserved_setup", false))
		or bool(snapshot_board.get("selected_target_closing_on_target", false))
		or not snapshot_board_context.is_empty()
		or not snapshot_board_closing.is_empty()
		or not bool(snapshot_board.get("selected_target_direct_actionable", false))
		or String(snapshot_board.get("selected_target_footer_label", "")).find("Click:") != 0
		or "board click will" not in String(snapshot.get("action_guidance", "")).to_lower()
		or "board click will" not in String(snapshot.get("target_context", "")).to_lower()
		or "preserved setup target" in String(snapshot.get("action_guidance", "")).to_lower()
		or "closing on target" in String(snapshot.get("action_guidance", "")).to_lower()
	):
		push_error("Battle layout smoke: shell snapshot after immediate Strike/Shoot button attack did not stay on the normal attack path at %s: snapshot=%s." % [viewport_size, snapshot])
		get_tree().quit(1)
		return false
	return true

func _run_post_clear_old_target_normal_move_case(shell, session, target_id: String, viewport_size: Vector2) -> bool:
	var active_stack := BattleRules.get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		push_error("Battle layout smoke: post-clear normal movement setup did not have a player active stack at %s: active=%s." % [viewport_size, active_stack])
		get_tree().quit(1)
		return false
	var player_id := String(active_stack.get("battle_id", ""))
	var followup_player_id := "post_clear_normal_move_player"
	_ensure_player_stack_for_test(session.battle, active_stack, followup_player_id)
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	var alternate_enemy_id := "ordinary_closing_retarget_enemy"
	_ensure_enemy_stack_for_test(session.battle, _battle_stack_by_id(session.battle, target_id), alternate_enemy_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, followup_player_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, followup_player_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, followup_player_id, {"q": 0, "r": 0})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, alternate_enemy_id, {"q": 10, "r": 6})
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id

	var normal_intent := BattleRules.movement_intent_for_destination(session.battle, 1, 3)
	if (
		String(normal_intent.get("action", "")) != "move"
		or not bool(normal_intent.get("closes_on_selected_target", false))
		or bool(normal_intent.get("sets_up_selected_target_attack", false))
		or String(normal_intent.get("selected_target_battle_id", "")) != target_id
	):
		push_error("Battle layout smoke: post-clear normal movement setup was not an ordinary move toward the old target at %s: intent=%s battle=%s." % [viewport_size, normal_intent, session.battle])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	var move_click: Dictionary = shell.call("validation_perform_board_hex_click", 1, 3)
	var move_context: Dictionary = move_click.get("selected_target_continuity_context", {}) if move_click.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_closing_context: Dictionary = move_click.get("selected_target_closing_context", {}) if move_click.get("selected_target_closing_context", {}) is Dictionary else {}
	var move_board: Dictionary = move_click.get("post_move_board_summary", {}) if move_click.get("post_move_board_summary", {}) is Dictionary else {}
	var move_board_cell := _stack_cell_entry(move_board.get("stack_cells", []), target_id)
	var move_action_guidance := String(move_click.get("post_move_action_guidance", "")).to_lower()
	var move_target_context := String(move_click.get("post_move_target_context", "")).to_lower()
	var move_guidance := String(move_click.get("post_move_target_guidance", "")).to_lower()
	if (
		not bool(move_click.get("ok", false))
		or String(move_click.get("action", "")) != "move"
		or bool(move_click.get("selected_target_continuity_preserved", false))
		or not move_context.is_empty()
		or String(move_click.get("selected_target_after_move_battle_id", "")) != target_id
		or not bool(move_click.get("closes_on_selected_target", false))
		or not bool(move_click.get("selected_target_closing_on_target", false))
		or move_closing_context.is_empty()
		or not bool(move_closing_context.get("ordinary_closing_target", false))
		or bool(move_closing_context.get("preserved_setup_target", false))
		or "closing on target" not in move_action_guidance
		or "closing on target" not in move_target_context
		or "closing on target" not in move_guidance
		or bool(move_board.get("selected_target_preserved_setup", false))
		or not bool(move_board.get("selected_target_closing_on_target", false))
		or String(move_board.get("selected_target_footer_label", "")).find("Setup:") == 0
		or String(move_board.get("selected_target_footer_label", "")).find("Closing:") != 0
		or (not move_board_cell.is_empty() and bool(move_board_cell.get("preserved_setup_target", false)))
		or (not move_board_cell.is_empty() and not bool(move_board_cell.get("ordinary_closing_target", false)))
		or "preserved setup target" in move_action_guidance
		or "preserved setup target" in move_target_context
		or "preserved setup target" in move_guidance
	):
		push_error("Battle layout smoke: post-clear normal movement toward the old setup target did not stay ordinary while surfacing closing progress at %s: intent=%s click=%s." % [viewport_size, normal_intent, move_click])
		get_tree().quit(1)
		return false
	var move_snapshot: Dictionary = shell.call("validation_snapshot")
	var move_snapshot_context: Dictionary = move_snapshot.get("selected_target_continuity_context", {}) if move_snapshot.get("selected_target_continuity_context", {}) is Dictionary else {}
	var move_snapshot_closing_context: Dictionary = move_snapshot.get("selected_target_closing_context", {}) if move_snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var move_snapshot_board: Dictionary = move_snapshot.get("battle_board", {}) if move_snapshot.get("battle_board", {}) is Dictionary else {}
	if (
		bool(move_snapshot.get("selected_target_preserved_setup", false))
		or not move_snapshot_context.is_empty()
		or not bool(move_snapshot.get("selected_target_closing_on_target", false))
		or move_snapshot_closing_context.is_empty()
		or not bool(move_snapshot_closing_context.get("ordinary_closing_target", false))
		or "closing on target" not in String(move_snapshot.get("action_guidance", "")).to_lower()
		or "closing on target" not in String(move_snapshot.get("target_context", "")).to_lower()
		or "preserved setup target" in String(move_snapshot.get("action_guidance", "")).to_lower()
		or "preserved setup target" in String(move_snapshot.get("target_context", "")).to_lower()
		or bool(move_snapshot_board.get("selected_target_preserved_setup", false))
		or not bool(move_snapshot_board.get("selected_target_closing_on_target", false))
		or String(move_snapshot_board.get("selected_target_footer_label", "")).find("Closing:") != 0
	):
		push_error("Battle layout smoke: post-clear normal movement did not keep ordinary closing visible in the shell snapshot at %s: snapshot=%s." % [viewport_size, move_snapshot])
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, target_id, {"q": 2, "r": 3})
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	var attackable_snapshot: Dictionary = shell.call("validation_snapshot")
	var attackable_context: Dictionary = attackable_snapshot.get("selected_target_closing_context", {}) if attackable_snapshot.get("selected_target_closing_context", {}) is Dictionary else {}
	var attackable_board: Dictionary = attackable_snapshot.get("battle_board", {}) if attackable_snapshot.get("battle_board", {}) is Dictionary else {}
	var attackable_board_context: Dictionary = attackable_board.get("selected_target_closing_context", {}) if attackable_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var attackable_cell := _stack_cell_entry(attackable_board.get("stack_cells", []), target_id)
	var attackable_action_guidance := String(attackable_snapshot.get("action_guidance", "")).to_lower()
	var attackable_target_context := String(attackable_snapshot.get("target_context", "")).to_lower()
	var attackable_action := String(attackable_snapshot.get("selected_target_board_click_action", ""))
	if (
		bool(attackable_snapshot.get("selected_target_closing_on_target", false))
		or not attackable_context.is_empty()
		or bool(attackable_board.get("selected_target_closing_on_target", false))
		or not attackable_board_context.is_empty()
		or String(attackable_board.get("selected_target_footer_label", "")).find("Closing:") == 0
		or (not attackable_cell.is_empty() and bool(attackable_cell.get("ordinary_closing_target", false)))
		or (not attackable_cell.is_empty() and not bool(attackable_cell.get("legal_attack_target", false)))
		or attackable_action not in ["strike", "shoot"]
		or "closing on target" in attackable_action_guidance
		or "closing on target" in attackable_target_context
		or "board click will" not in attackable_action_guidance
		or "board click will" not in attackable_target_context
	):
		push_error("Battle layout smoke: ordinary closing did not clear into actionable board-click guidance at %s: snapshot=%s." % [viewport_size, attackable_snapshot])
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, alternate_enemy_id, {"q": 10, "r": 6})
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	var retarget_stage_click: Dictionary = shell.call("validation_perform_board_hex_click", 1, 3)
	var retarget_stage_context: Dictionary = retarget_stage_click.get("selected_target_closing_context", {}) if retarget_stage_click.get("selected_target_closing_context", {}) is Dictionary else {}
	if not bool(retarget_stage_click.get("ok", false)) or retarget_stage_context.is_empty():
		push_error("Battle layout smoke: ordinary closing retarget-clear setup did not recreate closing context at %s: result=%s." % [viewport_size, retarget_stage_click])
		get_tree().quit(1)
		return false
	var retarget_click: Dictionary = shell.call("validation_perform_board_stack_click", alternate_enemy_id)
	var retarget_context: Dictionary = retarget_click.get("selected_target_closing_context", {}) if retarget_click.get("selected_target_closing_context", {}) is Dictionary else {}
	var retarget_board: Dictionary = retarget_click.get("battle_board", {}) if retarget_click.get("battle_board", {}) is Dictionary else {}
	var retarget_board_context: Dictionary = retarget_board.get("selected_target_closing_context", {}) if retarget_board.get("selected_target_closing_context", {}) is Dictionary else {}
	var retarget_action_guidance := String(retarget_click.get("action_guidance", "")).to_lower()
	var retarget_target_context := String(retarget_click.get("target_context", "")).to_lower()
	if (
		String(retarget_click.get("selected_target_after_click", "")) != alternate_enemy_id
		or bool(retarget_click.get("selected_target_closing_on_target", false))
		or not retarget_context.is_empty()
		or bool(retarget_board.get("selected_target_closing_on_target", false))
		or not retarget_board_context.is_empty()
		or String(retarget_board.get("selected_target_footer_label", "")).find("Closing:") == 0
		or "closing on target" in retarget_action_guidance
		or "closing on target" in retarget_target_context
	):
		push_error("Battle layout smoke: ordinary closing did not clear when target selection changed at %s: retarget=%s." % [viewport_size, retarget_click])
		get_tree().quit(1)
		return false
	return true

func _run_board_click_dispatch_case(shell, session, setup: Dictionary, viewport_size: Vector2) -> bool:
	if not shell.has_method("validation_perform_board_stack_click"):
		push_error("Battle layout smoke: battle shell does not expose board-click validation.")
		get_tree().quit(1)
		return false

	var legal_target_id := String(setup.get("legal_target_id", ""))
	var blocked_target_id := String(setup.get("blocked_target_id", ""))
	var legal_before := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
	session.battle["selected_target_id"] = blocked_target_id
	var blocked_selected_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var blocked_selected_message := String(blocked_selected_intent.get("message", "")).to_lower()
	if String(blocked_selected_intent.get("action", "")) != "" or not bool(blocked_selected_intent.get("blocked", false)):
		push_error("Battle layout smoke: blocked selected target exposed an executable board-click intent at %s: %s." % [viewport_size, blocked_selected_intent])
		get_tree().quit(1)
		return false
	if "board click blocked" not in blocked_selected_message or "highlighted enemy" not in blocked_selected_message:
		push_error("Battle layout smoke: blocked selected target intent did not explain the board-click contract at %s: %s." % [viewport_size, blocked_selected_intent])
		get_tree().quit(1)
		return false
	session.battle["selected_target_id"] = legal_target_id
	var blocked_click: Dictionary = shell.call("validation_perform_board_stack_click", blocked_target_id)
	var blocked_message := String(blocked_click.get("message", "")).to_lower()
	if bool(blocked_click.get("ok", false)) or String(blocked_click.get("action", "")) != "blocked_target":
		push_error("Battle layout smoke: blocked board click dispatched an action at %s: %s." % [viewport_size, blocked_click])
		get_tree().quit(1)
		return false
	if "blocked" not in blocked_message or "highlighted enemy" not in blocked_message:
		push_error("Battle layout smoke: blocked board click did not explain the legal alternative at %s: %s." % [viewport_size, blocked_click])
		get_tree().quit(1)
		return false
	if int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0)) != legal_before:
		push_error("Battle layout smoke: blocked board click damaged a legal target at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	session.battle["selected_target_id"] = blocked_target_id
	var attack_before := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
	var attack_click: Dictionary = shell.call("validation_perform_board_stack_click", legal_target_id)
	var attack_action := String(attack_click.get("action", ""))
	var attack_message := String(attack_click.get("message", "")).to_lower()
	if not bool(attack_click.get("ok", false)) or attack_action not in ["strike", "shoot"]:
		push_error("Battle layout smoke: legal board click did not dispatch an attack at %s: %s." % [viewport_size, attack_click])
		get_tree().quit(1)
		return false
	if bool(attack_click.get("selected_before", true)):
		push_error("Battle layout smoke: legal board click did not cover the unselected-target attack path at %s: %s." % [viewport_size, attack_click])
		get_tree().quit(1)
		return false
	if int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0)) >= attack_before:
		push_error("Battle layout smoke: legal board click did not damage the clicked target at %s: %s." % [viewport_size, attack_click])
		get_tree().quit(1)
		return false
	if "strikes" not in attack_message and "shoots" not in attack_message:
		push_error("Battle layout smoke: legal board click dispatch message did not report the attack at %s: %s." % [viewport_size, attack_click])
		get_tree().quit(1)
		return false
	return true

func _run_ranged_board_hex_click_dispatch_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if (
		board == null
		or not board.has_method("validation_perform_hex_cell_mouse_click")
		or not board.has_method("validation_perform_outer_hex_ring_mouse_click")
	):
		push_error("Battle layout smoke: battle board does not expose mouse-position hex click validation.")
		get_tree().quit(1)
		return false
	var setup := _stage_ranged_board_hex_click_dispatch_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage a ranged board hex-click attack case at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var legal_target_id := String(setup.get("legal_target_id", ""))
	var target_before := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
	var mouse_click: Dictionary = board.call(
		"validation_perform_hex_cell_mouse_click",
		int(setup.get("target_q", -1)),
		int(setup.get("target_r", -1))
	)
	var target_after := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
	var found_shape_miss := bool(mouse_click.get("found_shape_miss_position", false))
	var dispatch_kind := String(mouse_click.get("dispatch", ""))
	if not bool(mouse_click.get("accepted", false)) or dispatch_kind not in ["stack_hex", "stack_token"]:
		push_error("Battle layout smoke: ranged enemy hex-edge mouse click did not dispatch as a stack click at %s: %s." % [viewport_size, mouse_click])
		get_tree().quit(1)
		return false
	if String(mouse_click.get("battle_id", "")) != legal_target_id or String(mouse_click.get("cell_target_before", "")) != legal_target_id:
		push_error("Battle layout smoke: ranged enemy hex-edge mouse click targeted the wrong stack at %s: setup=%s click=%s." % [viewport_size, setup, mouse_click])
		get_tree().quit(1)
		return false
	if found_shape_miss and (dispatch_kind != "stack_hex" or String(mouse_click.get("shape_target_before", "")) != ""):
		push_error("Battle layout smoke: ranged enemy mouse validation did not exercise the hex-but-not-token click gap at %s: %s." % [viewport_size, mouse_click])
		get_tree().quit(1)
		return false
	if target_after >= target_before:
		push_error("Battle layout smoke: ranged enemy hex-edge mouse click did not execute Shoot damage at %s: before=%d after=%d click=%s." % [viewport_size, target_before, target_after, mouse_click])
		get_tree().quit(1)
		return false
	if viewport_size.x >= 1200.0:
		setup = _stage_ranged_board_hex_click_dispatch_state(session.battle)
		if setup.is_empty():
			push_error("Battle layout smoke: could not restage a ranged outer-ring attack case at %s." % [viewport_size])
			get_tree().quit(1)
			return false
		if shell.has_method("_refresh"):
			shell.call("_refresh")
		await get_tree().process_frame
		await get_tree().process_frame
		legal_target_id = String(setup.get("legal_target_id", ""))
		var outer_target_before := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
		var outer_click: Dictionary = board.call(
			"validation_perform_outer_hex_ring_mouse_click",
			int(setup.get("target_q", -1)),
			int(setup.get("target_r", -1))
		)
		var outer_target_after := int(_battle_stack_by_id(session.battle, legal_target_id).get("total_health", 0))
		if (
			not bool(outer_click.get("found_outer_ring_position", false))
			or float(outer_click.get("radius_factor", 0.0)) <= 0.92
			or String(outer_click.get("shape_target_before", "")) != ""
			or String(outer_click.get("dispatch", "")) != "stack_hex"
			or not bool(outer_click.get("accepted", false))
			or String(outer_click.get("battle_id", "")) != legal_target_id
			or String(outer_click.get("cell_target_before", "")) != legal_target_id
			or int(outer_click.get("resolved_q", -1)) != int(setup.get("target_q", -2))
			or int(outer_click.get("resolved_r", -1)) != int(setup.get("target_r", -2))
		):
			push_error("Battle layout smoke: ranged enemy outer hex-ring click did not resolve through occupied-hex dispatch at %s: setup=%s click=%s." % [viewport_size, setup, outer_click])
			get_tree().quit(1)
			return false
		if outer_target_after >= outer_target_before:
			push_error("Battle layout smoke: ranged enemy outer hex-ring click did not execute Shoot damage at %s: before=%d after=%d click=%s." % [viewport_size, outer_target_before, outer_target_after, outer_click])
			get_tree().quit(1)
			return false
	return true

func _run_overlapped_friendly_shape_movement_click_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_perform_overlapped_hex_destination_mouse_click"):
		push_error("Battle layout smoke: battle board does not expose overlapped movement-click validation.")
		get_tree().quit(1)
		return false
	var setup := _stage_overlapped_friendly_shape_movement_click_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage an overlapped friendly-shape movement click at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var player_id := String(setup.get("player_id", ""))
	var destination_q := int(setup.get("destination_q", -1))
	var destination_r := int(setup.get("destination_r", -1))
	var click: Dictionary = board.call(
		"validation_perform_overlapped_hex_destination_mouse_click",
		destination_q,
		destination_r
	)
	var player_after := _battle_stack_by_id(session.battle, player_id)
	var player_hex_after := _stack_hex_for_test(player_after)
	var expected_tooltip := String(setup.get("intent", {}).get("message", ""))
	var tooltip_before := String(click.get("tooltip_before", ""))
	if (
		not bool(click.get("found_friendly_shape_overlap", false))
		or not bool(click.get("legal_destination_before", false))
		or String(click.get("shape_target_before", "")) != player_id
		or String(click.get("shape_target_side_before", "")) != "player"
		or tooltip_before != expected_tooltip
		or String(click.get("movement_tooltip_before", "")) != expected_tooltip
		or String(click.get("shape_battle_id", "")) != player_id
		or String(click.get("dispatch", "")) != "destination"
		or not bool(click.get("accepted", false))
		or int(click.get("resolved_q", -1)) != destination_q
		or int(click.get("resolved_r", -1)) != destination_r
		or int(player_hex_after.get("q", -1)) != destination_q
		or int(player_hex_after.get("r", -1)) != destination_r
	):
		push_error("Battle layout smoke: overlapped friendly hit shape swallowed a visible green movement hex click at %s: setup=%s click=%s player_hex=%s." % [viewport_size, setup, click, player_hex_after])
		get_tree().quit(1)
		return false
	return true

func _run_overlapped_enemy_shape_movement_click_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_perform_enemy_overlapped_hex_destination_mouse_click"):
		push_error("Battle layout smoke: battle board does not expose enemy-overlapped movement-click validation.")
		get_tree().quit(1)
		return false
	var setup := _stage_overlapped_enemy_shape_movement_click_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage an overlapped enemy-shape movement click at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var player_id := String(setup.get("player_id", ""))
	var enemy_id := String(setup.get("enemy_id", ""))
	var destination_q := int(setup.get("destination_q", -1))
	var destination_r := int(setup.get("destination_r", -1))
	var click: Dictionary = board.call(
		"validation_perform_enemy_overlapped_hex_destination_mouse_click",
		destination_q,
		destination_r
	)
	var player_after := _battle_stack_by_id(session.battle, player_id)
	var player_hex_after := _stack_hex_for_test(player_after)
	var tooltip_before := String(click.get("tooltip_before", ""))
	var movement_tooltip_before := String(click.get("movement_tooltip_before", ""))
	if (
		not bool(click.get("found_enemy_shape_overlap", false))
		or not bool(click.get("legal_destination_before", false))
		or String(click.get("shape_target_before", "")) != enemy_id
		or String(click.get("shape_target_side_before", "")) != "enemy"
		or tooltip_before != movement_tooltip_before
		or "green hex click" not in tooltip_before.to_lower()
		or String(click.get("shape_battle_id", "")) != enemy_id
		or String(click.get("dispatch", "")) != "destination"
		or not bool(click.get("accepted", false))
		or int(click.get("resolved_q", -1)) != destination_q
		or int(click.get("resolved_r", -1)) != destination_r
		or int(player_hex_after.get("q", -1)) != destination_q
		or int(player_hex_after.get("r", -1)) != destination_r
	):
		push_error("Battle layout smoke: overlapped enemy hit shape swallowed a visible green movement hex click at %s: setup=%s click=%s player_hex=%s." % [viewport_size, setup, click, player_hex_after])
		get_tree().quit(1)
		return false
	return true

func _run_overlapped_enemy_shape_enemy_hex_attack_click_case(shell, session, viewport_size: Vector2) -> bool:
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_perform_enemy_overlapped_occupied_hex_mouse_click"):
		push_error("Battle layout smoke: battle board does not expose occupied-hex overlap click validation.")
		get_tree().quit(1)
		return false
	var setup := _stage_overlapped_enemy_shape_enemy_hex_attack_click_state(session.battle)
	if setup.is_empty():
		push_error("Battle layout smoke: could not stage an enemy-overlapped occupied enemy hex click at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if shell.has_method("_refresh"):
		shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var target_id := String(setup.get("target_id", ""))
	var overlap_enemy_id := String(setup.get("overlap_enemy_id", ""))
	var target_before := int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0))
	var overlap_before := int(_battle_stack_by_id(session.battle, overlap_enemy_id).get("total_health", 0))
	var click: Dictionary = board.call(
		"validation_perform_enemy_overlapped_occupied_hex_mouse_click",
		int(setup.get("target_q", -1)),
		int(setup.get("target_r", -1))
	)
	var target_after := int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0))
	var overlap_after := int(_battle_stack_by_id(session.battle, overlap_enemy_id).get("total_health", 0))
	var tooltip_before := String(click.get("tooltip_before", "")).to_lower()
	var expected_tooltip := String(click.get("cell_target_tooltip_before", ""))
	if (
		not bool(click.get("found_enemy_shape_overlap", false))
		or String(click.get("shape_target_before", "")) != overlap_enemy_id
		or String(click.get("shape_target_side_before", "")) != "enemy"
		or String(click.get("cell_target_before", "")) != target_id
		or String(click.get("cell_target_side_before", "")) != "enemy"
		or String(click.get("cell_target_click_action_before", "")) != "shoot"
		or String(click.get("tooltip_before", "")) != expected_tooltip
		or "board click will shoot" not in tooltip_before
		or String(click.get("shape_battle_id", "")) != overlap_enemy_id
		or String(click.get("dispatch", "")) != "stack_hex"
		or not bool(click.get("accepted", false))
		or String(click.get("battle_id", "")) != target_id
		or int(click.get("resolved_q", -1)) != int(setup.get("target_q", -2))
		or int(click.get("resolved_r", -1)) != int(setup.get("target_r", -2))
		or target_after >= target_before
		or overlap_after != overlap_before
	):
		push_error("Battle layout smoke: neighboring enemy token overlap stole a visible occupied enemy hex click at %s: setup=%s click=%s target_before=%d target_after=%d overlap_before=%d overlap_after=%d." % [viewport_size, setup, click, target_before, target_after, overlap_before, overlap_after])
		get_tree().quit(1)
		return false
	return true

func _first_stack_for_side(battle: Dictionary, side: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side and int(stack.get("total_health", 0)) > 0:
			return stack
	return {}

func _battle_stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _ensure_enemy_stack_for_test(battle: Dictionary, source_stack: Dictionary, battle_id: String) -> void:
	if not _battle_stack_by_id(battle, battle_id).is_empty():
		return
	var clone := source_stack.duplicate(true)
	clone["battle_id"] = battle_id
	clone["side"] = "enemy"
	clone["name"] = "%s Blocked Test Target" % String(source_stack.get("name", "Enemy"))
	clone["total_health"] = max(1, int(clone.get("total_health", clone.get("unit_hp", 1))))
	var stacks: Array = battle.get("stacks", [])
	stacks.append(clone)
	battle["stacks"] = stacks

func _ensure_player_stack_for_test(battle: Dictionary, source_stack: Dictionary, battle_id: String) -> void:
	if not _battle_stack_by_id(battle, battle_id).is_empty():
		return
	var clone := source_stack.duplicate(true)
	clone["battle_id"] = battle_id
	clone["side"] = "player"
	clone["name"] = "%s Follow-up Test Stack" % String(source_stack.get("name", "Player"))
	clone["total_health"] = max(1, int(clone.get("total_health", clone.get("unit_hp", 1))))
	var stacks: Array = battle.get("stacks", [])
	stacks.append(clone)
	battle["stacks"] = stacks

func _remove_battle_stack_for_test(battle: Dictionary, battle_id: String) -> void:
	var stacks: Array = battle.get("stacks", [])
	for index in range(stacks.size() - 1, -1, -1):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stacks.remove_at(index)
	battle["stacks"] = stacks

func _enemy_stack_ids_except_for_test(battle: Dictionary, retained_battle_id: String) -> Array[String]:
	var ids: Array[String] = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if String(stack.get("side", "")) == "enemy" and battle_id != retained_battle_id:
			ids.append(battle_id)
	return ids

func _stack_ids_for_side_except_for_test(battle: Dictionary, side: String, retained_battle_id: String) -> Array[String]:
	var ids: Array[String] = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if String(stack.get("side", "")) == side and battle_id != retained_battle_id:
			ids.append(battle_id)
	return ids

func _set_stack_hex_for_test(battle: Dictionary, battle_id: String, hex: Dictionary) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["hex"] = {"q": int(hex.get("q", 0)), "r": int(hex.get("r", 0))}
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _set_stack_health_for_test(battle: Dictionary, battle_id: String, total_health: int) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["total_health"] = max(1, total_health)
		stack["count"] = max(1, int(stack.get("count", 1)))
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _set_stack_combat_profile_for_test(
	battle: Dictionary,
	battle_id: String,
	speed: int,
	ranged: bool,
	abilities: Array
) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["speed"] = max(1, speed)
		stack["ranged"] = ranged
		stack["shots_remaining"] = max(1, int(stack.get("shots_remaining", 1))) if ranged else 0
		stack["abilities"] = abilities.duplicate(true)
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _stack_hex_for_test(stack: Dictionary) -> Dictionary:
	var hex = stack.get("hex", {})
	if hex is Dictionary:
		return {"q": int(hex.get("q", -1)), "r": int(hex.get("r", -1))}
	return {"q": -1, "r": -1}

func _hex_key_for_test(hex: Dictionary) -> String:
	return "%d,%d" % [int(hex.get("q", -1)), int(hex.get("r", -1))]

func _stage_later_attack_destination_for_test(battle: Dictionary, player_id: String, target_id: String) -> Dictionary:
	var active_stack := _battle_stack_by_id(battle, player_id)
	if active_stack.is_empty():
		return {}
	var active_hex := _stack_hex_for_test(active_stack)
	for destination_value in BattleRules.legal_destinations_for_active_stack(battle):
		if not (destination_value is Dictionary):
			continue
		var destination: Dictionary = destination_value
		for neighbor_value in BattleRules._hex_neighbors(destination):
			if not (neighbor_value is Dictionary):
				continue
			var target_hex: Dictionary = neighbor_value
			if _hex_key_for_test(target_hex) == _hex_key_for_test(active_hex):
				continue
			if _hex_occupied_by_other_for_test(battle, target_id, target_hex):
				continue
			_set_stack_hex_for_test(battle, target_id, target_hex)
			battle["selected_target_id"] = target_id
			var selected_legality: Dictionary = BattleRules.selected_target_legality(battle)
			if not bool(selected_legality.get("blocked", false)):
				continue
			var intent: Dictionary = BattleRules.movement_intent_for_destination(
				battle,
				int(destination.get("q", -1)),
				int(destination.get("r", -1))
			)
			if bool(intent.get("sets_up_selected_target_attack", false)):
				return {
					"destination": destination,
					"target_hex": target_hex,
					"intent": intent,
				}
	return {}

func _open_neighbor_for_test(battle: Dictionary, origin: Dictionary, forbidden_keys: Array = []) -> Dictionary:
	for neighbor_value in BattleRules._hex_neighbors(origin):
		if not (neighbor_value is Dictionary):
			continue
		var neighbor: Dictionary = neighbor_value
		var key := _hex_key_for_test(neighbor)
		if key in forbidden_keys:
			continue
		if _hex_occupied_by_other_for_test(battle, "", neighbor):
			continue
		return neighbor
	return {}

func _far_open_hex_for_test(battle: Dictionary, origin: Dictionary, min_distance: int) -> Dictionary:
	var candidates := [
		{"q": 0, "r": 0},
		{"q": 0, "r": 6},
		{"q": 10, "r": 0},
		{"q": 10, "r": 6},
		{"q": 1, "r": 3},
		{"q": 9, "r": 3},
	]
	for candidate in candidates:
		if BattleRules._hex_distance(candidate, origin) < min_distance:
			continue
		if _hex_occupied_by_other_for_test(battle, "", candidate):
			continue
		return candidate
	return {}

func _invalid_empty_destination_hex_for_test(battle: Dictionary) -> Dictionary:
	var active_stack := BattleRules.get_active_stack(battle)
	var active_hex := _stack_hex_for_test(active_stack)
	var legal_keys := {}
	for destination_value in BattleRules.legal_destinations_for_active_stack(battle):
		if destination_value is Dictionary:
			legal_keys[_hex_key_for_test(destination_value)] = true
	var best := {}
	var best_distance := -1
	for r in range(7):
		for q in range(11):
			var candidate := {"q": q, "r": r}
			var key := _hex_key_for_test(candidate)
			if legal_keys.has(key) or _hex_occupied_by_other_for_test(battle, "", candidate):
				continue
			var intent := BattleRules.movement_intent_for_destination(battle, q, r)
			if String(intent.get("action", "")) == "move" or not bool(intent.get("blocked", false)):
				continue
			var distance := BattleRules._hex_distance(active_hex, candidate)
			if best.is_empty() or distance > best_distance:
				best = candidate
				best_distance = distance
	return best

func _hex_occupied_by_other_for_test(battle: Dictionary, allowed_battle_id: String, hex: Dictionary) -> bool:
	var key := _hex_key_for_test(hex)
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or int(stack.get("total_health", 0)) <= 0:
			continue
		if String(stack.get("battle_id", "")) == allowed_battle_id:
			continue
		if _hex_key_for_test(_stack_hex_for_test(stack)) == key:
			return true
	return false

func _unique_target_count(primary: Array, secondary: Array) -> int:
	var seen := {}
	for value in primary:
		seen[String(value)] = true
	for value in secondary:
		seen[String(value)] = true
	return seen.size()

func _stack_cell_entry(stack_cells: Array, battle_id: String) -> Dictionary:
	for cell_value in stack_cells:
		if cell_value is Dictionary and String(cell_value.get("battle_id", "")) == battle_id:
			return cell_value
	return {}
