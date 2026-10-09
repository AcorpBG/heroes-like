extends Node

# Heroes guard the tiles around them, as neutral armies do (owner report
# 2026-10-09: an enemy hero walked right past the main hero without a battle).
# On a generated map, in open ground, checks both sides:
# - the human: a computer player's hero claims its eight neighbours as combat
#   entries, routes cannot cross them, clicking the hero walks to the nearest
#   one, and stepping onto one starts the battle with that hero;
# - the computer: its search never routes through the human's hero's zone, a
#   hero that lands in it fights there, a hero strong enough attacks from it,
#   and a rival computer player's hero guards its tiles the same way;
# - a hero standing in a town's doorway leaves the defence to the town.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const WaterTravelRules = preload("res://scripts/core/WaterTravelRules.gd")
const REPORT_ID := "HERO_GUARD_ZONE_REPORT"
const SEED := "hero-guard-zone-20261009"
## The open ground the fixture needs around the human's hero, as offsets from
## it: room for a computer hero four tiles east and a detour two rows away.
const CLEAR_MIN := Vector2i(-4, -3)
const CLEAR_MAX := Vector2i(5, 3)

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var session = _start_session()
	if session == null:
		return
	var controllers := _ai_controllers(session)
	if controllers.size() < 2:
		return _fail("The generated skirmish needs two computer players, got %s." % JSON.stringify(controllers))
	var center := _open_square(session)
	if center == Vector2i(-1, -1):
		return _fail("No open stretch of land on the generated map.")
	_place_human(session, center)
	var hero_id := _ai_hero_id(session, controllers[0])
	if hero_id == "":
		return _fail("The first computer player has no hero.")

	var player_side := _check_player_side(session, center, hero_id)
	if _failed:
		return
	var ai_search := _check_ai_search(session, controllers[0], center, hero_id)
	if _failed:
		return
	var ai_ambush := _check_ai_lands_in_zone(session, controllers[0], center, hero_id)
	if _failed:
		return
	var ai_attack := _check_ai_attacks_from_zone(session, controllers[0], center, hero_id)
	if _failed:
		return
	var rivals := _check_rival_ai_heroes(session, controllers, center, hero_id)
	if _failed:
		return
	var doorway := _check_town_doorway(session, controllers[0])
	if _failed:
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": SEED,
		"center": [center.x, center.y],
		"player_side": player_side,
		"ai_search": ai_search,
		"ai_ambush": ai_ambush,
		"ai_attack": ai_attack,
		"rival_ai_heroes": rivals,
		"town_doorway": doorway,
	})])
	_cleanup()
	get_tree().quit(0)

# --- Human side ---------------------------------------------------------------

func _check_player_side(session, center: Vector2i, hero_id: String) -> Dictionary:
	var anchor := center + Vector2i(3, 0)
	_place_ai_hero(session, hero_id, anchor)
	var zone := 0
	for offset in _neighbours():
		var tile: Vector2i = anchor + offset
		var owner := OverworldRules.guard_engagement_encounter_at_tile(session, tile.x, tile.y, 0)
		if String(owner.get("placement_id", "")) != hero_id:
			_fail("Tile %s next to the computer hero is not its combat entry: %s." % [tile, JSON.stringify(owner).left(200)])
			return {}
		if not OverworldRules.tile_has_route_interaction(session, tile.x, tile.y, 0):
			_fail("Tile %s next to the computer hero does not end a route." % tile)
			return {}
		zone += 1
	# Walking past along the row next to it is refused.
	_refill_movement(session)
	var past := [center, center + Vector2i(1, 1), center + Vector2i(2, 1), center + Vector2i(3, 1), center + Vector2i(4, 1), center + Vector2i(5, 1)]
	var refused: Dictionary = OverworldRules.try_move_along_route(session, past)
	if bool(refused.get("ok", false)) or OverworldRules.hero_position(session) != center:
		_fail("The human walked past a computer hero: %s." % JSON.stringify(refused).left(300))
		return {}
	# Selecting the hero walks to the nearest tile of its zone.
	var approach := OverworldRules.guard_engagement_approach_route(session, _encounter(session, hero_id))
	if approach.is_empty() or approach[-1] != center + Vector2i(2, 0) or approach.size() != 3:
		_fail("Selecting the computer hero should route to its nearest zone tile: %s." % JSON.stringify(approach))
		return {}
	# Stepping into the zone starts the battle with that hero.
	var result: Dictionary = OverworldRules.try_move_along_route(session, approach)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty() or not JSON.stringify(session.battle).contains(hero_id):
		_fail("Stepping next to the computer hero did not start a battle with it: %s." % JSON.stringify(result).left(300))
		return {}
	var stopped_at := OverworldRules.hero_position(session)
	session.battle = {}
	_place_human(session, center)
	return {"zone_tiles": zone, "walk_past_refused": String(refused.get("message", "")), "battle_from": [stopped_at.x, stopped_at.y]}

