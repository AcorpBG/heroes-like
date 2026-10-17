extends Node

# A computer player knows a rival town once it has seen the town's anchor tile
# or its doorway, and every check agrees on that: it neither scouts for a town it
# has seen nor ignores one as unseen. Until 2026-10-17 scouting tested the
# anchor and the planners the doorway, and a town seen only by its anchor was
# never attacked (seed ai-match-1305188145: 280 days next to a 320,000 army).
# A guarded site the rival looted does not close the way to the rival either.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const AiSeatRulesScript = preload("res://scripts/core/AiSeatRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const REPORT_ID := "AI_TOWN_KNOWLEDGE_REPORT"
const SEED := "ai-town-knowledge-20261017"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var results := {}
	for seen in ["anchor", "door"]:
		results[seen] = _check_seen_town_is_attacked(seen)
		if _failed:
			return
	results["unseen"] = _check_unseen_town_is_scouted_for()
	if _failed:
		return
	results["looted_site"] = _check_looted_site_is_crossed()
	if _failed:
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "cases": results})])
	get_tree().quit(0)

## The hero stands beside a rival capital with no defenders; of that town only
## the anchor tile or only the doorway is explored (the rival's other towns are
## fully seen). It goes to take the town.
func _check_seen_town_is_attacked(seen: String) -> Dictionary:
	var setup := _setup()
	if setup.is_empty():
		return {}
	var session = setup.session
	var context: Dictionary = setup.context
	var town: Dictionary = setup.town
	var size: Vector2i = context.map_size
	var tiles := PackedByteArray()
	tiles.resize(size.x * size.y)
	var entrance := LevelRules.town_entrance(town)
	var tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0))) if seen == "anchor" else Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0)))
	tiles[tile.y * size.x + tile.x] = 1
	context["explored"] = {LevelRules.level_of(town): tiles}
	for other in setup.other_towns:
		_see_town(context, other, size)
	context["decision"] = {}
	if AiHeroRulesScript._rival_towns_unknown(session, context):
		_fail("With the town's %s seen, the player still scouts for an unseen rival town." % seen)
		return {}
	var plan: Dictionary = AiHeroRulesScript._choose_plan(session, context, setup.entry)
	if String(plan.get("kind", "")) != "town_hostile" or String(plan.get("id", "")) != String(town.get("placement_id", "")):
		_fail("With the town's %s seen, the hero beside the undefended rival capital plans %s instead of taking it." % [seen, JSON.stringify({"kind": plan.get("kind", ""), "id": plan.get("id", "")})])
		return {}
	return {"plan": String(plan.kind), "distance": int(plan.get("distance", -1))}

func _check_unseen_town_is_scouted_for() -> Dictionary:
	var setup := _setup()
	if setup.is_empty():
		return {}
	var context: Dictionary = setup.context
	var size: Vector2i = context.map_size
	var tiles := PackedByteArray()
	tiles.resize(size.x * size.y)
	context["explored"] = {LevelRules.level_of(setup.town): tiles}
	context["decision"] = {}
	if not AiHeroRulesScript._rival_towns_unknown(setup.session, context):
		_fail("With nothing explored, the player counts the rival town as seen.")
		return {}
	return {"rival_towns_unknown": true}

## A guarded site the rival looted stays standing and holds nothing for anyone:
## the hero walks across its doorway as the looter does, so it never closes the
## way to the rival. Before it is looted its guard must be fought. Until
## 2026-10-17 only the looter crossed it, and a hero whose one way to the rival
## ran over a looted bank stood idle (seed ai-match-2298949441: 250 days).
func _check_looted_site_is_crossed() -> Dictionary:
	var setup := _setup()
	if setup.is_empty():
		return {}
	var session = setup.session
	var context: Dictionary = setup.context
	var controller := String(context.controller)
	var rival := PlayerRules.town_controller_id(setup.town)
	var surface: Dictionary = AiHeroRulesScript._level_surface(session, context, LevelRules.level_of(setup.entry))
	for site_stop in surface.get("site_stops", []):
		for ref in site_stop.refs:
			if int(ref.kind) != AiHeroRulesScript.STOP_RESOURCE:
				continue
			var node: Dictionary = session.overworld.resource_nodes[int(ref.index)]
			var site: Dictionary = NodePayload.site_for_node(node)
			if not bool(site.get("guarded", false)) or bool(node.get("collected", false)):
				continue
			node["collected"] = true
			node["collected_by_player_id"] = rival
			if not OverworldRules.resource_node_is_present(node, site):
				node["collected"] = false
				node.erase("collected_by_player_id")
				continue
			if not AiHeroRulesScript._site_stop_passable(session, controller, ref):
				_fail("The hero cannot cross %s, which the rival looted." % String(node.get("placement_id", "")))
				return {}
			node["collected"] = false
			node.erase("collected_by_player_id")
			if AiHeroRulesScript._site_stop_passable(session, controller, ref):
				_fail("The hero walks across %s before its guard is beaten." % String(node.get("placement_id", "")))
				return {}
			return {"site": String(node.get("placement_id", ""))}
	_fail("The map has no guarded site that stays standing once looted.")
	return {}

