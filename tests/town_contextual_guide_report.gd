extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_FOOTER_ORDER := [
	"TownOrdersToggle",
	"SaveStatus",
	"SaveSlot",
	"Save",
	"Leave",
	"Guide",
	"Settings",
	"Menu",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			push_error("Town contextual guide failed at %s: %s" % [viewport_size, JSON.stringify(row)])
			get_window().size = original_window_size
			get_tree().quit(1)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_CONTEXTUAL_GUIDE_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewport_sizes": VIEWPORT_SIZES,
		"rows": rows,
	}))
	get_tree().quit(0)

func _run_viewport_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, active_town)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(shell) or not shell.is_inside_tree():
		return {"ok": false, "failure": "town_shell_missing"}

	var session_before: Dictionary = session.to_dict()
	var initial_snapshot: Dictionary = shell.validation_snapshot()
	var initial_layout := _layout_snapshot(shell)
	var initial_authority := _authority_snapshot(initial_snapshot)
	var footer_order := _footer_order(shell)
	var expected_guide_text := SettingsService.describe_help_topic("town")
	var initial_guide: Dictionary = initial_snapshot.get("town_guide", {})
	var setup_exact: bool = (
		footer_order == EXPECTED_FOOTER_ORDER
		and not bool(initial_guide.get("open", true))
		and String(initial_guide.get("button_text", "")) == "Guide"
		and String(initial_guide.get("guide_text", "")) == expected_guide_text
		and String(initial_guide.get("guide_tooltip_text", "")) == expected_guide_text
		and String(initial_guide.get("title_text", "")) == "Town Field Manual"
	)

	var guide_button := shell.get_node_or_null("%Guide") as Button
	var guide_close := shell.get_node_or_null("%TownGuideClose") as Button
	var menu_button := shell.get_node_or_null("%Menu") as Button
	if guide_button == null or guide_close == null or menu_button == null:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "failure": "guide_nodes_missing"}

	guide_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var open_snapshot: Dictionary = shell.validation_snapshot()
	var open_guide: Dictionary = open_snapshot.get("town_guide", {})
	var host_rect: Rect2 = shell.get_global_rect()
	var panel_rect: Rect2 = open_guide.get("panel_rect", Rect2())
	var close_rect: Rect2 = open_guide.get("close_button_rect", Rect2())
	var overlay_rect: Rect2 = open_guide.get("overlay_rect", Rect2())
	var open_exact: bool = (
		bool(open_guide.get("open", false))
		and String(open_guide.get("guide_text", "")) == expected_guide_text
		and String(open_guide.get("expected_guide_text", "")) == expected_guide_text
		and int(open_guide.get("overlay_mouse_filter", -1)) == Control.MOUSE_FILTER_STOP
		and overlay_rect == host_rect
		and host_rect.encloses(panel_rect)
		and panel_rect.encloses(close_rect)
		and panel_rect.size.x <= 620.0
		and panel_rect.size.y <= 360.0
		and panel_rect.get_area() < host_rect.get_area() * 0.30
		and bool(open_guide.get("close_has_focus", false))
		and String(open_guide.get("focus_owner", "")) == "TownGuideClose"
		and _layout_snapshot(shell) == initial_layout
		and _authority_snapshot(open_snapshot) == initial_authority
	)

	# The full-screen STOP layer must own pointer input. A click over the live
	# Return-to-Menu button must not reach the background while Guide is open.
	await _click_global_position(menu_button.get_global_rect().get_center())
	var blocked_snapshot: Dictionary = shell.validation_snapshot()
	var background_pointer_blocked: bool = (
		shell.is_inside_tree()
		and bool(Dictionary(blocked_snapshot.get("town_guide", {})).get("open", false))
		and _authority_snapshot(blocked_snapshot) == initial_authority
		and int(blocked_snapshot.get("return_to_menu_request_count", -1)) == 0
		and session.to_dict() == session_before
	)

	shell.call("_configure_town_keyboard_focus", true)
	await get_tree().process_frame
	var refocused_snapshot: Dictionary = shell.validation_snapshot()
	var modal_focus_exact: bool = bool(Dictionary(refocused_snapshot.get("town_guide", {})).get("close_has_focus", false))

	await _press_action("ui_cancel")
	var canceled_snapshot: Dictionary = shell.validation_snapshot()
	var canceled_guide: Dictionary = canceled_snapshot.get("town_guide", {})
	var cancel_exact: bool = (
		not bool(canceled_guide.get("open", true))
		and String(canceled_guide.get("focus_owner", "")) == "Guide"
		and guide_button.has_focus()
		and _layout_snapshot(shell) == initial_layout
		and _authority_snapshot(canceled_snapshot) == initial_authority
	)

	guide_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	guide_close.emit_signal("pressed")
	await get_tree().process_frame
	var close_snapshot: Dictionary = shell.validation_snapshot()
	var close_guide: Dictionary = close_snapshot.get("town_guide", {})
	var close_exact: bool = (
		not bool(close_guide.get("open", true))
		and String(close_guide.get("focus_owner", "")) == "Guide"
		and _layout_snapshot(shell) == initial_layout
		and _authority_snapshot(close_snapshot) == initial_authority
		and session.to_dict() == session_before
	)

	var row := {
		"ok": setup_exact and open_exact and background_pointer_blocked and modal_focus_exact and cancel_exact and close_exact,
		"viewport_size": viewport_size,
		"setup_exact": setup_exact,
		"open_exact": open_exact,
		"background_pointer_blocked": background_pointer_blocked,
		"modal_focus_exact": modal_focus_exact,
		"cancel_exact": cancel_exact,
		"close_exact": close_exact,
		"footer_order": footer_order,
		"panel_rect": panel_rect,
		"overlay_rect": overlay_rect,
		"narrow_layout_active": bool(initial_guide.get("narrow_layout_active", true)),
		"session_authority_exact": session.to_dict() == session_before,
	}
	shell.queue_free()
	await get_tree().process_frame
	return row

func _layout_snapshot(shell: Node) -> Dictionary:
	var snapshot := {}
	for node_name in ["TownStagePanel", "SidebarShell", "FooterPanel", "FooterBar", "Guide", "Settings", "Menu"]:
		var control := shell.get_node_or_null("%%%s" % node_name) as Control
		if control == null:
			snapshot[node_name] = Rect2()
		else:
			snapshot[node_name] = control.get_global_rect()
	return snapshot

func _authority_snapshot(snapshot: Dictionary) -> Dictionary:
	var authority := {}
	for key in [
		"scenario_id",
		"difficulty",
		"launch_mode",
		"scenario_status",
		"game_state",
		"day",
		"town_placement_id",
		"town_id",
		"town_owner",
		"built_building_count",
		"available_recruits",
		"resources",
		"selected_build_action_id",
		"town_active_tab",
		"return_to_menu_request_count",
		"save_surface",
		"latest_save_summary",
	]:
		authority[key] = snapshot.get(key)
	return authority

func _footer_order(shell: Node) -> Array:
	var footer := shell.get_node_or_null("ContentMargin/Content/FooterPanel/FooterPad/FooterBar")
	var names := []
	if footer == null:
		return names
	for child in footer.get_children():
		names.append(String(child.name))
	return names

func _click_global_position(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame

func _press_action(action_id: String) -> void:
	var press := InputEventAction.new()
	press.action = action_id
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action_id
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame

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
