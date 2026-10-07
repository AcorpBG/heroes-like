extends RefCounted
## HoMM3-style water travel. Boats sit on water tiles. A hero who walks onto a
## free boat boards it, and a sailing hero who steps onto open shore leaves it
## there; either step ends the hero's movement for the day. Sailing heroes move
## only on water. Shipyards build a boat at their dock, and whirlpools throw a
## boat out at another whirlpool for half of the weakest stack.
##
## Boats live in session.overworld.boats; a sailing hero carries boat_id.
## OverworldRules owns route checks and calls these helpers.

const Levels = preload("res://scripts/core/OverworldLevelRules.gd")

const BOATS_KEY := "boats"
const HERO_BOAT_KEY := "boat_id"
const BOAT_ASSET_ID := "mapobj_water_boat"
const SHIPYARD_SITE_ID := "site_shipyard"
const WHIRLPOOL_SITE_ID := "site_whirlpool"
const NEIGHBORS := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

static func boats(session) -> Array:
	if session == null:
		return []
	var value: Variant = session.overworld.get(BOATS_KEY, [])
	return value if value is Array else []

static func boat_by_id(session, boat_id: String) -> Dictionary:
	for boat in boats(session):
		if boat is Dictionary and String(boat.get("id", "")) == boat_id:
			return boat
	return {}

static func hero_boat_id(hero: Variant) -> String:
	return String(hero.get(HERO_BOAT_KEY, "")) if hero is Dictionary else ""

## True when the active hero is aboard a boat.
static func is_sailing(session) -> bool:
	return session != null and hero_boat_id(session.overworld.get("hero", {})) != ""

static func is_water(session, x: int, y: int, level: int = -1) -> bool:
	var rows: Array = Levels.terrain_rows(session, level)
	if y < 0 or y >= rows.size() or not (rows[y] is Array):
		return false
	var row: Array = rows[y]
	if x < 0 or x >= row.size():
		return false
	return ContentService.normalize_terrain_id(String(row[x])) == "water"

## A boat no hero is aboard, at this water tile.
static func free_boat_at(session, tile: Vector2i, level: int = -1) -> Dictionary:
	level = Levels.query_level(session, level)
	for boat in boats(session):
		if boat is Dictionary and String(boat.get("hero_id", "")) == "" and int(boat.get("x", -1)) == tile.x and int(boat.get("y", -1)) == tile.y and int(boat.get("level", 0)) == level:
			return boat
	return {}

static func any_boat_at(session, tile: Vector2i, level: int) -> bool:
	for boat in boats(session):
		if boat is Dictionary and int(boat.get("x", -1)) == tile.x and int(boat.get("y", -1)) == tile.y and int(boat.get("level", 0)) == level:
			return true
	return false

static func free_boats(session, level: int) -> Array:
	var result := []
	for boat in boats(session):
		if boat is Dictionary and String(boat.get("hero_id", "")) == "" and int(boat.get("level", 0)) == level:
			result.append(boat)
	return result

## Keeps the boat list and every hero's boat_id consistent: a boat follows the
## hero aboard it, and a hero whose boat is gone walks again.
static func normalize(session) -> void:
	if session == null:
		return
	var cleaned := []
	var known := {}
	for boat_value in boats(session):
		if not (boat_value is Dictionary):
			continue
		var boat_id := String(boat_value.get("id", "")).strip_edges()
		if boat_id == "" or known.has(boat_id):
			continue
		known[boat_id] = true
		cleaned.append({
			"id": boat_id,
			"x": int(boat_value.get("x", 0)),
			"y": int(boat_value.get("y", 0)),
			"level": int(boat_value.get("level", 0)),
			"hero_id": "",
		})
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	var active: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var aboard := {}
	for hero_value in heroes + [active]:
		if not (hero_value is Dictionary):
			continue
		var boat_id := hero_boat_id(hero_value)
		if boat_id == "":
			continue
		if not known.has(boat_id):
			hero_value.erase(HERO_BOAT_KEY)
			continue
		if not aboard.has(boat_id):
			aboard[boat_id] = hero_value
	for boat in cleaned:
		var hero: Variant = aboard.get(String(boat.id))
		if hero is Dictionary:
			var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
			boat["hero_id"] = String(hero.get("id", ""))
			boat["x"] = int(position.get("x", boat.x))
			boat["y"] = int(position.get("y", boat.y))
			boat["level"] = Levels.level_of(position)
	session.overworld[BOATS_KEY] = cleaned