## A small generated two-player map, both seats played by the computer, one day
## played. player_2's main hero is moved beside player_1's capital, whose heroes
## are taken off the map and whose garrison is emptied.
func _setup() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED, "", "", 2, "land", false, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		"faction_embercourt", ""
	)
	var map_setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(map_setup.get("ok", false)):
		_fail("Generated setup failed: %s" % JSON.stringify(map_setup).left(400))
		return {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(map_setup)
	if session == null or session.scenario_id == "":
		_fail("Generated session could not start.")
		return {}
	OverworldRules.normalize_overworld_state(session)
	var rival := AiSeatRulesScript.hand_human_seat_to_ai(session)
	OverworldRules.end_turn(session)
	var controller := ""
	for record in session.overworld.get("players", []):
		if String(record.get("player_id", "")) != rival:
			controller = String(record.get("player_id", ""))
	var town := {}
	var other_towns := []
	for candidate in session.overworld.get("towns", []):
		if String(candidate.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(candidate) == rival:
			if not town.is_empty():
				other_towns.append(town)
			town = candidate
	if controller == "" or town.is_empty():
		_fail("The map has no rival capital for %s." % controller)
		return {}
	town["garrison"] = []
	var encounters := []
	for encounter in session.overworld.get("encounters", []):
		if not (AiHeroRulesScript.is_ai_hero(encounter) and PlayerRules.raid_controller_id(encounter) == rival):
			encounters.append(encounter)
	session.overworld["encounters"] = encounters
	var context := _context(session, controller)
	AiHeroRulesScript._start_heroes_day(session, controller)
	context["decision"] = {}
	var main_id := AiHeroRulesScript._decision_main_id(session, context)
	var index := AiHeroRulesScript._entry_index(session, main_id)
	if index < 0:
		_fail("%s has no main hero." % controller)
		return {}
	var entry: Dictionary = session.overworld.encounters[index]
	var spot := _beside_door(session, context, town)
	if spot.x < 0:
		_fail("No open tile beside the rival capital's doorway.")
		return {}
	entry["x"] = spot.x
	entry["y"] = spot.y
	return {"session": session, "context": context, "entry": entry, "town": town, "other_towns": other_towns}

## Marks a town's anchor and doorway explored.
func _see_town(context: Dictionary, town: Dictionary, size: Vector2i) -> void:
	var level := LevelRules.level_of(town)
	if not context.explored.has(level):
		var blank := PackedByteArray()
		blank.resize(size.x * size.y)
		context.explored[level] = blank
	var tiles: PackedByteArray = context.explored[level]
	var entrance := LevelRules.town_entrance(town)
	for tile in [Vector2i(int(town.get("x", 0)), int(town.get("y", 0))), Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0)))]:
		tiles[tile.y * size.x + tile.x] = 1
	context.explored[level] = tiles

func _context(session, controller: String) -> Dictionary:
	var config := {}
	for candidate in EnemyTurnRulesScript._enemy_faction_configs_for_session(session):
		if candidate is Dictionary and PlayerRules.controller_id(candidate) == controller:
			config = candidate
	var state := {}
	for candidate in session.overworld.get("enemy_states", []):
		if candidate is Dictionary and PlayerRules.controller_id(candidate) == controller:
			state = candidate
	return AiHeroRulesScript._new_context(session, config, state)

func _beside_door(session, context: Dictionary, town: Dictionary) -> Vector2i:
	var size: Vector2i = context.map_size
	var surface: Dictionary = AiHeroRulesScript._level_surface(session, context, LevelRules.level_of(town))
	var entrance := LevelRules.town_entrance(town)
	for dy in [1, 0, -1]:
		for dx in [0, 1, -1]:
			var x: int = int(entrance.get("x", 0)) + dx
			var y: int = int(entrance.get("y", 0)) + dy
			if (dx == 0 and dy == 0) or x < 0 or y < 0 or x >= size.x or y >= size.y:
				continue
			var tile := y * size.x + x
			if surface.blocked[tile] == 0 and surface.stop_mask[tile] == 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