# --- Computer side ------------------------------------------------------------

func _check_ai_search(session, controller: String, center: Vector2i, hero_id: String) -> Dictionary:
	_place_ai_hero(session, hero_id, center + Vector2i(3, 0))
	var context := _context(session, controller)
	var entry: Dictionary = _encounter(session, hero_id)
	var search: Dictionary = AiHeroRulesScript._search(session, context, entry, 30)
	var size: Vector2i = search.size
	for offset in _neighbours():
		var tile: Vector2i = center + offset
		var refs: Array = search.stops.get(tile.y * size.x + tile.x, [])
		var guarded := false
		for ref in refs:
			if int(ref.kind) == AiHeroRulesScript.STOP_HERO and bool(ref.get("zone", false)):
				guarded = true
		if not guarded:
			_fail("The computer's search does not see tile %s as the human hero's zone: %s." % [tile, JSON.stringify(refs)])
			return {}
	# The far side of the human's hero is reached around its zone, never through it.
	var far := center + Vector2i(-3, 0)
	var far_index := far.y * size.x + far.x
	if int(search.dist[far_index]) < 0:
		_fail("The computer hero cannot reach %s around the human's hero." % far)
		return {}
	var path: Array = AiHeroRulesScript._path_to(search, far_index)
	for tile in path:
		if _chebyshev(tile, center) <= 1:
			_fail("The computer hero's route to %s runs next to the human's hero: %s." % [far, JSON.stringify(path)])
			return {}
	return {"detour_steps": path.size()}

func _check_ai_lands_in_zone(session, controller: String, center: Vector2i, hero_id: String) -> Dictionary:
	_place_ai_hero(session, hero_id, center + Vector2i(3, 0))
	var context := _context(session, controller)
	var index := AiHeroRulesScript._entry_index(session, hero_id)
	_refill_ai_movement(session, index)
	# A plan that would walk right past the human's hero (as a portal or a stale
	# plan could): the hero stops at the first tile next to it and fights.
	var plan := {"kind": "wait", "id": "wait:test", "index": 0, "path": [center + Vector2i(2, -1), center + Vector2i(1, -1), center + Vector2i(0, -2), center + Vector2i(-1, -2)]}
	var step: Dictionary = AiHeroRulesScript._follow_plan(session, context, index, plan)
	var entry: Dictionary = session.overworld.encounters[index]
	var at := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
	if not bool(step.get("battle_started", false)) or at != center + Vector2i(1, -1):
		_fail("A computer hero stepping next to the human's hero did not stop and fight: %s at %s." % [JSON.stringify(step).left(300), at])
		return {}
	session.battle = {}
	session.game_state = "overworld"
	return {"stopped_at": [at.x, at.y]}

