extends Node

const REPORT_ID := "OVERWORLD_TOWN_FOOTPRINT_CLICK_ENTRY_ROUTING_REPORT"
const TOWN_PLACEMENT_ID := "town_footprint_click_fixture"
const TOWN_ENTRY := Vector2i(4, 2)
const TOWN_ORIGIN := Vector2i(3, 1)
const HERO_START := Vector2i(1, 2)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	var session = SessionState.set_active_session(_fixture_session())
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session != null:
		session = live_session
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("town_footprint_selection"):
		return _fail("Live map view does not expose town footprint click ownership.")

	var footprint_rows := []
	var body_cells := []
	for y_offset in range(2):
		for x_offset in range(3):
			var clicked_tile := TOWN_ORIGIN + Vector2i(x_offset, y_offset)
			var selection: Dictionary = map_view.call("town_footprint_selection", clicked_tile)
			var expected_entry := clicked_tile == TOWN_ENTRY
			if (
				String(selection.get("town_placement_id", "")) != TOWN_PLACEMENT_ID
				or String(selection.get("owner", "")) != "player"
				or selection.get("entry_tile", Vector2i(-1, -1)) != TOWN_ENTRY
				or bool(selection.get("is_entry_tile", false)) != expected_entry
			):
				return _fail("Town footprint cell did not retain exact entry/body ownership.", {"tile": _tile_payload(clicked_tile), "selection": selection})
			footprint_rows.append({
				"tile": _tile_payload(clicked_tile),
				"entry": expected_entry,
				"role": String(selection.get("tile_role", "")),
			})
			if not expected_entry:
				body_cells.append(clicked_tile)
	if footprint_rows.size() != 6 or body_cells.size() != 5:
		return _fail("Town footprint did not retain one entry plus five body cells.", footprint_rows)

	var reset_selection: Dictionary = shell.call("validation_select_tile", HERO_START.x, HERO_START.y)
	if reset_selection.get("selected_tile", {}) != _tile_payload(HERO_START):
		return _fail("Focused fixture could not reset selection to the active hero.", reset_selection)
	var towns_before: Array = session.overworld.get("towns", []).duplicate(true)
	var first_entry_click: Dictionary = shell.call("validation_click_tile", TOWN_ENTRY.x, TOWN_ENTRY.y)
	var first_selected: Dictionary = first_entry_click.get("selected_tile", {}) if first_entry_click.get("selected_tile", {}) is Dictionary else {}
	var first_primary: Dictionary = first_entry_click.get("primary_action", {}) if first_entry_click.get("primary_action", {}) is Dictionary else {}
	if (
		first_selected != _tile_payload(TOWN_ENTRY)
		or String(first_primary.get("id", "")) != "advance_route"
		or String(session.game_state) != "overworld"
		or OverworldRules.hero_position(session) != HERO_START
	):
		return _fail("First entry click did not select a movement route.", first_entry_click)

	var second_entry_click: Dictionary = shell.call("validation_click_tile", TOWN_ENTRY.x, TOWN_ENTRY.y)
	var arrival_primary: Dictionary = second_entry_click.get("primary_action", {}) if second_entry_click.get("primary_action", {}) is Dictionary else {}
	if (
		OverworldRules.hero_position(session) != TOWN_ENTRY
		or String(session.game_state) != "overworld"
		or String(session.flags.get(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, "")) != ""
		or String(arrival_primary.get("id", "")) != "visit_town"
	):
		return _fail("Entry route did not move onto the gate without opening Town.", {
			"hero": _tile_payload(OverworldRules.hero_position(session)),
			"game_state": String(session.game_state),
			"active_town_placement_id": String(session.flags.get(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, "")),
			"arrival_primary": arrival_primary,
			"last_action": String(session.flags.get("last_action", "")),
		})
	var movement_after_entry: Dictionary = session.overworld.get("movement", {}).duplicate(true)

	var body_tile: Vector2i = body_cells[0]
	var scene_tree := get_tree()
	map_view.tile_pressed.emit(body_tile)
	if (
		String(session.game_state) != "town"
		or String(session.flags.get(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, "")) != TOWN_PLACEMENT_ID
		or OverworldRules.hero_position(session) != TOWN_ENTRY
		or session.overworld.get("movement", {}) != movement_after_entry
		or session.overworld.get("towns", []) != towns_before
	):
		return _fail("Town body click did not open the exact owned Town without field mutation.", {
			"game_state": String(session.game_state),
			"active_town_placement_id": String(session.flags.get(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, "")),
			"hero": _tile_payload(OverworldRules.hero_position(session)),
			"movement": session.overworld.get("movement", {}),
		})

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"footprint_cells": footprint_rows,
		"entry_tile": _tile_payload(TOWN_ENTRY),
		"entry_route_moves_without_opening": true,
		"arrival_primary_action": "visit_town",
		"body_click_opens_town": true,
		"body_cell_count": 5,
		"town_authority_exact": true,
		"movement_preserved_on_body_open": true,
	})])
	scene_tree.quit(0)

func _fixture_session():
	var rows := []
	for _y in range(5):
		var row := []
		for _x in range(8):
			row.append("grass")
		rows.append(row)
	var position := _tile_payload(HERO_START)
	var session = SessionStateStore.SessionData.new("town_footprint_click_fixture", "town_footprint_click_fixture", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": 8, "height": 5},
		"hero_position": position.duplicate(true),
		"hero": {"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true)},
		"active_hero_id": "hero_lyra",
		"player_heroes": [{"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true), "is_active": true, "is_primary": true}],
		"movement": {"current": 6, "max": 6},
		"towns": [{
			"placement_id": TOWN_PLACEMENT_ID,
			"town_id": "town_riverwatch",
			"x": TOWN_ENTRY.x,
			"y": TOWN_ENTRY.y,
			"owner": "player",
			"garrison": [],
		}],
		"resource_nodes": [],
		"artifact_nodes": [],
		"encounters": [],
		"resolved_encounters": [],
		"terrain_layers": {},
		"fog": _all_visible_fog(8, 5),
	})
	session.overworld["command_briefing"] = {"signature": "town_footprint_click_fixture|campaign", "shown": true, "shown_day": 1}
	return session

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var visible_row := []
		var explored_row := []
		for _x in range(width):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _fail(message: String, payload: Variant = {}) -> void:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
