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
	if not _assert_town_production_overview(shell):
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
	if not _assert_town_economy_decision_payload(shell):
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
	if not await _assert_battle_aftermath_transition(session):
		get_tree().quit(1)
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
	if not town_hero_text.contains("Lyra Emberwell") or not town_hero_text.contains("Embercourt League") or not town_hero_text.contains("Fast scouting caster"):
		push_error("Town smoke: hero panel did not expose hero identity/faction/role context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Lv1") or not town_hero_text.contains("XP 0/250") or not town_hero_text.contains("Wayfinder I"):
		push_error("Town smoke: hero panel did not expose progression and specialty context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Move") or not town_hero_text.contains("Scout") or not town_hero_text.contains("Army"):
		push_error("Town smoke: hero panel did not expose readiness and army command context: %s." % town_hero_text)
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
	overworld_shell.queue_free()
	await get_tree().process_frame
	if not event_tooltip.contains("Rewards:") or not event_tooltip.contains("Forces:") or not event_tooltip.contains("Overworld:"):
		push_error("Battle smoke: overworld return notice did not expose reward, force, and transition clarity: %s." % snapshot)
		return false
	if String(feedback.get("kind", "")) != "battle" or not feedback_text.contains("Forces:"):
		push_error("Battle smoke: post-battle action feedback did not surface as a battle recap: %s." % snapshot)
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
	return true

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
	for token in ["Owner ", "Faction ", "Income/day", "Works ", "Muster ", "Weekly ", "Ready now", "Next:"]:
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
	for token in ["Strength", "HP", "T", "Ready"]:
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
	return true

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}