func _check_ai_attacks_from_zone(session, controller: String, center: Vector2i, hero_id: String) -> Dictionary:
	_place_ai_hero(session, hero_id, center + Vector2i(4, 0))
	var index := AiHeroRulesScript._entry_index(session, hero_id)
	var entry: Dictionary = session.overworld.encounters[index]
	# Far stronger than the human's hero, so attacking it is worth it.
	var stacks: Array = entry.get("enemy_army", {}).get("stacks", []).duplicate(true)
	for stack in stacks:
		stack["count"] = int(stack.get("count", 1)) * 200
	entry["enemy_army"]["stacks"] = stacks
	session.overworld.encounters[index] = entry
	_refill_ai_movement(session, index)
	var context := _context(session, controller)
	entry = session.overworld.encounters[index]
	AiHeroRulesScript._reveal(session, context, LevelRules.position(entry), 8)
	# The human's hero is offered as a target from the nearest tile of its
	# zone, not from its own tile, which no route reaches any more.
	var search: Dictionary = AiHeroRulesScript._search(session, context, entry, 30)
	var plan := {}
	for tile_index in search.stops.keys():
		for ref in search.stops[tile_index]:
			if int(ref.kind) != AiHeroRulesScript.STOP_HERO or not bool(ref.get("zone", false)):
				continue
			if not plan.is_empty() and int(search.dist[int(tile_index)]) >= int(plan.distance):
				continue
			var candidate: Dictionary = AiHeroRulesScript._candidate(session, context, entry, ref, AiHeroRulesScript.hero_power(entry), AiHeroRulesScript._resource_needs(session, context), search)
			if String(candidate.get("kind", "")) == "hero":
				candidate["tile_index"] = int(tile_index)
				candidate["distance"] = int(search.dist[int(tile_index)])
				plan = candidate
	if plan.is_empty() or int(plan.distance) != 3:
		_fail("A far stronger computer hero is not offered the human's hero from the zone three tiles away: %s." % JSON.stringify(plan).left(300))
		return {}
	plan["path"] = AiHeroRulesScript._path_to(search, int(plan.tile_index))
	var step: Dictionary = AiHeroRulesScript._follow_plan(session, context, index, plan)
	entry = session.overworld.encounters[index]
	var at := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
	if not bool(step.get("battle_started", false)) or _chebyshev(at, center) != 1:
		_fail("The computer hero did not attack from the human hero's zone: %s at %s." % [JSON.stringify(step).left(300), at])
		return {}
	session.battle = {}
	session.game_state = "overworld"
	return {"attacked_from": [at.x, at.y]}

func _check_rival_ai_heroes(session, controllers: Array, center: Vector2i, hero_id: String) -> Dictionary:
	var rival_id := _ai_hero_id(session, controllers[1])
	if rival_id == "":
		_fail("The second computer player has no hero.")
		return {}
	# The human steps aside; two rival computer heroes meet in the open.
	_place_human(session, center + CLEAR_MIN)
	_place_ai_hero(session, rival_id, center)
	_place_ai_hero(session, hero_id, center + Vector2i(3, 0))
	var context := _context(session, controllers[0])
	var entry: Dictionary = _encounter(session, hero_id)
	var search: Dictionary = AiHeroRulesScript._search(session, context, entry, 30)
	var size: Vector2i = search.size
	var beside := center + Vector2i(1, 0)
	var guarded := false
	for ref in search.stops.get(beside.y * size.x + beside.x, []):
		if int(ref.kind) == AiHeroRulesScript.STOP_AI_HERO and bool(ref.get("zone", false)):
			guarded = true
	if not guarded:
		_fail("A rival computer hero's neighbouring tile is not in its zone for the other computer player.")
		return {}
	var ambush: Dictionary = AiHeroRulesScript._hostile_hero_beside(session, context, beside, 0)
	if String(ambush.get("kind", "")) != "ai_hero" or String(ambush.get("id", "")) != rival_id:
		_fail("A computer hero next to a rival's hero does not fight it: %s." % JSON.stringify(ambush))
		return {}
	var own := _context(session, controllers[1])
	if not AiHeroRulesScript._hostile_hero_beside(session, own, center + Vector2i(1, 1), 0).is_empty():
		_fail("A hero's own player treats it as hostile.")
		return {}
	_place_human(session, center)
	return {"rival": rival_id}

