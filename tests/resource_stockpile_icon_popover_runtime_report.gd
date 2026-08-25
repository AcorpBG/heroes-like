extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_window_size: Vector2i = get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var town_row: Dictionary = await _run_town_case(viewport_size)
		rows.append(town_row)
		if not bool(town_row.get("ok", false)):
			_fail("Town stockpile menu case failed: %s" % JSON.stringify(town_row), original_window_size)
			return
		var overworld_row: Dictionary = await _run_overworld_case(viewport_size)
		rows.append(overworld_row)
		if not bool(overworld_row.get("ok", false)):
			_fail("Overworld stockpile menu case failed: %s" % JSON.stringify(overworld_row), original_window_size)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("RESOURCE_STOCKPILE_ICON_POPOVER_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"schema": "resource_stockpile_icon_popover_runtime_report_v1",
		"resource_ids": RESOURCE_IDS,
		"rows": rows,
	}))
	get_tree().quit(0)


func _run_town_case(viewport_size: Vector2i) -> Dictionary:
	if not await _set_window_size(viewport_size):
		return {"ok": false, "shell": "town", "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town: Dictionary = _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "shell": "town", "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	SessionState.set_active_session(session)
	var host := _case_host(viewport_size, "TownCaseHost")
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	host.add_child(shell)
	await _settle()
	var menu := shell.get_node_or_null("%Resources") as ResourceStockpileMenu
	var banner := shell.get_node_or_null("%Banner") as Control
	var resource_chip := shell.get_node_or_null("%ResourceChip") as PanelContainer
	if menu == null or banner == null or resource_chip == null:
		return await _finish_case(host, {"ok": false, "shell": "town", "failure": "menu_missing"})
	var live_session = SessionState.ensure_active_session()
	var authority_before: Dictionary = live_session.to_dict()
	var town_signature_before: Dictionary = TownRules.town_action_consequence_signature(live_session)
	var shell_snapshot_before: Dictionary = shell.validation_snapshot()
	var menu_before: Dictionary = menu.validation_snapshot()
	var contract: Dictionary = _menu_contract(menu_before, live_session.overworld.get("resources", {}))
	var compact_expected: bool = viewport_size.x < 1360 or viewport_size.y < 760
	var layout_size_exact: bool = shell.size == Vector2(viewport_size)
	var visible_summary_exact: bool = String(menu_before.get("visible_text", "")) == String(shell_snapshot_before.get("resources_visible_text", ""))
	var tooltip_exact: bool = String(menu_before.get("tooltip_text", "")) == String(shell_snapshot_before.get("resources_tooltip_text", ""))
	var chip_style := resource_chip.get_theme_stylebox("panel")
	var chip_texture_path := (chip_style as StyleBoxTexture).texture.resource_path if chip_style is StyleBoxTexture and (chip_style as StyleBoxTexture).texture != null else ""
	var chip_art_exact: bool = chip_texture_path == "res://art/ui/runtime/town/resource_ledger.png"
	var contained: bool = banner.get_global_rect().encloses(resource_chip.get_global_rect()) and resource_chip.get_global_rect().encloses(menu.get_global_rect())
	var frame_width_exact: bool = is_equal_approx(resource_chip.custom_minimum_size.x, 96.0 if compact_expected else 226.0) and is_equal_approx(resource_chip.size.x, 96.0 if compact_expected else 226.0)
	var menu_width_exact: bool = is_equal_approx(menu.custom_minimum_size.x, 80.0 if compact_expected else 210.0) and is_equal_approx(menu.size.x, 80.0 if compact_expected else 210.0)
	var interaction: Dictionary = await _open_and_close_menu(menu)
	var authority_after: Dictionary = SessionState.ensure_active_session().to_dict()
	var town_signature_after: Dictionary = TownRules.town_action_consequence_signature(SessionState.ensure_active_session())
	var shell_snapshot_after: Dictionary = shell.validation_snapshot()
	return await _finish_case(host, {
		"ok": bool(contract.get("ok", false)) and layout_size_exact and bool(resource_chip.visible) and bool(menu_before.get("compact", false)) == compact_expected and visible_summary_exact and tooltip_exact and chip_art_exact and contained and frame_width_exact and menu_width_exact and bool(interaction.get("ok", false)) and authority_after == authority_before and town_signature_after == town_signature_before and _town_surface_authority(shell_snapshot_after) == _town_surface_authority(shell_snapshot_before),
		"shell": "town",
		"viewport_size": viewport_size,
		"layout_size_exact": layout_size_exact,
		"contract": contract,
		"resource_chip_visible": resource_chip.visible,
		"compact_exact": bool(menu_before.get("compact", false)) == compact_expected,
		"visible_summary_exact": visible_summary_exact,
		"tooltip_exact": tooltip_exact,
		"chip_art_exact": chip_art_exact,
		"chip_texture_path": chip_texture_path,
		"contained": contained,
		"frame_width_exact": frame_width_exact,
		"menu_width_exact": menu_width_exact,
		"interaction": interaction,
		"session_authority_exact": authority_after == authority_before,
		"town_consequence_authority_exact": town_signature_after == town_signature_before,
		"surface_authority_exact": _town_surface_authority(shell_snapshot_after) == _town_surface_authority(shell_snapshot_before),
		"save_version_exact": int(SessionState.ensure_active_session().save_version) == SessionStateStore.SAVE_VERSION,
	})


func _run_overworld_case(viewport_size: Vector2i) -> Dictionary:
	if not await _set_window_size(viewport_size):
		return {"ok": false, "shell": "overworld", "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	SessionState.set_active_session(session)
	var host := _case_host(viewport_size, "OverworldCaseHost")
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	host.add_child(shell)
	await _settle()
	var menu := shell.get_node_or_null("%Resources") as ResourceStockpileMenu
	var command_band := shell.get_node_or_null("%CommandBand") as Control
	var resource_chip := shell.get_node_or_null("%ResourceChip") as Control
	if menu == null or command_band == null or resource_chip == null:
		return await _finish_case(host, {"ok": false, "shell": "overworld", "failure": "menu_missing"})
	var live_session = SessionState.ensure_active_session()
	var authority_before: Dictionary = live_session.to_dict()
	var shell_snapshot_before: Dictionary = shell.validation_snapshot()
	var menu_before: Dictionary = menu.validation_snapshot()
	var contract: Dictionary = _menu_contract(menu_before, live_session.overworld.get("resources", {}))
	var compact_expected: bool = viewport_size.x < 1360 or viewport_size.y < 760
	var layout_size_exact: bool = shell.size == Vector2(viewport_size)
	var visible_summary_exact: bool = String(menu_before.get("visible_text", "")) == (ResourceStockpileMenu.COMPACT_LABEL if compact_expected else OverworldRules.describe_resources(live_session))
	var tooltip_exact: bool = String(menu_before.get("tooltip_text", "")) == OverworldRules.describe_resources(live_session)
	var contained: bool = command_band.get_global_rect().encloses(resource_chip.get_global_rect()) and resource_chip.get_global_rect().encloses(menu.get_global_rect())
	var bounded_width_exact: bool = is_equal_approx(menu.size.x, 80.0 if compact_expected else 210.0)
	var interaction: Dictionary = await _open_and_close_menu(menu)
	var authority_after: Dictionary = SessionState.ensure_active_session().to_dict()
	var shell_snapshot_after: Dictionary = shell.validation_snapshot()
	return await _finish_case(host, {
		"ok": bool(contract.get("ok", false)) and layout_size_exact and bool(menu_before.get("visible", false)) and bool(menu_before.get("compact", false)) == compact_expected and visible_summary_exact and tooltip_exact and contained and bounded_width_exact and bool(interaction.get("ok", false)) and authority_after == authority_before and _overworld_surface_authority(shell_snapshot_after) == _overworld_surface_authority(shell_snapshot_before),
		"shell": "overworld",
		"viewport_size": viewport_size,
		"layout_size_exact": layout_size_exact,
		"contract": contract,
		"resource_chip_visible": resource_chip.visible,
		"compact_exact": bool(menu_before.get("compact", false)) == compact_expected,
		"visible_summary_exact": visible_summary_exact,
		"tooltip_exact": tooltip_exact,
		"contained": contained,
		"bounded_width_exact": bounded_width_exact,
		"interaction": interaction,
		"session_authority_exact": authority_after == authority_before,
		"surface_authority_exact": _overworld_surface_authority(shell_snapshot_after) == _overworld_surface_authority(shell_snapshot_before),
		"save_version_exact": int(SessionState.ensure_active_session().save_version) == SessionStateStore.SAVE_VERSION,
	})


func _menu_contract(snapshot: Dictionary, resources: Variant) -> Dictionary:
	var rows: Array = snapshot.get("popup_items", []) if snapshot.get("popup_items", []) is Array else []
	var exact: bool = (
		String(snapshot.get("schema", "")) == "resource_stockpile_icon_menu_v1"
		and snapshot.get("resource_ids", []) == RESOURCE_IDS
		and int(snapshot.get("popup_item_count", 0)) == RESOURCE_IDS.size()
		and rows.size() == RESOURCE_IDS.size()
	)
	var icon_paths: Array = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var resource_id: String = String(RESOURCE_IDS[index])
		var definition: Dictionary = OverworldRules.resource_definition(resource_id)
		var display_name: String = String(definition.get("display_name", ""))
		var amount: int = int((resources as Dictionary).get(resource_id, 0)) if resources is Dictionary else 0
		var expected_icon_path: String = OverworldRules.resource_icon_path(resource_id)
		var texture: Texture2D = load(expected_icon_path) as Texture2D
		exact = exact and (
			String(row.get("resource_id", "")) == resource_id
			and String(row.get("display_name", "")) == display_name
			and int(row.get("amount", -1)) == amount
			and String(row.get("text", "")) == "%s  %d" % [display_name, amount]
			and String(row.get("tooltip", "")) == "%s: %d" % [display_name, amount]
			and bool(row.get("disabled", false))
			and bool(row.get("icon_loaded", false))
			and String(row.get("icon_path", "")) == expected_icon_path
			and String(row.get("icon_resource_path", "")) == expected_icon_path
			and texture != null
			and texture.get_size() == Vector2(128.0, 128.0)
		)
		icon_paths.append(expected_icon_path)
	return {
		"ok": exact and icon_paths.size() == RESOURCE_IDS.size() and _unique_strings(icon_paths).size() == RESOURCE_IDS.size(),
		"item_count": rows.size(),
		"icon_paths": icon_paths,
	}


func _open_and_close_menu(menu: ResourceStockpileMenu) -> Dictionary:
	menu.grab_focus()
	await get_tree().process_frame
	await _emit_action("ui_accept")
	await get_tree().process_frame
	var open_snapshot: Dictionary = menu.validation_snapshot()
	var popup_rect: Dictionary = open_snapshot.get("popup_rect", {}) if open_snapshot.get("popup_rect", {}) is Dictionary else {}
	var window_rect := Rect2i(get_window().position, get_window().size)
	var viewport_visible_rect := get_viewport().get_visible_rect()
	var viewport_rect := Rect2i(Vector2i(viewport_visible_rect.position), Vector2i(viewport_visible_rect.size))
	var live_popup_rect := Rect2i(
		Vector2i(int(popup_rect.get("x", -1)), int(popup_rect.get("y", -1))),
		Vector2i(int(popup_rect.get("width", 0)), int(popup_rect.get("height", 0)))
	)
	var popup_contained: bool = viewport_rect.encloses(live_popup_rect)
	await _emit_action("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	var closed_snapshot: Dictionary = menu.validation_snapshot()
	return {
		"ok": bool(open_snapshot.get("popup_visible", false)) and popup_contained and not bool(closed_snapshot.get("popup_visible", true)) and bool(closed_snapshot.get("has_focus", false)),
		"opened": bool(open_snapshot.get("popup_visible", false)),
		"popup_contained": popup_contained,
		"popup_rect": popup_rect.duplicate(true),
		"window_rect": {"x": window_rect.position.x, "y": window_rect.position.y, "width": window_rect.size.x, "height": window_rect.size.y},
		"viewport_rect": {"x": viewport_rect.position.x, "y": viewport_rect.position.y, "width": viewport_rect.size.x, "height": viewport_rect.size.y},
		"menu_rect": open_snapshot.get("rect", {}),
		"viewport_size": get_viewport().get_visible_rect().size,
		"content_scale_factor": get_window().content_scale_factor,
		"closed": not bool(closed_snapshot.get("popup_visible", true)),
		"focus_returned": bool(closed_snapshot.get("has_focus", false)),
	}


func _emit_action(action_name: String) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action_name
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action_name
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _town_surface_authority(snapshot: Dictionary) -> Dictionary:
	return {
		"resources": snapshot.get("resources", {}),
		"resources_text": snapshot.get("resources_text", ""),
		"resources_tooltip_text": snapshot.get("resources_tooltip_text", ""),
		"build_actions": snapshot.get("build_actions", []),
		"recruit_actions": snapshot.get("recruit_actions", []),
		"market_actions": snapshot.get("market_actions", []),
		"latest_save_summary": snapshot.get("latest_save_summary", {}),
	}


func _overworld_surface_authority(snapshot: Dictionary) -> Dictionary:
	return {
		"resources": snapshot.get("resources", {}),
		"primary_action": snapshot.get("primary_action", {}),
		"context_action_ids": snapshot.get("context_action_ids", []),
		"selected_route_decision": snapshot.get("selected_route_decision", {}),
		"save_surface": snapshot.get("save_surface", {}),
		"resource_delta_presentation": snapshot.get("resource_delta_presentation", {}),
	}


func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position: Dictionary = {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _set_window_size(viewport_size: Vector2i) -> bool:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	return get_window().size == viewport_size


func _case_host(viewport_size: Vector2i, host_name: String) -> Control:
	var host := Control.new()
	host.name = host_name
	host.custom_minimum_size = Vector2(viewport_size)
	host.size = Vector2(viewport_size)
	add_child(host)
	return host


func _settle() -> void:
	for _index in range(4):
		await get_tree().process_frame


func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	SessionState.reset_session()
	await get_tree().process_frame
	return result


func _unique_strings(values: Array) -> Array:
	var unique: Array = []
	for value in values:
		if value not in unique:
			unique.append(value)
	return unique


func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
