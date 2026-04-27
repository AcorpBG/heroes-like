extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_town_smoke():
		return
	if not await _run_battle_smoke():
		return
	get_tree().quit(0)

func _run_town_smoke() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		push_error("Town smoke: could not find a player-owned town in the sample scenario.")
		get_tree().quit(1)
		return false
	_move_active_hero_to_town(session, active_town)
	_seed_town_artifact_readiness_fixture(session)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var board = shell.get_node_or_null("%TownStage")
	if board == null:
		push_error("Town smoke: town stage board did not load.")
		get_tree().quit(1)
		return false

	var build_actions = shell.get_node_or_null("%BuildActions")
	if build_actions == null or build_actions.get_child_count() <= 0:
		push_error("Town smoke: construction action surface did not populate.")
		get_tree().quit(1)
		return false
	if not _assert_town_production_overview(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_build_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_trade_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_faction_identity_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_stack_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_hero_identity_progression_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_magic_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_study_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_artifact_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_build_recruit_next_step_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_field_handoff_recap_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_departure_confirmation_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_save_handoff_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_order_target_handoff_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_command_tab_readiness_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_muster_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_action_button_command_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_active_return_handoff_contract(shell, "Town", "Menu: Town"):
		get_tree().quit(1)
		return false
	if not _assert_town_economy_decision_payload(shell):
		get_tree().quit(1)
		return false

	var town_return_handoff: Dictionary = shell.call("validation_prepare_town_return_handoff")
	if not _assert_town_return_handoff_payload(town_return_handoff):
		get_tree().quit(1)
		return false
	shell.queue_free()
	await get_tree().process_frame
	if not await _assert_overworld_town_return_handoff(session, town_return_handoff):
		get_tree().quit(1)
		return false
	return true

func _run_battle_smoke() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter = _first_encounter(session)
	if encounter.is_empty():
		push_error("Battle smoke: could not find an encounter in the sample scenario.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var board = shell.get_node_or_null("%BattleBoard")
	if board == null:
		push_error("Battle smoke: battle board did not load.")
		get_tree().quit(1)
		return false
	if not _assert_battle_entry_context(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_stack_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_magic_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not board.has_method("validation_hex_layout_summary"):
		push_error("Battle smoke: battle board does not expose hex layout validation.")
		get_tree().quit(1)
		return false
	if not board.has_method("validation_terrain_rendering_summary"):
		push_error("Battle smoke: battle board does not expose terrain rendering validation.")
		get_tree().quit(1)
		return false
	var hex_summary: Dictionary = board.call("validation_hex_layout_summary")
	if String(hex_summary.get("presentation", "")) != "hex":
		push_error("Battle smoke: battle board did not render through the hex-field presentation.")
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("terrain_texture_loaded", false)):
		push_error("Battle smoke: terrain texture was not loaded for the active battlefield: %s." % hex_summary)
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("terrain_hex_snapped", false)) or bool(hex_summary.get("terrain_single_board_backdrop", true)):
		push_error("Battle smoke: terrain texture rendering is not snapped to the hex grid: %s." % hex_summary)
		get_tree().quit(1)
		return false
	var terrain_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if not bool(terrain_summary.get("texture_loaded", false)) or float(terrain_summary.get("texture_width", 0.0)) <= 0.0 or float(terrain_summary.get("texture_height", 0.0)) <= 0.0:
		push_error("Battle smoke: terrain rendering validation did not report a usable runtime texture: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("rendering_mode", "")) != "hex_snapped_texture" or not bool(terrain_summary.get("hex_snapped", false)) or bool(terrain_summary.get("single_board_backdrop", true)):
		push_error("Battle smoke: terrain texture is not using the hex-snapped rendering path: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if not bool(terrain_summary.get("texture_visible", false)) or bool(terrain_summary.get("grid_repaints_texture_cells", true)):
		push_error("Battle smoke: terrain texture visibility is still being buried by the tactical grid pass: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("grid_fill_mode", "")) != "texture_transparent_tactical_tint" or float(terrain_summary.get("grid_max_fill_alpha", 1.0)) > 0.05:
		push_error("Battle smoke: textured battlefield grid fills are too opaque for the terrain art: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("grid_border_mode", "")) != "deduplicated_texture_grid" or not bool(terrain_summary.get("grid_border_deduplicated", false)):
		push_error("Battle smoke: textured battlefield grid borders are not using the cleaned single-border path: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if int(terrain_summary.get("hex_tile_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle smoke: terrain texture tile count does not match the tactical hex count: terrain=%s hex=%s." % [terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	if float(terrain_summary.get("source_tile_width", 0.0)) <= 0.0 or float(terrain_summary.get("source_tile_height", 0.0)) <= 0.0:
		push_error("Battle smoke: terrain texture did not expose a usable per-hex source sample size: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("texture_uv_space", "")) != "normalized_0_1" or not bool(terrain_summary.get("texture_uv_within_0_1", false)):
		push_error("Battle smoke: terrain texture UV sampling is not normalized for draw_polygon: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if not bool(terrain_summary.get("texture_source_within_texture", false)) or int(terrain_summary.get("texture_source_sample_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle smoke: terrain texture source samples do not stay inside the runtime texture: terrain=%s hex=%s." % [terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	if float(terrain_summary.get("texture_uv_min_x", -1.0)) < 0.0 or float(terrain_summary.get("texture_uv_min_y", -1.0)) < 0.0 or float(terrain_summary.get("texture_uv_max_x", 2.0)) > 1.0 or float(terrain_summary.get("texture_uv_max_y", 2.0)) > 1.0:
		push_error("Battle smoke: terrain texture normalized UV range is outside 0..1: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	var original_terrain := String(session.battle.get("terrain", ""))
	session.battle["terrain"] = "plains"
	board.call("set_battle_state", session)
	await get_tree().process_frame
	var plains_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if String(plains_summary.get("texture_id", "")) != "grass" or not bool(plains_summary.get("texture_loaded", false)) or not bool(plains_summary.get("mapped", false)) or String(plains_summary.get("rendering_mode", "")) != "hex_snapped_texture":
		push_error("Battle smoke: plains terrain did not map cleanly to the grass battlefield texture: %s." % plains_summary)
		get_tree().quit(1)
		return false
	session.battle["terrain"] = "validation_missing_texture"
	board.call("set_battle_state", session)
	await get_tree().process_frame
	var missing_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if bool(missing_summary.get("texture_loaded", true)) or not bool(missing_summary.get("fallback", false)) or String(missing_summary.get("rendering_mode", "")) != "hex_snapped_color_fallback" or not bool(missing_summary.get("hex_snapped", false)) or bool(missing_summary.get("single_board_backdrop", true)):
		push_error("Battle smoke: missing terrain texture did not fall back to hex-snapped color/detail rendering: %s." % missing_summary)
		get_tree().quit(1)
		return false
	if String(missing_summary.get("grid_fill_mode", "")) != "fallback_readability_fill" or float(missing_summary.get("grid_max_fill_alpha", 0.0)) <= 0.10:
		push_error("Battle smoke: missing terrain texture fallback lost its readable tactical grid fills: %s." % missing_summary)
		get_tree().quit(1)
		return false
	session.battle["terrain"] = original_terrain
	board.call("set_battle_state", session)
	await get_tree().process_frame
	if int(hex_summary.get("hex_count", 0)) < 70:
		push_error("Battle smoke: hex battlefield is too small to be a proper tactical surface: %s." % hex_summary)
		get_tree().quit(1)
		return false
	if int(hex_summary.get("player_stack_count", 0)) <= 0 or int(hex_summary.get("enemy_stack_count", 0)) <= 0:
		push_error("Battle smoke: both armies must have on-field stacks in the hex presentation: %s." % hex_summary)
		get_tree().quit(1)
		return false
	var expected_stack_count := int(hex_summary.get("player_stack_count", 0)) + int(hex_summary.get("enemy_stack_count", 0))
	var occupied_hexes: Dictionary = hex_summary.get("occupied_hexes", {})
	if occupied_hexes.size() != expected_stack_count:
		push_error("Battle smoke: occupied hex map did not match the on-field stacks: %s." % hex_summary)
		get_tree().quit(1)
		return false

	var recent_before: int = int(session.battle.get("recent_events", []).size())
	var active_stack := BattleRules.get_active_stack(session.battle)
	if not active_stack.is_empty() and String(active_stack.get("side", "")) != "player":
		var guard := 0
		while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
			BattleRules.advance_turn(session.battle)
			guard += 1
		shell._refresh()
		await get_tree().process_frame
	if not _assert_battle_ability_status_action_consequence_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_exit_order_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_target_cycle_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_initiative_handoff_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_command_tab_readiness_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_save_handoff_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_active_return_handoff_contract(shell, "Battle", "Menu: Battle"):
		get_tree().quit(1)
		return false

	var defend_button = shell.get_node_or_null("%Defend")
	if defend_button == null:
		push_error("Battle smoke: defend action button did not load.")
		get_tree().quit(1)
		return false
	var post_action_response := {}
	if not defend_button.disabled:
		post_action_response = shell.call("validation_perform_action", "defend")
		await get_tree().process_frame
		if not _assert_battle_post_action_status_recap_contract(shell, post_action_response):
			get_tree().quit(1)
			return false

	var recent_after: int = int(session.battle.get("recent_events", []).size())
	if recent_after < recent_before:
		push_error("Battle smoke: recent event feed regressed after action refresh.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	if not await _assert_battle_aftermath_transition(session):
		get_tree().quit(1)
		return false
	return true

func _assert_active_return_handoff_contract(shell: Node, expected_target: String, expected_button_label: String) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("%s smoke: shell does not expose return handoff validation snapshot." % expected_target)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("return_handoff", "")),
		String(save_surface.get("menu_button_label", "")),
		String(save_surface.get("menu_button_tooltip", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Return handoff:", "Continue Latest returns", expected_target, "preserved", expected_button_label]:
		if not handoff_text.contains(token):
			push_error("%s smoke: active return handoff lost %s clarity: %s." % [expected_target, token, handoff_text])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("%s smoke: active return handoff leaked internal token %s: %s." % [expected_target, leak_token, handoff_text])
			return false
	return true

func _assert_town_save_handoff_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose save-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("save_handoff", "")),
		String(save_surface.get("save_handoff_brief", "")),
		String(snapshot.get("save_handoff_visible_text", "")),
		String(snapshot.get("save_button_text", "")),
		String(snapshot.get("save_button_tooltip_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Save handoff:", "Manual", "Town Resume", "Load Selected", "reopens", "preserved", "Save Town"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: save handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if not bool(snapshot.get("save_handoff_visible", false)):
		push_error("Town smoke: save handoff cue is not visible in the town footer: %s." % handoff_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: save handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_battle_save_handoff_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell does not expose save-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("save_handoff", "")),
		String(save_surface.get("save_handoff_brief", "")),
		String(snapshot.get("save_handoff_visible_text", "")),
		String(snapshot.get("save_button_text", "")),
		String(snapshot.get("save_button_tooltip_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Save handoff:", "Manual", "Battle Resume", "Load Selected", "reopens", "preserved", "Save Battle"]:
		if not handoff_text.contains(token):
			push_error("Battle smoke: save handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if not bool(snapshot.get("save_handoff_visible", false)) or not String(snapshot.get("save_handoff_visible_text", "")).contains("Save handoff:"):
		push_error("Battle smoke: save handoff cue is not visible in the battle footer: %s." % handoff_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Battle smoke: save handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_town_command_tab_readiness_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose command-tab readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("town_tab_readiness", {}) if snapshot.get("town_tab_readiness", {}) is Dictionary else {}
	var titles: Array = snapshot.get("town_tab_titles", []) if snapshot.get("town_tab_titles", []) is Array else []
	var tabs: Array = readiness.get("tabs", []) if readiness.get("tabs", []) is Array else []
	var cue_text := "\n".join([
		" ".join(titles),
		String(snapshot.get("town_tab_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Build", "Muster", "Spells", "Trade", "Log", "Town command tabs:", "Selected:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: command-tab readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if tabs.size() != 5:
		push_error("Town smoke: command-tab readiness payload should cover five town tabs: %s." % readiness)
		return false
	var ready_title_found := false
	for tab in tabs:
		if tab is Dictionary and int(tab.get("ready_count", 0)) > 0 and String(tab.get("title", "")).contains(str(int(tab.get("ready_count", 0)))):
			ready_title_found = true
			break
	if not ready_title_found:
		push_error("Town smoke: no actionable tab exposed a visible ready count: titles=%s readiness=%s." % [titles, readiness])
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: command-tab readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_battle_command_tab_readiness_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell does not expose command-tab readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("battle_tab_readiness", {}) if snapshot.get("battle_tab_readiness", {}) is Dictionary else {}
	var titles: Array = snapshot.get("battle_tab_titles", []) if snapshot.get("battle_tab_titles", []) is Array else []
	var tabs: Array = readiness.get("tabs", []) if readiness.get("tabs", []) is Array else []
	var cue_text := "\n".join([
		" ".join(titles),
		String(snapshot.get("battle_tab_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Order", "Focus", "Spells", "Timing", "Battle command tabs:", "Selected:"]:
		if not cue_text.contains(token):
			push_error("Battle smoke: command-tab readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if tabs.size() != 4:
		push_error("Battle smoke: command-tab readiness payload should cover four battle tabs: %s." % readiness)
		return false
	var ready_title_found := false
	for tab in tabs:
		if tab is Dictionary and int(tab.get("ready_count", 0)) > 0 and String(tab.get("title", "")).contains(str(int(tab.get("ready_count", 0)))):
			ready_title_found = true
			break
	if not ready_title_found:
		push_error("Battle smoke: no actionable tab exposed a visible ready count: titles=%s readiness=%s." % [titles, readiness])
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Battle smoke: command-tab readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_action_button_command_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose action-button command cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var tooltip_payload: Dictionary = snapshot.get("town_action_button_tooltips", {}) if snapshot.get("town_action_button_tooltips", {}) is Dictionary else {}
	var all_text_lines := []
	var lanes_with_cues := []
	for lane in tooltip_payload.keys():
		var entries: Array = tooltip_payload.get(lane, []) if tooltip_payload.get(lane, []) is Array else []
		for entry in entries:
			if not (entry is Dictionary):
				continue
			var tooltip := String(entry.get("tooltip", ""))
			all_text_lines.append("%s %s %s" % [
				String(lane),
				String(entry.get("text", "")),
				tooltip,
			])
			if tooltip.contains("Command cue:") and tooltip.contains("Next:"):
				lanes_with_cues.append(String(lane))
	var all_text := "\n".join(all_text_lines)
	for token in ["Command cue:", "Next:", "Build tab", "Muster tab"]:
		if not all_text.contains(token):
			push_error("Town smoke: action-button command cues lost %s clarity: %s." % [token, all_text])
			return false
	if not lanes_with_cues.has("build") or not lanes_with_cues.has("recruit"):
		push_error("Town smoke: build and recruit buttons should expose command cues: lanes=%s payload=%s." % [lanes_with_cues, tooltip_payload])
		return false
	if all_text.find("Ready") < 0 and all_text.find("Blocked") < 0 and all_text.find("Needs exchange") < 0:
		push_error("Town smoke: action-button command cues do not expose readiness state: %s." % all_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if all_text.contains(leak_token):
			push_error("Town smoke: action-button command cue leaked internal token %s: %s." % [leak_token, all_text])
			return false
	return true

func _assert_town_muster_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose muster-readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("muster_readiness", {}) if snapshot.get("muster_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("muster_readiness_visible_text", "")),
		String(snapshot.get("muster_readiness_tooltip_text", "")),
		String(snapshot.get("recruit_visible_text", "")),
		String(snapshot.get("recruit_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("cap_line", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Muster check:", "Muster Readiness", "Town reserve:", "Best order:", "Best cap:", "Readiness:", "Why it matters:", "Next practical action:", "Recruit Reserves"]:
		if not text.contains(token):
			push_error("Town smoke: muster readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("reserve_total", -1)) < 0 or int(readiness.get("ready_order_count", -1)) < 0:
		push_error("Town smoke: muster readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if int(readiness.get("best_order_available_count", -1)) < 0 or int(readiness.get("best_order_direct_count", -1)) < 0 or int(readiness.get("best_order_market_count", -1)) < 0:
		push_error("Town smoke: muster cap cue did not expose stable selected-order counts: %s." % readiness)
		return false
	if not (
		text.contains("can field")
		or text.contains("can unlock")
		or text.contains("stores field 0")
		or text.contains("No recruit stack")
		or text.contains("no reserve waiting")
	):
		push_error("Town smoke: muster cap cue does not explain fieldable versus waiting reserves: %s." % readiness)
		return false
	if (
		int(readiness.get("ready_units", 0)) <= 0
		and int(readiness.get("market_units", 0)) <= 0
		and int(readiness.get("blocked_reserve", 0)) <= 0
		and not String(readiness.get("visible_text", "")).contains("no recruits waiting")
	):
		push_error("Town smoke: muster readiness cue does not explain ready, trade, blocked, or empty state: %s." % readiness)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: muster readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_battle_post_action_status_recap_contract(shell: Node, action_response: Dictionary) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose post-action validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var response_recap: Dictionary = action_response.get("post_action_recap", {}) if action_response.get("post_action_recap", {}) is Dictionary else {}
	var snapshot_recap: Dictionary = snapshot.get("post_action_recap", {}) if snapshot.get("post_action_recap", {}) is Dictionary else {}
	var recap_text := "\n".join([
		String(action_response.get("post_action_recap_text", "")),
		String(snapshot.get("post_action_recap_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
	])
	var context: Dictionary = snapshot.get("battle_action_context", {}) if snapshot.get("battle_action_context", {}) is Dictionary else {}
	var context_text := "\n".join([
		String(snapshot.get("battle_action_context_text", "")),
		String(snapshot.get("battle_action_context_tooltip_text", "")),
		String(snapshot.get("event_visible_text", "")),
		String(snapshot.get("event_tooltip_text", "")),
		String(context.get("latest_action", "")),
		String(context.get("next_step", "")),
		String(context.get("handoff_check", "")),
	])
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var save_text := "\n".join([
		String(save_surface.get("save_check", "")),
		String(save_surface.get("current_save_recap", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["After order:", "Affected:", "Why it matters:", "Next:"]:
		if not recap_text.contains(token):
			push_error("Battle smoke: post-action recap lost %s clarity: response=%s snapshot=%s text=%s." % [token, action_response, snapshot_recap, recap_text])
			return false
	for token in ["Save check:", "What changed:", "Resume:", "Next:"]:
		if not save_text.contains(token):
			push_error("Battle smoke: save continuity check lost %s clarity after a battle order: %s." % [token, save_text])
			return false
	for token in ["Latest:", "Next:", "Battle Turn Context", "Latest action:", "Next practical step:", "Handoff check:"]:
		if not context_text.contains(token):
			push_error("Battle smoke: battle action context strip lost %s clarity: context=%s snapshot=%s." % [token, context_text, snapshot])
			return false
	if String(context.get("source", "")) != "post_action_recap":
		push_error("Battle smoke: battle action context strip did not use the post-action recap source: %s." % context)
		return false
	if not String(snapshot.get("event_visible_text", "")).contains("Latest:"):
		push_error("Battle smoke: battle action context strip is not visible in the dispatch rail: %s." % snapshot)
		return false
	for key in ["happened", "affected", "why_it_matters", "next_step", "decision", "next_actor", "text"]:
		if String(response_recap.get(key, "")) == "" or String(snapshot_recap.get(key, "")) == "":
			push_error("Battle smoke: post-action recap payload is missing %s: response=%s snapshot=%s." % [key, response_recap, snapshot_recap])
			return false
	var action_tooltips := "\n".join([
		String(snapshot.get("advance_tooltip", "")),
		String(snapshot.get("strike_tooltip", "")),
		String(snapshot.get("shoot_tooltip", "")),
		String(snapshot.get("defend_tooltip", "")),
	])
	if not action_tooltips.contains("Last order:") or not action_tooltips.contains("acts now"):
		push_error("Battle smoke: action tooltips did not carry the post-action next-actor recap: %s." % action_tooltips)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "ai_score", "weight"]:
		if recap_text.contains(leak_token) or context_text.contains(leak_token) or action_tooltips.contains(leak_token) or save_text.contains(leak_token):
			push_error("Battle smoke: post-action recap leaked internal token %s." % leak_token)
			return false
	return true

func _assert_battle_entry_context(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose validation snapshot.")
		return false
	var battle_context_label: Label = shell.get_node_or_null("%BattleContext")
	if battle_context_label == null:
		push_error("Battle smoke: battle entry context label did not load.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var entry_context := String(snapshot.get("entry_context", ""))
	var visible_context := String(battle_context_label.text)
	if not entry_context.contains("Matchup:") or not entry_context.contains("Forces:") or not entry_context.contains("Stakes:"):
		push_error("Battle smoke: entry context did not expose matchup, force, and stakes lines: %s." % entry_context)
		return false
	if not entry_context.contains("Commanders:") or not entry_context.contains("Lyra Emberwell") or not entry_context.contains("Embercourt League"):
		push_error("Battle smoke: entry context did not expose commander identity context: %s." % entry_context)
		return false
	if not entry_context.contains("Blackbranch Raiders") or not entry_context.contains("Difficulty Low"):
		push_error("Battle smoke: entry context did not expose enemy force identity and encounter difficulty: %s." % entry_context)
		return false
	if not entry_context.contains("Friendly") or not entry_context.contains("Enemy") or not entry_context.contains("Reward"):
		push_error("Battle smoke: entry context did not expose army framing and reward context: %s." % entry_context)
		return false
	if not visible_context.contains("Matchup:") or battle_context_label.tooltip_text != entry_context:
		push_error("Battle smoke: live battle entry label is not carrying the validation entry context: visible=%s tooltip=%s snapshot=%s." % [visible_context, battle_context_label.tooltip_text, entry_context])
		return false
	var player_commander := String(snapshot.get("player_commander_text", ""))
	if not player_commander.contains("Lyra Emberwell") or not player_commander.contains("Fast scouting caster") or not player_commander.contains("Lv1") or not player_commander.contains("XP 0/250") or not player_commander.contains("Wayfinder I"):
		push_error("Battle smoke: player commander summary did not expose hero identity and progression context: %s." % player_commander)
		return false
	if not player_commander.contains("Gear impact:") or not player_commander.contains("Command no equipped battle bonuses"):
		push_error("Battle smoke: player commander summary did not expose equipment impact context: %s." % player_commander)
		return false
	return true

func _assert_town_hero_identity_progression_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing hero identity validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var town_hero_text := "%s\n%s\n%s" % [
		String(snapshot.get("hero_text", "")),
		String(snapshot.get("hero_tooltip_text", "")),
		String(snapshot.get("heroes_text", "")),
	]
	var town_artifact_text := "%s\n%s" % [
		String(snapshot.get("artifact_text", "")),
		String(snapshot.get("artifact_tooltip_text", "")),
	]
	if not town_hero_text.contains("Lyra Emberwell") or not town_hero_text.contains("Embercourt League") or not town_hero_text.contains("Fast scouting caster"):
		push_error("Town smoke: hero panel did not expose hero identity/faction/role context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Lv1") or not town_hero_text.contains("XP 0/250") or not town_hero_text.contains("Wayfinder I"):
		push_error("Town smoke: hero panel did not expose progression and specialty context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Move") or not town_hero_text.contains("Scout") or not town_hero_text.contains("Army"):
		push_error("Town smoke: hero panel did not expose readiness and army command context: %s." % town_hero_text)
		return false
	if not town_artifact_text.contains("Gear impact:") or not town_artifact_text.contains("Collection:"):
		push_error("Town smoke: artifact panel did not expose equipment impact and collection context: %s." % town_artifact_text)
		return false
	return true

func _assert_town_faction_identity_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell is missing faction identity validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var identity_text := "\n".join([
		String(snapshot.get("summary", "")),
		String(snapshot.get("production_overview", "")),
	])
	for token in [
		"Identity:",
		"Riverwatch Hold",
		"Embercourt League",
		"Frontier Stronghold",
		"Economy:",
		"Stable civic investment",
		"Magic:",
		"Strategic cue:",
		"Braced lines",
	]:
		if not identity_text.contains(token):
			push_error("Town smoke: town identity surface is missing %s: %s." % [token, identity_text])
			return false
	for leak_token in ["build_category_weights", "raid_target_weights", "final_priority", "debug_reason"]:
		if identity_text.contains(leak_token):
			push_error("Town smoke: town identity surface leaked internal strategy token %s: %s." % [leak_token, identity_text])
			return false
	return true

func _assert_town_magic_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing magic inspection validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var magic_text := "\n".join([
		String(snapshot.get("study_text", "")),
		String(snapshot.get("study_tooltip_text", "")),
		String(snapshot.get("spellbook_text", "")),
		String(snapshot.get("spellbook_tooltip_text", "")),
	])
	for token in ["Spell Study", "Spellbook", "Waystride", "Field Route", "Cinder Burst", "Battle Strike", "Cost", "Ready mana", "Use:"]:
		if not magic_text.contains(token):
			push_error("Town smoke: magic panels lost practical spellbook token %s: %s." % [token, magic_text])
			return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var study_actions: Array = catalog.get("study", [])
	if study_actions.is_empty():
		return true
	for action in study_actions:
		if action is Dictionary:
			var payload := "%s\n%s\n%s" % [
				String(action.get("label", "")),
				String(action.get("category", "")),
				String(action.get("summary", "")),
			]
			if payload.contains("Cost") and payload.contains("Use:") and (payload.contains("Battle ") or payload.contains("Field ")):
				return true
	push_error("Town smoke: study actions do not expose compact category/cost/effect/use payloads: %s." % study_actions)
	return false

func _assert_town_study_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing study-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("study_readiness", {}) if snapshot.get("study_readiness", {}) is Dictionary else {}
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var study_actions: Array = catalog.get("study", []) if catalog.get("study", []) is Array else []
	var cue_text := "\n".join([
		String(snapshot.get("study_visible_text", "")),
		String(snapshot.get("study_tooltip_text", "")),
		String(snapshot.get("study_readiness_visible_text", "")),
		String(snapshot.get("study_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Study check:", "Study Readiness", "Archive tier:", "Catalog:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: study readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	var ready_count := int(readiness.get("ready_order_count", -1))
	var accessible_count := int(readiness.get("accessible_count", -1))
	if ready_count != study_actions.size():
		push_error("Town smoke: study readiness count does not match visible study actions: readiness=%s actions=%s." % [readiness, study_actions])
		return false
	if accessible_count < ready_count:
		push_error("Town smoke: study readiness accessible count is smaller than learnable actions: readiness=%s." % readiness)
		return false
	if ready_count > 0 and not cue_text.contains("Learn "):
		push_error("Town smoke: study readiness cue did not name a learnable spell order: %s." % cue_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: study readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_artifact_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing artifact-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("artifact_readiness", {}) if snapshot.get("artifact_readiness", {}) is Dictionary else {}
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var artifact_actions: Array = catalog.get("artifact", []) if catalog.get("artifact", []) is Array else []
	var cue_text := "\n".join([
		String(snapshot.get("artifact_visible_text", "")),
		String(snapshot.get("artifact_tooltip_text", "")),
		String(snapshot.get("artifact_readiness_visible_text", "")),
		String(snapshot.get("artifact_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Gear check:", "Gear Readiness", "Loadout:", "Collection:", "Gear orders:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: artifact readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if int(readiness.get("ready_order_count", -1)) <= 0 or int(readiness.get("listed_order_count", -1)) != artifact_actions.size():
		push_error("Town smoke: artifact readiness counts do not match visible artifact orders: readiness=%s actions=%s." % [readiness, artifact_actions])
		return false
	if int(readiness.get("pack_count", -1)) <= 0 or int(readiness.get("owned_count", -1)) <= 0:
		push_error("Town smoke: artifact readiness did not expose owned pack state: %s." % readiness)
		return false
	if not cue_text.contains("Equip Trailsinger Boots") or not cue_text.contains("Ready now"):
		push_error("Town smoke: artifact readiness cue did not name the ready gear order: %s." % cue_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: artifact readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_battle_stack_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var roster_text := "\n".join(snapshot.get("player_roster", [])) + "\n" + "\n".join(snapshot.get("enemy_roster", []))
	for token in ["Strength", "HP", "T", "Ready", "Atk", "Coh"]:
		if not roster_text.contains(token):
			push_error("Battle smoke: stack rosters lost compact inspection token %s: %s." % [token, roster_text])
			return false
	return true

func _assert_battle_aftermath_transition(source_session) -> bool:
	var outcome_session = _clone_session(source_session)
	if outcome_session.battle.is_empty():
		push_error("Battle smoke: aftermath transition coverage needs an active battle payload.")
		return false
	var stacks = outcome_session.battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			stacks[index] = stack
	outcome_session.battle["stacks"] = stacks
	var result: Dictionary = BattleRules.resolve_if_battle_ready(outcome_session)
	if String(result.get("state", "")) != "victory":
		push_error("Battle smoke: aftermath transition did not resolve the live battle payload into victory: %s." % result)
		return false
	var report: Dictionary = outcome_session.flags.get("last_battle_aftermath", {})
	if "Rewards:" not in String(report.get("reward_summary", "")) or "xp" not in String(report.get("reward_summary", "")):
		push_error("Battle smoke: aftermath report did not expose compact rewards and experience: %s." % report)
		return false
	if "Forces:" not in String(report.get("force_summary", "")) or "Enemy defeated" not in String(report.get("force_summary", "")):
		push_error("Battle smoke: aftermath report did not expose surviving and defeated forces: %s." % report)
		return false
	if "Overworld:" not in String(report.get("world_summary", "")) or String(report.get("return_summary", "")) == "":
		push_error("Battle smoke: aftermath report did not expose the post-battle overworld transition: %s." % report)
		return false
	if outcome_session.scenario_status != "in_progress":
		return true

	SessionState.set_active_session(outcome_session)
	var overworld_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not overworld_shell.has_method("validation_snapshot"):
		push_error("Battle smoke: overworld shell does not expose validation snapshot for post-battle transition.")
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var snapshot: Dictionary = overworld_shell.call("validation_snapshot")
	var event_tooltip := String(snapshot.get("event_tooltip_text", ""))
	var feedback: Dictionary = snapshot.get("action_feedback", {})
	var feedback_text := String(feedback.get("full_text", feedback.get("text", "")))
	var return_recap_text := "%s\n%s" % [event_tooltip, feedback_text]
	overworld_shell.queue_free()
	await get_tree().process_frame
	if not return_recap_text.contains("Rewards:") or not return_recap_text.contains("Forces:") or not return_recap_text.contains("Overworld:"):
		push_error("Battle smoke: overworld return notice did not expose reward, force, and transition clarity: %s." % snapshot)
		return false
	for token in ["Handoff:", "Affected:", "Why it matters:", "Next practical action:"]:
		if not return_recap_text.contains(token):
			push_error("Battle smoke: overworld return notice lost battle handoff token %s: %s." % [token, snapshot])
			return false
	if String(feedback.get("kind", "")) != "battle" or not feedback_text.contains("Forces:"):
		push_error("Battle smoke: post-battle action feedback did not surface as a battle recap: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "ai_score", "weight"]:
		if return_recap_text.contains(leak_token):
			push_error("Battle smoke: battle handoff recap leaked internal token %s." % leak_token)
			return false
	return true

func _clone_session(session):
	var clone = SessionState.new_session_data()
	clone.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(clone)
	if not clone.battle.is_empty():
		BattleRules.normalize_battle_state(clone)
	return clone

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _seed_town_artifact_readiness_fixture(session) -> void:
	var artifact_id := "artifact_trailsinger_boots"
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		var artifacts := ArtifactRules.normalize_hero_artifacts(active_hero.get("artifacts", {}))
		var inventory: Array = artifacts.get("inventory", []) if artifacts.get("inventory", []) is Array else []
		if artifact_id not in inventory:
			inventory.append(artifact_id)
		artifacts["inventory"] = inventory
		active_hero["artifacts"] = ArtifactRules.normalize_hero_artifacts(artifacts)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["artifacts"] = session.overworld.get("hero", {}).get("artifacts", {})
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _assert_town_economy_decision_payload(shell: Node) -> bool:
	if not shell.has_method("validation_action_catalog") or not shell.has_method("validation_try_progress_action"):
		push_error("Town smoke: town shell does not expose action catalog validation hooks.")
		return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var build_actions: Array = catalog.get("build", [])
	if build_actions.is_empty():
		push_error("Town smoke: town action catalog did not expose build actions.")
		return false
	var build_surface_ok := false
	for action in build_actions:
		if not (action is Dictionary):
			continue
		var summary := String(action.get("summary", ""))
		var affordability := String(action.get("affordability_label", ""))
		if summary.contains("Cost ") and (summary.contains("Ready:") or summary.contains("Blocked:") or summary.contains("Needs exchange:")) and affordability != "":
			build_surface_ok = true
		if bool(action.get("disabled", false)) and String(action.get("disabled_reason", "")) == "":
			push_error("Town smoke: disabled build action is missing an economy disabled reason: %s." % action)
			return false
	if not build_surface_ok:
		push_error("Town smoke: build actions do not explain cost readiness in their live tooltip payload: %s." % build_actions)
		return false

	var recruit_actions: Array = catalog.get("recruit", [])
	if recruit_actions.is_empty():
		push_error("Town smoke: town action catalog did not expose recruit actions.")
		return false
	var recruit_surface_ok := false
	for action in recruit_actions:
		if not (action is Dictionary):
			continue
		var summary := String(action.get("summary", ""))
		if summary.contains("Weekly +") and summary.contains("Cost ") and String(action.get("affordability_label", "")) != "":
			recruit_surface_ok = true
		if bool(action.get("disabled", false)) and String(action.get("disabled_reason", "")) == "":
			push_error("Town smoke: disabled recruit action is missing an economy disabled reason: %s." % action)
			return false
	if not recruit_surface_ok:
		push_error("Town smoke: recruit actions do not explain weekly growth, cost, and affordability in their live payload: %s." % recruit_actions)
		return false

	var progress: Dictionary = shell.call("validation_try_progress_action")
	if not bool(progress.get("ok", false)):
		push_error("Town smoke: validation town economy action did not change state: %s." % progress)
		return false
	var message := String(progress.get("message", ""))
	if not message.contains("Spent ") or (not message.contains("remain in town reserve") and not message.contains("Daily income now") and not message.contains("Weekly muster")):
		push_error("Town smoke: economy action feedback did not explain spend plus the visible town/field outcome: %s." % progress)
		return false
	if not _assert_town_post_action_consequence_contract(shell, progress):
		return false
	return true

func _assert_town_post_action_consequence_contract(shell: Node, action_response: Dictionary) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell does not expose post-action validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var response_recap: Dictionary = action_response.get("town_action_recap", {}) if action_response.get("town_action_recap", {}) is Dictionary else {}
	var snapshot_recap: Dictionary = snapshot.get("town_action_recap", {}) if snapshot.get("town_action_recap", {}) is Dictionary else {}
	var context: Dictionary = snapshot.get("town_action_context", {}) if snapshot.get("town_action_context", {}) is Dictionary else {}
	var recap_text := "\n".join([
		String(action_response.get("town_action_recap_text", "")),
		String(snapshot.get("town_action_recap_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
	])
	var context_text := "\n".join([
		String(snapshot.get("town_action_context_text", "")),
		String(snapshot.get("town_action_context_tooltip_text", "")),
		String(context.get("latest_action", "")),
		String(context.get("next_step", "")),
		String(context.get("handoff_check", "")),
	])
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var save_text := "\n".join([
		String(save_surface.get("save_check", "")),
		String(save_surface.get("current_save_recap", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["After order:", "Affected:", "Why it matters:", "Next:"]:
		if not recap_text.contains(token):
			push_error("Town smoke: post-action town recap lost %s clarity: response=%s snapshot=%s text=%s." % [token, response_recap, snapshot_recap, recap_text])
			return false
	for token in ["Save check:", "What changed:", "Resume:", "Next:"]:
		if not save_text.contains(token):
			push_error("Town smoke: save continuity check lost %s clarity after a town order: %s." % [token, save_text])
			return false
	for token in ["Latest:", "Next:", "Town Turn Context", "Latest action:", "Next practical step:", "Handoff check:", "Town status:", "Departure Check", "Save check:"]:
		if not context_text.contains(token):
			push_error("Town smoke: town action context strip lost %s clarity: %s." % [token, context_text])
			return false
	if String(context.get("source", "")) != "town_action_recap":
		push_error("Town smoke: town action context strip did not use the town action recap source: %s." % context)
		return false
	if not String(snapshot.get("visible_consequence_text", "")).contains("Latest:"):
		push_error("Town smoke: compact town Latest/Next strip is not visible in the event rail: %s." % snapshot)
		return false
	for key in ["happened", "affected", "why_it_matters", "next_step", "matters", "next", "text"]:
		if String(response_recap.get(key, "")) == "" or String(snapshot_recap.get(key, "")) == "":
			push_error("Town smoke: post-action town recap is missing structured %s: response=%s snapshot=%s." % [key, response_recap, snapshot_recap])
			return false
	var consequence_text := "\n".join([
		String(response_recap.get("affected", "")),
		String(response_recap.get("why_it_matters", "")),
		String(response_recap.get("next_step", "")),
	])
	var practical_tokens := ["Stores", "Reserve", "Field", "Building", "Income", "Weekly muster", "readiness", "frontier", "build", "recruit"]
	var practical_token_found := false
	for token in practical_tokens:
		if consequence_text.contains(String(token)):
			practical_token_found = true
			break
	if not practical_token_found:
		push_error("Town smoke: post-action town recap did not explain a practical town/field consequence: %s." % response_recap)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if recap_text.contains(leak_token) or save_text.contains(leak_token) or context_text.contains(leak_token):
			push_error("Town smoke: post-action town recap leaked internal strategy token %s: %s." % [leak_token, recap_text])
			return false
	if String(snapshot.get("visible_consequence_text", "")) == "" or String(snapshot.get("consequence_tooltip_text", "")) == "":
		push_error("Town smoke: post-action town recap is not exposed through visible rail and tooltip text: %s." % snapshot)
		return false
	return true

func _assert_town_build_recruit_next_step_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing town next-step recommendation validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var overview := String(snapshot.get("production_overview", ""))
	if not overview.contains("Practical priority:") or not overview.contains("Defense/frontier:"):
		push_error("Town smoke: production overview did not surface a practical build/recruit priority with readiness impact: %s." % overview)
		return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var inspected_build := false
	for action in catalog.get("build", []):
		if not (action is Dictionary):
			continue
		var payload := "%s\n%s\n%s\n%s" % [
			String(action.get("button_label", "")),
			String(action.get("affordability_label", "")),
			String(action.get("impact_line", "")),
			String(action.get("recommendation_line", "")),
		]
		if payload.contains("|") and payload.contains("Defense/frontier:") and (
			payload.contains("Ready") or payload.contains("Trade") or payload.contains("Blocked")
		):
			inspected_build = true
			break
	if not inspected_build:
		push_error("Town smoke: build actions did not expose button status, impact, and recommendation payloads: %s." % [catalog.get("build", [])])
		return false
	var inspected_recruit := false
	for action in catalog.get("recruit", []):
		if not (action is Dictionary):
			continue
		var payload := "%s\n%s\n%s\n%s" % [
			String(action.get("button_label", "")),
			String(action.get("affordability_label", "")),
			String(action.get("impact_line", "")),
			String(action.get("recommendation_line", "")),
		]
		if payload.contains("|") and payload.contains("Defense/frontier:") and (
			payload.contains("Ready") or payload.contains("Trade") or payload.contains("Blocked")
		):
			inspected_recruit = true
			break
	if not inspected_recruit:
		push_error("Town smoke: recruit actions did not expose button status, impact, and recommendation payloads: %s." % [catalog.get("recruit", [])])
		return false
	for leak_token in ["build_category_weights", "final_score", "debug_reason", "raid_target_weights"]:
		if overview.contains(leak_token):
			push_error("Town smoke: next-step recommendation leaked internal strategy token %s: %s." % [leak_token, overview])
			return false
	return true

func _assert_town_build_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing build-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("build_readiness", {}) if snapshot.get("build_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("build_readiness_visible_text", "")),
		String(snapshot.get("build_readiness_tooltip_text", "")),
		String(snapshot.get("build_visible_text", "")),
		String(snapshot.get("build_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Build check:", "Build Readiness", "Town works:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:", "Construction Ledger"]:
		if not text.contains(token):
			push_error("Town smoke: build readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("open_order_count", -1)) < 0 or int(readiness.get("built_count", -1)) < 0:
		push_error("Town smoke: build readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if not (
		text.contains("Ready")
		or text.contains("Trade")
		or text.contains("Blocked")
		or text.contains("no open")
	):
		push_error("Town smoke: build readiness cue does not explain ready, trade, blocked, or empty state: %s." % readiness)
		return false
	if not String(snapshot.get("build_visible_text", "")).contains("Build check:"):
		push_error("Town smoke: build readiness cue is not visible in the construction label: %s." % snapshot)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: build readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_trade_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing trade-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("market_readiness", {}) if snapshot.get("market_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("market_readiness_visible_text", "")),
		String(snapshot.get("market_readiness_tooltip_text", "")),
		String(snapshot.get("market_visible_text", "")),
		String(snapshot.get("market_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Trade check:", "Trade Readiness", "Exchange orders:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:", "Exchange Hall"]:
		if not text.contains(token):
			push_error("Town smoke: trade readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("listed_order_count", -1)) < 0 or int(readiness.get("ready_order_count", -1)) < 0 or int(readiness.get("blocked_order_count", -1)) < 0:
		push_error("Town smoke: trade readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if not (
		text.contains("Ready")
		or text.contains("Blocked")
		or text.contains("no market")
		or text.contains("no exchange")
	):
		push_error("Town smoke: trade readiness cue does not explain ready, blocked, or absent exchange state: %s." % readiness)
		return false
	if not String(snapshot.get("market_visible_text", "")).contains("Trade check:"):
		push_error("Town smoke: trade readiness cue is not visible in the market label: %s." % snapshot)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: trade readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_field_handoff_recap_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town handoff validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("town_handoff", {}) if snapshot.get("town_handoff", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(snapshot.get("town_handoff_visible_text", "")),
		String(snapshot.get("town_handoff_tooltip_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
		String(handoff.get("affected", "")),
		String(handoff.get("why_it_matters", "")),
		String(handoff.get("next_step", "")),
	])
	for token in ["Handoff:", "Town Handoff", "Affected:", "Why it matters:", "Next practical action:", "Riverwatch Hold", "field route"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: town handoff recap lost %s clarity: %s." % [token, handoff_text])
			return false
	for key in ["affected", "why_it_matters", "next_step", "visible_text", "tooltip_text"]:
		if String(handoff.get(key, "")) == "":
			push_error("Town smoke: town handoff recap is missing structured %s: %s." % [key, handoff])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: town handoff recap leaked internal strategy token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_town_departure_confirmation_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town departure confirmation validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var departure: Dictionary = snapshot.get("town_departure_confirmation", {}) if snapshot.get("town_departure_confirmation", {}) is Dictionary else {}
	var departure_text := "\n".join([
		String(snapshot.get("town_departure_visible_text", "")),
		String(snapshot.get("leave_button_text", "")),
		String(snapshot.get("leave_button_tooltip_text", "")),
		String(departure.get("town_readiness", "")),
		String(departure.get("affected", "")),
		String(departure.get("why_it_matters", "")),
		String(departure.get("next_step", "")),
	])
	for token in ["Ready check:", "Departure Check", "Town readiness:", "Next practical action:", "Leave"]:
		if not departure_text.contains(token):
			push_error("Town smoke: town departure confirmation lost %s clarity: %s." % [token, departure_text])
			return false
	if not String(snapshot.get("leave_button_text", "")).contains("Leave"):
		push_error("Town smoke: departure confirmation is not visible on the Leave control: %s." % snapshot)
		return false
	for key in ["button_label", "visible_text", "tooltip_text", "town_readiness", "affected", "why_it_matters", "next_step"]:
		if String(departure.get(key, "")) == "":
			push_error("Town smoke: departure confirmation is missing structured %s: %s." % [key, departure])
			return false
	var decision_text := String(departure.get("visible_text", "")) + "\n" + String(departure.get("next_step", ""))
	if not (
		decision_text.contains("town orders")
		or decision_text.contains("response order")
		or decision_text.contains("end turn")
		or decision_text.contains("field route")
	):
		push_error("Town smoke: departure confirmation did not help decide town action, field route, or end turn: %s." % departure_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if departure_text.contains(leak_token):
			push_error("Town smoke: departure confirmation leaked internal strategy token %s: %s." % [leak_token, departure_text])
			return false
	return true

func _assert_town_return_handoff_payload(handoff: Dictionary) -> bool:
	var handoff_text := "\n".join([
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("town_name", "")),
		String(handoff.get("field_position", "")),
		String(handoff.get("movement_line", "")),
		String(handoff.get("next_step", "")),
		JSON.stringify(handoff.get("post_action_recap", {})),
	])
	for token in ["Town return:", "Town Return Handoff", "Returned:", "Field position:", "Movement:", "Day:", "Next practical action:", "Riverwatch Hold", "Move"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: town return handoff payload lost %s clarity: %s." % [token, handoff_text])
			return false
	var recap: Dictionary = handoff.get("post_action_recap", {}) if handoff.get("post_action_recap", {}) is Dictionary else {}
	for key in ["happened", "affected", "why_it_matters", "next_step", "cue_text", "tooltip_text"]:
		if String(recap.get(key, "")) == "":
			push_error("Town smoke: town return handoff recap is missing structured %s: %s." % [key, recap])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: town return handoff leaked internal strategy token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_overworld_town_return_handoff(session, handoff_seed: Dictionary) -> bool:
	session.game_state = "overworld"
	OverworldRules.clear_active_town_visit(session)
	session.flags["town_return_handoff"] = handoff_seed.duplicate(true)
	SessionState.set_active_session(session)
	var overworld_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not overworld_shell.has_method("validation_snapshot"):
		push_error("Town smoke: overworld shell does not expose validation snapshot for town return handoff.")
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var snapshot: Dictionary = overworld_shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("field_return_handoff", {}) if snapshot.get("field_return_handoff", {}) is Dictionary else {}
	var feedback: Dictionary = snapshot.get("action_feedback", {}) if snapshot.get("action_feedback", {}) is Dictionary else {}
	var return_text := "\n".join([
		String(snapshot.get("field_return_handoff_visible_text", "")),
		String(snapshot.get("field_return_handoff_tooltip_text", "")),
		String(snapshot.get("event_visible_text", "")),
		String(snapshot.get("event_tooltip_text", "")),
		String(snapshot.get("map_cue_text", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(feedback.get("full_text", feedback.get("text", ""))),
		JSON.stringify(handoff),
	])
	overworld_shell.queue_free()
	await get_tree().process_frame
	for token in ["Town return:", "Town Return Handoff", "Returned:", "Field position:", "Movement:", "Day:", "Next practical action:", "Current Turn Context", "Riverwatch Hold", "Move"]:
		if not return_text.contains(token):
			push_error("Town smoke: overworld town-return cue lost %s clarity: %s." % [token, return_text])
			return false
	if String(feedback.get("kind", "")) != "town":
		push_error("Town smoke: town return handoff did not surface as town action feedback: %s." % snapshot)
		return false
	if not String(snapshot.get("map_cue_text", "")).contains("Town:"):
		push_error("Town smoke: map cue did not visibly surface the town return handoff: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if return_text.contains(leak_token):
			push_error("Town smoke: overworld town-return cue leaked internal token %s." % leak_token)
			return false
	return true

func _assert_town_order_target_handoff_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town order target handoff validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var order_target: Dictionary = snapshot.get("town_order_target_handoff", {}) if snapshot.get("town_order_target_handoff", {}) is Dictionary else {}
	var target_text := "\n".join([
		String(snapshot.get("town_order_target_visible_text", "")),
		String(snapshot.get("town_order_target_tooltip_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
		String(order_target.get("target_label", "")),
		String(order_target.get("ui_surface", "")),
		String(order_target.get("readiness", "")),
		String(order_target.get("why_it_matters", "")),
		String(order_target.get("next_step", "")),
	])
	for token in ["Order target:", "Town Order Target", "Target:", "Lane:", "Where:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not target_text.contains(token):
			push_error("Town smoke: town order target handoff lost %s clarity: %s." % [token, target_text])
			return false
	if not String(snapshot.get("visible_consequence_text", "")).contains("Order target:"):
		push_error("Town smoke: order target handoff is not visible in the town dispatch rail: %s." % snapshot)
		return false
	for key in ["action_id", "lane", "target_label", "ui_surface", "readiness", "why_it_matters", "next_step", "visible_text", "tooltip_text"]:
		if String(order_target.get(key, "")) == "":
			push_error("Town smoke: town order target handoff is missing structured %s: %s." % [key, order_target])
			return false
	var ui_surface := String(order_target.get("ui_surface", ""))
	if not (ui_surface.contains("Build") or ui_surface.contains("Muster") or ui_surface.contains("Spells") or ui_surface.contains("Trade") or ui_surface.contains("Log") or ui_surface.contains("Town orders")):
		push_error("Town smoke: town order target handoff did not name a usable town surface: %s." % order_target)
		return false
	for public_token in ["Ready", "Blocked", "exchange", "Press", "Use"]:
		if target_text.contains(public_token):
			for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
				if target_text.contains(leak_token):
					push_error("Town smoke: town order target handoff leaked internal token %s: %s." % [leak_token, target_text])
					return false
			return true
	push_error("Town smoke: town order target handoff did not expose a public readiness or action cue: %s." % target_text)
	return false

func _assert_town_production_overview(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell does not expose validation snapshot.")
		return false
	var overview_label: Label = shell.get_node_or_null("%ProductionOverview")
	if overview_label == null:
		push_error("Town smoke: production overview label did not load.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var overview := String(snapshot.get("production_overview", ""))
	var visible_overview := String(snapshot.get("visible_production_overview", overview_label.text))
	if overview_label.text != visible_overview:
		push_error("Town smoke: production overview snapshot does not match the visible label: visible=%s snapshot=%s." % [overview_label.text, snapshot])
		return false
	for token in ["Owner ", "Faction ", "Income/day", "Works ", "Muster ", "Weekly ", "Ready now", "Next:", "Practical priority:"]:
		if not overview.contains(token):
			push_error("Town smoke: production overview is missing %s: %s." % [token, overview])
			return false
	if not visible_overview.contains("Income/day") or not visible_overview.contains("Next:"):
		push_error("Town smoke: visible production overview lost income or next-action clarity: %s." % visible_overview)
		return false
	return true

func _assert_town_stack_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: town shell is missing stack inspection validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var town_text := "\n".join([
		String(snapshot.get("army_text", "")),
		String(snapshot.get("army_visible_text", "")),
		String(snapshot.get("defense_text", "")),
		String(snapshot.get("defense_visible_text", "")),
		String(snapshot.get("recruit_text", "")),
		String(snapshot.get("recruit_visible_text", "")),
	])
	for token in ["Strength", "HP", "T", "Ready", "Defense readiness:", "Why:", "Next:", "Readiness"]:
		if not town_text.contains(token):
			push_error("Town smoke: town stack inspection text is missing %s: %s." % [token, town_text])
			return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	for action in catalog.get("recruit", []):
		if action is Dictionary and String(action.get("summary", "")).contains("Strength") and String(action.get("summary", "")).contains("HP"):
			return true
	push_error("Town smoke: recruit action tooltips do not expose stack role/health/strength: %s." % [catalog.get("recruit", [])])
	return false

func _assert_battle_magic_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose magic validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var magic_text := "\n".join([
		String(snapshot.get("spellbook_text", "")),
		String(snapshot.get("spellbook_tooltip_text", "")),
		String(snapshot.get("spell_timing_text", "")),
		String(snapshot.get("spell_timing_tooltip_text", "")),
	])
	for token in ["Battle Spells", "Mana", "Cinder Burst", "Battle Strike", "Stone Veil", "Battle Ward", "Cost", "Use:"]:
		if not magic_text.contains(token):
			push_error("Battle smoke: spellbook/timing panels lost practical magic token %s: %s." % [token, magic_text])
			return false
	var spell_actions: Array = snapshot.get("spell_actions", [])
	var inspected_action := false
	for action in spell_actions:
		if action is Dictionary:
			var payload := "%s\n%s\n%s\n%s\n%s" % [
				String(action.get("label", "")),
				String(action.get("category", "")),
				String(action.get("effect", "")),
				String(action.get("best_use", "")),
				String(action.get("summary", "")),
			]
			if payload.contains("Battle ") and payload.contains("Cost") and payload.contains("Target") and String(action.get("best_use", "")) != "":
				inspected_action = true
				break
	if not inspected_action:
		push_error("Battle smoke: spell action tooltips do not expose category, cost, target, effect, and use context: %s." % [spell_actions])
		return false
	var button_surfaces: Array = snapshot.get("spell_action_button_surfaces", [])
	var inspected_button := false
	var button_text := ""
	for surface in button_surfaces:
		if not (surface is Dictionary):
			continue
		var rendered := "%s\n%s" % [
			String(surface.get("text", "")),
			String(surface.get("tooltip", "")),
		]
		button_text += "\n%s" % rendered
		if (
			(rendered.contains("| Ready") or rendered.contains("| Blocked"))
			and rendered.contains("Spell action:")
			and rendered.contains("Readiness:")
			and rendered.contains("Target:")
			and rendered.contains("Cost:")
			and rendered.contains("Use:")
			and rendered.contains("Effect:")
			and rendered.contains("Next:")
		):
			inspected_button = true
	if not inspected_button:
		push_error("Battle smoke: rendered spell buttons do not expose visible readiness and action tooltip context: %s." % button_surfaces)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if button_text.contains(leak_token):
			push_error("Battle smoke: spell action cue leaked internal token %s: %s." % [leak_token, button_text])
			return false
	return true

func _assert_battle_ability_status_action_consequence_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose action consequence validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var active_text := "\n".join([
		String(snapshot.get("active_ability_role", "")),
		String(snapshot.get("active_status_pressure", "")),
		String(snapshot.get("active_target_range", "")),
		String(snapshot.get("target_context", "")),
	])
	for token in ["Role:", "Status pressure:", "Target/range:"]:
		if not active_text.contains(token):
			push_error("Battle smoke: active battle focus lost %s clarity: %s." % [token, active_text])
			return false
	var action_surface: Dictionary = snapshot.get("action_surface", {})
	var inspected_ready_action := false
	for action_id in ["shoot", "strike", "advance", "defend"]:
		var action: Dictionary = action_surface.get(action_id, {}) if action_surface.get(action_id, {}) is Dictionary else {}
		var payload := "\n".join([
			String(action.get("readiness", "")),
			String(action.get("target", "")),
			String(action.get("range", "")),
			String(action.get("why", "")),
			String(action.get("consequence", "")),
			String(action.get("confirmation", "")),
			String(action.get("tooltip", "")),
		])
		for token in ["Target/range:", "Why:", "Consequence:", "Confirm:"]:
			if not payload.contains(token):
				push_error("Battle smoke: %s action tooltip/payload lost %s clarity: %s." % [action_id, token, payload])
				return false
		if not bool(action.get("disabled", true)) and payload.contains("Ready") and String(action.get("why", "")) != "" and String(action.get("consequence", "")) != "" and String(action.get("confirmation", "")) != "":
			inspected_ready_action = true
	if not inspected_ready_action:
		push_error("Battle smoke: no ready action exposed readiness, why, consequence, and confirmation payloads: %s." % [action_surface])
		return false
	var button_tooltips := "\n".join([
		String(snapshot.get("advance_tooltip", "")),
		String(snapshot.get("strike_tooltip", "")),
		String(snapshot.get("shoot_tooltip", "")),
		String(snapshot.get("defend_tooltip", "")),
	])
	for token in ["Target/range:", "Why:", "Consequence:", "Confirm:"]:
		if not button_tooltips.contains(token):
			push_error("Battle smoke: live action button tooltips lost %s clarity: %s." % [token, button_tooltips])
			return false
	var order_button_surfaces: Array = snapshot.get("battle_order_button_surfaces", [])
	if order_button_surfaces.size() != 4:
		push_error("Battle smoke: non-spell order button cue snapshot should cover four stack orders: %s." % order_button_surfaces)
		return false
	var inspected_order_button := false
	var order_button_text := ""
	for surface in order_button_surfaces:
		if not (surface is Dictionary):
			continue
		var rendered := "%s\n%s" % [
			String(surface.get("text", "")),
			String(surface.get("tooltip", "")),
		]
		order_button_text += "\n%s" % rendered
		if (
			(rendered.contains("| Ready") or rendered.contains("| Blocked"))
			and rendered.contains("Order cue:")
			and rendered.contains("Readiness:")
			and rendered.contains("Target:")
			and rendered.contains("Range:")
			and rendered.contains("Why:")
			and rendered.contains("Next:")
		):
			inspected_order_button = true
	if not inspected_order_button:
		push_error("Battle smoke: rendered non-spell order buttons do not expose visible readiness and order tooltip context: %s." % order_button_surfaces)
		return false
	var action_guidance := String(snapshot.get("action_guidance", ""))
	var visible_action_guidance := String(snapshot.get("visible_action_guidance", ""))
	var manual_cue_text := "%s\n%s" % [action_guidance, visible_action_guidance]
	if not manual_cue_text.contains("Try:") or not manual_cue_text.contains("click"):
		push_error("Battle smoke: battle order rail lost the compact manual-play action cue: %s." % snapshot)
		return false
	if not visible_action_guidance.contains("Try:"):
		push_error("Battle smoke: manual-play action cue is not visible in the order rail: %s." % snapshot)
		return false
	var target_handoff: Dictionary = snapshot.get("target_handoff", {}) if snapshot.get("target_handoff", {}) is Dictionary else {}
	var target_handoff_text := "\n".join([
		String(snapshot.get("target_handoff_visible_text", "")),
		String(snapshot.get("target_handoff_tooltip_text", "")),
		String(target_handoff.get("focus", "")),
		String(target_handoff.get("board_click", "")),
		String(target_handoff.get("cycle", "")),
		String(target_handoff.get("move", "")),
		visible_action_guidance,
	])
	for token in ["Target handoff:", "Target Handoff", "Focus:", "Board click:", "Cycle:", "Try:"]:
		if not target_handoff_text.contains(token):
			push_error("Battle smoke: battle target handoff cue lost %s clarity: %s." % [token, target_handoff_text])
			return false
	if String(target_handoff.get("focus", "")) == "" or String(target_handoff.get("board_click", "")) == "" or String(target_handoff.get("cycle", "")) == "":
		push_error("Battle smoke: target handoff payload is missing focus, board-click, or cycle context: %s." % target_handoff)
		return false
	if not visible_action_guidance.contains("Target handoff:"):
		push_error("Battle smoke: target handoff cue is not visible in the footer action guide: %s." % snapshot)
		return false
	var confirmation: Dictionary = snapshot.get("action_confirmation", {}) if snapshot.get("action_confirmation", {}) is Dictionary else {}
	var confirmation_text := "\n".join([
		String(confirmation.get("visible_text", "")),
		String(confirmation.get("tooltip_text", "")),
		String(snapshot.get("action_confirmation_text", "")),
		String(snapshot.get("action_confirmation_tooltip_text", "")),
		visible_action_guidance,
	])
	for token in ["Ready check:", "confirm", "order ends this stack", "initiative advances"]:
		if not confirmation_text.contains(token):
			push_error("Battle smoke: battle action confirmation lost %s clarity: %s." % [token, confirmation_text])
			return false
	if String(confirmation.get("button_label", "")) == "" or String(confirmation.get("next_step", "")) == "":
		push_error("Battle smoke: battle action confirmation payload is missing button/next-step fields: %s." % confirmation)
		return false
	var roster_text := "\n".join(snapshot.get("player_roster", []) + snapshot.get("enemy_roster", []))
	if not roster_text.contains("Role ") or not roster_text.contains("Status "):
		push_error("Battle smoke: roster lines do not expose ability role and status pressure text: %s." % roster_text)
		return false
	var consequence_payload: Dictionary = snapshot.get("active_consequence_payload", {}) if snapshot.get("active_consequence_payload", {}) is Dictionary else {}
	if String(consequence_payload.get("active_ability_role", "")) == "" or String(consequence_payload.get("status_pressure", "")) == "" or String(consequence_payload.get("target_range", "")) == "" or String(consequence_payload.get("confirmation", "")) == "":
		push_error("Battle smoke: active consequence payload is missing ability/status/range fields: %s." % [consequence_payload])
		return false
	for leak_token in ["final_priority", "debug_reason", "score", "ai_score", "weight"]:
		if active_text.contains(leak_token) or button_tooltips.contains(leak_token) or order_button_text.contains(leak_token) or manual_cue_text.contains(leak_token) or target_handoff_text.contains(leak_token) or confirmation_text.contains(leak_token) or roster_text.contains(leak_token):
			push_error("Battle smoke: battle consequence UI leaked internal token %s." % leak_token)
			return false
	return true

func _assert_battle_exit_order_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing exit-order cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var exit_cues: Dictionary = snapshot.get("battle_exit_order_cues", {}) if snapshot.get("battle_exit_order_cues", {}) is Dictionary else {}
	var exit_text := "\n".join([
		String(exit_cues.get("visible_text", "")),
		String(exit_cues.get("route", "")),
		String(exit_cues.get("save", "")),
		String(exit_cues.get("retreat_tooltip", "")),
		String(exit_cues.get("surrender_tooltip", "")),
		String(snapshot.get("retreat_text", "")),
		String(snapshot.get("surrender_text", "")),
		String(snapshot.get("retreat_tooltip", "")),
		String(snapshot.get("surrender_tooltip", "")),
	])
	for token in ["Exit cue:", "Retreat", "Surrender", "army-wide battle exit order", "Route:", "returns to the field", "Save Battle first"]:
		if not exit_text.contains(token):
			push_error("Battle smoke: battle exit-order cue lost %s clarity: %s." % [token, exit_text])
			return false
	if String(exit_cues.get("retreat_state", "")) == "" or String(exit_cues.get("surrender_state", "")) == "":
		push_error("Battle smoke: exit-order cue is missing retreat/surrender readiness states: %s." % exit_cues)
		return false
	if not String(snapshot.get("retreat_tooltip", "")).contains("Exit cue:") or not String(snapshot.get("surrender_tooltip", "")).contains("Exit cue:"):
		push_error("Battle smoke: live retreat/surrender button tooltips do not carry the exit-order cue: %s." % exit_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if exit_text.contains(leak_token):
			push_error("Battle smoke: battle exit-order cue leaked internal token %s: %s." % [leak_token, exit_text])
			return false
	return true

func _assert_battle_target_cycle_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing target-cycle cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var cycle: Dictionary = snapshot.get("target_cycle_cue", {}) if snapshot.get("target_cycle_cue", {}) is Dictionary else {}
	var cycle_text := "\n".join([
		String(cycle.get("visible_text", "")),
		String(cycle.get("focus", "")),
		String(cycle.get("position", "")),
		String(cycle.get("scope", "")),
		String(cycle.get("state", "")),
		String(cycle.get("prev_tooltip", "")),
		String(cycle.get("next_tooltip", "")),
		String(snapshot.get("prev_target_text", "")),
		String(snapshot.get("next_target_text", "")),
		String(snapshot.get("prev_target_tooltip", "")),
		String(snapshot.get("next_target_tooltip", "")),
	])
	for token in ["Target cycle:", "Focus:", "Position:", "Scope:", "State:", "Prev:", "Next:"]:
		if not cycle_text.contains(token):
			push_error("Battle smoke: target-cycle cue lost %s clarity: %s." % [token, cycle_text])
			return false
	if not String(snapshot.get("prev_target_text", "")).contains("/") or not String(snapshot.get("next_target_text", "")).contains("/"):
		push_error("Battle smoke: target-cycle position is not visible on Prev/Next controls: %s." % cycle_text)
		return false
	if int(cycle.get("target_count", 0)) <= 0 or String(cycle.get("position", "")) == "0/0":
		push_error("Battle smoke: target-cycle cue did not expose a usable target count: %s." % cycle)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cycle_text.contains(leak_token):
			push_error("Battle smoke: target-cycle cue leaked internal token %s: %s." % [leak_token, cycle_text])
			return false
	return true

func _assert_battle_initiative_handoff_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing initiative-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("initiative_handoff", {}) if snapshot.get("initiative_handoff", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("current_stack", "")),
		String(handoff.get("current_side", "")),
		String(handoff.get("next_stack", "")),
		String(handoff.get("next_side", "")),
		String(handoff.get("handoff", "")),
		String(snapshot.get("initiative_handoff_visible_text", "")),
		String(snapshot.get("initiative_handoff_tooltip_text", "")),
		String(snapshot.get("initiative_visible_text", "")),
	])
	for token in ["Initiative cue:", "Now:", "Next:", "Initiative Handoff", "Round:", "Current:", "Handoff:", "Player input:"]:
		if not handoff_text.contains(token):
			push_error("Battle smoke: initiative handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if String(handoff.get("current_stack", "")) == "" or String(handoff.get("next_stack", "")) == "":
		push_error("Battle smoke: initiative handoff cue is missing current or next stack labels: %s." % handoff)
		return false
	if int(handoff.get("round", 0)) <= 0 or int(handoff.get("next_round", 0)) <= 0:
		push_error("Battle smoke: initiative handoff cue is missing stable round timing: %s." % handoff)
		return false
	if not String(snapshot.get("initiative_visible_text", "")).contains("Initiative cue:"):
		push_error("Battle smoke: initiative handoff cue is not visible in the initiative rail: %s." % handoff_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Battle smoke: initiative handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}
