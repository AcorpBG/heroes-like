extends Node

# A computer player knows a rival town once it has seen the town's anchor tile
# or its doorway, and every check agrees on that: it neither scouts for a town it
# has seen nor ignores one as unseen. Until 2026-10-17 scouting tested the
# anchor and the planners the doorway, and a town seen only by its anchor was
# never attacked (seed ai-match-1305188145: 280 days next to a 320,000 army).
# A guarded site the rival looted does not close the way to the rival either,
# and a monolith to the other level is a way like a subterranean gate. A town
# planner counts what a dwelling upgrade adds once. A main army shut in with
# its rivals' towns unseen goes for a guard whose fight opens unexplored ground,
# and one whose way to a rival town passes several gates takes the first.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const AiSeatRulesScript = preload("res://scripts/core/AiSeatRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")
const AdventureRules = preload("res://scripts/core/EnemyAdventureRules.gd")
const REPORT_ID := "AI_TOWN_KNOWLEDGE_REPORT"
const SEED := "ai-town-knowledge-20261017"
# A small two-level map with two-way monoliths between the levels.
const PORTAL_SEED := "ai-town-knowledge-portal-2"
# A small two-level map whose capitals lie two gates from some of its ground.
const GATES_SEED := "ai-town-knowledge-gates-0"

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
	results["portal_to_other_level"] = _check_portal_to_other_level_is_crossed()
	if _failed:
		return
	results["upgrade_counted_once"] = _check_upgrade_counted_once()
	if _failed:
		return
	results["shut_in_fights_way_out"] = _check_shut_in_army_fights_way_out()
	if _failed:
		return
	results["town_gates_away"] = _check_town_several_gates_away_is_weighed()
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

