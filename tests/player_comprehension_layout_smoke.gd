extends Control

const OVERWORLD_SCENE := preload("res://scenes/overworld/OverworldShell.tscn")
const TOWN_SCENE := preload("res://scenes/town/TownShell.tscn")
const COMPACT_SIZE := Vector2(1280.0, 720.0)
const NARROW_SIZE := Vector2(1024.0, 600.0)
const FULL_SIZE := Vector2(1600.0, 900.0)
const WIDE_SIZE := Vector2(1920.0, 1080.0)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [COMPACT_SIZE, NARROW_SIZE, FULL_SIZE, WIDE_SIZE]:
		if not await _check_overworld(viewport_size):
			return
		if not await _check_town(viewport_size):
			return
	get_tree().quit(0)

func _check_overworld(viewport_size: Vector2) -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var initial_position: Dictionary = session.overworld.get("hero_position", {}).duplicate(true)
	var initial_movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	var initial_resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	session = SessionState.set_active_session(session)
	var frame := _new_frame("OverworldFrame", viewport_size)
	var shell = OVERWORLD_SCENE.instantiate()
	frame.add_child(shell)
	await _settle_layout()
	var compact := viewport_size.x < 1360.0 or viewport_size.y < 760.0
	var narrow := viewport_size.x < 1100.0
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if compact:
		shell.call("_refresh")
		await _settle_layout()
		snapshot = shell.call("validation_snapshot")
	var ok := _inside(frame, shell.get_node("%Map"), "overworld map", viewport_size)
	ok = _inside(frame, shell.get_node("%CommandBand"), "overworld command band", viewport_size) and ok
	ok = _inside(frame, shell.get_node("%StatusChip"), "overworld status chip", viewport_size) and ok
	for control_name in ["PrimaryAction", "EndTurn", "Save", "Settings", "Menu"]:
		ok = _inside(frame, shell.get_node("%" + control_name), "overworld %s" % control_name, viewport_size) and ok
		ok = _expect_command_available(shell.get_node("%" + control_name), "overworld %s" % control_name, viewport_size) and ok
	ok = _expect_overworld_status_contract(shell, narrow, compact, viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SidebarShell"), not narrow, "overworld sidebar", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CommandSpine"), false, "overworld opening context drawer", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%BriefingPanel"), not compact, "overworld briefing", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CommitmentPanel"), not compact, "overworld commitment", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CueChip"), not compact, "overworld duplicate cue", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SaveStatus"), not narrow, "overworld save detail", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SaveSlot"), not narrow, "overworld save slot picker", viewport_size) and ok
	if not narrow:
		ok = _inside(frame, shell.get_node("%SaveStatus"), "overworld save detail", viewport_size) and ok
		ok = _inside(frame, shell.get_node("%SaveSlot"), "overworld save slot picker", viewport_size) and ok
	if viewport_size == FULL_SIZE:
		print("OVERWORLD_1600_COMMAND_LAYOUT %s" % JSON.stringify({
			"command_band": str(shell.get_node("%CommandBand").get_global_rect()),
			"primary_action": str(shell.get_node("%PrimaryAction").get_global_rect()),
			"end_turn": str(shell.get_node("%EndTurn").get_global_rect()),
			"save": str(shell.get_node("%Save").get_global_rect()),
			"settings": str(shell.get_node("%Settings").get_global_rect()),
			"menu": str(shell.get_node("%Menu").get_global_rect()),
		}))
	ok = _expect_opening_order(snapshot, viewport_size) and ok
	ok = _expect_unchanged_opening_session(session, initial_position, initial_movement, initial_resources, viewport_size) and ok
	frame.queue_free()
	await get_tree().process_frame
	return ok

