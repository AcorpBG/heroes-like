class_name ScenarioFactory
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const LIVE_STOCKPILE_RESOURCE_KEYS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const ENEMY_TOWN_DEVELOPMENT_SOURCE_SITE_ID := "site_generated_town_required_source_cache"
const ENEMY_TOWN_DEVELOPMENT_SOURCE_LOCAL_RADIUS := 2
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func create_session(
	scenario_id: String,
	difficulty: String = "normal",
	launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
) -> SessionStateStoreScript.SessionData:
	var scenario := ContentService.get_scenario_readonly(scenario_id)
	if scenario.is_empty():
		push_error("Unable to build session for missing scenario %s." % scenario_id)
		return SessionStateStoreScript.new_session_data()

	var hero_id := String(scenario.get("hero_id", ""))
	if hero_id == "":
		var hero_starts = scenario.get("hero_starts", [])
		if hero_starts is Array and not hero_starts.is_empty():
			hero_id = String(hero_starts[0])

	var hero_template := ContentService.get_hero(hero_id)
	var army_template := ContentService.get_army_group(String(scenario.get("player_army_id", "")))
	var start := _normalize_position(scenario.get("start", {"x": 0, "y": 0}))
	var normalized_difficulty: String = DifficultyRulesScript.normalize_difficulty(difficulty)
	var player_army_state := _build_army_state(army_template)
	# A start hero never begins without troops: a scenario without a usable
	# starting army falls back to the hero's own starting army.
	if not HeroCommandRulesScript.army_has_troops(player_army_state):
		player_army_state = HeroCommandRulesScript.starting_army_for_hero(hero_template, "%s|start|%s" % [scenario_id, hero_id])
	var hero_state: Dictionary = HeroCommandRulesScript.build_hero_from_template(hero_template, start, player_army_state, normalized_difficulty)
	hero_state["is_primary"] = true

	var town_states := _build_town_states(scenario.get("towns", []))
	var enemy_states := EnemyTurnRulesScript.build_enemy_states(scenario.get("enemy_factions", []))
	_seed_enemy_town_starting_treasuries(enemy_states, town_states)
	var resource_states := _build_resource_states(scenario.get("resource_nodes", []))
	resource_states = _ensure_enemy_town_development_source_support(scenario, town_states, resource_states)

	var overworld_state := {
		"map": _duplicate_array(scenario.get("map", [])),
		"map_size": _duplicate_dict(scenario.get("map_size", {})),
		"terrain_layers": _duplicate_dict(ContentService.get_terrain_layers_for_scenario(scenario_id)),
		"active_hero_id": hero_id,
		"player_heroes": [hero_state],
		"hero_position": hero_state.get("position", start),
		"hero": hero_state,
		"movement": hero_state.get("movement", {"current": 0, "max": 0}),
		"fog": {},
		"resources": _normalize_resources(scenario.get("starting_resources", {})),
		"army": hero_state.get("army", player_army_state),
		"encounters": _duplicate_array(scenario.get("encounters", [])),
		"resolved_encounters": [],
		"towns": town_states,
		"resource_nodes": resource_states,
		"artifact_nodes": ArtifactRulesScript.build_artifact_nodes(scenario.get("artifact_nodes", []), scenario_id),
		"map_objects": _duplicate_array(scenario.get("map_objects", [])),
		"enemy_states": enemy_states,
		# New games start with computer players already fielding heroes.
		"ai_heroes_version": EnemyTurnRulesScript.AiHeroRulesScript.MIGRATION_VERSION,
		"scenario_script_state": ScenarioScriptRulesScript.build_script_state(),
	}

	var session := SessionStateStoreScript.new_session_data(
		str(Time.get_ticks_msec()),
		scenario_id,
		hero_id,
		1,
		overworld_state,
		normalized_difficulty,
		launch_mode
	)
	HeroCommandRulesScript.seed_start_heroes_from_session(session)
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.scenario_summary = ""
	session.flags = {}
	return session

