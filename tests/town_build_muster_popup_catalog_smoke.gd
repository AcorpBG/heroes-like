extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CAPTURE_DIR := "res://.artifacts/town_build_muster_popup_catalog"

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var original_size := get_window().size
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_errors.append("%s popup case failed: %s" % [viewport_size, JSON.stringify(row)])
	get_window().size = original_size
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_build_muster_popup_catalog_smoke_v1",
		"rows": rows,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("TOWN_BUILD_MUSTER_POPUP_CATALOG_SMOKE %s" % JSON.stringify(report))
	else:
		push_error("TOWN_BUILD_MUSTER_POPUP_CATALOG_SMOKE failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		return {"ok": false, "failure": "town_visit", "result": visit_result}
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var expected_build_ids := _unique_strings(town_template.get("starting_building_ids", []), town_template.get("buildable_building_ids", []))
	var expected_unit_ids := _town_unit_ids(expected_build_ids)
	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(initial_snapshot.get("narrow_layout_active", false)) and not bool(initial_snapshot.get("narrow_orders_open", false)):
		shell.call("validation_toggle_narrow_town_orders")
		await get_tree().process_frame

	var build_launcher := shell.get_node("%OpenBuildCatalog") as Button
	build_launcher.grab_focus()
	var build_previous_focus := get_viewport().gui_get_focus_owner()
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	await get_tree().process_frame
	var build_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var build_catalog: Array = TownRules.get_build_catalog(SessionState.ensure_active_session())
	var build_icons := _catalog_button_icon_count(shell.get_node("%BuildActions"))
	var build_contained := _rect_contains(build_snapshot.get("overlay_rect", Rect2()), build_snapshot.get("panel_rect", Rect2()))
	_capture("build", viewport_size)

	shell.call("validation_close_town_catalog")
	await get_tree().process_frame
	await get_tree().process_frame
	var build_close_focus := get_viewport().gui_get_focus_owner()
	var build_focus_returned := build_close_focus == build_previous_focus
	(shell.get_node("%ManagementTabs") as TabContainer).current_tab = 1
	await get_tree().process_frame
	var muster_launcher := shell.get_node("%OpenMusterCatalog") as Button
	muster_launcher.grab_focus()
	var muster_previous_focus := get_viewport().gui_get_focus_owner()
	shell.call("validation_open_town_catalog", "muster")
	await get_tree().process_frame
	await get_tree().process_frame
	var muster_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var muster_catalog: Array = TownRules.get_muster_catalog(SessionState.ensure_active_session())
	var portrait_count := _texture_rect_count(shell.get_node("%RecruitActions"))
	var muster_contained := _rect_contains(muster_snapshot.get("overlay_rect", Rect2()), muster_snapshot.get("panel_rect", Rect2()))
	_capture("muster", viewport_size)
	shell.call("validation_close_town_catalog")
	await get_tree().process_frame
	await get_tree().process_frame
	var muster_close_focus := get_viewport().gui_get_focus_owner()
	var muster_focus_returned := muster_close_focus == muster_previous_focus

	var build_ids: Array = build_snapshot.get("build_ids", [])
	var muster_ids: Array = muster_snapshot.get("muster_ids", [])
	var build_statuses: Dictionary = build_snapshot.get("build_statuses", {})
	var muster_statuses: Dictionary = muster_snapshot.get("muster_statuses", {})
	var build_exact := build_ids == expected_build_ids and build_catalog.size() == expected_build_ids.size()
	var muster_exact := muster_ids == expected_unit_ids and muster_catalog.size() == expected_unit_ids.size()
	var build_states_complete := int(build_statuses.get("Built", 0)) > 0 and (int(build_statuses.get("Ready", 0)) + int(build_statuses.get("Trade", 0)) + int(build_statuses.get("Resources", 0))) > 0 and int(build_statuses.get("Locked", 0)) > 0
	var muster_states_complete := int(muster_statuses.get("Locked", 0)) > 0 and (int(muster_statuses.get("Ready", 0)) + int(muster_statuses.get("Empty", 0)) + int(muster_statuses.get("Resources", 0)) + int(muster_statuses.get("Trade", 0))) > 0
	var ok := (
		build_exact
		and muster_exact
		and build_states_complete
		and muster_states_complete
		and bool(build_snapshot.get("open", false))
		and String(build_snapshot.get("mode", "")) == "build"
		and bool(build_snapshot.get("focus_inside", false))
		and bool(build_snapshot.get("build_grid_visible", false))
		and not bool(build_snapshot.get("muster_grid_visible", true))
		and int(build_snapshot.get("build_card_count", 0)) == expected_build_ids.size()
		and build_icons == expected_build_ids.size()
		and build_contained
		and build_focus_returned
		and bool(muster_snapshot.get("open", false))
		and String(muster_snapshot.get("mode", "")) == "muster"
		and bool(muster_snapshot.get("focus_inside", false))
		and bool(muster_snapshot.get("muster_grid_visible", false))
		and not bool(muster_snapshot.get("build_grid_visible", true))
		and not bool(muster_snapshot.get("confirm_build_visible", true))
		and int(muster_snapshot.get("muster_card_count", 0)) == expected_unit_ids.size()
		and portrait_count == expected_unit_ids.size()
		and muster_contained
		and muster_focus_returned
	)
	var row := {
		"ok": ok,
		"viewport_size": viewport_size,
		"expected_build_count": expected_build_ids.size(),
		"expected_muster_count": expected_unit_ids.size(),
		"build_icons": build_icons,
		"muster_portraits": portrait_count,
		"build_statuses": build_statuses,
		"muster_statuses": muster_statuses,
		"build_focus_returned": build_focus_returned,
		"muster_focus_returned": muster_focus_returned,
		"build_close_focus": String(build_close_focus.name) if build_close_focus != null else "",
		"muster_close_focus": String(muster_close_focus.name) if muster_close_focus != null else "",
		"build_previous_focus": String(build_previous_focus.name) if build_previous_focus != null else "",
		"muster_previous_focus": String(muster_previous_focus.name) if muster_previous_focus != null else "",
		"build_contained": build_contained,
		"muster_contained": muster_contained,
		"build_exact": build_exact,
		"muster_exact": muster_exact,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["x"] = position.x
		hero["y"] = position.y
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero

func _unique_strings(first: Variant, second: Variant) -> Array:
	var result := []
	for source in [first, second]:
		if not (source is Array):
			continue
		for value in source:
			var text := String(value)
			if text != "" and text not in result:
				result.append(text)
	return result

func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result

func _town_unit_ids(building_ids: Array) -> Array:
	var rows := []
	for building_id_value in building_ids:
		var unit_id := String(ContentService.get_building(String(building_id_value)).get("unlock_unit_id", ""))
		if unit_id == "" or unit_id in rows:
			continue
		rows.append(unit_id)
	rows.sort_custom(func(left, right):
		var left_unit := ContentService.get_unit(String(left))
		var right_unit := ContentService.get_unit(String(right))
		var left_tier := int(left_unit.get("tier", 0))
		var right_tier := int(right_unit.get("tier", 0))
		return left_tier < right_tier if left_tier != right_tier else String(left_unit.get("name", left)) < String(right_unit.get("name", right))
	)
	return rows

func _catalog_button_icon_count(node: Node) -> int:
	var count := 0
	if node is Button and node.icon != null:
		count += 1
	for child in node.get_children():
		count += _catalog_button_icon_count(child)
	return count

func _texture_rect_count(node: Node) -> int:
	var count := 1 if node is TextureRect and node.texture != null else 0
	for child in node.get_children():
		count += _texture_rect_count(child)
	return count

func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end - Vector2.ONE)

func _capture(mode: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [CAPTURE_DIR, mode, viewport_size.x, viewport_size.y])
