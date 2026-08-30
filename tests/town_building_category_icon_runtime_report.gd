extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CATEGORY_IDS := ["civic", "dwelling", "economy", "support", "magic"]

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Building category icon catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_live_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Town building category icon case failed: %s" % JSON.stringify(row), original_window_size)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_BUILDING_CATEGORY_ICON_RUNTIME_REPORT %s" % JSON.stringify({"ok": true, "catalog": catalog, "rows": rows}))
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var category_counts := {}
	var asset_paths := []
	var building_count := 0
	for building_id in ContentService.get_content_ids(ContentService.BUILDINGS_PATH):
		var building := ContentService.get_building(building_id)
		var category_id := String(building.get("category", ""))
		building_count += 1
		category_counts[category_id] = int(category_counts.get(category_id, 0)) + 1
		var icon_path := TownRules.building_category_icon_path(building_id)
		if category_id not in CATEGORY_IDS or icon_path == "":
			return {"ok": false, "failure": "building_mapping", "building_id": building_id, "category_id": category_id, "icon_path": icon_path}
		if icon_path not in asset_paths:
			asset_paths.append(icon_path)
	for category_id in CATEGORY_IDS:
		var icon := ContentService.get_building_category_icon(category_id)
		var path := String(icon.get("icon_path", ""))
		var texture := load(path) as Texture2D
		if String(icon.get("icon_id", "")) != "building_category_sigil_%s" % category_id or texture == null or texture.get_size() != Vector2(128.0, 128.0):
			return {"ok": false, "failure": "category_asset", "category_id": category_id, "icon": icon, "size": texture.get_size() if texture != null else Vector2.ZERO}
	return {
		"ok": building_count == 142 and category_counts.size() == 5 and asset_paths.size() == 5,
		"building_count": building_count,
		"category_counts": category_counts,
		"asset_paths": asset_paths,
	}

func _run_live_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = SessionState.ensure_active_session()
	var actions: Array = TownRules.get_build_catalog(live_session)
	var container := shell.get_node_or_null("%BuildActions") as Control
	var confirm := shell.get_node_or_null("%ConfirmBuild") as Button
	if container == null or confirm == null or actions.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "build_surface_missing"})
	var buttons := _buttons_in(container)
	if buttons.size() != actions.size():
		return await _finish_case(shell, {"ok": false, "failure": "button_count", "buttons": buttons.size(), "actions": actions.size()})
	var presentation_exact := true
	var contained := true
	var enabled_action := {}
	var enabled_index := -1
	for index in range(actions.size()):
		var action: Dictionary = actions[index]
		var button: Button = buttons[index]
		var building_id := TownRules.building_id_for_action(String(action.get("id", "")))
		var expected_path := TownRules.building_icon_path(building_id)
		presentation_exact = presentation_exact and button.icon != null and button.icon.resource_path == expected_path and button.expand_icon and button.get_theme_constant("icon_max_width") == 46
		presentation_exact = presentation_exact and button.text.find(String(action.get("name", ""))) >= 0 and button.text.find(String(action.get("catalog_status", ""))) >= 0 and button.tooltip_text == shell._catalog_build_tooltip(action)
		contained = contained and container.get_global_rect().encloses(button.get_global_rect())
		if enabled_action.is_empty() and bool(action.get("direct_affordable", false)) and not bool(action.get("disabled", true)):
			enabled_action = action.duplicate(true)
			enabled_index = index
	var invalid_button := Button.new()
	shell._apply_build_action_icon(invalid_button, {"id": "build:missing_building"})
	var invalid_fail_closed := invalid_button.icon == null
	invalid_button.free()
	if enabled_action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "enabled_build_missing"})
	var action_id := String(enabled_action.get("id", ""))
	var building_id := action_id.trim_prefix("build:")
	var selection: Dictionary = shell.validation_select_build_plan(action_id)
	await get_tree().process_frame
	var refreshed_buttons := _buttons_in(container)
	var selected_button: Button = refreshed_buttons[enabled_index] if enabled_index >= 0 and enabled_index < refreshed_buttons.size() else null
	var selection_exact := bool(selection.get("ok", false)) and selected_button != null and selected_button.button_pressed and not confirm.disabled
	var before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(before.duplicate(true))
	var control_before: Dictionary = TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.build_active_town(control, building_id)
	var control_recap: Dictionary = TownRules.build_town_action_recap(control, "build", action_id, enabled_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)
	confirm.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var consequence_exact := bool(control_result.get("ok", false)) and live_session.to_dict() == control.to_dict()
	return await _finish_case(shell, {
		"ok": presentation_exact and contained and invalid_fail_closed and selection_exact and consequence_exact,
		"viewport_size": viewport_size,
		"building_id": building_id,
		"presentation_exact": presentation_exact,
		"contained": contained,
		"invalid_fail_closed": invalid_fail_closed,
		"selection_exact": selection_exact,
		"consequence_exact": consequence_exact,
		"save_version_exact": int(live_session.save_version) == SessionStateStore.SAVE_VERSION,
	})

func _buttons_in(node: Node) -> Array:
	var buttons := []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_buttons_in(child))
	return buttons

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
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	SessionState.reset_session()
	await get_tree().process_frame
	return result

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
