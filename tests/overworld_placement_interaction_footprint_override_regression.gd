extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "OVERWORLD_PLACEMENT_INTERACTION_FOOTPRINT_OVERRIDE_REGRESSION"
const PLACEMENT_ID := "reef_coin_override_fixture"
const ACTION_TILE := Vector2i(4, 4)
const NON_ACTION_BODY_TILE := Vector2i(3, 4)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Variant = _fixture_session()
	OverworldRules.normalize_overworld_state(session)
	var failures := []
	var surface := OverworldRules.overworld_object_placement_pathing_surface(session, PLACEMENT_ID)
	var body_tiles: Array = surface.get("body_tiles", []) if surface.get("body_tiles", []) is Array else []
	var interaction_tiles: Array = surface.get("interaction_tiles", []) if surface.get("interaction_tiles", []) is Array else []
	if not _surface_has_tile(body_tiles, ACTION_TILE):
		failures.append("Reef Coin Assay action tile is not inside the body footprint: %s" % JSON.stringify(surface))
	if not _surface_has_tile(interaction_tiles, ACTION_TILE):
		failures.append("Reef Coin Assay did not expose the inside-footprint action tile: %s" % JSON.stringify(surface))
	if not OverworldRules.tile_is_blocked(session, ACTION_TILE.x, ACTION_TILE.y):
		failures.append("Inside-footprint action tile should remain in the blocking lookup.")
	if not OverworldRules.tile_is_actionable_route_destination(session, ACTION_TILE.x, ACTION_TILE.y):
		failures.append("Inside-footprint blocked action tile should remain actionable.")
	if not OverworldRules.tile_is_blocked(session, NON_ACTION_BODY_TILE.x, NON_ACTION_BODY_TILE.y):
		failures.append("Non-action body tile should stay blocked.")
	if OverworldRules.tile_is_actionable_route_destination(session, NON_ACTION_BODY_TILE.x, NON_ACTION_BODY_TILE.y):
		failures.append("Non-action body tile should not become actionable.")

	var blocked_probe: Variant = _fixture_session()
	OverworldRules.normalize_overworld_state(blocked_probe)
	_set_active_hero_position(blocked_probe, Vector2i(3, 5))
	blocked_probe.overworld["movement"] = {"current": 4, "max": 4}
	var blocked_result: Dictionary = OverworldRules.try_move(blocked_probe, 0, -1)
	if bool(blocked_result.get("ok", false)):
		failures.append("Moving into a non-action body tile should still fail: %s" % JSON.stringify(blocked_result))

	_set_active_hero_position(session, Vector2i(4, 5))
	session.overworld["movement"] = {"current": 4, "max": 4}
	var visit_result: Dictionary = OverworldRules.try_move(session, 0, -1)
	var claimed: Dictionary = _resource_node(session, PLACEMENT_ID)
	if not bool(visit_result.get("ok", false)):
		failures.append("Moving onto the blocked action tile should activate the site: %s" % JSON.stringify(visit_result))
	if OverworldRules.hero_position(session) != ACTION_TILE:
		failures.append("Hero did not land on the actionable destination tile: %s" % OverworldRules.hero_position(session))
	if String(claimed.get("collected_by_faction_id", "")) != "player":
		failures.append("Action tile did not capture Reef Coin Assay: %s" % JSON.stringify(claimed))

	var overlay: Dictionary = _overlay_snapshot(_fixture_session())
	if not _tile_present(overlay.get("blocker_tiles", []), ACTION_TILE, "resource_body", PLACEMENT_ID):
		failures.append("Overlay did not keep the action tile in the blocker/body layer: %s" % JSON.stringify(overlay))
	if not _tile_present(overlay.get("interactable_tiles", []), ACTION_TILE, "resource_visit", PLACEMENT_ID):
		failures.append("Overlay did not draw the overlapped action tile in the interactable layer: %s" % JSON.stringify(overlay))

	if not failures.is_empty():
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(failures)])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"placement_id": PLACEMENT_ID,
		"object_id": "object_reef_coin_assay",
		"surface": surface,
		"visit_result": {
			"ok": bool(visit_result.get("ok", false)),
			"hero_position": _tile_payload(OverworldRules.hero_position(session)),
			"claimed_by": String(claimed.get("collected_by_faction_id", "")),
		},
		"blocked_body_move": blocked_result,
		"overlay_counts": {
			"blocker": int(overlay.get("blocker_tile_count", 0)),
			"interactable": int(overlay.get("interactable_tile_count", 0)),
		},
	})])
	get_tree().quit(0)

func _overlay_snapshot(session: Variant) -> Dictionary:
	var view: Variant = OverworldMapViewScript.new()
	view.size = Vector2(640, 480)
	add_child(view)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(4, 4))
	view.set_placement_debug_overlay_enabled(true)
	var snapshot: Dictionary = view.validation_placement_debug_overlay_snapshot()
	remove_child(view)
	view.queue_free()
	return snapshot

func _fixture_session() -> Variant:
	var width := 8
	var height := 8
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	var session = SessionStateStore.SessionData.new("reef_coin_override", "reef_coin_override", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": width, "height": height},
		"hero_position": {"x": 4, "y": 5},
		"hero": {"hero_id": "hero_lyra", "position": {"x": 4, "y": 5}},
		"player_heroes": [{"hero_id": "hero_lyra", "x": 4, "y": 5, "is_active": true}],
		"movement": {"current": 4, "max": 4},
		"resource_nodes": [
			{
				"placement_id": PLACEMENT_ID,
				"site_id": "site_reef_coin_assay",
				"object_id": "object_reef_coin_assay",
				"x": 4,
				"y": 4,
				"collected": false,
				"collected_by_faction_id": "",
			},
		],
		"artifact_nodes": [],
		"encounters": [],
		"towns": [],
		"resolved_encounters": [],
		"fog": _all_visible_fog(width, height),
	})
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
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

func _set_active_hero_position(session: Variant, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _resource_node(session: Variant, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _surface_has_tile(tiles: Array, tile: Vector2i) -> bool:
	for tile_value in tiles:
		if not (tile_value is Dictionary):
			continue
		if int(tile_value.get("x", -1)) == tile.x and int(tile_value.get("y", -1)) == tile.y:
			return true
	return false

func _tile_present(tiles_value: Variant, tile: Vector2i, kind: String, placement_id: String) -> bool:
	if not (tiles_value is Array):
		return false
	for value in tiles_value:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		if int(entry.get("x", -1)) != tile.x or int(entry.get("y", -1)) != tile.y:
			continue
		var kinds: Array = entry.get("kinds", []) if entry.get("kinds", []) is Array else []
		var placement_ids: Array = entry.get("placement_ids", []) if entry.get("placement_ids", []) is Array else []
		return kind in kinds and placement_id in placement_ids
	return false

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}
