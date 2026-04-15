extends Node

const SCENARIO_ID := "river-pass"
const DIFFICULTY_ID := "normal"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_end_turn_and_enemy_presence():
		return
	if not _run_auto_interaction_regressions():
		return
	if not _run_enemy_hero_intercept_regression():
		return
	if not _run_enemy_town_assault_regression():
		return
	if not _run_enemy_opening_turn_regression():
		return
	get_tree().quit(0)

func _run_end_turn_and_enemy_presence() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_movement(session, 0)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	shell._on_end_turn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	if int(session.day) != 2:
		push_error("Core systems smoke: end turn did not advance the day on first press.")
		get_tree().quit(1)
		return false

	var movement: Dictionary = session.overworld.get("movement", {})
	if int(movement.get("current", 0)) <= 0 or int(movement.get("current", 0)) != int(movement.get("max", 0)):
		push_error("Core systems smoke: end turn did not refresh movement to the daily maximum.")
		get_tree().quit(1)
		return false

	if EnemyTurnRules.active_raid_count(session, "faction_mireclaw") <= 0:
		shell._on_end_turn_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
	if EnemyTurnRules.active_raid_count(session, "faction_mireclaw") <= 0:
		push_error("Core systems smoke: enemy turn did not restore hostile raid-host presence after day advance.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _run_auto_interaction_regressions() -> bool:
	if not _run_resource_auto_collect_regression():
		return false
	if not _run_encounter_auto_battle_regression():
		return false
	if not _run_enemy_town_context_regression():
		return false
	return true

func _run_resource_auto_collect_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(0, 0))
	var resource_before: int = int(session.overworld.get("resources", {}).get("wood", 0))
	var result := OverworldRules.try_move(session, 1, 0)
	var resource_node := _resource_node_by_placement(session, "north_timber")
	if not bool(result.get("ok", false)):
		push_error("Core systems smoke: stepping onto a resource site failed instead of auto-resolving.")
		get_tree().quit(1)
		return false
	if String(resource_node.get("collected_by_faction_id", "")) != "player":
		push_error("Core systems smoke: stepping onto a resource site did not auto-claim it.")
		get_tree().quit(1)
		return false
	if int(session.overworld.get("resources", {}).get("wood", 0)) <= resource_before:
		push_error("Core systems smoke: resource auto-claim did not award its stores.")
		get_tree().quit(1)
		return false
	return true

