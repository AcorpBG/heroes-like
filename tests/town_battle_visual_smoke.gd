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

	shell.queue_free()
	await get_tree().process_frame
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
	if int(terrain_summary.get("hex_tile_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle smoke: terrain texture tile count does not match the tactical hex count: terrain=%s hex=%s." % [terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	if float(terrain_summary.get("source_tile_width", 0.0)) <= 0.0 or float(terrain_summary.get("source_tile_height", 0.0)) <= 0.0:
		push_error("Battle smoke: terrain texture did not expose a usable per-hex source sample size: %s." % terrain_summary)
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

	var defend_button = shell.get_node_or_null("%Defend")
	if defend_button == null:
		push_error("Battle smoke: defend action button did not load.")
		get_tree().quit(1)
		return false
	if not defend_button.disabled:
		shell._on_defend_pressed()
		await get_tree().process_frame

	var recent_after: int = int(session.battle.get("recent_events", []).size())
	if recent_after < recent_before:
		push_error("Battle smoke: recent event feed regressed after action refresh.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

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

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}
