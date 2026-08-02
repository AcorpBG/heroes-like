extends Control

const OVERWORLD_SCENE := preload("res://scenes/overworld/OverworldShell.tscn")
const TOWN_SCENE := preload("res://scenes/town/TownShell.tscn")
const COMPACT_SIZE := Vector2(1280.0, 720.0)
const NARROW_SIZE := Vector2(1024.0, 600.0)
const FULL_SIZE := Vector2(1600.0, 900.0)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [COMPACT_SIZE, NARROW_SIZE, FULL_SIZE]:
		if not await _check_overworld(viewport_size):
			return
		if not await _check_town(viewport_size):
			return
	get_tree().quit(0)

func _check_overworld(viewport_size: Vector2) -> bool:
	SessionState.set_active_session(ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	))
	var frame := _new_frame("OverworldFrame", viewport_size)
	var shell = OVERWORLD_SCENE.instantiate()
	frame.add_child(shell)
	await _settle_layout()
	var compact := viewport_size.x < 1360.0 or viewport_size.y < 760.0
	var narrow := viewport_size.x < 1100.0
	if compact:
		shell.call("_refresh")
		await _settle_layout()
	var ok := _inside(frame, shell.get_node("%Map"), "overworld map", viewport_size)
	ok = _inside(frame, shell.get_node("%CommandBand"), "overworld command band", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SidebarShell"), not narrow, "overworld sidebar", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%BriefingPanel"), not compact, "overworld briefing", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CommitmentPanel"), not compact, "overworld commitment", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CueChip"), not compact, "overworld duplicate cue", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SaveStatus"), not narrow, "overworld save detail", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SaveSlot"), not narrow, "overworld save slot picker", viewport_size) and ok
	frame.queue_free()
	await get_tree().process_frame
	return ok

func _check_town(viewport_size: Vector2) -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Town layout smoke could not find a player town.")
	_move_active_hero_to_town(session, town)
	SessionState.set_active_session(session)
	var frame := _new_frame("TownFrame", viewport_size)
	var shell = TOWN_SCENE.instantiate()
	frame.add_child(shell)
	await _settle_layout()
	var compact := viewport_size.x < 1360.0 or viewport_size.y < 760.0
	var narrow := viewport_size.x < 1100.0
	var ok := _inside(frame, shell.get_node("%TownStage"), "town stage", viewport_size)
	ok = _inside(frame, shell.get_node("%FooterPanel"), "town footer", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SidebarShell"), not narrow, "town management sidebar", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CommandPanel"), not compact, "town command summary", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%Event"), not compact, "town dispatch", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%Status"), not compact, "town duplicate status", viewport_size) and ok
	frame.queue_free()
	await get_tree().process_frame
	return ok

func _new_frame(frame_name: String, viewport_size: Vector2) -> Control:
	var frame := Control.new()
	frame.name = frame_name
	frame.size = viewport_size
	add_child(frame)
	return frame

func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _inside(frame: Control, target: Control, label: String, viewport_size: Vector2) -> bool:
	var frame_rect := frame.get_global_rect()
	var target_rect := target.get_global_rect()
	if target_rect.position.x < frame_rect.position.x - 1.0 or target_rect.position.y < frame_rect.position.y - 1.0:
		return _fail("%s starts outside %s: %s" % [label, viewport_size, target_rect])
	if target_rect.end.x > frame_rect.end.x + 1.0 or target_rect.end.y > frame_rect.end.y + 1.0:
		return _fail("%s overflows %s: %s" % [label, viewport_size, target_rect])
	return true

func _expect_visibility(target: CanvasItem, expected: bool, label: String, viewport_size: Vector2) -> bool:
	if target.visible != expected:
		return _fail("%s visibility at %s expected %s but got %s" % [label, viewport_size, expected, target.visible])
	return true

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false