func _run_encounter_auto_battle_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: sample scenario is missing an encounter for auto-battle coverage.")
		get_tree().quit(1)
		return false
	var encounter_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	var staging_tile := _adjacent_open_tile(session, encounter_tile)
	if staging_tile.x < 0:
		push_error("Core systems smoke: could not find an approach tile for encounter auto-battle coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, staging_tile)
	var delta := encounter_tile - staging_tile
	var result := OverworldRules.try_move(session, delta.x, delta.y)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: stepping onto an encounter did not auto-open battle flow.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_town_context_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the hostile town coverage target.")
		get_tree().quit(1)
		return false
	var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
	var staging_tile := _adjacent_open_tile(session, town_tile)
	if staging_tile.x < 0:
		push_error("Core systems smoke: could not find an approach tile for hostile-town coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, staging_tile)
	var delta := town_tile - staging_tile
	var result := OverworldRules.try_move(session, delta.x, delta.y)
	var updated_town := _town_by_placement(session, "duskfen_bastion")
	if not bool(result.get("ok", false)):
		push_error("Core systems smoke: moving onto the hostile town failed unexpectedly.")
		get_tree().quit(1)
		return false
	if String(updated_town.get("owner", "")) != "enemy":
		push_error("Core systems smoke: stepping onto a hostile town auto-converted ownership.")
		get_tree().quit(1)
		return false
	if String(result.get("route", "")) == "town" or TownRules.can_visit_active_town(session):
		push_error("Core systems smoke: hostile town entry still routes as a player town visit.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_hero_intercept_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(2, 2))
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var hero_name := String(session.overworld.get("hero", {}).get("name", "the hero"))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "intercept_smoke_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991201,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": hero_name,
			"target_x": 2,
			"target_y": 2,
			"goal_x": 2,
			"goal_y": 2,
		}
	)
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if session.battle.is_empty():
		push_error("Core systems smoke: hero-targeting raid did not launch an interception battle.")
		get_tree().quit(1)
		return false
	if String(session.battle.get("context", {}).get("type", "")) != "hero_intercept":
		push_error("Core systems smoke: interception battle did not preserve hero-intercept context.")
		get_tree().quit(1)
		return false
	if String(result.get("message", "")) == "":
		push_error("Core systems smoke: interception launch returned no enemy-turn feedback.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_town_assault_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the hostile town assault target.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))

	var result := OverworldRules.capture_active_town(session)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: hostile-town capture did not route into a town-assault battle.")
		get_tree().quit(1)
		return false
	if String(session.battle.get("context", {}).get("type", "")) != "town_assault":
		push_error("Core systems smoke: town assault battle did not preserve assault context.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(session, "duskfen_bastion").get("owner", "")) != "enemy":
		push_error("Core systems smoke: hostile-town assault flipped ownership before battle resolution.")
		get_tree().quit(1)
		return false

	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		stack["total_health"] = 0
		session.battle["stacks"][index] = stack
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		push_error("Core systems smoke: town assault victory did not resolve through the standard battle flow.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(session, "duskfen_bastion").get("owner", "")) != "player":
		push_error("Core systems smoke: town assault victory did not transfer town ownership.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_opening_turn_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: sample scenario is missing an encounter for enemy-turn coverage.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: could not create a battle payload for enemy-turn coverage.")
		get_tree().quit(1)
		return false

	var enemy_first_id := _first_battle_stack_id(session.battle, "enemy")
	if enemy_first_id == "":
		push_error("Core systems smoke: battle payload has no enemy stack for enemy-turn coverage.")
		get_tree().quit(1)
		return false

	var reordered_turn_order := [enemy_first_id]
	for battle_id_value in session.battle.get("turn_order", []):
		var battle_id := String(battle_id_value)
		if battle_id == "" or battle_id == enemy_first_id:
			continue
		reordered_turn_order.append(battle_id)
	session.battle["turn_order"] = reordered_turn_order
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = enemy_first_id
	session.battle["selected_target_id"] = ""

	var recent_before := int(session.battle.get("recent_events", []).size())
	var result := BattleRules.resolve_if_battle_ready(session)
	var recent_after := int(session.battle.get("recent_events", []).size())
	var active_stack := BattleRules.get_active_stack(session.battle)
	if String(result.get("state", "continue")) == "invalid":
		push_error("Core systems smoke: battle opening autoplay produced an invalid enemy turn.")
		get_tree().quit(1)
		return false
	if session.scenario_status == "in_progress" and not active_stack.is_empty() and String(active_stack.get("side", "")) == "enemy":
		push_error("Core systems smoke: enemy opening turns did not execute back to a player response window.")
		get_tree().quit(1)
		return false
	if recent_after <= recent_before and String(result.get("message", "")) == "":
		push_error("Core systems smoke: enemy opening autoplay produced no battle activity.")
		get_tree().quit(1)
		return false
	return true

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

func _set_active_hero_movement(session, current: int) -> void:
	var max_movement := int(session.overworld.get("movement", {}).get("max", 0))
	var movement := {"current": clamp(current, 0, max_movement), "max": max_movement}
	session.overworld["movement"] = movement.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["movement"] = movement.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["movement"] = movement.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _resource_node_by_placement(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _adjacent_open_tile(session, target: Vector2i) -> Vector2i:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = target + offset
		if tile.x < 0 or tile.y < 0:
			continue
		var map_size: Vector2i = OverworldRules.derive_map_size(session)
		if tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		return tile
	return Vector2i(-1, -1)

func _first_battle_stack_id(battle: Dictionary, side: String) -> String:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side:
			return String(stack.get("battle_id", ""))
	return ""