static func _build_army_state(army_template: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioFactory._build_army_state", [army_template])

static func _build_town_states(placements: Variant) -> Array:
	return HumanEngine.native_writing(&"ScenarioFactory._build_town_states", [placements])

static func _seed_enemy_town_starting_treasuries(enemy_states: Array, town_states: Array) -> void:
	for town_value in town_states:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "")) != "enemy":
			continue
		var town_template := ContentService.get_town(String(town.get("town_id", "")))
		var development_balance: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
		var starting_resources: Dictionary = development_balance.get("starting_resources", {}) if development_balance.get("starting_resources", {}) is Dictionary else {}
		if starting_resources.is_empty():
			continue
		var faction_id := String(town.get("controlling_faction_id", ""))
		if faction_id == "":
			faction_id = String(town_template.get("faction_id", ""))
		var state_index := _find_enemy_state_index(enemy_states, faction_id)
		if state_index < 0:
			continue
		var state: Dictionary = enemy_states[state_index]
		var treasury := _normalize_resources(state.get("treasury", {}))
		treasury = _add_resource_sets(treasury, starting_resources)
		state["treasury"] = treasury
		enemy_states[state_index] = state

static func _ensure_enemy_town_development_source_support(scenario: Dictionary, town_states: Array, resource_states: Array) -> Array:
	if bool(scenario.get("generated", false)):
		return resource_states
	var result := resource_states.duplicate(true)
	var occupied := _scenario_occupied_tiles(scenario, town_states, result)
	for town_value in town_states:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "")) != "enemy":
			continue
		var required_resource_ids := _town_development_required_resource_ids(String(town.get("town_id", "")))
		var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
		var local_source_resource_ids := _resource_source_ids_near_tile(
			result,
			town_tile,
			ENEMY_TOWN_DEVELOPMENT_SOURCE_LOCAL_RADIUS
		)
		var missing_resource_ids := []
		for resource_id in required_resource_ids:
			if String(resource_id) == "gold":
				continue
			if not bool(local_source_resource_ids.get(String(resource_id), false)):
				missing_resource_ids.append(String(resource_id))
		if missing_resource_ids.is_empty():
			continue
		var support_tile := _nearest_development_source_tile(town_tile, _scenario_map_size(scenario), occupied)
		if support_tile.x < 0:
			continue
		var placement_id := "%s_development_source_support" % String(town.get("placement_id", "enemy_town"))
		var faction_id := String(town.get("controlling_faction_id", ""))
		if faction_id == "":
			var town_template := ContentService.get_town(String(town.get("town_id", "")))
			faction_id = String(town_template.get("faction_id", ""))
		result.append({
			"placement_id": placement_id,
			"site_id": ENEMY_TOWN_DEVELOPMENT_SOURCE_SITE_ID,
			"x": support_tile.x,
			"y": support_tile.y,
			"owner": "enemy",
			"kind": "enemy_town_development_source_support",
			"development_source_support": true,
			"source_support_town_placement_id": String(town.get("placement_id", "")),
			"source_support_faction_id": faction_id,
			"source_support_missing_resource_ids": missing_resource_ids,
		})
		occupied[_tile_key(support_tile)] = true
	return result

static func _resource_source_ids_near_tile(resource_states: Array, tile: Vector2i, radius: int) -> Dictionary:
	var ids := {}
	for node_value in resource_states:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var dx: int = abs(int(node.get("x", 0)) - tile.x)
		var dy: int = abs(int(node.get("y", 0)) - tile.y)
		if max(dx, dy) > radius:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		for source_key in ["claim_rewards", "rewards", "control_income"]:
			var resources: Dictionary = site.get(source_key, {}) if site.get(source_key, {}) is Dictionary else {}
			for resource_id in resources.keys():
				var id := String(resource_id)
				if id != "" and int(resources.get(resource_id, 0)) > 0:
					ids[id] = true
	return ids

