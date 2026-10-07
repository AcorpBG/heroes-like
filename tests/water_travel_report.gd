extends Node

## Focused live report for HoMM3-style water travel and transit translation.
## Carves a small lake into a skirmish map and drives the real overworld rules:
## a shipyard builds a boat at its dock, the hero boards it (ending the day's
## movement), sails through a whirlpool (losing half of the weakest stack),
## steps ashore and boards again, with saves round-tripping in between. It also
## checks random-map translation by meaning, the one-time save migration and
## the pay-to-open gate prompt.

const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const CAPTURE_DIR := "res://.artifacts/water_travel"
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var _failures := []
var _checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_check_translation()
	_check_migration()
	var session = await _check_voyage()
	if session != null:
		await _check_rendering(session)
	_check_gate_prompt()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	if _failures.is_empty():
		print("WATER_TRAVEL_REPORT %s" % JSON.stringify(report))
	else:
		push_error("WATER_TRAVEL_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

# --- translation ---------------------------------------------------------------

func _check_translation() -> void:
	var rows := []
	for y in range(4):
		rows.append(["snow", "snow", "grass", "lava"])
	var base := {"placement_id": "probe", "kind": "resource_site", "x": 0, "y": 1, "level": 0, "visit_tile": {"x": 0, "y": 1, "level": 0}}
	var expect := {87: "site_shipyard", 111: "site_whirlpool", 43: "site_slipgate_mirror", 44: "site_slipgate_mirror", 45: "site_slipgate_mirror", 103: "site_basalt_undergate"}
	for type_id in expect:
		var object := base.duplicate(true)
		object["h3m_type_id"] = type_id
		_check(String(GeneratedRewards.resolve(object, [], rows).get("site_id", "")) == expect[type_id], "type %d translates to %s" % [type_id, expect[type_id]])
	for type_id in [9, 33, 212, 215, 219]:
		var object := base.duplicate(true)
		object["h3m_type_id"] = type_id
		_check(String(GeneratedRewards.resolve(object, [], rows).get("site_id", "")) == "site_frost_toll_bar", "gate type %d on snow becomes the frost toll bar" % type_id)
		object["x"] = 3
		_check(String(GeneratedRewards.resolve(object, [], rows).get("site_id", "")) == "site_ash_sluice_lock", "gate type %d on lava becomes the ash sluice lock" % type_id)
	var boat := base.duplicate(true)
	boat["h3m_type_id"] = 8
	var keymaster := base.duplicate(true)
	keymaster["h3m_type_id"] = 10
	_check(GeneratedRewards.is_skipped(boat) and GeneratedRewards.is_skipped(keymaster), "boats and keymaster's tents are not resource sites")
	_check(GeneratedRewards.boat_tile(boat) == {"x": 0, "y": 1, "level": 0}, "a HoMM3 boat waits on its water tile")
	var bridge = load("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
	var boats: Array = bridge.boats_from_objects([boat, keymaster])
	_check(boats.size() == 1 and String(boats[0].get("id", "")) == "boat_probe", "the map bridge turns HoMM3 boats into boats")

# --- migration -----------------------------------------------------------------

func _check_migration() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var sources := {}
	var legacy := [
		{"placement_id": "legacy_shipyard", "h3m_type_id": 87, "site_id": "site_ash_sluice_lock", "object_id": "object_ash_sluice_lock", "collected": true, "x": 2, "y": 2, "visit_tile": {"x": 2, "y": 2}},
		{"placement_id": "legacy_boat", "h3m_type_id": 8, "site_id": "site_reef_chain_boom", "object_id": "object_reef_chain_boom", "x": 3, "y": 3, "visit_tile": {"x": 3, "y": 3}},
		{"placement_id": "legacy_tent", "h3m_type_id": 10, "site_id": "site_charter_bar_gate", "object_id": "object_charter_bar_gate", "x": 4, "y": 4, "visit_tile": {"x": 4, "y": 4}},
		{"placement_id": "legacy_open_gate", "h3m_type_id": 9, "site_id": "site_charter_bar_gate", "object_id": "object_charter_bar_gate", "collected": true, "x": 5, "y": 5, "visit_tile": {"x": 5, "y": 5}},
	]
	for node in legacy:
		nodes.append(node.duplicate(true))
		var source: Dictionary = node.duplicate(true)
		source.erase("collected")
		source["kind"] = "resource_site"
		sources[String(node.placement_id)] = source
	session.overworld["resource_nodes"] = nodes
	session.overworld["package_source_objects_by_id"] = sources
	session.overworld.erase(OverworldRules.GENERATED_TRANSIT_TRANSLATION_KEY)
	OverworldRules.normalize_overworld_state(session)
	var by_id := {}
	for node in session.overworld.get("resource_nodes", []):
		by_id[String(node.get("placement_id", ""))] = node
	_check(String(by_id.get("legacy_shipyard", {}).get("site_id", "")) == "site_shipyard" and not bool(by_id.get("legacy_shipyard", {}).get("collected", true)), "an old shipyard save becomes a working shipyard")
	_check(not by_id.has("legacy_boat") and not WaterTravel.boat_by_id(session, "boat_legacy_boat").is_empty(), "an old boat site becomes a boat")
	_check(not by_id.has("legacy_tent"), "an old keymaster's tent is removed")
	_check(String(by_id.get("legacy_open_gate", {}).get("site_id", "")) == "site_charter_bar_gate" and bool(by_id.get("legacy_open_gate", {}).get("collected", false)), "an opened gate stays open")
	_check(int(session.overworld.get(OverworldRules.GENERATED_TRANSIT_TRANSLATION_KEY, 0)) == OverworldRules.GENERATED_TRANSIT_TRANSLATION_VERSION, "the migration runs once")

# --- the voyage ----------------------------------------------------------------

func _check_voyage():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var origin := _clear_area(session, Vector2i(10, 7))
	if origin.x < 0:
		_check(false, "no clear area for the lake")
		return null
	# Lake: columns 1..7, rows 0..5 of the area. Shore hero at (0, 2).
	var rows: Array = session.overworld.get("map", [])
	for y in range(origin.y, origin.y + 6):
		for x in range(origin.x + 1, origin.x + 8):
			rows[y][x] = "water"
	session.overworld["map"] = rows
	var shore := origin + Vector2i(0, 2)
	var shipyard_visit := origin + Vector2i(0, 4)
	var whirl_a := origin + Vector2i(4, 1)
	var whirl_b := origin + Vector2i(6, 4)
	var far_shore := origin + Vector2i(8, 2)
	var nodes: Array = session.overworld.get("resource_nodes", [])
	nodes.append({"placement_id": "test_shipyard", "site_id": "site_shipyard", "object_id": "object_shipyard", "kind": "resource_site", "x": shipyard_visit.x, "y": shipyard_visit.y, "visit_tile": {"x": shipyard_visit.x, "y": shipyard_visit.y}, "body_tiles": [{"x": shipyard_visit.x, "y": shipyard_visit.y + 1}]})
	for entry in [["test_whirl_a", whirl_a], ["test_whirl_b", whirl_b]]:
		var tile: Vector2i = entry[1]
		nodes.append({"placement_id": entry[0], "site_id": "site_whirlpool", "object_id": "object_whirlpool", "kind": "resource_site", "x": tile.x, "y": tile.y, "visit_tile": {"x": tile.x, "y": tile.y}})
	session.overworld["resource_nodes"] = nodes
	session.overworld["resources"] = {"gold": 5000, "wood": 40, "ore": 20}
	_place_hero(session, shore)
	var army: Dictionary = session.overworld.get("army", {})
	army["stacks"] = [{"unit_id": "unit_river_guard", "count": 20}, {"unit_id": "unit_ember_archer", "count": 9}]
	session.overworld["army"] = army
	HeroCommandRules.commit_active_hero(session)
	session = SessionState.set_active_session(session)
	OverworldRules.normalize_overworld_state(session)

	# Walking heroes cannot use water, except to board a free boat.
	var water := origin + Vector2i(2, 2)
	_check(OverworldRules.hero_route_tile_blocked(session, water.x, water.y) and not OverworldRules.hero_route_destination(session, water.x, water.y), "a walking hero treats water as blocked")

	# The shipyard asks first, then builds a boat at its dock.
	_set_movement(session, 10)
	var visit := OverworldRules.try_move_along_route(session, [shore, shore + Vector2i(0, 1), shipyard_visit])
	_check(String(visit.get("route", "")) == "reward_choice" and visit.get("reward_choice", {}).get("choices", []).size() == 1, "the shipyard offers to build a boat %s" % visit.get("message", ""))
	var gold_before := int(session.overworld.resources.gold)
	var built := OverworldRules.choose_resource_reward(session, "build_boat", visit.get("reward_choice", {}).get("context", {}))
	var dock := WaterTravel.dock_tile(session, _node(session, "test_shipyard"))
	_check(bool(built.get("ok", false)) and int(session.overworld.resources.gold) == gold_before - 1000 and int(session.overworld.resources.wood) == 30, "building a boat costs 1,000 gold and 10 wood %s" % built.get("message", ""))
	_check(WaterTravel.boats(session).size() == 1 and not WaterTravel.free_boat_at(session, Vector2i(int(dock.get("x", -1)), int(dock.get("y", -1)))).is_empty(), "the boat waits at the dock %s" % [WaterTravel.boats(session)])
	var again := OverworldRules.choose_resource_reward(session, "build_boat", visit.get("reward_choice", {}).get("context", {}))
	_check(not bool(again.get("ok", true)) and int(session.overworld.resources.gold) == gold_before - 1000, "a full dock refuses a second boat without charging")

	# Boarding ends the day's movement.
	var dock_tile := Vector2i(int(dock.x), int(dock.y))
	_check(OverworldRules.hero_route_destination(session, dock_tile.x, dock_tile.y), "a walking hero may end a route on a free boat")
	var board := OverworldRules.try_move_along_route(session, _route(session, shipyard_visit, dock_tile))
	_check(WaterTravel.is_sailing(session) and int(session.overworld.movement.current) == 0, "boarding ends the day's movement %s" % board.get("message", ""))
	_check(String(WaterTravel.boats(session)[0].get("hero_id", "")) == String(session.overworld.active_hero_id), "the boat carries the hero")
	session = _round_trip(session, "sailing save")
	_check(WaterTravel.is_sailing(session), "a sailing hero is still aboard after loading")

	# Sailing: water is open, land only as a place to step ashore.
	_set_movement(session, 10)
	_check(OverworldRules.hero_route_tile_blocked(session, shore.x, shore.y) and not OverworldRules.hero_route_tile_blocked(session, water.x, water.y), "a sailing hero moves on water only")
	var loss_before := _stack_count(session, "unit_ember_archer")
	var whirl := OverworldRules.try_move_along_route(session, _route(session, _hero_tile(session), whirl_a))
	var hero_tile := _hero_tile(session)
	_check(maxi(abs(hero_tile.x - whirl_b.x), abs(hero_tile.y - whirl_b.y)) == 1, "the whirlpool throws the boat out at the other whirlpool %s %s" % [hero_tile, whirl.get("message", "")])
	_check(_stack_count(session, "unit_ember_archer") == loss_before - loss_before / 2 and _stack_count(session, "unit_river_guard") == 20, "the weakest stack loses half its creatures")
	var boat: Dictionary = WaterTravel.boats(session)[0]
	_check(Vector2i(int(boat.x), int(boat.y)) == hero_tile, "the boat follows the hero")

	# Going ashore ends the day's movement and leaves the boat moored.
	_set_movement(session, 10)
	var ashore := OverworldRules.try_move_along_route(session, _route(session, hero_tile, far_shore))
	boat = WaterTravel.boats(session)[0]
	_check(not WaterTravel.is_sailing(session) and _hero_tile(session) == far_shore and int(session.overworld.movement.current) == 0, "stepping ashore ends the day's movement %s" % ashore.get("message", ""))
	_check(String(boat.get("hero_id", "")) == "" and WaterTravel.is_water(session, int(boat.x), int(boat.y)), "the boat stays moored on the water")
	session = _round_trip(session, "moored save")
	_check(WaterTravel.free_boats(session, 0).size() == 1, "a moored boat survives saving")

	# A walking hero can board the moored boat again.
	_set_movement(session, 10)
	OverworldRules.try_move_along_route(session, _route(session, _hero_tile(session), Vector2i(int(boat.x), int(boat.y))))
	_check(WaterTravel.is_sailing(session), "the hero boards the moored boat again")
	return session

# --- rendering -----------------------------------------------------------------

func _check_rendering(session) -> void:
	session = SessionState.set_active_session(session)
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var shipyard := _node(session, "test_shipyard")
	var dock := WaterTravel.dock_tile(session, shipyard)
	# Show a moored boat beside the sailing hero for the capture.
	var spare := Vector2i(int(dock.get("x", 0)), int(dock.get("y", 0)))
	if WaterTravel.any_boat_at(session, spare, 0):
		spare += Vector2i(1, 0)
	WaterTravel.add_boat(session, spare, 0, "capture_boat")
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	for _frame in range(6):
		await get_tree().process_frame
	var view = shell.get("_map_view")
	var boats_indexed: Dictionary = view.get("_boats_by_tile") if view != null else {}
	_check(boats_indexed.size() >= 1, "the map draws moored boats %d" % boats_indexed.size())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/voyage.png" % CAPTURE_DIR)
	shell.queue_free()
	for _frame in range(2):
		await get_tree().process_frame

# --- gates ---------------------------------------------------------------------

func _check_gate_prompt() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var origin := _clear_area(session, Vector2i(3, 3))
	var gate_tile := origin + Vector2i(1, 1)
	var nodes: Array = session.overworld.get("resource_nodes", [])
	nodes.append({"placement_id": "test_gate", "site_id": "site_charter_bar_gate", "object_id": "object_charter_bar_gate", "kind": "resource_site", "x": gate_tile.x, "y": gate_tile.y, "visit_tile": {"x": gate_tile.x, "y": gate_tile.y}})
	session.overworld["resource_nodes"] = nodes
	session.overworld["resources"] = {"gold": 1000, "wood": 10, "ore": 10}
	_place_hero(session, origin)
	session = SessionState.set_active_session(session)
	OverworldRules.normalize_overworld_state(session)
	_set_movement(session, 5)
	var visit := OverworldRules.try_move_along_route(session, [origin, gate_tile])
	_check(String(visit.get("route", "")) == "reward_choice" and int(session.overworld.resources.gold) == 1000, "a gate asks before taking payment %s" % visit.get("message", ""))
	var opened := OverworldRules.choose_resource_reward(session, OverworldRules.ROUTE_LOCK_CHOICE_ID, visit.get("reward_choice", {}).get("context", {}))
	_check(bool(opened.get("ok", false)) and int(session.overworld.resources.gold) == 820 and String(_node(session, "test_gate").get("route_state_id", "")) == "opened", "paying opens the gate %s" % opened.get("message", ""))

# --- helpers -------------------------------------------------------------------

## An area well away from towns, cleared to open grass: sites, armies,
## artifacts and scenery inside it (plus a one-tile margin) are removed.
func _clear_area(session, size: Vector2i) -> Vector2i:
	# The skirmish map is tiny; widen it with open grass to the east and south.
	var rows: Array = session.overworld.get("map", [])
	var width := 30
	var height := 20
	for y in range(height):
		if y >= rows.size():
			rows.append([])
		while rows[y].size() < width:
			rows[y].append("grass")
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height}
	session.overworld.erase("fog")
	session.overworld.erase("terrain_layers")
	OverworldRules.normalize_overworld_state(session)
	var map_size := OverworldRules.derive_map_size(session)
	var area := Rect2i(-1, -1, 0, 0)
	for y in range(2, map_size.y - size.y - 2):
		for x in range(2, map_size.x - size.x - 2):
			var candidate := Rect2i(x - 1, y - 1, size.x + 2, size.y + 2)
			var near_town := false
			for town in session.overworld.get("towns", []):
				if candidate.grow(3).has_point(Vector2i(int(town.get("x", -99)), int(town.get("y", -99)))):
					near_town = true
					break
			if not near_town:
				area = candidate
				break
		if area.position.x >= 0:
			break
	if area.position.x < 0:
		return Vector2i(-1, -1)
	var inside := func(value: Variant) -> bool:
		if not (value is Dictionary):
			return false
		if area.has_point(Vector2i(int(value.get("x", -99)), int(value.get("y", -99)))):
			return true
		for key in ["visit_tile", "position"]:
			var tile: Variant = value.get(key, {})
			if tile is Dictionary and area.has_point(Vector2i(int(tile.get("x", -99)), int(tile.get("y", -99)))):
				return true
		for tile in value.get("body_tiles", []):
			if tile is Dictionary and area.has_point(Vector2i(int(tile.get("x", -99)), int(tile.get("y", -99)))):
				return true
		return false
	for key in ["resource_nodes", "encounters", "artifact_nodes", "map_objects"]:
		var kept := []
		for value in session.overworld.get(key, []):
			if not inside.call(value):
				kept.append(value)
		session.overworld[key] = kept
	rows = session.overworld.get("map", [])
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			rows[y][x] = "grass"
	session.overworld["map"] = rows
	OverworldRules.normalize_overworld_state(session)
	return area.position + Vector2i.ONE

func _place_hero(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if String(heroes[index].get("id", "")) == String(hero.get("id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _set_movement(session, amount: int) -> void:
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = amount
	movement["max"] = maxi(int(movement.get("max", amount)), amount)
	session.overworld["movement"] = movement
	HeroCommandRules.commit_active_hero(session)

func _hero_tile(session) -> Vector2i:
	return OverworldRules.hero_position(session)

func _node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _stack_count(session, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total

## The same search the overworld shell uses, on the active hero's route rules.
func _route(session, start: Vector2i, goal: Vector2i) -> Array:
	var parents := {start: start}
	var queue := [start]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if current == goal:
			break
		for delta in DIRECTIONS:
			var next: Vector2i = current + delta
			if parents.has(next):
				continue
			if OverworldRules.tile_step_cuts_blocked_corner(session, current, next):
				continue
			if OverworldRules.hero_route_tile_blocked(session, next.x, next.y) and not (next == goal and OverworldRules.hero_route_destination(session, next.x, next.y)):
				continue
			if next != goal and OverworldRules.tile_has_route_interaction(session, next.x, next.y):
				continue
			parents[next] = current
			queue.append(next)
	if not parents.has(goal):
		_check(false, "no route from %s to %s" % [start, goal])
		return [start]
	var path := [goal]
	while path[0] != start:
		path.push_front(parents[path[0]])
	return path

func _round_trip(session, label: String):
	var restored = SessionStateStore.new_session_data()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	_check(restored.overworld.get("boats", []) == session.overworld.get("boats", []), "%s keeps the boats" % label)
	return SessionState.set_active_session(restored)
