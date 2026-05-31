extends Node

const REPORT_ID := "AI_KNOWN_WORLD_MEMORY_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var preservation_case := _known_world_memory_survives_normalization()
	if preservation_case.is_empty():
		return
	var sighting_case := _hero_targets_require_ai_sighting()
	if sighting_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "strategic_ai_known_world_memory_live_behavior",
		"behavior_policy": "enemy_hero_pressure_uses_current_or_recent_ai_sightings_not_omniscient_player_state",
		"save_policy": "known_world_memory_live_persist_no_save_migration",
		"cases": [preservation_case, sighting_case],
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

func _hero_targets_require_ai_sighting() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 4)
	var hidden_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if not hidden_candidates.is_empty():
		_fail("Hidden player hero should not become a hero target without AI sighting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	_set_primary_hero_position(session, 5, 2)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	var visible_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if visible_candidates.is_empty():
		_fail("Currently sighted player hero did not become eligible for hero pressure.")
		return {}
	_set_primary_hero_position(session, 0, 4)
	var remembered_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if remembered_candidates.is_empty():
		_fail("Recent remembered player hero sighting did not remain eligible for hero pressure.")
		return {}
	var remembered: Dictionary = remembered_candidates[0]
	if int(remembered.get("target_x", -1)) != 5 or int(remembered.get("target_y", -1)) != 2:
		_fail("Remembered hero target used live hidden position instead of remembered sighting: %s" % JSON.stringify(remembered))
		return {}
	return {
		"case_id": "hero_targets_require_ai_sighting",
		"hidden_candidate_count": hidden_candidates.size(),
		"visible_candidate_count": visible_candidates.size(),
		"remembered_target": {
			"target_id": String(remembered.get("target_placement_id", "")),
			"x": int(remembered.get("target_x", -1)),
			"y": int(remembered.get("target_y", -1)),
		},
		"sighting_count": int(memory_result.get("sighting_count", 0)),
	}

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
