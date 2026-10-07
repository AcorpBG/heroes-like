extends Node

const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")

const REPORT_ID := "AI_KNOWN_WORLD_MEMORY_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"
const EXPLORATION_DAYS := 3
const SCOUTING_MAP_HEIGHT := 30

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var preservation_case := _known_world_memory_survives_normalization()
	if preservation_case.is_empty():
		return
	var hidden_hero_case := _scouting_hero_does_not_hunt_hidden_hero()
	if hidden_hero_case.is_empty():
		return
	var exploration_case := _scouting_hero_uncovers_new_ground()
	if exploration_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "strategic_ai_known_world_memory_live_behavior",
		"behavior_policy": "enemy_heroes_know_only_what_their_towns_and_heroes_have_seen_and_scout_the_unexplored_frontier",
		"save_policy": "known_world_memory_live_persist_no_save_migration",
		"cases": [preservation_case, hidden_hero_case, exploration_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _known_world_memory_survives_normalization() -> Dictionary:
	var session = _base_session()
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [
				{
					"hero_id": "hero_lyra",
					"hero_label": "Lyra",
					"x": 0,
					"y": 4,
					"army_strength": 96,
					"seen_day": int(session.day),
					"expires_day": int(session.day) + 2,
					"source_kind": "town",
					"source_id": "duskfen_bastion",
				}
			],
		}
	)
	EnemyTurnRules.normalize_enemy_states(session)
	var memory := _enemy_memory(session)
	var scouted: Array = memory.get("scouted_targets", []) if memory.get("scouted_targets", []) is Array else []
	var sightings: Array = memory.get("player_hero_sightings", []) if memory.get("player_hero_sightings", []) is Array else []
	if scouted.is_empty() or sightings.is_empty():
		_fail("Enemy state normalization dropped known_world_memory: %s" % JSON.stringify(memory))
		return {}
	return {
		"case_id": "known_world_memory_survives_normalization",
		"scouted_target_count": scouted.size(),
		"hero_sighting_count": sightings.size(),
		"hero_sighting_position": {"x": int(sightings[0].get("x", -1)), "y": int(sightings[0].get("y", -1))},
	}

## With nothing known, Mireclaw fields a hero that scouts the unexplored
## frontier and never walks at the hidden player hero.
func _scouting_hero_does_not_hunt_hidden_hero() -> Dictionary:
	var session = _base_session()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	# Towns see as far as the player's towns do, which covers the whole river
	# strip, so the map gets an unseen south with the hero hidden in it.
	_extend_map_south(session, SCOUTING_MAP_HEIGHT)
	_set_primary_hero_position(session, 0, SCOUTING_MAP_HEIGHT - 2)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(turn_result.get("ok", false)):
		_fail("No-known-target enemy turn failed: %s" % JSON.stringify(turn_result))
		return {}
	if not _first_enemy_raid_for_kind(session, "explore").is_empty():
		_fail("Live enemy turn spawned a raid host instead of fielding a hero.")
		return {}
	var explorer := {}
	for entry in AiHeroRulesScript.active_hero_entries(session, MIRECLAW):
		var goal: Dictionary = entry.get("ai_hero", {}).get("goal", {})
		if String(goal.get("kind", "")) == "hero":
			_fail("Enemy hero hunted the hidden player hero: %s" % JSON.stringify(entry))
			return {}
		if String(goal.get("kind", "")) == "explore" and explorer.is_empty():
			explorer = entry
	if explorer.is_empty():
		_fail("Live enemy turn did not send a hero to scout with no known targets: %s" % JSON.stringify(AiHeroRulesScript.active_hero_entries(session, MIRECLAW)))
		return {}
	if _distance_to_hidden_hero(session, explorer) < 3:
		_fail("Scouting hero ended its day beside the hidden player hero: %s" % JSON.stringify(explorer))
		return {}
	return {
		"case_id": "scouting_hero_does_not_hunt_hidden_hero",
		"live_scouting_hero_id": String(explorer.get("placement_id", "")),
		"live_scouting_goal": explorer.get("ai_hero", {}).get("goal", {}),
		"explored_tiles": AiHeroRulesScript.explored_tile_count(_enemy_state(session)),
	}

