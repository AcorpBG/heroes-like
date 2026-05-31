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
	var empty_fallback_case := _empty_target_fallback_does_not_hunt_hidden_hero()
	if empty_fallback_case.is_empty():
		return
	var nonhero_case := _nonhero_targets_require_visibility_or_memory()
	if nonhero_case.is_empty():
		return
	var neutral_town_case := _neutral_towns_require_visibility_or_memory()
	if neutral_town_case.is_empty():
		return
	var exploration_case := _exploration_arrival_reassigns_visible_resource()
	if exploration_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "strategic_ai_known_world_memory_live_behavior",
		"behavior_policy": "enemy_pressure_uses_current_or_recent_ai_sightings_and_known_world_memory_instead_of_omniscient_targets",
		"save_policy": "known_world_memory_live_persist_no_save_migration",
		"cases": [preservation_case, sighting_case, empty_fallback_case, nonhero_case, neutral_town_case, exploration_case],
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

func _empty_target_fallback_does_not_hunt_hidden_hero() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 4)
	_make_no_known_targets_session(session)
	var origin := {"x": 7, "y": 2}
	var chosen := EnemyAdventureRules.choose_target(session, config, origin, {})
	if chosen.is_empty():
		_fail("No-candidate target fallback should produce an exploration or regroup plan.")
		return {}
	if String(chosen.get("target_kind", "")) == "hero":
		_fail("No-candidate target fallback used hidden active hero coordinates: %s" % JSON.stringify(chosen))
		return {}
	if String(chosen.get("target_kind", "")) != "explore":
		_fail("No-candidate target fallback should scout reachable frontier before passive regroup, got %s" % JSON.stringify(chosen))
		return {}
	if "no_known_targets" not in _normalize_string_array(chosen.get("target_reason_codes", [])):
		_fail("No-candidate exploration fallback did not explain no_known_targets: %s" % JSON.stringify(chosen))
		return {}
	var state := _enemy_state(session)
	state["pressure"] = 999
	_update_enemy_state(session, state)
	if not EnemyTurnRules._can_launch_raid(session, config, state, MIRECLAW):
		_fail("Fresh pressure should launch an exploration commander when no legitimate target candidates exist.")
		return {}
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var exploration_raid := _first_enemy_raid_for_kind(session, "explore")
	if exploration_raid.is_empty():
		_fail("Live enemy turn did not dispatch an exploration raid with no known targets: %s" % JSON.stringify(turn_result))
		return {}
	return {
		"case_id": "empty_target_fallback_does_not_hunt_hidden_hero",
		"fallback_target_kind": String(chosen.get("target_kind", "")),
		"fallback_target_id": String(chosen.get("target_placement_id", "")),
		"fallback_goal_distance": int(chosen.get("goal_distance", -1)),
		"pressure_launch_allowed_without_target": true,
		"live_exploration_raid_id": String(exploration_raid.get("placement_id", "")),
	}

func _nonhero_targets_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_resource_target_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "resource", "river_free_company"):
		_fail("Hidden resource should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "resource", "river_free_company"):
		_fail("Scouting discovery path should still see unknown nearby resources: %s" % JSON.stringify(scoutable))
		return {}
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
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "resource", "river_free_company"):
		_fail("Scouted resource memory did not make resource targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "nonhero_targets_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_resource": true,
		"known_resource_candidate": true,
		"known_world_target_id": "river_free_company",
	}

func _neutral_towns_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_neutral_town_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "town", "hidden_neutral_hold"):
		_fail("Hidden neutral town should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "town", "hidden_neutral_hold"):
		_fail("Scouting discovery path should still see unknown neutral towns: %s" % JSON.stringify(scoutable))
		return {}
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "town",
					"target_id": "hidden_neutral_hold",
					"target_label": "Hidden Neutral Hold",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "town", "hidden_neutral_hold"):
		_fail("Scouted neutral-town memory did not make the town targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "neutral_towns_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_neutral_town": true,
		"known_neutral_town_candidate": true,
		"known_world_target_id": "hidden_neutral_hold",
	}

func _exploration_arrival_reassigns_visible_resource() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_resource_target_session(session)
	_add_exploration_raid(session, 5, 4)
	var state := _enemy_state(session)
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var reassigned := _first_enemy_raid_for_kind(session, "resource")
	if reassigned.is_empty():
		_fail("Exploration arrival did not reassign to newly visible resource: %s" % JSON.stringify(result))
		return {}
	if String(reassigned.get("target_placement_id", "")) != "river_free_company":
		_fail("Exploration arrival reassigned to wrong resource: %s" % JSON.stringify(reassigned))
		return {}
	return {
		"case_id": "exploration_arrival_reassigns_visible_resource",
		"exploration_origin": {"x": 5, "y": 4},
		"reassigned_target_kind": String(reassigned.get("target_kind", "")),
		"reassigned_target_id": String(reassigned.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
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

func _make_hidden_resource_target_session(session) -> void:
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

	var resources := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["x"] = 0
		node["y"] = 4
		node["collected"] = true
		node["collected_by_faction_id"] = "player"
		node["response_until_day"] = 0
		node["response_security_rating"] = 0
		node["delivery_manifest"] = {}
		resources.append(node)
	session.overworld["resource_nodes"] = resources
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _make_hidden_neutral_town_session(session) -> void:
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
	towns.append({
		"placement_id": "hidden_neutral_hold",
		"town_id": "town_duskfen",
		"name": "Hidden Neutral Hold",
		"x": 0,
		"y": 4,
		"owner": "neutral",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _add_exploration_raid(session, x: int, y: int) -> void:
	var raid := {
		"placement_id": "known_world_exploration_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": true,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [x, y],
		"target_label": "Frontier scout %d,%d" % [x, y],
		"target_x": x,
		"target_y": y,
		"goal_x": x,
		"goal_y": y,
		"goal_distance": 0,
		"target_reason_codes": ["no_known_targets", "frontier_scouting", "search_contact"],
		"target_public_reason": "scouting the frontier",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _candidate_has_target(candidates: Array, target_kind: String, target_id: String) -> bool:
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("target_kind", "")) == target_kind and String(candidate.get("target_placement_id", "")) == target_id:
			return true
	return false

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

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event_value in events:
		if event_value is Dictionary:
			var event_type := String(event_value.get("event_type", ""))
			if event_type != "" and event_type not in output:
				output.append(event_type)
	return output

func _normalize_string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "":
			output.append(text)
	return output

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _ordinary_target_config() -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["priority_target_placement_ids"] = []
	config["priority_target_bonus"] = 0
	return config

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
