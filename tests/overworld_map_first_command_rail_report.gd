extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "OVERWORLD_MAP_FIRST_COMMAND_RAIL_REPORT"
const CAPTURE_ENV := "OVERWORLD_MAP_FIRST_CAPTURE_DIR"
const VIEWPORTS := [Vector2i(1920, 1060), Vector2i(1280, 720)]
const SEED := "map-first-command-rail-10228"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED,
		"",
		"",
		2,
		"land",
		false,
		"homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,
		"faction_veilmourn",
		"hero_veilmourn_orso_nightchart"
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		return _fail("Deterministic generated Small setup failed: %s" % JSON.stringify(setup))
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null:
		return _fail("Deterministic generated Small session did not start.")
	OverworldRules.normalize_overworld_state_for_runtime(session)
	SessionState.set_active_session(session)
	var authority_before: Dictionary = session.to_dict()
	var rows := []
	var captures := []
	for viewport in VIEWPORTS:
		get_window().size = viewport
		var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		for _frame in range(6):
			await get_tree().process_frame
		var capture_path := _capture_path(viewport)
		if capture_path != "":
			var image := get_viewport().get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(capture_path) != OK:
				return _fail("Could not save %s capture." % viewport)
			captures.append(capture_path)
		var row := await _validate_viewport(shell, session, viewport)
		if not bool(row.get("ok", false)):
			return
		rows.append(row)
		shell.queue_free()
		await get_tree().process_frame
	if session.to_dict() != authority_before:
		return _fail("Responsive layout, drawers, or minimap changed generated session authority.")
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": SEED,
		"scenario_id": session.scenario_id,
		"generated_random_map": bool(session.flags.get("generated_random_map", false)),
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"rows": rows,
		"captures": captures,
		"session_exact": true,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)