## Enemy heroes keep their own explored map. Day after day the scout reaches
## new ground and moves on from frontiers it has already uncovered.
func _scouting_hero_uncovers_new_ground() -> Dictionary:
	var session = _base_session()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	_extend_map_south(session, SCOUTING_MAP_HEIGHT)
	_set_primary_hero_position(session, 0, SCOUTING_MAP_HEIGHT - 2)
	var explored_by_day := []
	var scout_positions := []
	var scout_id := ""
	for _day in range(EXPLORATION_DAYS):
		var turn_result := EnemyTurnRules.run_enemy_turn(session)
		if not bool(turn_result.get("ok", false)):
			_fail("Exploration enemy turn failed: %s" % JSON.stringify(turn_result))
			return {}
		if not _first_enemy_raid_for_kind(session, "explore").is_empty():
			_fail("Exploration turn spawned a raid host instead of moving a hero.")
			return {}
		var heroes := AiHeroRulesScript.active_hero_entries(session, MIRECLAW)
		if heroes.is_empty():
			_fail("Mireclaw fielded no hero to explore with.")
			return {}
		if scout_id == "":
			scout_id = String(heroes[0].get("placement_id", ""))
		var scout := _encounter_by_id(session, scout_id)
		if scout.is_empty():
			_fail("Scouting hero disappeared on an empty map: %s" % JSON.stringify(heroes))
			return {}
		scout_positions.append({"x": int(scout.get("x", 0)), "y": int(scout.get("y", 0))})
		explored_by_day.append(AiHeroRulesScript.explored_tile_count(_enemy_state(session)))
	if int(explored_by_day[explored_by_day.size() - 1]) <= int(explored_by_day[0]):
		_fail("Scouting hero did not uncover new ground over %d days: %s" % [EXPLORATION_DAYS, JSON.stringify(explored_by_day)])
		return {}
	if scout_positions[0] == scout_positions[scout_positions.size() - 1]:
		_fail("Scouting hero stayed on one tile instead of moving to new frontiers: %s" % JSON.stringify(scout_positions))
		return {}

	return {
		"case_id": "scouting_hero_uncovers_new_ground",
		"scouting_hero_id": scout_id,
		"scout_positions": scout_positions,
		"explored_tiles_by_day": explored_by_day,
	}

# River Pass (9x5) lies wholly inside the AI town's round sight, so hidden-hero
# fixtures extend it south with open grass to reach tiles no AI source sees.
func _extend_map_south(session, height: int) -> void:
	var rows: Array = session.overworld.get("map", [])
	var width: int = rows[0].size() if not rows.is_empty() and rows[0] is Array else 0
	while rows.size() < height:
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": rows.size()}
	OverworldRules.refresh_fog_of_war(session)

func _base_session():
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _set_primary_hero_position(session, x: int, y: int) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = String(session.overworld.get("active_hero_id", "hero_lyra"))
	hero["name"] = String(hero.get("name", "Lyra"))
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = {"x": x, "y": y}
	session.overworld["active_hero_id"] = String(hero.get("id", "hero_lyra"))
	session.overworld["player_heroes"] = [hero]

func _make_no_known_targets_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	session.overworld["towns"] = towns

	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _distance_to_hidden_hero(session, entry: Dictionary) -> int:
	var hero_position: Dictionary = session.overworld.get("hero_position", {})
	return maxi(absi(int(entry.get("x", 0)) - int(hero_position.get("x", 0))), absi(int(entry.get("y", 0)) - int(hero_position.get("y", 0))))

func _first_enemy_raid_for_kind(session, target_kind: String) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("target_kind", "")) == target_kind:
			return encounter
	return {}

func _encounter_by_id(session, placement_id: String) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find Mireclaw enemy state.")
	return {}

func _enemy_memory(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("known_world_memory", {}) if state.get("known_world_memory", {}) is Dictionary else {}

func _patch_enemy_memory(session, memory: Dictionary) -> void:
	var state := _enemy_state(session)
	state["known_world_memory"] = memory
	_update_enemy_state(session, state)

func _update_enemy_state(session, updated_state: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if states[index] is Dictionary and String(states[index].get("faction_id", "")) == MIRECLAW:
			states[index] = updated_state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update Mireclaw enemy state.")

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
