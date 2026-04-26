extends Node

const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const TREASURY := {"gold": 5200, "wood": 8, "ore": 8}
const LEAK_KEYS := [
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"raid_score",
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	var garrison_case := _run_case("garrison", "garrison")
	if garrison_case.is_empty():
		return
	cases.append(garrison_case)
	var raid_case := _run_case("raid", "raid")
	if raid_case.is_empty():
		return
	cases.append(raid_case)
	var rebuild_case := _run_case("commander_rebuild", "rebuild")
	if rebuild_case.is_empty():
		return
	cases.append(rebuild_case)

	var all_events := []
	for case_report in cases:
		for event in case_report.get("events", []):
			if event is Dictionary:
				all_events.append(event)
	for event_type in ["ai_town_built", "ai_town_recruited", "ai_garrison_reinforced", "ai_raid_reinforced", "ai_commander_rebuilt"]:
		if _event_by_type(all_events, event_type).is_empty():
			_fail("Missing compact event type %s" % event_type)
			return
	for event in all_events:
		_assert_no_event_leak(String(event.get("event_type", "event")), event)
		if _failed:
			return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"cases": cases,
		"event_types": _event_types(all_events),
	}
	print("AI_TOWN_GOVERNOR_PRESSURE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_case(case_id: String, expected_destination: String) -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	match case_id:
		"raid":
			_strengthen_duskfen_garrison(session)
			_add_active_raid(session)
		"commander_rebuild":
			_strengthen_duskfen_garrison(session)
			_set_shattered_commander_roster(session)
		_:
			pass
	var report := EnemyTurnRules.town_governor_pressure_report(session, _enemy_config(), FACTION_ID)
	var town_report := _town_report_by_id(report.get("towns", []), "duskfen_bastion")
	if town_report.is_empty():
		_fail("%s missing Duskfen town report" % case_id)
		return {}
	var selected_build: Dictionary = town_report.get("build", {}).get("selected_build", {})
	if selected_build.is_empty():
		_fail("%s missing selected build candidate" % case_id)
		return {}
	if String(selected_build.get("public_reason", "")) == "":
		_fail("%s selected build missing public reason" % case_id)
		return {}
	for key in ["income_value", "growth_value", "quality_value", "readiness_value", "pressure_value", "recovery_value", "market_value", "category_bonus", "garrison_need_bonus", "raid_need_bonus", "cost_value", "final_score"]:
		if not selected_build.has(key):
			_fail("%s selected build missing debug component %s" % [case_id, key])
			return {}
	var selected_recruit: Dictionary = town_report.get("recruitment", {}).get("selected_recruitment", {})
	if selected_recruit.is_empty():
		_fail("%s missing selected recruitment" % case_id)
		return {}
	var destination: Dictionary = selected_recruit.get("destination", {})
	if String(destination.get("type", "")) != expected_destination:
		_fail("%s expected destination %s, got %s" % [case_id, expected_destination, destination])
		return {}
	if String(destination.get("public_reason", "")) == "":
		_fail("%s destination missing public reason" % case_id)
		return {}
	var public_events := []
	for event in town_report.get("events", []):
		if event is Dictionary:
			public_events.append(event)
	return {
		"case_id": case_id,
		"town_placement_id": String(town_report.get("placement_id", "")),
		"strategic_role": String(town_report.get("strategic_role", "")),
		"treasury": report.get("projected_treasury", {}),
		"selected_build": selected_build,
		"selected_recruitment": selected_recruit,
		"events": public_events,
	}

func _base_session():
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

func _set_enemy_treasury(session, treasury: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != FACTION_ID:
			continue
		state["treasury"] = treasury.duplicate(true)
		states[index] = state
		session.overworld["enemy_states"] = states
		return
	_fail("Could not set enemy treasury")

func _strengthen_duskfen_garrison(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("placement_id", "")) != "duskfen_bastion":
			continue
		town["garrison"] = [
			{"unit_id": "unit_blackbranch_cutthroat", "count": 55},
			{"unit_id": "unit_mire_slinger", "count": 35},
		]
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not strengthen Duskfen garrison")

func _add_active_raid(session) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": "report_duskfen_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 7,
			"y": 1,
			"difficulty": "pressure",
			"combat_seed": hash("%s:report_duskfen_raid" % SCENARIO_ID),
			"spawned_by_faction_id": FACTION_ID,
			"days_active": 1,
			"arrived": false,
			"goal_distance": 2,
			"target_kind": "resource",
			"target_placement_id": "river_free_company",
			"target_label": "Riverwatch Free Company Yard",
			"target_x": 0,
			"target_y": 4,
			"enemy_army": {"id": "report_duskfen_raid", "name": "Report Raid", "stacks": []},
		}
	)
	session.overworld["encounters"] = encounters

func _set_shattered_commander_roster(session) -> void:
	var roster := []
	for hero_id_value in ContentService.get_faction(FACTION_ID).get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id == "":
			continue
		roster.append(
			{
				"roster_hero_id": hero_id,
				"status": EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE,
				"renown": 0,
				"army_continuity": {
					"encounter_id": "encounter_mire_raid",
					"stacks": [],
					"base_strength": 220,
					"current_strength": 0,
					"rebuild_need": 220,
					"status": "shattered",
				},
			}
		)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != FACTION_ID:
			continue
		state["commander_roster"] = roster
		states[index] = state
		session.overworld["enemy_states"] = states
		return
	_fail("Could not set shattered commander roster")

func _town_report_by_id(towns: Array, placement_id: String) -> Dictionary:
	for town in towns:
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type != "" and event_type not in types:
			types.append(event_type)
	return types

func _assert_no_event_leak(label: String, event: Dictionary) -> void:
	var event_text := JSON.stringify(event)
	for key in LEAK_KEYS:
		if event.has(String(key)) or event_text.contains(String(key)):
			_fail("%s leaked score-table key %s" % [label, key])
			return

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("AI_TOWN_GOVERNOR_PRESSURE_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