static func _town_development_required_resource_ids(town_id: String) -> Array:
	var town_template := ContentService.get_town(town_id)
	var ids := {}
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building := ContentService.get_building(String(building_id_value))
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		for resource_id in cost.keys():
			var id := String(resource_id)
			if id in LIVE_STOCKPILE_RESOURCE_KEYS and int(cost.get(resource_id, 0)) > 0:
				ids[id] = true
	var result := ids.keys()
	result.sort()
	return result

static func _scenario_occupied_tiles(scenario: Dictionary, town_states: Array, resource_states: Array) -> Dictionary:
	var occupied := {}
	var start := _normalize_position(scenario.get("start", {"x": 0, "y": 0}))
	occupied[_tile_key(Vector2i(int(start.get("x", 0)), int(start.get("y", 0))))] = true
	for town_value in town_states:
		if town_value is Dictionary:
			occupied[_tile_key(Vector2i(int(town_value.get("x", 0)), int(town_value.get("y", 0))))] = true
	for collection in [resource_states, scenario.get("encounters", []), scenario.get("artifact_nodes", [])]:
		if not (collection is Array):
			continue
		for value in collection:
			if value is Dictionary:
				occupied[_tile_key(Vector2i(int(value.get("x", 0)), int(value.get("y", 0))))] = true
	return occupied

static func _nearest_development_source_tile(origin: Vector2i, map_size: Vector2i, occupied: Dictionary) -> Vector2i:
	for radius in range(1, 7):
		for offset in _development_source_offsets(radius):
			var tile := Vector2i(origin.x + int(offset.x), origin.y + int(offset.y))
			if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
				continue
			if bool(occupied.get(_tile_key(tile), false)):
				continue
			return tile
	return Vector2i(-1, -1)

static func _development_source_offsets(radius: int) -> Array:
	var offsets := [
		Vector2i(0, -radius),
		Vector2i(-radius, 0),
		Vector2i(radius, 0),
		Vector2i(0, radius),
	]
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if max(abs(dx), abs(dy)) != radius:
				continue
			var offset := Vector2i(dx, dy)
			if offset not in offsets:
				offsets.append(offset)
	return offsets

static func _scenario_map_size(scenario: Dictionary) -> Vector2i:
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", map_size.get("x", 0)))
	var height := int(map_size.get("height", map_size.get("y", 0)))
	if width <= 0 or height <= 0:
		var rows: Array = scenario.get("map", []) if scenario.get("map", []) is Array else []
		height = max(height, rows.size())
		for row in rows:
			if row is Array:
				width = max(width, row.size())
			elif row is String:
				width = max(width, String(row).length())
	return Vector2i(max(1, width), max(1, height))

static func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func _find_enemy_state_index(enemy_states: Array, faction_id: String) -> int:
	for index in range(enemy_states.size()):
		var state = enemy_states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return index
	return -1

static func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := _normalize_resources(left)
	for key in right.keys():
		var resource_key := String(key)
		if resource_key == "" or resource_key == "experience":
			continue
		result[resource_key] = max(0, int(result.get(resource_key, 0)) + int(right.get(key, 0)))
	return result

static func _build_resource_states(placements: Variant) -> Array:
	return HumanEngine.native_writing(&"ScenarioFactory._build_resource_states", [placements])

static func _normalize_position(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	return {"x": 0, "y": 0}

static func _normalize_resources(value: Variant) -> Dictionary:
	return HumanEngine.native(&"ScenarioFactory._normalize_resources", [value])

static func _duplicate_array(value: Variant) -> Array:
	return HumanEngine.native(&"ScenarioFactory._duplicate_array", [value])

static func _duplicate_dict(value: Variant) -> Dictionary:
	return HumanEngine.native(&"ScenarioFactory._duplicate_dict", [value])