func _validate_viewport(shell: Control, session, viewport: Vector2i) -> Dictionary:
	var layout: Dictionary = shell.call("validation_map_first_layout_snapshot")
	var map_rect := _rect_from_payload(layout.get("map", {}))
	var rail_rect := _rect_from_payload(layout.get("rail", {}))
	var footer_rect := _rect_from_payload(layout.get("footer", {}))
	var minimap_rect := _rect_from_payload(layout.get("minimap", {}))
	var root_rect := _rect_from_payload(layout.get("viewport", {}))
	var map_share := float(layout.get("map_width_share", 0.0))
	var footer_share := float(layout.get("footer_height_share", 1.0))
	if not root_rect.encloses(map_rect) or not root_rect.encloses(rail_rect) or not root_rect.encloses(footer_rect):
		return _fail("Layout escaped %s: %s" % [viewport, JSON.stringify(layout)])
	if map_rect.intersects(rail_rect) or map_rect.intersects(footer_rect) or rail_rect.intersects(footer_rect):
		return _fail("Map, rail, and footer overlap at %s: %s" % [viewport, JSON.stringify(layout)])
	if not rail_rect.encloses(minimap_rect) or map_share < (0.78 if viewport.x >= 1900 else 0.76) or footer_share > 0.09:
		return _fail("Map-first proportions failed at %s: %s" % [viewport, JSON.stringify(layout)])
	var minimap: Control = shell.get_node_or_null("%Minimap")
	var minimap_snapshot: Dictionary = minimap.call("validation_snapshot") if minimap != null else {}
	var map_size: Dictionary = minimap_snapshot.get("map_size", {}) if minimap_snapshot.get("map_size", {}) is Dictionary else {}
	if minimap == null or not minimap.is_visible_in_tree() or minimap.focus_mode != Control.FOCUS_ALL or int(minimap_snapshot.get("terrain_cell_count", 0)) != int(map_size.get("x", 0)) * int(map_size.get("y", 0)):
		return _fail("Functional minimap contract failed at %s: %s" % [viewport, JSON.stringify(minimap_snapshot)])
	var target := Vector2i(maxi(int(map_size.get("x", 1)) - 2, 0), maxi(int(map_size.get("y", 1)) - 2, 0))
	var camera_before: Dictionary = shell.get_node("%Map").call("validation_view_metrics")
	var recenter: Dictionary = shell.call("validation_minimap_recenter", target.x, target.y)
	var camera_after: Dictionary = recenter.get("map_view", {}) if recenter.get("map_view", {}) is Dictionary else {}
	if not bool(recenter.get("authority_exact", false)) or not bool(recenter.get("selection_exact", false)) or not bool(recenter.get("movement_exact", false)):
		return _fail("Minimap recenter mutated authority at %s: %s" % [viewport, JSON.stringify(recenter)])
	if bool(camera_after.get("pan_supported", false)) and camera_before.get("camera_focus_tile_precise", {}) == camera_after.get("camera_focus_tile_precise", {}):
		return _fail("Minimap recenter did not update a pannable camera at %s." % viewport)
	var command_state: Dictionary = shell.call("validation_open_command_drawer")
	await get_tree().process_frame
	if not bool(command_state.get("command_drawer_visible", false)) or shell.get_node("%MinimapPanel").is_visible_in_tree():
		return _fail("Command drawer did not replace base rail content at %s." % viewport)
	shell.call("_on_close_drawers_pressed")
	await get_tree().process_frame
	var frontier_state: Dictionary = shell.call("validation_open_frontier_drawer")
	await get_tree().process_frame
	if not bool(frontier_state.get("frontier_drawer_visible", false)) or shell.get_node("%MinimapPanel").is_visible_in_tree():
		return _fail("Frontier drawer did not replace base rail content at %s." % viewport)
	shell.call("_on_close_drawers_pressed")
	await get_tree().process_frame
	var required_controls := ["%Resources", "%PrimaryAction", "%OpenCommand", "%OpenFrontier", "%EndTurn", "%SaveSlot", "%Save", "%Settings", "%Menu"]
	for path in required_controls:
		var control: Control = shell.get_node_or_null(path)
		if control == null or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE or control.tooltip_text.strip_edges() == "":
			return _fail("Required reachable control %s failed at %s: present=%s visible=%s focus=%s tooltip=%s rect=%s." % [path, viewport, control != null, control.is_visible_in_tree() if control != null else false, control.focus_mode if control != null else -1, control.tooltip_text if control != null else "", control.get_global_rect() if control != null else Rect2()])
	var army_bar: Control = shell.get_node_or_null("%ArmyManagement")
	var army_snapshot: Dictionary = shell.call("validation_army_management_snapshot")
	var army_rect := army_bar.get_global_rect() if army_bar != null else Rect2()
	for button_value in army_snapshot.get("buttons", []):
		var button_payload: Dictionary = button_value if button_value is Dictionary else {}
		var button_rect := _rect_from_payload(button_payload.get("rect", {}))
		if army_bar == null or not army_rect.encloses(button_rect):
			return _fail("Compact army slot escaped its rail owner at %s: army=%s button=%s." % [viewport, army_rect, button_rect])
	var town_actions: Control = shell.get_node_or_null("%TownActions")
	if town_actions == null or town_actions.get_child_count() < 1:
		return _fail("Generated player holdings did not reach the compact Town roster at %s." % viewport)
	return {
		"ok": true,
		"viewport": {"width": viewport.x, "height": viewport.y},
		"layout": layout,
		"minimap": minimap_snapshot,
		"camera_before": camera_before.get("camera_focus_tile_precise", {}),
		"camera_after": camera_after.get("camera_focus_tile_precise", {}),
		"town_roster_count": town_actions.get_child_count(),
		"army_slot_count": army_snapshot.get("buttons", []).size(),
		"reachable_control_count": required_controls.size(),
	}


func _capture_path(viewport: Vector2i) -> String:
	var directory := OS.get_environment(CAPTURE_ENV).strip_edges()
	if directory == "":
		return ""
	var absolute := ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(absolute)
	return absolute.path_join("overworld_map_first_%dx%d.png" % [viewport.x, viewport.y])


func _rect_from_payload(value: Variant) -> Rect2:
	var payload: Dictionary = value if value is Dictionary else {}
	return Rect2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)), float(payload.get("width", 0.0)), float(payload.get("height", 0.0)))


func _fail(message: String) -> Dictionary:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
	return {"ok": false, "message": message}
