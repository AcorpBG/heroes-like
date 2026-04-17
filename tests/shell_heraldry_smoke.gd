extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_menu_glyph():
		return
	if not await _run_overworld_glyph():
		return
	if not await _run_town_glyph():
		return
	if not await _run_battle_glyph():
		return
	if not await _run_outcome_glyph():
		return
	get_tree().quit(0)

func _run_menu_glyph() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)
	return await _assert_shell_node(
		"res://scenes/menus/MainMenu.tscn",
		"LogoPocketPanel/LogoPocketPad/LogoPocketBox/LogoHeader/WarGlyph",
		"Menu heraldry glyph"
	)

func _run_overworld_glyph() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)
	return await _assert_shell_node(
		"res://scenes/overworld/OverworldShell.tscn",
		"ShellMargin/Shell/ShellPad/Content/BodyRow/SidebarShell/SidebarPad/SidebarBox/TopStrip/TopPad/TopBar/BannerGlyph",
		"Overworld heraldry glyph"
	)

func _run_town_glyph() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		push_error("Town heraldry smoke: missing player town.")
		get_tree().quit(1)
		return false
	_move_active_hero_to_town(session, active_town)
	SessionState.set_active_session(session)
	return await _assert_shell_node(
		"res://scenes/town/TownShell.tscn",
		"ContentMargin/Content/Banner/BannerPad/TopBar/CrestFrame/CrestPad/CrestBox/CrestGlyph",
		"Town heraldry glyph"
	)

func _run_battle_glyph() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Battle heraldry smoke: missing encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	SessionState.set_active_session(session)
	return await _assert_shell_node(
		"res://scenes/battle/BattleShell.tscn",
		"ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/BannerGlyph",
		"Battle heraldry glyph"
	)

func _run_outcome_glyph() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session.scenario_status = "victory"
	SessionState.set_active_session(session)
	return await _assert_shell_node(
		"res://scenes/results/ScenarioOutcomeShell.tscn",
		"ContentMargin/Content/Banner/BannerPad/BannerColumns/BannerInfo/TopLine/ResultGlyph",
		"Outcome heraldry glyph"
	)

func _assert_shell_node(scene_path: String, node_path: String, label: String) -> bool:
	var shell = load(scene_path).instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var node = shell.get_node_or_null(node_path)
	if node == null:
		push_error("%s did not load." % label)
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