## A monolith whose one exit is on the other level is planned and crossed like
## a subterranean gate. Until 2026-10-17 heroes never used one, and on two-level
## maps whose start region opened only through it, its player stayed shut in
## and no rival came (seeds ai-match-1520175333 and ai-match-113824639: 320 days).
func _check_portal_to_other_level_is_crossed() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		PORTAL_SEED, "", "", 2, "land", true, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		"faction_embercourt", ""
	)
	var map_setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(map_setup.get("ok", false)):
		_fail("Generated two-level setup failed: %s" % JSON.stringify(map_setup).left(400))
		return {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(map_setup)
	if session == null or session.scenario_id == "":
		_fail("Generated two-level session could not start.")
		return {}
	OverworldRules.normalize_overworld_state(session)
	var handed := AiSeatRulesScript.hand_human_seat_to_ai(session)
	OverworldRules.end_turn(session)
	var controller := ""
	for record in session.overworld.get("players", []):
		if String(record.get("player_id", "")) != handed:
			controller = String(record.get("player_id", ""))
	var context := _context(session, controller)
	AiHeroRulesScript._start_heroes_day(session, controller)
	context["decision"] = {}
	var index := AiHeroRulesScript._entry_index(session, AiHeroRulesScript._decision_main_id(session, context))
	if index < 0:
		_fail("%s has no main hero on the two-level map." % controller)
		return {}
	var size: Vector2i = context.map_size
	var nodes: Array = session.overworld.resource_nodes
	var portals := 0
	for node_index in range(nodes.size()):
		var node: Dictionary = nodes[node_index]
		var options := NativeTransit.destinations(node)
		if not NativeTransit.is_native(node) or NativeTransit.portal_kind(node) != "two_way_portal" or options.size() != 1:
			continue
		var entrance := NativeTransit.point(NativeTransit.link_of(node).get("entry", {}))
		var exit := NativeTransit.point(options[0].get("exit", {}))
		if exit.z == entrance.z:
			continue
		portals += 1
		var gates: Dictionary = AiHeroRulesScript._level_surface(session, context, entrance.z).get("gates", {})
		var gate: Dictionary = gates.get(entrance.y * size.x + entrance.x, {})
		if gate.is_empty() or int(gate.node) != node_index or gate.exit != exit:
			_fail("The monolith %s to the other level is not a way for the computer's heroes." % String(node.get("placement_id", "")))
			return {}
		if int(OverworldRules._find_guard_engagement_at_tile(session, exit.x, exit.y, exit.z, false).get("index", -1)) >= 0:
			continue
		var entry: Dictionary = session.overworld.encounters[index]
		entry["x"] = entrance.x
		entry["y"] = entrance.y
		entry["level"] = entrance.z
		session.overworld.encounters[index] = entry
		OverworldRules.invalidate_spatial_lookup(session)
		AiHeroRulesScript._cross_gate(session, context, index, {"kind": "gate", "index": node_index, "beyond": {}})
		var crossed: Dictionary = session.overworld.encounters[index]
		if NativeTransit.point(crossed) != exit:
			_fail("The hero on monolith %s did not come out at %s on the other level." % [String(node.get("placement_id", "")), str(exit)])
			return {}
		return {"portal": String(node.get("placement_id", "")), "exit_level": exit.z, "portals": portals}
	_fail("The two-level map has no unguarded monolith between its levels (%d guarded)." % portals)
	return {}

## A computer player's town that stands a first dwelling values that dwelling's
## upgrade at what the upgraded creatures add over the planning horizon, once.
## Until 2026-10-17 the planner added the gain a second time, and factions
## whose upgrades add much upgraded before opening a second dwelling.
func _check_upgrade_counted_once() -> Dictionary:
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
	OverworldRules.normalize_overworld_state(session)
	var town := {}
	for candidate in session.overworld.get("towns", []):
		if String(candidate.get("owner", "")) == "enemy" and TownDevelopment.is_current(candidate):
			town = candidate
			break
	if town.is_empty():
		_fail("The map has no computer player's town on the current development rules.")
		return {}
	var faction := TownDevelopment.faction_id(town)
	var base := {}
	var upgrade := {}
	for building in ContentService.get_town(String(town.get("town_id", ""))).get("buildable_building_ids", []):
		var record := ContentService.get_building(String(building))
		if String(record.get("faction_id", "")) == faction and int(record.get("dwelling_tier", 0)) == 1 and int(record.get("stage", 0)) == 1 and base.is_empty():
			base = record
	for building in ContentService.get_town(String(town.get("town_id", ""))).get("buildable_building_ids", []):
		var record := ContentService.get_building(String(building))
		if String(record.get("upgrade_from", "")) == String(base.get("id", "")) and String(base.get("id", "")) != "":
			upgrade = record
	if upgrade.is_empty():
		_fail("%s has no first dwelling with an upgrade." % faction)
		return {}
	town["built_buildings"] = ["building_town_hall", String(base.id)]
	var values := {}
	AiHeroRulesScript._build_choice(session, town, {"gold": 100000, "wood": 100, "ore": 100}, values)
	if not values.has(String(upgrade.id)):
		_fail("The planner did not weigh %s with %s built." % [String(upgrade.id), String(base.id)])
		return {}
	var trial_built: Array = town.built_buildings.duplicate()
	trial_built.append(String(upgrade.id))
	var trial := {"town_id": town.get("town_id", ""), "placement_id": town.get("placement_id", ""), "built_buildings": trial_built, "development_version": town.get("development_version", 0)}
	var before := AiHeroRulesScript._recruit_set_value(AiHeroRulesScript._trial_growth(town))
	var troops := (AiHeroRulesScript._recruit_set_value(AiHeroRulesScript._trial_growth(trial)) - before) * AiHeroRulesScript.BUILD_HORIZON_WEEKS
	if before < AiHeroRulesScript.STARVED_TOWN_WEEKLY_TROOPS:
		troops *= 1.5
	var expected := troops + 100.0 * float(upgrade.get("readiness_bonus", 0)) + 150.0 * float(AiHeroRulesScript._opens_count(town, String(upgrade.id), trial_built))
	if troops <= 0.0 or absf(float(values[String(upgrade.id)]) - expected) > 0.01:
		_fail("The planner values %s at %.1f, not the %.1f its upgraded creatures add." % [String(upgrade.id), float(values[String(upgrade.id)]), expected])
		return {}
	return {"upgrade": String(upgrade.id), "value": snappedf(expected, 0.1)}

## Every tile the main hero can walk to without a fight is explored, with the
## tiles around them; the player holds every neutral town and has seen no rival
## town. The main army, a hundred times its start, weighs what lies beyond its
## daily search (local radius 0 here) and plans a guard fight that opens
## unexplored ground. Until 2026-10-18 only guards on the way to a known town
## counted there, and on a large map (seed ai-match-147308053) the leader's
## 960,000-strength armies ran errands for 200 days with the last rival's towns
## behind three weak guards. Then the guard is gone and pickups lie on every
## tile of its zone: the main army goes to take one, for the ground it opens.
## Until then a site in the way counted for nothing, and on that large map a
## spell scroll, worth nothing to the computer, closed the one corridor between
## the leader and the last rival for 200 days.
func _check_shut_in_army_fights_way_out() -> Dictionary:
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
	OverworldRules.normalize_overworld_state(session)
	var rival := AiSeatRulesScript.hand_human_seat_to_ai(session)
	OverworldRules.end_turn(session)
	var controller := ""
	for record in session.overworld.get("players", []):
		if String(record.get("player_id", "")) != rival:
			controller = String(record.get("player_id", ""))
	var context := _context(session, controller)
	AiHeroRulesScript._start_heroes_day(session, controller)
	context["decision"] = {}
	var index := AiHeroRulesScript._entry_index(session, AiHeroRulesScript._decision_main_id(session, context))
	if index < 0:
		_fail("%s has no main hero." % controller)
		return {}
	var entry: Dictionary = session.overworld.encounters[index]
	for stack in entry.get("enemy_army", {}).get("stacks", []):
		stack["count"] = int(stack.get("count", 0)) * 100
	session.day = AiHeroRulesScript.HUNT_FULL_DAY
	for town in session.overworld.get("towns", []):
		if String(town.get("owner", "")) == "neutral":
			town["owner"] = "enemy"
			town["controlling_player_id"] = controller
			town["garrison"] = []
	var movement_max := maxi(1, int(entry.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("movement", {}).get("max", 1)))
	var wide: Dictionary = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
	var size: Vector2i = context.map_size
	var tiles := PackedByteArray()
	tiles.resize(size.x * size.y)
	for tile in range(tiles.size()):
		if int(wide.dist[tile]) < 0:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = tile % size.x + dx
				var y: int = tile / size.x + dy
				if x >= 0 and y >= 0 and x < size.x and y < size.y:
					tiles[y * size.x + x] = 1
	context["explored"] = {LevelRules.level_of(entry): tiles}
	context["decision"] = {}
	if not AiHeroRulesScript._rival_towns_unknown(session, context):
		_fail("The rival's towns stand in ground %s reaches without a fight." % controller)
		return {}
	if not AiHeroRulesScript._exploration_candidate(session, context, entry, wide).is_empty():
		_fail("With everything in reach explored, the hero still finds ground to scout.")
		return {}
	var plan: Dictionary = AiHeroRulesScript._strategic_candidate(session, context, entry, movement_max, 0, wide)
	if String(plan.get("kind", "")) != "encounter":
		_fail("Shut in with the rival's towns unseen, the main army plans %s instead of a guard fight." % JSON.stringify({"kind": plan.get("kind", ""), "id": plan.get("id", "")}))
		return {}
	var opened := int(wide.get("passage_unexplored", {}).get(int(plan.index), 0))
	if opened <= 0:
		_fail("The main army plans to fight %s, which opens no unexplored ground." % String(plan.id))
		return {}
	var result := {"guard": String(plan.id), "unexplored_opened": opened, "distance": int(plan.get("distance", -1))}
	var pickup := {}
	for node in session.overworld.get("artifact_nodes", []):
		if not bool(node.get("collected", false)) and LevelRules.level_of(node) == LevelRules.level_of(entry) and AdventureRules._artifact_guard_encounter_for_node(session, node).is_empty():
			pickup = node
			break
	if pickup.is_empty():
		_fail("The map has no unguarded artifact to lay in the guard's place.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	resolved.append(String(plan.id))
	session.overworld["resolved_encounters"] = resolved
	var placed := {}
	for zone_tile in wide.guard_zones[int(plan.index)]:
		var copy: Dictionary = pickup.duplicate(true)
		copy["placement_id"] = "%s_door_%d" % [String(pickup.get("placement_id", "")), int(zone_tile)]
		copy["x"] = int(zone_tile) % size.x
		copy["y"] = int(zone_tile) / size.x
		session.overworld.artifact_nodes.append(copy)
		placed[String(copy.placement_id)] = true
	OverworldRules.invalidate_spatial_lookup(session)
	var site_context := _context(session, controller)
	site_context["explored"] = {LevelRules.level_of(entry): tiles}
	site_context["decision"] = {}
	var site_wide: Dictionary = AiHeroRulesScript._search(session, site_context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
	var site_plan: Dictionary = AiHeroRulesScript._strategic_candidate(session, site_context, entry, movement_max, 0, site_wide)
	if String(site_plan.get("kind", "")) != "artifact" or not placed.has(String(site_plan.get("id", ""))):
		_fail("With pickups closing the way where the guard stood, the main army plans %s instead of taking one." % JSON.stringify({"kind": site_plan.get("kind", ""), "id": site_plan.get("id", "")}))
		return {}
	var site_opened := int(site_wide.get("passage_unexplored", {}).get(AiHeroRulesScript._site_door_key(int(site_plan.tile_index)), 0))
	if site_opened <= 0:
		_fail("The main army plans to take %s, which opens no unexplored ground." % String(site_plan.id))
		return {}
	result["pickup_unexplored_opened"] = site_opened
	return result

## A main army stands on a stretch of ground from which the rival's capital is
## reached only through two or more subterranean gates or monoliths. With the
## whole map seen and the army strong enough for every guard, it heads for the
## first gate of that way, the capital its errand beyond. Until 2026-10-18 a
## hero weighed what lay one gate ahead only, and on a large two-level map
## (seed ai-match-3718099446) a 372,000-strength army never went for a rival
## town five gates away, from day 163 to the 320-day cap.
func _check_town_several_gates_away_is_weighed() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		GATES_SEED, "", "", 2, "land", true, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		"faction_embercourt", ""
	)
	var map_setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(map_setup.get("ok", false)):
		_fail("Generated two-level setup failed: %s" % JSON.stringify(map_setup).left(400))
		return {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(map_setup)
	OverworldRules.normalize_overworld_state(session)
	var rival := AiSeatRulesScript.hand_human_seat_to_ai(session)
	OverworldRules.end_turn(session)
	var controller := ""
	for record in session.overworld.get("players", []):
		if String(record.get("player_id", "")) != rival:
			controller = String(record.get("player_id", ""))
	var context := _context(session, controller)
	AiHeroRulesScript._start_heroes_day(session, controller)
	context["decision"] = {}
	var index := AiHeroRulesScript._entry_index(session, AiHeroRulesScript._decision_main_id(session, context))
	if index < 0:
		_fail("%s has no main hero on the two-level map." % controller)
		return {}
	var entry: Dictionary = session.overworld.encounters[index]
	for stack in entry.get("enemy_army", {}).get("stacks", []):
		stack["count"] = int(stack.get("count", 0)) * 1000
	var size: Vector2i = context.map_size
	var levels := LevelRules.level_count(session)
	var explored := {}
	for level in range(levels):
		var tiles := PackedByteArray()
		tiles.resize(size.x * size.y)
		tiles.fill(1)
		explored[level] = tiles
	context["explored"] = explored
	var town := {}
	for candidate in session.overworld.get("towns", []):
		if String(candidate.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(candidate) == rival:
			town = candidate
	if town.is_empty():
		_fail("The two-level map has no rival capital for %s." % controller)
		return {}
	# The capital is the one town left to take.
	for other in session.overworld.get("towns", []):
		if String(other.get("owner", "")) == "neutral":
			other["owner"] = "enemy"
			other["controlling_player_id"] = controller
	# Gate hops from every stretch to the capital's, walking the gates backwards.
	var links := {}
	for level in range(levels):
		var regions: PackedInt32Array = AiHeroRulesScript._level_regions(session, context, level)
		var gates: Dictionary = AiHeroRulesScript._level_surface(session, context, level).get("gates", {})
		for gate_tile in gates.keys():
			var exit: Vector3i = gates[gate_tile].exit
			var to := "%d:%d" % [exit.z, int(AiHeroRulesScript._level_regions(session, context, exit.z)[exit.y * size.x + exit.x])]
			if not links.has(to):
				links[to] = []
			links[to].append("%d:%d" % [level, int(regions[int(gate_tile)])])
	var door := LevelRules.town_entrance(town)
	var town_key := "%d:%d" % [LevelRules.level_of(town), int(AiHeroRulesScript._level_regions(session, context, LevelRules.level_of(town))[int(door.get("y", 0)) * size.x + int(door.get("x", 0))])]
	var hops := {town_key: 0}
	var queue := [town_key]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for previous in links.get(current, []):
			if not hops.has(previous):
				hops[previous] = int(hops[current]) + 1
				queue.append(previous)
	var start_key := ""
	for region_key in hops.keys():
		if int(hops[region_key]) >= 2 and (start_key == "" or int(hops[region_key]) > int(hops[start_key])):
			start_key = region_key
	if start_key == "":
		_fail("No stretch of the two-level map lies two gates from the rival capital: %s." % JSON.stringify(hops))
		return {}
	# The army stands on an open tile of that stretch.
	var start_level := int(start_key.get_slice(":", 0))
	var start_region := int(start_key.get_slice(":", 1))
	var regions: PackedInt32Array = AiHeroRulesScript._level_regions(session, context, start_level)
	var surface: Dictionary = AiHeroRulesScript._level_surface(session, context, start_level)
	var spot := -1
	for tile in range(regions.size()):
		if int(regions[tile]) == start_region and surface.blocked[tile] == 0 and surface.stop_mask[tile] == 0 				and int(OverworldRules._find_guard_engagement_at_tile(session, tile % size.x, tile / size.x, start_level, true).get("index", -1)) < 0:
			spot = tile
			break
	if spot < 0:
		_fail("The stretch %s has no open tile." % start_key)
		return {}
	entry["x"] = spot % size.x
	entry["y"] = spot / size.x
	entry["level"] = start_level
	session.overworld.encounters[index] = entry
	OverworldRules.invalidate_spatial_lookup(session)
	context["decision"] = {}
	var movement_max := maxi(1, int(entry.get(AiHeroRulesScript.AI_HERO_KEY, {}).get("movement", {}).get("max", 1)))
	var wide: Dictionary = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
	var routes: Dictionary = AiHeroRulesScript._gate_routes(session, context, entry, wide, movement_max)
	var town_id := String(town.get("placement_id", ""))
	var leads := false
	for gate_tile in routes.keys():
		if String(routes[gate_tile].id) == town_id:
			leads = true
	if not leads:
		_fail("From %s, %d gates from the rival capital, no gate starts the way to it: %s." % [start_key, int(hops[start_key]), JSON.stringify(routes)])
		return {}
	# Guards in the way to that first gate carry the capital's worth; beaten,
	# the gate itself is the plan.
	var guards := []
	var plan := {}
	for attempt in range(6):
		var war: Dictionary = AiHeroRulesScript._war_paths(session, context, entry, wide, AiHeroRulesScript._resource_needs(session, context))
		var far: Dictionary = AiHeroRulesScript._strategic_candidate(session, context, entry, movement_max, 0, wide)
		if String(far.get("kind", "")) != "encounter" or not war.has(int(far.index)):
			plan = AiHeroRulesScript._gate_candidate(session, context, entry, wide, movement_max, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
			break
		guards.append(String(far.id))
		var resolved: Array = session.overworld.get("resolved_encounters", [])
		resolved.append(String(far.id))
		session.overworld["resolved_encounters"] = resolved
		OverworldRules.invalidate_spatial_lookup(session)
		context = _context(session, controller)
		context["explored"] = explored
		context["decision"] = {}
		wide = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
	if String(plan.get("beyond", {}).get("id", "")) != town_id:
		_fail("%d gates from the rival capital, past guards %s, the main army plans %s instead of the way to it." % [int(hops[start_key]), JSON.stringify(guards), JSON.stringify({"kind": plan.get("kind", ""), "id": plan.get("id", ""), "beyond": plan.get("beyond", {})})])
		return {}
	return {"gates_away": int(hops[start_key]), "guards_in_way": guards.size(), "plan": String(plan.kind), "distance": int(plan.get("distance", -1))}

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
