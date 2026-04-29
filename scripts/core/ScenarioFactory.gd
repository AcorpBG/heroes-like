class_name ScenarioFactory
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

static func create_session(
	scenario_id: String,
	difficulty: String = "normal",
	launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
) -> SessionStateStoreScript.SessionData:
	var scenario := ContentService.get_scenario(scenario_id)
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
	var hero_state: Dictionary = HeroCommandRulesScript.build_hero_from_template(hero_template, start, player_army_state, normalized_difficulty)
	hero_state["is_primary"] = true

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
		"towns": _build_town_states(scenario.get("towns", [])),
		"resource_nodes": _build_resource_states(scenario.get("resource_nodes", [])),
		"artifact_nodes": ArtifactRulesScript.build_artifact_nodes(scenario.get("artifact_nodes", [])),
		"enemy_states": EnemyTurnRulesScript.build_enemy_states(scenario.get("enemy_factions", [])),
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
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.scenario_summary = ""
	session.flags = {}
	return session

static func create_generated_draft_session(
	generated_map: Dictionary,
	difficulty: String = "normal"
) -> SessionStateStoreScript.SessionData:
	var scenario: Dictionary = generated_map.get("scenario_record", {})
	var terrain_layers: Dictionary = generated_map.get("terrain_layers_record", {})
	var registration: Dictionary = ContentService.register_generated_scenario_draft(scenario, terrain_layers)
	if not bool(registration.get("ok", false)):
		push_error("Unable to register generated scenario draft: %s" % String(registration.get("message", "")))
		return SessionStateStoreScript.new_session_data()

	var scenario_id := String(scenario.get("id", ""))
	var session := create_session(scenario_id, difficulty, SessionStateStoreScript.LAUNCH_MODE_GENERATED_DRAFT)
	if session.scenario_id == "":
		return session

	var metadata: Dictionary = generated_map.get("metadata", {})
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	session.flags["generated_random_map_draft"] = true
	session.flags["generated_random_map_metadata"] = metadata.duplicate(true)
	session.flags["generated_random_map_boundary"] = {
		"write_policy": String(generated_map.get("write_policy", "")),
		"registry_write_policy": String(registration.get("write_policy", "")),
		"menu_policy": String(registration.get("menu_policy", "")),
		"availability": selection.get("availability", {}),
	}
	session.overworld["generated_random_map_metadata"] = metadata.duplicate(true)
	session.overworld["generated_terrain_layers_record_id"] = String(terrain_layers.get("id", ""))
	return session

static func _build_hero_state(hero_template: Dictionary) -> Dictionary:
	var command = hero_template.get("command", {})
	return HeroProgressionRulesScript.ensure_hero_progression(
		{
			"id": String(hero_template.get("id", "")),
			"name": String(hero_template.get("name", "Wandering Captain")),
			"level": 1,
			"experience": 0,
			"next_level_experience": 250,
			"base_movement": max(1, int(hero_template.get("base_movement", 10))),
			"command": {
				"attack": int(command.get("attack", 0)),
				"defense": int(command.get("defense", 0)),
				"power": int(command.get("power", 0)),
				"knowledge": int(command.get("knowledge", 0)),
			},
			"spellbook": SpellRulesScript.build_spellbook(hero_template),
			"artifacts": ArtifactRulesScript.normalize_hero_artifacts({}),
			"specialties": [],
			"battle_traits": hero_template.get("battle_traits", []).duplicate(true) if hero_template.get("battle_traits", []) is Array else [],
			"pending_specialty_choices": [],
		}
	)

static func _build_army_state(army_template: Dictionary) -> Dictionary:
	var stacks := []
	for stack in army_template.get("stacks", []):
		if not (stack is Dictionary):
			continue
		stacks.append(
			{
				"unit_id": String(stack.get("unit_id", "")),
				"count": max(0, int(stack.get("count", 0))),
			}
		)

	return {
		"id": String(army_template.get("id", "")),
		"name": String(army_template.get("name", "Field Army")),
		"stacks": stacks,
	}