func _expect_opening_order(snapshot: Dictionary, viewport_size: Vector2) -> bool:
	if not bool(snapshot.get("command_briefing_active", false)):
		return _fail("first-turn briefing is not active at %s" % viewport_size)
	if not bool(snapshot.get("opening_route_suggested", false)):
		return _fail("first-turn route was not suggested at %s" % viewport_size)
	if String(snapshot.get("opening_route_suggestion_kind", "")) not in ["town", "resource", "artifact"]:
		return _fail("first-turn route kind is invalid at %s: %s" % [viewport_size, snapshot.get("opening_route_suggestion_kind", "")])
	if String(snapshot.get("primary_action_id", "")) == "":
		return _fail("first-turn primary order is missing at %s" % viewport_size)
	if bool(snapshot.get("primary_action_button_disabled", true)):
		return _fail("first-turn primary order is disabled at %s: %s" % [viewport_size, snapshot.get("primary_action_button_text", "")])
	if snapshot.get("selected_tile", {}) == snapshot.get("hero_position", {}):
		return _fail("first-turn route still selects the hero tile at %s" % viewport_size)
	return true

func _expect_overworld_status_contract(shell: Control, narrow: bool, compact: bool, viewport_size: Vector2) -> bool:
	var status_chip := shell.get_node("%StatusChip") as PanelContainer
	var status_label := shell.get_node("%Status") as Label
	if status_chip == null or status_label == null:
		return _fail("overworld status controls are missing at %s" % viewport_size)
	if not status_chip.visible or not status_label.visible:
		return _fail("overworld status chip was hidden at %s" % viewport_size)
	if not is_equal_approx(status_chip.custom_minimum_size.x, 118.0):
		return _fail("overworld status chip changed its authored compact width at %s: %s" % [viewport_size, status_chip.custom_minimum_size])
	if status_label.clip_text != narrow:
		return _fail("overworld status clipping at %s expected %s but got %s" % [viewport_size, narrow, status_label.clip_text])
	var full_status := status_label.text
	if full_status.is_empty():
		return _fail("overworld status text is empty at %s" % viewport_size)
	var tooltip := status_label.tooltip_text
	if compact:
		if not tooltip.begins_with("%s\n" % full_status):
			return _fail("overworld compact status tooltip lost its exact full status at %s: %s" % [viewport_size, tooltip])
	elif tooltip != full_status:
		return _fail("overworld desktop status tooltip differs from its full status at %s: %s" % [viewport_size, tooltip])
	return true

func _expect_command_available(target: Button, label: String, viewport_size: Vector2) -> bool:
	if target == null or not target.visible:
		return _fail("%s is not visible at %s" % [label, viewport_size])
	if target.disabled:
		return _fail("%s is disabled at %s" % [label, viewport_size])
	return true

func _expect_unchanged_opening_session(session, initial_position: Dictionary, initial_movement: Dictionary, initial_resources: Dictionary, viewport_size: Vector2) -> bool:
	if session.day != 1:
		return _fail("first-turn suggestion advanced the day at %s" % viewport_size)
	if session.overworld.get("hero_position", {}) != initial_position:
		return _fail("first-turn suggestion moved the hero at %s" % viewport_size)
	if session.overworld.get("movement", {}) != initial_movement:
		return _fail("first-turn suggestion spent movement at %s" % viewport_size)
	if session.overworld.get("resources", {}) != initial_resources:
		return _fail("first-turn suggestion changed resources at %s" % viewport_size)
	return true

