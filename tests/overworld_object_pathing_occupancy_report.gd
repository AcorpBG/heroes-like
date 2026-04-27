extends Node

const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "brightwood_sawmill"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session = SessionState.set_active_session(session)

	var surface := OverworldRules.overworld_object_placement_pathing_surface(session, PLACEMENT_ID)
	if surface.is_empty():
		_fail("missing pathing surface for %s" % PLACEMENT_ID)
		return
	if String(surface.get("object_id", "")) != "object_brightwood_sawmill":
		_fail("unexpected object surface: %s" % surface)
		return
	if int(surface.get("body_tile_count", 0)) != 10:
		_fail("sawmill body mask should contain 10 blocking tiles, got %s" % surface)
		return
	var footprint: Dictionary = surface.get("footprint", {})
	if int(footprint.get("visual_tile_count", 0)) != 15:
		_fail("sawmill visual footprint should be 15 tiles, got %s" % surface)
		return
	if int(surface.get("interaction_tile_count", 0)) != 1:
		_fail("sawmill should expose one separate interaction tile, got %s" % surface)
		return

	var body_tile := Vector2i(16, 3)
	var lower_body_tile := Vector2i(14, 4)
	var interaction_tile := Vector2i(16, 4)
	var visual_non_body_tile := Vector2i(18, 4)
	if not _surface_has_tile(surface.get("body_tiles", []), body_tile):
		_fail("expected body tile %s absent from %s" % [body_tile, surface])
		return
	if not _surface_has_tile(surface.get("interaction_tiles", []), interaction_tile):
		_fail("expected interaction tile %s absent from %s" % [interaction_tile, surface])
		return
	if OverworldRules.tile_is_blocked(session, interaction_tile.x, interaction_tile.y):
		_fail("interaction tile should stay pathable: %s" % interaction_tile)
		return
	if not OverworldRules.tile_is_blocked(session, body_tile.x, body_tile.y):
		_fail("body tile should block pathing: %s" % body_tile)
		return
	if not OverworldRules.tile_is_blocked(session, lower_body_tile.x, lower_body_tile.y):
		_fail("lower-row body tile should block pathing: %s" % lower_body_tile)
		return
	if OverworldRules.tile_is_blocked(session, visual_non_body_tile.x, visual_non_body_tile.y):
		_fail("visual footprint tile outside body mask should remain pathable: %s" % visual_non_body_tile)
		return

	_set_active_hero_position(session, Vector2i(16, 5))
	session.overworld["movement"] = {"current": 4, "max": 4}
	OverworldRules.normalize_overworld_state(session)
	var visit_result: Dictionary = OverworldRules.try_move(session, 0, -1)
	if not bool(visit_result.get("ok", false)):
		_fail("moving onto the interaction tile should be valid: %s" % visit_result)
		return
	var claimed := _resource_node(session, PLACEMENT_ID)
	if String(claimed.get("collected_by_faction_id", "")) != "player":
		_fail("interaction tile did not visit/capture the object-backed resource node: %s" % claimed)
		return
	var blocked_result: Dictionary = OverworldRules.try_move(session, 0, -1)
	if bool(blocked_result.get("ok", false)):
		_fail("moving from interaction tile into body tile should be blocked: %s" % blocked_result)
		return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"adopted_runtime_fields": ["body_tiles", "approach.visit_offsets", "passability_class"],
		"surface": surface,
		"interaction_visit_result": {
			"ok": bool(visit_result.get("ok", false)),
			"hero_position": session.overworld.get("hero_position", {}),
			"claimed_by": String(claimed.get("collected_by_faction_id", "")),
		},
		"blocked_body_move": blocked_result,
	}
	print("OVERWORLD_OBJECT_PATHING_OCCUPANCY_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _surface_has_tile(tiles: Array, tile: Vector2i) -> bool:
	for tile_value in tiles:
		if not (tile_value is Dictionary):
			continue
		if int(tile_value.get("x", -1)) == tile.x and int(tile_value.get("y", -1)) == tile.y:
			return true
	return false

func _resource_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
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

func _fail(message: String) -> void:
	_failed = true
	push_error("Overworld object pathing occupancy report: %s" % message)
	get_tree().quit(1)