func _check_town_doorway(session, controller: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var entrance := LevelRules.town_entrance(town)
		var tile := Vector2i(int(entrance.get("x", -1)), int(entrance.get("y", -1)))
		if not OverworldRules.hero_guard_zone_tiles(session, tile, LevelRules.level_of(entrance)).is_empty():
			_fail("A hero in the doorway of %s guards the tiles around the town." % String(town.get("placement_id", "")))
			return {}
		return {"town": String(town.get("placement_id", ""))}
	_fail("The generated map has no town.")
	return {}

# --- Fixture ------------------------------------------------------------------

func _start_session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED,
		"",
		"",
		3,
		"land",
		false,
		"homm3_medium",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		"faction_embercourt",
		"hero_lyra"
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_fail("Generated setup failed: %s" % JSON.stringify(setup).left(600))
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated session could not start.")
		return null
	OverworldRules.normalize_overworld_state(session)
	# Each computer player starts with a hero.
	for config_value in EnemyTurnRules._enemy_faction_configs_for_session(session):
		var controller := PlayerRules.controller_id(config_value)
		var context := _context(session, controller)
		AiHeroRulesScript._ensure_starting_hero(session, context)
	return session

## Open ground for the fixture: generated maps are dense with scenery, so the
## patch with the most passable land and no town nearby is cleared of every
## object, site, neutral army and boat, and its rock becomes that land.
func _open_square(session) -> Vector2i:
	var size := OverworldRules.derive_map_size(session)
	var rows: Array = LevelRules.terrain_rows(session, 0)
	var town_tiles := {}
	for town in session.overworld.get("towns", []):
		if town is Dictionary and LevelRules.level_of(town) == 0:
			for tile in OverworldRules.town_footprint_tiles(town):
				town_tiles[tile] = true
	var best := Vector2i(-1, -1)
	var best_open := -1
	for y in range(-CLEAR_MIN.y + 3, size.y - CLEAR_MAX.y - 3):
		for x in range(-CLEAR_MIN.x + 3, size.x - CLEAR_MAX.x - 3):
			var open := 0
			var near_town := false
			for dy in range(CLEAR_MIN.y - 2, CLEAR_MAX.y + 3):
				for dx in range(CLEAR_MIN.x - 2, CLEAR_MAX.x + 3):
					var tile := Vector2i(x + dx, y + dy)
					if town_tiles.has(tile):
						near_town = true
					elif _land(rows, tile):
						open += 1
			if not near_town and open > best_open:
				best_open = open
				best = Vector2i(x, y)
	if best == Vector2i(-1, -1):
		return best
	_clear_ground(session, best)
	return best if _square_is_open(session, best) else Vector2i(-1, -1)

func _land(rows: Array, tile: Vector2i) -> bool:
	var terrain := ContentService.normalize_terrain_id(String(rows[tile.y][tile.x]))
	return terrain != "water" and OverworldRules.terrain_id_is_passable(terrain)

func _clear_ground(session, center: Vector2i) -> void:
	var rows: Array = LevelRules.terrain_rows(session, 0)
	var land := ""
	var area := {}
	for dy in range(CLEAR_MIN.y - 1, CLEAR_MAX.y + 2):
		for dx in range(CLEAR_MIN.x - 1, CLEAR_MAX.x + 2):
			var tile := center + Vector2i(dx, dy)
			area[tile] = true
			if land == "" and _land(rows, tile):
				land = String(rows[tile.y][tile.x])
	for tile in area.keys():
		if not _land(rows, tile):
			rows[tile.y][tile.x] = land
	for key in ["map_objects", "resource_nodes", "artifact_nodes", "boats"]:
		var kept := []
		for item in session.overworld.get(key, []):
			if not (item is Dictionary and _touches(item, area)):
				kept.append(item)
		session.overworld[key] = kept
	var encounters := []
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and not AiHeroRulesScript.is_ai_hero(encounter) and (_touches(encounter, area) or _zone_touches(encounter, area)):
			continue
		encounters.append(encounter)
	session.overworld["encounters"] = encounters
	OverworldRules._refresh_blocked_tile_index(session)
	OverworldRules.invalidate_spatial_lookup(session)
	AiHeroRulesScript._surface_cache_key = ""

## Whether a placement stands on, or reaches into, these tiles.
func _touches(item: Dictionary, area: Dictionary) -> bool:
	if LevelRules.level_of(item) != 0:
		return false
	var anchor := Vector2i(int(item.get("x", -99)), int(item.get("y", -99)))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if area.has(anchor + Vector2i(dx, dy)):
				return true
	for tile in OverworldRules._generated_body_tiles_for_placement(item, true):
		if area.has(tile):
			return true
	return false

func _zone_touches(encounter: Dictionary, area: Dictionary) -> bool:
	for tile in OverworldRules._guard_engagement_world_tiles(encounter):
		if area.has(tile):
			return true
	return false

func _square_is_open(session, center: Vector2i) -> bool:
	for dy in range(CLEAR_MIN.y, CLEAR_MAX.y + 1):
		for dx in range(CLEAR_MIN.x, CLEAR_MAX.x + 1):
			var tile := center + Vector2i(dx, dy)
			if OverworldRules.tile_is_blocked(session, tile.x, tile.y, 0) or OverworldRules.tile_has_route_interaction(session, tile.x, tile.y, 0):
				return false
			if WaterTravelRules.is_water(session, tile.x, tile.y, 0):
				return false
			if tile == OverworldRules.hero_position(session) or OverworldRules._town_entrance_at(session, tile, 0):
				return false
	return true

func _place_human(session, tile: Vector2i) -> void:
	OverworldRules._set_active_hero_position(session, tile, 0)
	HeroCommandRules.commit_active_hero(session)
	OverworldRules.invalidate_spatial_lookup(session)

func _place_ai_hero(session, hero_id: String, tile: Vector2i) -> void:
	var index := AiHeroRulesScript._entry_index(session, hero_id)
	var entry: Dictionary = session.overworld.encounters[index]
	entry["x"] = tile.x
	entry["y"] = tile.y
	entry["level"] = 0
	session.overworld.encounters[index] = entry
	OverworldRules.invalidate_spatial_lookup(session)

func _refill_movement(session) -> void:
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = 30
	session.overworld["movement"] = movement

func _refill_ai_movement(session, index: int) -> void:
	var entry: Dictionary = session.overworld.encounters[index]
	var block: Dictionary = entry.get(AiHeroRulesScript.AI_HERO_KEY, {})
	var movement: Dictionary = block.get("movement", {})
	movement["current"] = 30
	movement["max"] = maxi(30, int(movement.get("max", 0)))
	block["movement"] = movement
	block.erase("avoid")
	block["goal"] = {}
	entry[AiHeroRulesScript.AI_HERO_KEY] = block
	session.overworld.encounters[index] = entry

func _context(session, controller: String) -> Dictionary:
	return AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))

func _ai_controllers(session) -> Array:
	var result := []
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary:
			result.append(PlayerRules.controller_id(state))
	return result

func _ai_hero_id(session, controller: String) -> String:
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		return String(entry.get("placement_id", ""))
	return ""

func _encounter(session, placement_id: String) -> Dictionary:
	var index := AiHeroRulesScript._entry_index(session, placement_id)
	return session.overworld.encounters[index] if index >= 0 else {}

func _state(session, controller: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and PlayerRules.controller_id(state) == controller:
			return state
	return {}

func _ai_config(session, controller: String) -> Dictionary:
	for config in EnemyTurnRules._enemy_faction_configs_for_session(session):
		if config is Dictionary and PlayerRules.controller_id(config) == controller:
			return config
	return {}

func _neighbours() -> Array:
	return [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _cleanup() -> void:
	ContentService.clear_generated_scenario_drafts()

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	_cleanup()
	get_tree().quit(1)