static func add_boat(session, tile: Vector2i, level: int, id_hint: String) -> Dictionary:
	var list := boats(session).duplicate(true)
	var boat_id := id_hint
	var serial := 1
	while not boat_by_id(session, boat_id).is_empty():
		serial += 1
		boat_id = "%s_%d" % [id_hint, serial]
	var boat := {"id": boat_id, "x": tile.x, "y": tile.y, "level": level, "hero_id": ""}
	list.append(boat)
	session.overworld[BOATS_KEY] = list
	return boat

## The active hero takes the boat at this tile.
static func embark(session, boat: Dictionary) -> void:
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var list := boats(session).duplicate(true)
	for index in range(list.size()):
		if String(list[index].get("id", "")) == String(boat.get("id", "")):
			list[index]["hero_id"] = hero_id
	session.overworld[BOATS_KEY] = list
	_set_active_hero_boat(session, String(boat.get("id", "")))

## The active hero steps ashore; the boat stays moored at its water tile.
static func disembark(session, mooring: Vector2i, level: int) -> void:
	var boat_id := hero_boat_id(session.overworld.get("hero", {}))
	var list := boats(session).duplicate(true)
	for index in range(list.size()):
		if String(list[index].get("id", "")) == boat_id:
			list[index]["hero_id"] = ""
			list[index]["x"] = mooring.x
			list[index]["y"] = mooring.y
			list[index]["level"] = level
	session.overworld[BOATS_KEY] = list
	_set_active_hero_boat(session, "")

## Moves the active hero's boat with the hero.
static func follow_active_hero(session, tile: Vector2i, level: int) -> void:
	var boat_id := hero_boat_id(session.overworld.get("hero", {}))
	if boat_id == "":
		return
	var list := boats(session).duplicate(true)
	for index in range(list.size()):
		if String(list[index].get("id", "")) == boat_id:
			list[index]["x"] = tile.x
			list[index]["y"] = tile.y
			list[index]["level"] = level
	session.overworld[BOATS_KEY] = list

static func _set_active_hero_boat(session, boat_id: String) -> void:
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var active: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	if boat_id == "":
		active.erase(HERO_BOAT_KEY)
	else:
		active[HERO_BOAT_KEY] = boat_id
	session.overworld["hero"] = active
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_id:
			if boat_id == "":
				heroes[index].erase(HERO_BOAT_KEY)
			else:
				heroes[index][HERO_BOAT_KEY] = boat_id
	session.overworld["player_heroes"] = heroes

static func hero_at(session, tile: Vector2i, level: int) -> bool:
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
			if int(position.get("x", -999)) == tile.x and int(position.get("y", -999)) == tile.y and Levels.level_of(position) == level:
				return true
	return false

# --- shipyard ------------------------------------------------------------------