func _check_town(viewport_size: Vector2) -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Town layout smoke could not find a player town.")
	var initial_built_buildings: Array = town.get("built_buildings", []).duplicate()
	var initial_resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	_move_active_hero_to_town(session, town)
	session = SessionState.set_active_session(session)
	town = _first_player_town(session)
	var frame := _new_frame("TownFrame", viewport_size)
	var shell = TOWN_SCENE.instantiate()
	frame.add_child(shell)
	await _settle_layout()
	var compact := viewport_size.x < 1360.0 or viewport_size.y < 760.0
	var narrow := viewport_size.x < 1100.0
	var ok := _inside(frame, shell.get_node("%Banner"), "town banner", viewport_size)
	ok = _inside(frame, shell.get_node("%Header"), "town header", viewport_size) and ok
	ok = _inside(frame, shell.get_node("%Resources"), "town resources", viewport_size) and ok
	ok = _inside(frame, shell.get_node("%TownStage"), "town stage", viewport_size) and ok
	ok = _inside(frame, shell.get_node("%FooterPanel"), "town footer", viewport_size) and ok
	for control_name in ["SaveSlot", "Save", "Leave", "Guide", "Settings", "Menu"]:
		ok = _inside(frame, shell.get_node("%" + control_name), "town %s" % control_name, viewport_size) and ok
	for button_name in ["Save", "Leave", "Guide", "Settings", "Menu"]:
		ok = _expect_command_available(shell.get_node("%" + button_name), "town %s" % button_name, viewport_size) and ok
	ok = _expect_town_banner_contract(shell, compact, viewport_size) and ok
	ok = _expect_town_sidebar_contract(shell, compact, viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%SidebarShell"), not narrow, "town management sidebar", viewport_size) and ok
	if not narrow:
		ok = _inside(frame, shell.get_node("%SidebarShell"), "town management sidebar", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%CommandPanel"), not compact, "town command summary", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%Event"), not compact, "town dispatch", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%Status"), not compact, "town duplicate status", viewport_size) and ok
	ok = _expect_visibility(shell.get_node("%TownOrdersToggle"), narrow, "town narrow orders switch", viewport_size) and ok
	if narrow:
		ok = _inside(frame, shell.get_node("%TownOrdersToggle"), "town narrow orders switch", viewport_size) and ok
		ok = _expect_command_available(shell.get_node("%TownOrdersToggle"), "town narrow orders switch", viewport_size) and ok
		var toggle_result: Dictionary = shell.call("validation_toggle_narrow_town_orders")
		await _settle_layout()
		if not bool(toggle_result.get("ok", false)) or not bool(toggle_result.get("narrow_orders_open", false)):
			return _fail("town narrow orders switch did not open management at %s: %s" % [viewport_size, toggle_result])
		ok = _expect_visibility(shell.get_node("%SidebarShell"), true, "town narrow management surface", viewport_size) and ok
		ok = _expect_visibility(shell.get_node("%StageColumn"), false, "town stage while narrow orders are open", viewport_size) and ok
		ok = _inside(frame, shell.get_node("%SidebarShell"), "town narrow management surface", viewport_size) and ok
		if String(toggle_result.get("toggle_text", "")) != "View Town":
			return _fail("town narrow orders switch does not expose the return command at %s" % viewport_size)
	ok = (await _expect_town_build_plan(shell, session, initial_built_buildings, initial_resources, viewport_size)) and ok
	frame.queue_free()
	await get_tree().process_frame
	return ok

func _expect_town_build_plan(shell: Node, session, initial_built_buildings: Array, initial_resources: Dictionary, viewport_size: Vector2) -> bool:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var selected_id := String(snapshot.get("selected_build_action_id", ""))
	if not selected_id.begins_with("build:"):
		return _fail("town build planner has no selected construction at %s" % viewport_size)
	if String(snapshot.get("build_plan_visible_text", "")).find("Cost ") < 0:
		return _fail("town build planner omits selected cost at %s: %s" % [viewport_size, snapshot.get("build_plan_visible_text", "")])
	if String(snapshot.get("build_plan_tooltip_text", "")).find("Selection does not spend resources") < 0:
		return _fail("town build planner omits its non-mutating selection guarantee at %s" % viewport_size)
	if bool(snapshot.get("confirm_build_button_disabled", true)):
		return _fail("town build planner has no ready confirm command at %s: %s" % [viewport_size, snapshot.get("confirm_build_button_text", "")])
	if session.overworld.get("resources", {}) != initial_resources:
		return _fail("town build planner spent resources during initial selection at %s" % viewport_size)
	if _first_player_town(session).get("built_buildings", []) != initial_built_buildings:
		return _fail("town build planner constructed during initial selection at %s" % viewport_size)

	var candidate_id := selected_id
	var catalog: Dictionary = shell.call("validation_action_catalog")
	for action_value in catalog.get("build", []):
		if not (action_value is Dictionary):
			continue
		var action_id := String(action_value.get("id", ""))
		if action_id != selected_id and not bool(action_value.get("disabled", false)):
			candidate_id = action_id
			break
	var selection_result: Dictionary = shell.call("validation_select_build_plan", candidate_id)
	if not bool(selection_result.get("ok", false)) or not bool(selection_result.get("state_unchanged", false)):
		return _fail("town build selection mutated or failed at %s: %s" % [viewport_size, selection_result])
	if session.overworld.get("resources", {}) != initial_resources:
		return _fail("town build selection spent resources at %s" % viewport_size)
	if _first_player_town(session).get("built_buildings", []) != initial_built_buildings:
		return _fail("town build selection constructed before confirmation at %s" % viewport_size)

	var commit_result: Dictionary = shell.call("validation_confirm_build_plan")
	await _settle_layout()
	if not bool(commit_result.get("ok", false)) or not bool(commit_result.get("state_changed", false)):
		return _fail("town build confirmation did not commit at %s: %s" % [viewport_size, commit_result])
	var committed_id := String(commit_result.get("committed_action_id", "")).trim_prefix("build:")
	var built_after: Array = _first_player_town(session).get("built_buildings", [])
	if built_after.size() != initial_built_buildings.size() + 1 or committed_id not in built_after:
		return _fail("town build confirmation committed the wrong construction at %s: %s" % [viewport_size, built_after])
	if session.overworld.get("resources", {}) == initial_resources:
		return _fail("town build confirmation did not spend resources at %s" % viewport_size)
	return true

func _expect_town_banner_contract(shell: Control, compact: bool, viewport_size: Vector2) -> bool:
	var header := shell.get_node("%Header") as Label
	var resources := shell.get_node("%Resources") as ResourceStockpileMenu
	if header == null or resources == null:
		return _fail("town banner controls are missing at %s" % viewport_size)
	if header.text.is_empty() or header.tooltip_text != header.text:
		return _fail("town header lost its exact full tooltip at %s: %s" % [viewport_size, header.tooltip_text])
	if header.clip_text != compact:
		return _fail("town header clipping at %s expected %s but got %s" % [viewport_size, compact, header.clip_text])
	var expected_resource_width := 80.0 if compact else 210.0
	if not is_equal_approx(resources.custom_minimum_size.x, expected_resource_width):
		return _fail("town resource menu width at %s expected %s but got %s" % [viewport_size, expected_resource_width, resources.custom_minimum_size.x])
	var resource_snapshot: Dictionary = resources.validation_snapshot()
	if bool(resource_snapshot.get("compact", false)) != compact:
		return _fail("town resource compact mode at %s expected %s: %s" % [viewport_size, compact, resource_snapshot])
	if String(resource_snapshot.get("tooltip_text", "")) != String(resource_snapshot.get("full_summary", "")):
		return _fail("town resource menu lost its full tooltip at %s: %s" % [viewport_size, resource_snapshot])
	return true

func _expect_town_sidebar_contract(shell: Control, compact: bool, viewport_size: Vector2) -> bool:
	var sidebar := shell.get_node("%SidebarShell") as PanelContainer
	if sidebar == null:
		return _fail("town management sidebar is missing at %s" % viewport_size)
	var expected_width := 272.0 if compact else 400.0
	if not is_equal_approx(sidebar.custom_minimum_size.x, expected_width):
		return _fail("town management sidebar budget at %s expected %s but got %s" % [viewport_size, expected_width, sidebar.custom_minimum_size.x])
	if sidebar.visible and sidebar.size.x + 0.01 < sidebar.get_combined_minimum_size().x:
		return _fail("town management sidebar violates its live minimum at %s: %s / %s" % [viewport_size, sidebar.size, sidebar.get_combined_minimum_size()])
	return true

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
