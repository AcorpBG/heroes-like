extends Node

const REPORT_ID := "AI_TOWN_DEFENSE_RETASK_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_raid_retasks_to_stabilizing_town()
	if case_report.is_empty():
		return
	var overcommit_case := _covered_town_defense_does_not_retask_second_commander()
	if overcommit_case.is_empty():
		return
	var resource_overcommit_case := _covered_resource_defense_does_not_retask_second_commander()
	if resource_overcommit_case.is_empty():
		return
	var release_case := _stationed_town_defender_releases_when_front_clears()
	if release_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_town_defense_retask_rotation_no_save_migration",
		"behavior_policy": "active_raids_defend_threatened_owned_town_fronts_without_overcommitting_and_release_cleared_defenders",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"overcommit_case": overcommit_case,
		"resource_overcommit_case": resource_overcommit_case,
		"release_case": release_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_raid_retasks_to_stabilizing_town() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_stabilizing_front(session, "duskfen_bastion")
	_set_player_position(session, {"x": 6, "y": 2})
	_set_resource_controller(session, "river_free_company", "player")
	var raid := _defense_retask_raid(session)
	if EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Fixture raid should be strong enough to avoid regroup before defense retask: %s" % JSON.stringify(raid))
		return {}
	var town_before := _town(session, "duskfen_bastion")
	var garrison_strength_before := _garrison_strength(town_before)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := {}
	var all_events := []
	for _turn_index in range(4):
		result = EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
		state = result.get("state", state)
		all_events.append_array(result.get("events", []))
		if "ai_town_defended" in _event_types(all_events):
			break
	var after_raid := _encounter(session, "defense_retask_vaska")
	if after_raid.is_empty():
		_fail("Defense retask raid disappeared after advance.")
		return {}
	var event_types := _event_types(all_events)
	if "ai_target_assigned" not in event_types:
		_fail("Defense retask did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if "ai_town_defended" not in event_types:
		_fail("Defense retask did not resolve town-defense arrival: %s" % JSON.stringify(result))
		return {}
	if String(after_raid.get("target_kind", "")) != "town":
		_fail("Defense retask did not target a town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Defense retask targeted wrong town: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "town_defense" not in reason_codes or "front_stabilization" not in reason_codes:
		_fail("Defense retask missing public reason codes: %s" % JSON.stringify(reason_codes))
		return {}
	if String(after_raid.get("previous_target_placement_id", "")) != "river_free_company":
		_fail("Defense retask did not preserve previous offensive target metadata: %s" % JSON.stringify(after_raid))
		return {}
	if _resource_controller(session, "river_free_company") == MIRECLAW:
		_fail("Defense retask still captured the previous resource target.")
		return {}
	var town_after := _town(session, "duskfen_bastion")
	var garrison_strength_after := _garrison_strength(town_after)
	if garrison_strength_after <= garrison_strength_before:
		_fail("Town-defense arrival did not increase Duskfen garrison strength: before=%d after=%d town=%s" % [garrison_strength_before, garrison_strength_after, JSON.stringify(town_after)])
		return {}
	if String(town_after.get("ai_defended_by_faction_id", "")) != MIRECLAW:
		_fail("Town-defense arrival did not mark Duskfen as AI defended: %s" % JSON.stringify(town_after))
		return {}
	var front_after := OverworldRules.town_front_state(session, town_after)
	if not bool(front_after.get("active", false)) or String(front_after.get("mode", "")) != "stabilizing":
		_fail("Town-defense arrival did not keep Duskfen as an active defended front: %s" % JSON.stringify(front_after))
		return {}
	var defender_commander: Dictionary = town_after.get("ai_defender_commander_state", {}) if town_after.get("ai_defender_commander_state", {}) is Dictionary else {}
	if String(defender_commander.get("roster_hero_id", "")) != "hero_vaska":
		_fail("Town-defense arrival did not station Vaska as Duskfen defender: %s" % JSON.stringify(defender_commander))
		return {}
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var active_roster_entry := _commander_roster_entry(session, "hero_vaska")
	if String(active_roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE:
		_fail("Town defender commander was not retained as active after roster normalization: %s" % JSON.stringify(active_roster_entry))
		return {}
	if String(active_roster_entry.get("active_placement_id", "")) != "town_defense:duskfen_bastion":
		_fail("Town defender active placement was not retained after roster normalization: %s" % JSON.stringify(active_roster_entry))
		return {}
	var replacement_selection := EnemyAdventureRules.select_raid_commander_roster_hero_id(session, MIRECLAW, 0)
	if replacement_selection == "hero_vaska":
		_fail("Town defender commander was selectable for a second raid while stationed.")
		return {}
	var assault_payload := BattleRules.create_town_assault_payload(session, "duskfen_bastion")
	if String(assault_payload.get("enemy_hero", {}).get("roster_hero_id", "")) != "hero_vaska":
		_fail("Town assault payload did not use stationed AI defender commander: %s" % JSON.stringify(assault_payload.get("enemy_hero", {})))
		return {}
	if not _battle_has_enemy_unit(assault_payload, "unit_bog_brute"):
		_fail("Town assault payload did not include the arrived defender stack in the garrison battle.")
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(all_events, 8)
	if not bool(public_log.get("ok", false)):
		_fail("Defense retask public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	_assert_saved_task_state(session)
	var town_after_front: Dictionary = town_after.get("front", {}) if town_after.get("front", {}) is Dictionary else {}
	var defense_until: int = max(
		int(town_after.get("ai_defense_until_day", 0)),
		int(town_after_front.get("defense_until_day", 0))
	)
	session.day = defense_until + 1
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var released_town := _town(session, "duskfen_bastion")
	if released_town.has("ai_defender_commander_state") or String(released_town.get("ai_defender_roster_hero_id", "")) != "":
		_fail("Expired town defender metadata was not cleared: %s" % JSON.stringify(released_town))
		return {}
	var released_roster_entry := _commander_roster_entry(session, "hero_vaska")
	if String(released_roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE:
		_fail("Expired town defender commander did not return to available roster status: %s" % JSON.stringify(released_roster_entry))
		return {}
	if _failed:
		return {}
	return {
		"case_id": "river_pass_active_raid_defends_stabilizing_duskfen",
		"before_target_id": "river_free_company",
		"after_target_kind": String(after_raid.get("target_kind", "")),
		"after_target_id": String(after_raid.get("target_placement_id", "")),
		"town_defended_event": "ai_town_defended" in event_types,
		"garrison_strength_before": garrison_strength_before,
		"garrison_strength_after": garrison_strength_after,
		"front_active_after_defense": bool(front_after.get("active", false)),
		"front_mode_after_defense": String(front_after.get("mode", "")),
		"stationed_commander_id": String(defender_commander.get("roster_hero_id", "")),
		"stationed_commander_status": String(active_roster_entry.get("status", "")),
		"stationed_active_placement_id": String(active_roster_entry.get("active_placement_id", "")),
		"replacement_selection_while_stationed": replacement_selection,
		"released_commander_status": String(released_roster_entry.get("status", "")),
		"defender_metadata_cleared_after_expiry": not released_town.has("ai_defender_commander_state"),
		"town_assault_enemy_commander_id": String(assault_payload.get("enemy_hero", {}).get("roster_hero_id", "")),
		"target_public_reason": String(after_raid.get("target_public_reason", "")),
		"target_reason_codes": reason_codes,
		"event_types": event_types,
		"resource_controller_after": _resource_controller(session, "river_free_company"),
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _stationed_town_defender_releases_when_front_clears() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_stabilizing_front(session, "duskfen_bastion")
	_set_player_position(session, {"x": 6, "y": 2})
	var raid := _defense_retask_raid(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var all_events := []
	for _turn_index in range(4):
		var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
		state = result.get("state", state)
		all_events.append_array(result.get("events", []))
		if "ai_town_defended" in _event_types(all_events):
			break
	if "ai_town_defended" not in _event_types(all_events):
		_fail("Defender release fixture did not station a town defender before release check.")
		return {}
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var stationed_entry := _commander_roster_entry(session, "hero_vaska")
	if String(stationed_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE:
		_fail("Defender release fixture did not mark Vaska active before front clear: %s" % JSON.stringify(stationed_entry))
		return {}
	var town_before_clear := _town(session, "duskfen_bastion")
	var front_before_clear := OverworldRules.town_front_state(session, town_before_clear)
	if not bool(front_before_clear.get("active", false)):
		_fail("Defender release fixture did not expose an active defended front before clear: %s" % JSON.stringify(front_before_clear))
		return {}
	_clear_town_front(session, "duskfen_bastion")
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var released_town := _town(session, "duskfen_bastion")
	if released_town.has("ai_defender_commander_state") or String(released_town.get("ai_defender_roster_hero_id", "")) != "":
		_fail("Cleared town front did not release stationed defender metadata: %s" % JSON.stringify(released_town))
		return {}
	var released_entry := _commander_roster_entry(session, "hero_vaska")
	if String(released_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE:
		_fail("Cleared town front did not return defender commander to available roster: %s" % JSON.stringify(released_entry))
		return {}
	return {
		"case_id": "stationed_town_defender_releases_when_front_clears",
		"front_active_before_clear": bool(front_before_clear.get("active", false)),
		"front_mode_before_clear": String(front_before_clear.get("mode", "")),
		"stationed_status_before_clear": String(stationed_entry.get("status", "")),
		"released_status_after_clear": String(released_entry.get("status", "")),
		"defender_metadata_cleared": not released_town.has("ai_defender_commander_state"),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _covered_town_defense_does_not_retask_second_commander() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_stabilizing_front(session, "duskfen_bastion")
	_set_player_position(session, {"x": 6, "y": 2})
	_set_resource_controller(session, "river_free_company", "player")

	var committed := _defense_retask_raid(session)
	committed["placement_id"] = "defense_committed_vaska"
	committed["target_kind"] = "town"
	committed["target_placement_id"] = "duskfen_bastion"
	committed["target_label"] = "Duskfen Bastion"
	committed["target_reason_codes"] = ["town_defense", "front_stabilization"]
	committed["target_public_reason"] = "defending threatened town"
	committed["goal_distance"] = 2
	committed["arrived"] = false
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(committed)
	session.overworld["encounters"] = encounters

	var probe := _defense_retask_raid(session)
	probe["placement_id"] = "defense_probe_sable"
	probe["target_reason_codes"] = ["pressure_probe_fixture"]
	probe["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		probe,
		"hero_sable",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	probe = EnemyAdventureRules.ensure_raid_army(probe, session)
	var redirected := EnemyAdventureRules._redirect_raid_to_threatened_town_defense(session, config, probe, MIRECLAW)
	if String(redirected.get("target_kind", "")) != "resource" or String(redirected.get("target_placement_id", "")) != "river_free_company":
		_fail("Covered town defense front should not retask second commander away from pressure: %s" % JSON.stringify(redirected))
		return {}
	if String(redirected.get("previous_target_placement_id", "")) != "":
		_fail("Covered town defense front should leave probe target metadata untouched: %s" % JSON.stringify(redirected))
		return {}
	var committed_strength := EnemyAdventureRules.raid_strength(committed)
	return {
		"case_id": "covered_town_defense_does_not_retask_second_commander",
		"covered_town_id": "duskfen_bastion",
		"committed_defender_id": String(committed.get("placement_id", "")),
		"committed_defender_strength": committed_strength,
		"probe_target_kind": String(redirected.get("target_kind", "")),
		"probe_target_id": String(redirected.get("target_placement_id", "")),
		"probe_preserved_offense": String(redirected.get("target_placement_id", "")) == "river_free_company",
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _covered_resource_defense_does_not_retask_second_commander() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_position(session, {"x": 0, "y": 4})
	_set_resource_controller(session, "river_free_company", MIRECLAW)
	_set_resource_controller(session, "river_signal_post", "player")
	_set_resource_defense_front(session, "river_free_company")

	var committed := _defense_retask_raid(session)
	committed["placement_id"] = "resource_defense_committed_vaska"
	committed["target_kind"] = "resource"
	committed["target_placement_id"] = "river_free_company"
	committed["target_label"] = "Free Company Camp"
	committed["target_reason_codes"] = ["site_defense", "defend_front", "front_stabilization"]
	committed["target_public_reason"] = "defending held site"
	committed["goal_distance"] = 2
	committed["arrived"] = false
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(committed)
	session.overworld["encounters"] = encounters

	var probe := _defense_retask_raid(session)
	probe["placement_id"] = "resource_defense_probe_sable"
	probe["target_placement_id"] = "river_signal_post"
	probe["target_label"] = "Signal Post"
	probe["target_x"] = 2
	probe["target_y"] = 3
	probe["goal_x"] = 2
	probe["goal_y"] = 3
	probe["target_reason_codes"] = ["pressure_probe_fixture"]
	probe["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		probe,
		"hero_sable",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	probe = EnemyAdventureRules.ensure_raid_army(probe, session)
	var redirected := EnemyAdventureRules._redirect_raid_to_threatened_resource_defense(session, config, probe, MIRECLAW)
	if String(redirected.get("target_kind", "")) != "resource" or String(redirected.get("target_placement_id", "")) != "river_signal_post":
		_fail("Covered resource defense front should not retask second commander away from pressure: %s" % JSON.stringify(redirected))
		return {}
	if String(redirected.get("previous_target_placement_id", "")) != "":
		_fail("Covered resource defense front should leave probe target metadata untouched: %s" % JSON.stringify(redirected))
		return {}
	var committed_strength := EnemyAdventureRules.raid_strength(committed)
	return {
		"case_id": "covered_resource_defense_does_not_retask_second_commander",
		"covered_resource_id": "river_free_company",
		"committed_defender_id": String(committed.get("placement_id", "")),
		"committed_defender_strength": committed_strength,
		"probe_target_kind": String(redirected.get("target_kind", "")),
		"probe_target_id": String(redirected.get("target_placement_id", "")),
		"probe_preserved_offense": String(redirected.get("target_placement_id", "")) == "river_signal_post",
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _defense_retask_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "defense_retask_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 6,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:defense_retask_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Free Company Camp",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"enemy_army": {
			"id": "defense_retask_fixture_host",
			"name": "Defense Retask Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 8}],
		},
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

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
	_fail("Could not find enemy state for %s" % MIRECLAW)
	return {}

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _set_stabilizing_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["front"] = {
			"state": "stabilizing",
			"faction_id": MIRECLAW,
			"last_change_day": max(0, int(session.day) - 1),
			"stabilize_until_day": int(session.day) + 4,
			"last_owner": "player",
			"capture_count": 1,
			"source": "test_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for stabilizing front fixture." % placement_id)

func _clear_town_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["front"] = {}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for front-clear fixture." % placement_id)

func _set_player_position(session, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	var heroes: Array = session.overworld.get("heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("owner", "player")) == "player":
			hero["position"] = session.overworld["hero_position"].duplicate(true)
			heroes[index] = hero
			session.overworld["heroes"] = heroes
			return

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _set_resource_defense_front(session, placement_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["front"] = {
			"state": "defend",
			"faction_id": MIRECLAW,
			"threatened_by_player": true,
			"priority_bonus": 120,
			"last_change_day": max(0, int(session.day) - 1),
			"defense_until_day": int(session.day) + 4,
			"source": "test_fixture",
		}
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s for defense front fixture." % placement_id)

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _commander_roster_entry(session, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	return {}

func _garrison_strength(town: Dictionary) -> int:
	var total := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit: Dictionary = ContentService.get_unit(String(stack.get("unit_id", "")))
		var count: int = max(0, int(stack.get("count", 0)))
		total += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total

func _battle_has_enemy_unit(payload: Dictionary, unit_id: String) -> bool:
	for stack in payload.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == "enemy" and String(stack.get("unit_id", "")) == unit_id:
			return true
	return false

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _event_types(events: Variant) -> Array:
	var types := []
	if not (events is Array):
		return types
	for event in events:
		if event is Dictionary:
			var event_type := String(event.get("event_type", ""))
			if event_type != "" and event_type not in types:
				types.append(event_type)
	types.sort()
	return types

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

func _assert_saved_task_state(session) -> void:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW and state.has("hero_task_state"):
			return
	_fail("Defense retask did not persist hero_task_state.")

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Defense retask public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