## The water tile where this shipyard launches boats: the open water tile next
## to its visit tile, or else next to its body, nearest the visit tile.
static func dock_tile(session, node: Dictionary) -> Dictionary:
	var level := Levels.level_of(node)
	var visit: Dictionary = node.get("visit_tile", {}) if node.get("visit_tile", {}) is Dictionary else {}
	var origin := Vector2i(int(visit.get("x", node.get("x", 0))), int(visit.get("y", node.get("y", 0))))
	var sources := [origin]
	for tile in node.get("body_tiles", []):
		if tile is Dictionary:
			sources.append(Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))))
	var best := Vector2i(-1, -1)
	var best_distance := 1 << 30
	for source in sources:
		for delta in NEIGHBORS:
			var tile: Vector2i = source + delta
			if not is_water(session, tile.x, tile.y, level):
				continue
			var distance := (tile - origin).length_squared()
			if distance < best_distance:
				best_distance = distance
				best = tile
	if best.x < 0:
		return {}
	return {"x": best.x, "y": best.y, "level": level}

## Why the shipyard cannot launch a boat now, or "" when it can.
static func dock_blocker(session, node: Dictionary) -> String:
	var dock := dock_tile(session, node)
	if dock.is_empty():
		return "This shipyard has no water at its dock."
	var tile := Vector2i(int(dock.x), int(dock.y))
	if any_boat_at(session, tile, int(dock.level)) or hero_at(session, tile, int(dock.level)):
		return "A boat already waits at the dock."
	return ""

static func build_boat(session, node: Dictionary) -> String:
	var blocker := dock_blocker(session, node)
	if blocker != "":
		return blocker
	var dock := dock_tile(session, node)
	add_boat(session, Vector2i(int(dock.x), int(dock.y)), int(dock.level), "boat_%s" % String(node.get("placement_id", "shipyard")))
	return ""

# --- whirlpool -----------------------------------------------------------------

## Another whirlpool's free water tile for this boat, chosen by a stable hash
## of the source, the day and the hero so a save always replays the same throw.
static func whirlpool_exit(session, node: Dictionary, blocked: Callable) -> Dictionary:
	var level := Levels.level_of(node)
	var source_id := String(node.get("placement_id", ""))
	var others := []
	for other in session.overworld.get("resource_nodes", []):
		if other is Dictionary and String(other.get("site_id", "")) == WHIRLPOOL_SITE_ID and String(other.get("placement_id", "")) != source_id and Levels.level_of(other) == level:
			others.append(other)
	if others.is_empty():
		return {}
	others.sort_custom(func(a, b): return String(a.get("placement_id", "")) < String(b.get("placement_id", "")))
	var key := "%s|%d|%s" % [source_id, int(session.day), String(session.overworld.get("active_hero_id", ""))]
	var start := int(posmod(key.hash(), others.size()))
	for offset in range(others.size()):
		var target: Dictionary = others[(start + offset) % others.size()]
		var visit: Dictionary = target.get("visit_tile", {}) if target.get("visit_tile", {}) is Dictionary else {}
		var center := Vector2i(int(visit.get("x", target.get("x", 0))), int(visit.get("y", target.get("y", 0))))
		for delta in NEIGHBORS:
			var tile: Vector2i = center + delta
			if is_water(session, tile.x, tile.y, level) and not any_boat_at(session, tile, level) and not hero_at(session, tile, level) and not bool(blocked.call(tile, level)):
				return {"x": tile.x, "y": tile.y, "level": level, "whirlpool": String(target.get("placement_id", ""))}
	return {}

## Half of the weakest stack (by total health), rounded down, never the last
## creature of the army.
static func whirlpool_losses(stacks: Array) -> Dictionary:
	var weakest := -1
	var weakest_health := 1 << 30
	var total := 0
	for index in range(stacks.size()):
		var stack: Variant = stacks[index]
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		total += count
		if count <= 0:
			continue
		var health := count * maxi(1, int(ContentService.get_unit(String(stack.get("unit_id", ""))).get("hp", 1)))
		if health < weakest_health:
			weakest_health = health
			weakest = index
	if weakest < 0:
		return {}
	var lost := int(stacks[weakest].get("count", 0)) / 2
	lost = mini(lost, total - 1)
	if lost <= 0:
		return {}
	return {"index": weakest, "unit_id": String(stacks[weakest].get("unit_id", "")), "lost": lost}
