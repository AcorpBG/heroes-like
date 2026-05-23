extends Node

const REPORT_ID := "AI_RAID_REGROUP_RETREAT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_understrength_raid_regroups()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_regroup_behavior_no_save_migration",
		"behavior_policy": "understrength_raids_retreat_to_owned_town_and_pull_garrison",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_understrength_raid_regroups() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	var raid := _understrength_raid(session, config)
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	var desired_before := EnemyAdventureRules.desired_raid_strength(raid)
	if not EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Fixture raid was not considered understrength: strength=%d desired=%d raid=%s" % [before_strength, desired_before, JSON.stringify(raid)])
		return {}
	var garrison_before := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "regroup_vaska_understrength")
	if after_raid.is_empty():
		_fail("Regroup raid disappeared after advance.")
		return {}
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	var garrison_after := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var resource_controller := _resource_controller(session, "river_free_company")
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Regroup advance did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if "ai_raid_regrouped" not in event_types:
		_fail("Regroup advance did not emit ai_raid_regrouped: %s" % JSON.stringify(result))
		return {}
	if after_strength <= before_strength:
		_fail("Regroup did not increase raid strength: before=%d after=%d raid=%s" % [before_strength, after_strength, JSON.stringify(after_raid)])
		return {}
	if garrison_after >= garrison_before:
		_fail("Regroup did not pull from town garrison: before=%d after=%d" % [garrison_before, garrison_after])
		return {}
	if String(after_raid.get("last_regroup_town_id", "")) != "duskfen_bastion":
		_fail("Regroup did not record duskfen_bastion as regroup town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) != "":
		_fail("Regrouped raid should clear its target after reaching a usable host strength: %s" % JSON.stringify(after_raid))
		return {}
	if resource_controller == MIRECLAW:
		_fail("Understrength raid captured the original offensive resource instead of regrouping.")
		return {}
	return {
		"case_id": "river_pass_understrength_raid_regroups_at_duskfen",
		"before_strength": before_strength,
		"after_strength": after_strength,
		"desired_before": desired_before,
		"garrison_before": garrison_before,
		"garrison_after": garrison_after,
		"event_types": event_types,
		"message": String(result.get("message", "")),
		"resource_controller_after": resource_controller,
		"regroup_town_id": String(after_raid.get("last_regroup_town_id", "")),
	}

func _understrength_raid(session, config: Dictionary) -> Dictionary:
	var raid := {
		"placement_id": "regroup_vaska_understrength",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:regroup_vaska_understrength" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Free Company Camp",
		"target_x": 3,
		"target_y": 4,
		"goal_x": 3,
		"goal_y": 4,
		"enemy_army": {
			"id": "regroup_fixture_host",
			"name": "Damaged Raid Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 1}],
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

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _town_garrison_count(session, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		for stack in town.get("garrison", []):
			if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
				return int(stack.get("count", 0))
	return 0

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

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