static func _build_town_states(placements: Variant) -> Array:
	var towns := []
	if not (placements is Array):
		return towns

	for placement in placements:
		if not (placement is Dictionary):
			continue
		var town_template := ContentService.get_town(String(placement.get("town_id", "")))
		var built_buildings := _duplicate_array(town_template.get("starting_building_ids", []))
		var town_state := {
			"placement_id": String(placement.get("placement_id", "")),
			"town_id": String(placement.get("town_id", "")),
			"x": int(placement.get("x", 0)),
			"y": int(placement.get("y", 0)),
			"owner": String(placement.get("owner", "neutral")),
			"built_buildings": built_buildings,
			"available_recruits": {},
			"garrison": _duplicate_array(town_template.get("garrison", [])),
			"recovery": _duplicate_dict(placement.get("recovery", {})),
			"front": _duplicate_dict(placement.get("front", {})),
			"occupation": _duplicate_dict(placement.get("occupation", {})),
		}
		town_state["available_recruits"] = _seed_recruits_for_town_state(town_state)
		towns.append(
			town_state
		)
	return towns

static func _build_resource_states(placements: Variant) -> Array:
	var nodes := []
	if not (placements is Array):
		return nodes

	for placement in placements:
		if not (placement is Dictionary):
			continue
		nodes.append(
			{
				"placement_id": String(placement.get("placement_id", "")),
				"site_id": String(placement.get("site_id", "")),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
				"collected": bool(placement.get("collected", false)),
				"collected_by_faction_id": String(placement.get("collected_by_faction_id", "")),
				"collected_day": max(0, int(placement.get("collected_day", 0))),
				"response_origin": String(placement.get("response_origin", "")),
				"response_source_town_id": String(placement.get("response_source_town_id", "")),
				"response_last_day": max(0, int(placement.get("response_last_day", 0))),
				"response_until_day": max(0, int(placement.get("response_until_day", 0))),
			}
		)
	return nodes

static func _seed_recruits(built_buildings: Array) -> Dictionary:
	var recruits := {}
	var growth_bonus := {}
	for building_id_value in built_buildings:
		var building := ContentService.get_building(String(building_id_value))
		if building.is_empty():
			continue
		var unlock_unit_id := String(building.get("unlock_unit_id", ""))
		if unlock_unit_id != "":
			recruits[unlock_unit_id] = _unit_growth(unlock_unit_id)
		var building_growth_bonus = building.get("growth_bonus", {})
		if building_growth_bonus is Dictionary:
			for unit_id in building_growth_bonus.keys():
				growth_bonus[String(unit_id)] = int(growth_bonus.get(String(unit_id), 0)) + int(building_growth_bonus[unit_id])

	for unit_id in growth_bonus.keys():
		recruits[unit_id] = int(recruits.get(unit_id, _unit_growth(unit_id))) + int(growth_bonus[unit_id])
	return recruits

static func _seed_recruits_for_town_state(town: Dictionary) -> Dictionary:
	var recruits := _seed_recruits(_duplicate_array(town.get("built_buildings", [])))
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	recruits = _apply_growth_profile(recruits, town_template.get("recruitment", {}))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	recruits = _apply_growth_profile(recruits, faction.get("recruitment", {}))
	return recruits

static func _apply_growth_profile(recruits: Dictionary, profile: Variant) -> Dictionary:
	var merged := recruits.duplicate(true)
	if not (profile is Dictionary):
		return merged
	var growth_bonus = profile.get("growth_bonus", {})
	if not (growth_bonus is Dictionary):
		return merged
	for unit_id_value in growth_bonus.keys():
		var unit_id := String(unit_id_value)
		if unit_id == "" or not merged.has(unit_id):
			continue
		merged[unit_id] = int(merged.get(unit_id, 0)) + max(0, int(growth_bonus[unit_id]))
	return merged

static func _unit_growth(unit_id: String) -> int:
	var unit := ContentService.get_unit(unit_id)
	return max(0, int(unit.get("growth", 0)))

static func _normalize_position(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	return {"x": 0, "y": 0}

static func _normalize_resources(value: Variant) -> Dictionary:
	var resources := {"gold": 0, "wood": 0, "ore": 0}
	if value is Dictionary:
		for key in resources.keys():
			resources[key] = max(0, int(value.get(key, 0)))
	return resources

static func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

static func _duplicate_dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
