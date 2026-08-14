extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SCENARIO_DEADLINE_LOSS_VARIETY_REPORT"
const MIN_ACTIVE_DEADLINE_SCENARIO_COUNT := 16
const DUAL_MODE_ISOLATION_SCENARIO_ID := "mireford-skirmish"
const FINALE_SCENARIO_ID := "ninefold-confluence"
const RIVER_PASS_SCENARIO_ID := "river-pass"
const RIVER_PASS_PRESSURE_FACTION_ID := "faction_mireclaw"
const RIVER_PASS_SAFE_PRESSURE := 14
const RIVER_PASS_DEFEAT_PRESSURE := 15
const RIVER_PASS_RELIEF_RIVER_GUARDS := 20
const RIVER_PASS_RECALL_RIVER_GUARDS := 2
const RIVER_PASS_RECALL_EMBER_ARCHERS := 8
const CAUSEWAY_SCENARIO_ID := "causeway-stand"
const CAUSEWAY_VETERAN_RIVER_GUARDS := 10
const CAUSEWAY_DUSKFEN_GARRISON_BOG_BRUTES := 5
const CAUSEWAY_VETERAN_GARRISON_RIVER_GUARDS := 32
const FEN_CROWN_SCENARIO_ID := "fen-crown"
const FEN_CROWN_FINAL_MARCH_RIVER_GUARDS := 14
const FORBIDDEN_CLAIM_TOKENS := [
	"alpha_or_parity_claim\":true",
	"final_scenario_balance\":true",
	"campaign_breadth_complete\":true",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario_ids := _active_authored_scenario_ids()
	if scenario_ids.size() < MIN_ACTIVE_DEADLINE_SCENARIO_COUNT:
		_fail("Active authored scenario deadline set is too small: %s" % JSON.stringify(scenario_ids))
		return
	var rows := []
	for scenario_id in scenario_ids:
		var row := _deadline_row(String(scenario_id))
		if row.is_empty():
			return
		rows.append(row)
	var campaign_deadline_count := 0
	var skirmish_deadline_count := 0
	var finale_deadline_count := 0
	for row in rows:
		if bool(row.get("campaign_available", false)):
			campaign_deadline_count += 1
		if bool(row.get("skirmish_available", false)):
			skirmish_deadline_count += 1
		if String(row.get("scenario_id", "")) == FINALE_SCENARIO_ID:
			finale_deadline_count += 1
	var expected_counts := _active_availability_counts(scenario_ids)
	if campaign_deadline_count != int(expected_counts.get("campaign", 0)) or skirmish_deadline_count != int(expected_counts.get("skirmish", 0)) or finale_deadline_count != 1:
		_fail("Deadline loss objectives do not cover campaign, skirmish, and finale surfaces: %s" % JSON.stringify(rows))
		return
	var river_pass_pressure_boundary := _river_pass_pressure_boundary()
	if river_pass_pressure_boundary.is_empty():
		return
	var river_pass_refit_reinforcement := _river_pass_refit_reinforcement_contract()
	if river_pass_refit_reinforcement.is_empty():
		return
	var river_pass_objective_chain := _river_pass_objective_chain()
	if river_pass_objective_chain.is_empty():
		return
	var causeway_veteran_staging_contract := _causeway_veteran_staging_contract()
	if causeway_veteran_staging_contract.is_empty():
		return
	var fen_crown_final_march_reserve := _fen_crown_final_march_reserve_contract()
	if fen_crown_final_march_reserve.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": "scenario_deadline_loss_variety_report_v5",
		"deadline_scenario_count": rows.size(),
		"active_deadline_count": scenario_ids.size(),
		"expected_campaign_deadline_count": int(expected_counts.get("campaign", 0)),
		"expected_skirmish_deadline_count": int(expected_counts.get("skirmish", 0)),
		"campaign_deadline_count": campaign_deadline_count,
		"skirmish_deadline_count": skirmish_deadline_count,
		"finale_deadline_count": finale_deadline_count,
		"dual_mode_isolation_scenario_id": DUAL_MODE_ISOLATION_SCENARIO_ID,
		"finale_scenario_id": FINALE_SCENARIO_ID,
		"river_pass_pressure_boundary": river_pass_pressure_boundary,
		"river_pass_refit_reinforcement": river_pass_refit_reinforcement,
		"river_pass_objective_chain": river_pass_objective_chain,
		"causeway_veteran_staging_contract": causeway_veteran_staging_contract,
		"fen_crown_final_march_reserve": fen_crown_final_march_reserve,
		"rows": rows,
		"boundary": {
			"authored_deadline_loss_objectives": true,
			"final_scenario_balance": false,
			"new_campaign_arc": true,
			"campaign_breadth_complete": false,
			"alpha_or_parity_claim": false,
		},
	}
	var compact_text := JSON.stringify(payload).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if compact_text.contains(String(token)):
			_fail("Report payload contains forbidden claim token: %s." % token)
			return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _active_authored_scenario_ids() -> Array:
	var ids := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario := ContentService.get_authored_scenario(String(scenario_id))
		var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false)):
			ids.append(String(scenario_id))
	ids.sort()
	return ids

func _active_availability_counts(scenario_ids: Array) -> Dictionary:
	var counts := {"campaign": 0, "skirmish": 0}
	for scenario_id in scenario_ids:
		var scenario := ContentService.get_authored_scenario(String(scenario_id))
		var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if bool(availability.get("campaign", false)):
			counts["campaign"] = int(counts.get("campaign", 0)) + 1
		if bool(availability.get("skirmish", false)):
			counts["skirmish"] = int(counts.get("skirmish", 0)) + 1
	return counts

func _deadline_row(scenario_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		_fail("Missing scenario %s." % scenario_id)
		return {}
	var deadline_objective := _deadline_objective(scenario)
	if deadline_objective.is_empty():
		_fail("Scenario %s is missing a day_at_least defeat objective." % scenario_id)
		return {}
	var day := int(deadline_objective.get("day", 0))
	if day < 5:
		_fail("Scenario %s has an unrealistically low deadline day: %d." % [scenario_id, day])
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null or session.scenario_id != scenario_id:
		_fail("Scenario %s did not boot a live skirmish session." % scenario_id)
		return {}
	ScenarioRulesScript.normalize_scenario_state(session)
	session.day = day - 1
	var before_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(before_result.get("status", "")) != "in_progress":
		_fail("Scenario %s deadline resolved before the authored day: %s" % [scenario_id, JSON.stringify(before_result)])
		return {}
	session.scenario_status = "in_progress"
	session.scenario_summary = ""
	session.day = day
	var deadline_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(deadline_result.get("status", "")) != "defeat" or session.scenario_status != "defeat":
		_fail("Scenario %s deadline did not resolve as defeat on day %d: %s" % [scenario_id, day, JSON.stringify(deadline_result)])
		return {}
	var objective_text := ScenarioRulesScript.describe_objectives(session)
	if objective_text.find(String(deadline_objective.get("label", ""))) < 0:
		_fail("Scenario %s deadline label is not visible in objective text: %s" % [scenario_id, objective_text])
		return {}
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return {
		"scenario_id": scenario_id,
		"deadline_objective_id": String(deadline_objective.get("id", "")),
		"deadline_label": String(deadline_objective.get("label", "")),
		"day": day,
		"pre_deadline_status": String(before_result.get("status", "")),
		"deadline_status": String(deadline_result.get("status", "")),
		"campaign_available": bool(availability.get("campaign", false)),
		"skirmish_available": bool(availability.get("skirmish", false)),
	}

func _deadline_objective(scenario: Dictionary) -> Dictionary:
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var defeat: Array = objectives.get("defeat", []) if objectives.get("defeat", []) is Array else []
	for objective in defeat:
		if objective is Dictionary and String(objective.get("type", "")) == "day_at_least":
			return objective
	return {}

func _river_pass_pressure_boundary() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS_SCENARIO_ID)
	if scenario.is_empty():
		_fail("River Pass pressure boundary scenario is missing.")
		return {}
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var defeat: Array = objectives.get("defeat", []) if objectives.get("defeat", []) is Array else []
	var pressure_objective := {}
	for objective in defeat:
		if objective is Dictionary and String(objective.get("id", "")) == "contain_pressure":
			pressure_objective = objective
			break
	if pressure_objective.is_empty() or String(pressure_objective.get("type", "")) != "enemy_pressure_at_least":
		_fail("River Pass contain_pressure is missing its enemy-pressure objective.")
		return {}
	if String(pressure_objective.get("faction_id", "")) != RIVER_PASS_PRESSURE_FACTION_ID or int(pressure_objective.get("threshold", 0)) != RIVER_PASS_DEFEAT_PRESSURE or String(pressure_objective.get("label", "")) != "Do not let Mireclaw pressure reach 15":
		_fail("River Pass pressure objective does not expose the exact 15-pressure contract: %s" % JSON.stringify(pressure_objective))
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		RIVER_PASS_SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if session == null or session.scenario_id != RIVER_PASS_SCENARIO_ID:
		_fail("River Pass pressure boundary did not boot a live campaign session.")
		return {}
	ScenarioRulesScript.normalize_scenario_state(session)
	session.day = 1
	_set_enemy_pressure(session, RIVER_PASS_PRESSURE_FACTION_ID, RIVER_PASS_SAFE_PRESSURE)
	var safe_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(safe_result.get("status", "")) != "in_progress" or session.scenario_status != "in_progress":
		_fail("River Pass resolved before the exact 15-pressure boundary: %s" % JSON.stringify(safe_result))
		return {}
	var safe_objective_text := ScenarioRulesScript.describe_objectives(session)
	if safe_objective_text.find("Do not let Mireclaw pressure reach 15 (14/15)") < 0:
		_fail("River Pass pressure 14/15 is not visible in objective text: %s" % safe_objective_text)
		return {}
	_set_enemy_pressure(session, RIVER_PASS_PRESSURE_FACTION_ID, RIVER_PASS_DEFEAT_PRESSURE)
	var defeat_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(defeat_result.get("status", "")) != "defeat" or session.scenario_status != "defeat":
		_fail("River Pass did not resolve at the exact 15-pressure boundary: %s" % JSON.stringify(defeat_result))
		return {}
	return {
		"scenario_id": RIVER_PASS_SCENARIO_ID,
		"objective_id": "contain_pressure",
		"label": String(pressure_objective.get("label", "")),
		"threshold": int(pressure_objective.get("threshold", 0)),
		"safe_pressure": RIVER_PASS_SAFE_PRESSURE,
		"safe_status": String(safe_result.get("status", "")),
		"defeat_pressure": RIVER_PASS_DEFEAT_PRESSURE,
		"defeat_status": String(defeat_result.get("status", "")),
		"day_deadline": int(_deadline_objective(scenario).get("day", 0)),
	}

func _river_pass_refit_reinforcement_contract() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS_SCENARIO_ID)
	var relief_recruits := _hook_town_recruits(scenario, "riverwatch_relief_column", "riverwatch_hold")
	var recall_recruits := _hook_town_recruits(scenario, "riverwatch_bell_recall", "riverwatch_hold")
	var relief_exact := (
		relief_recruits.size() == 1
		and int(relief_recruits.get("unit_river_guard", -1)) == RIVER_PASS_RELIEF_RIVER_GUARDS
	)
	var recall_exact := (
		recall_recruits.size() == 2
		and int(recall_recruits.get("unit_river_guard", -1)) == RIVER_PASS_RECALL_RIVER_GUARDS
		and int(recall_recruits.get("unit_ember_archer", -1)) == RIVER_PASS_RECALL_EMBER_ARCHERS
	)
	if not relief_exact or not recall_exact:
		_fail("River Pass refit reinforcement does not expose the exact relief and recall shield: %s" % JSON.stringify({
			"relief": relief_recruits,
			"recall": recall_recruits,
		}))
		return {}
	return {
		"relief_hook_id": "riverwatch_relief_column",
		"relief_recruits": relief_recruits,
		"recall_hook_id": "riverwatch_bell_recall",
		"recall_recruits": recall_recruits,
		"post_totemist_screen_army": {
			"unit_river_guard": 34,
			"unit_ember_archer": 8,
		},
	}

func _river_pass_objective_chain() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS_SCENARIO_ID)
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var victory: Array = objectives.get("victory", []) if objectives.get("victory", []) is Array else []
	var clear_blackbranch := _objective_by_id(victory, "clear_blackbranch")
	var repulse_counterstroke := _objective_by_id(victory, "repulse_duskfen_counterstroke")
	if clear_blackbranch != {
		"id": "clear_blackbranch",
		"label": "Break the Blackbranch raiders",
		"type": "encounter_resolved",
		"placement_id": "river_pass_ghoul_grove",
	}:
		_fail("River Pass Blackbranch objective must follow the cleared authored Ghoul Grove placement: %s" % JSON.stringify(clear_blackbranch))
		return {}
	if repulse_counterstroke != {
		"id": "repulse_duskfen_counterstroke",
		"label": "Repulse the Duskfen counterstroke",
		"type": "encounter_resolved",
		"placement_id": "duskfen_counterstroke",
	}:
		_fail("River Pass counterstroke must remain a required resolved encounter: %s" % JSON.stringify(repulse_counterstroke))
		return {}
	var north_road_hook := _hook_by_id(scenario, "north_road_salvage")
	var north_road_effects: Array = north_road_hook.get("effects", []) if north_road_hook.get("effects", []) is Array else []
	if north_road_effects.is_empty() or north_road_effects[0] != {"type": "set_flag", "flag": "pass_cleared", "value": true}:
		_fail("River Pass north-road hook must export pass_cleared after the resolved Ghoul Grove objective: %s" % JSON.stringify(north_road_hook))
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		RIVER_PASS_SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if session == null:
		_fail("River Pass objective-chain proof could not create a live session.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	resolved.append("river_pass_ghoul_grove")
	session.overworld["resolved_encounters"] = resolved
	var blackbranch_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(blackbranch_result.get("status", "")) != "in_progress" or not bool(session.flags.get("pass_cleared", false)):
		_fail("Resolved Ghoul Grove did not clear Blackbranch and export the campaign carryover flag: %s" % JSON.stringify(blackbranch_result))
		return {}
	_set_town_owner(session, "duskfen_bastion", "player")
	session.flags["mire_cleared"] = true
	resolved = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	resolved.append("river_pass_reed_totemists")
	session.overworld["resolved_encounters"] = resolved
	var counterstroke_pending_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(counterstroke_pending_result.get("status", "")) != "in_progress" or not _encounter_exists(session, "duskfen_counterstroke"):
		_fail("River Pass resolved before its authored Duskfen counterstroke became a live required encounter: %s" % JSON.stringify(counterstroke_pending_result))
		return {}
	resolved = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	resolved.append("duskfen_counterstroke")
	session.overworld["resolved_encounters"] = resolved
	var counterstroke_cleared_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(counterstroke_cleared_result.get("status", "")) != "victory" or session.scenario_status != "victory":
		_fail("River Pass did not resolve only after the authored Duskfen counterstroke cleared: %s" % JSON.stringify(counterstroke_cleared_result))
		return {}
	return {
		"victory_objective_count": victory.size(),
		"blackbranch_placement_id": String(clear_blackbranch.get("placement_id", "")),
		"pass_cleared_exported": bool(session.flags.get("pass_cleared", false)),
		"counterstroke_placement_id": String(repulse_counterstroke.get("placement_id", "")),
		"pending_status": String(counterstroke_pending_result.get("status", "")),
		"cleared_status": String(counterstroke_cleared_result.get("status", "")),
	}

func _causeway_veteran_staging_contract() -> Dictionary:
	var scenario := ContentService.get_scenario(CAUSEWAY_SCENARIO_ID)
	var veteran_recruits := _hook_town_recruits(scenario, "veteran_supply_train", "duskfen_staging")
	var veteran_garrison := _hook_town_garrison(scenario, "veteran_supply_train", "duskfen_staging")
	if veteran_recruits.size() != 1 or int(veteran_recruits.get("unit_river_guard", -1)) != CAUSEWAY_VETERAN_RIVER_GUARDS:
		_fail("Causeway veteran supply train must expose only the exact ten-Guard field reinforcement: %s" % JSON.stringify(veteran_recruits))
		return {}
	if veteran_garrison.size() != 1 or int(veteran_garrison.get("unit_river_guard", -1)) != CAUSEWAY_VETERAN_GARRISON_RIVER_GUARDS:
		_fail("Causeway veteran supply train must expose only the exact 32-Guard staging reinforcement: %s" % JSON.stringify(veteran_garrison))
		return {}
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		CAUSEWAY_SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if session == null:
		_fail("Causeway staging-defense proof could not create a live campaign session.")
		return {}
	var duskfen_before := _town_by_placement(session, "duskfen_staging")
	var garrison_before: Array = duskfen_before.get("garrison", []) if duskfen_before.get("garrison", []) is Array else []
	if (
		garrison_before.size() != 1
		or not (garrison_before[0] is Dictionary)
		or String(garrison_before[0].get("unit_id", "")) != "unit_bog_brute"
		or int(garrison_before[0].get("count", 0)) != CAUSEWAY_DUSKFEN_GARRISON_BOG_BRUTES
	):
		_fail("Causeway must retain the exact authored five-Bog-Brute Duskfen base defense: %s" % JSON.stringify(garrison_before))
		return {}
	session.flags["carryover_pass_cleared"] = true
	var hook_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var duskfen_after := _town_by_placement(session, "duskfen_staging")
	var garrison_after: Array = duskfen_after.get("garrison", []) if duskfen_after.get("garrison", []) is Array else []
	if (
		String(hook_result.get("status", "")) != "in_progress"
		or garrison_after != [
			{"unit_id": "unit_bog_brute", "count": CAUSEWAY_DUSKFEN_GARRISON_BOG_BRUTES},
			{"unit_id": "unit_river_guard", "count": CAUSEWAY_VETERAN_GARRISON_RIVER_GUARDS},
		]
	):
		_fail("Causeway veteran hook did not reinforce the unchanged Duskfen base garrison through live scenario rules: %s" % JSON.stringify({"result": hook_result, "garrison": garrison_after}))
		return {}
	return {
		"scenario_id": CAUSEWAY_SCENARIO_ID,
		"hook_id": "veteran_supply_train",
		"field_recruits": veteran_recruits,
		"staging_reinforcement": veteran_garrison,
		"staging_placement_id": "duskfen_staging",
		"base_staging_garrison": garrison_before.duplicate(true),
		"reinforced_staging_garrison": garrison_after.duplicate(true),
		"screened_totemist_entry": {"unit_river_guard": 20},
		"screened_totemist_survivors": {"unit_river_guard": 17},
	}

func _fen_crown_final_march_reserve_contract() -> Dictionary:
	var scenario := ContentService.get_scenario(FEN_CROWN_SCENARIO_ID)
	var hook := _hook_by_id(scenario, "crown_archive_falls")
	var reserve_recruits := _hook_town_recruits(scenario, "crown_archive_falls", "blackfen_bridgehead")
	if hook.get("conditions", []) != [
		{"type": "objective_met", "objective_id": "break_crown_watch"},
	]:
		_fail("Fen Crown final-march reserve must remain gated by the authored Crown Watch objective: %s" % JSON.stringify(hook.get("conditions", [])))
		return {}
	if reserve_recruits.size() != 1 or int(reserve_recruits.get("unit_river_guard", -1)) != FEN_CROWN_FINAL_MARCH_RIVER_GUARDS:
		_fail("Fen Crown Crown Watch hook must expose only the exact screened 14-Guard final-march reserve: %s" % JSON.stringify(reserve_recruits))
		return {}
	return {
		"scenario_id": FEN_CROWN_SCENARIO_ID,
		"hook_id": "crown_archive_falls",
		"objective_id": "break_crown_watch",
		"recruitment_placement_id": "blackfen_bridgehead",
		"reserve_recruits": reserve_recruits,
		"observed_zero_reserve_result": "defeat",
		"first_observed_victory_reserve": 13,
		"first_all_victory_screened_reserve": FEN_CROWN_FINAL_MARCH_RIVER_GUARDS,
		"screen_sample_count": 34,
	}

func _objective_by_id(objectives: Array, objective_id: String) -> Dictionary:
	for objective in objectives:
		if objective is Dictionary and String(objective.get("id", "")) == objective_id:
			return objective.duplicate(true)
	return {}

func _town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town.duplicate(true)
	return {}

func _hook_by_id(scenario: Dictionary, hook_id: String) -> Dictionary:
	for hook in scenario.get("script_hooks", []):
		if hook is Dictionary and String(hook.get("id", "")) == hook_id:
			return hook.duplicate(true)
	return {}

func _set_town_owner(session: SessionStateStoreScript.SessionData, placement_id: String, owner: String) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			session.overworld["towns"] = towns
			return
	_fail("River Pass objective-chain proof could not find town %s." % placement_id)

func _encounter_exists(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return true
	return false

func _hook_town_recruits(scenario: Dictionary, hook_id: String, placement_id: String) -> Dictionary:
	for hook in scenario.get("script_hooks", []):
		if not (hook is Dictionary) or String(hook.get("id", "")) != hook_id:
			continue
		for effect in hook.get("effects", []):
			if (
				effect is Dictionary
				and String(effect.get("type", "")) == "town_add_recruits"
				and String(effect.get("placement_id", "")) == placement_id
				and effect.get("recruits", {}) is Dictionary
			):
				return effect.get("recruits", {}).duplicate(true)
	return {}

func _hook_town_garrison(scenario: Dictionary, hook_id: String, placement_id: String) -> Dictionary:
	for hook in scenario.get("script_hooks", []):
		if not (hook is Dictionary) or String(hook.get("id", "")) != hook_id:
			continue
		for effect in hook.get("effects", []):
			if (
				effect is Dictionary
				and String(effect.get("type", "")) == "town_add_garrison"
				and String(effect.get("placement_id", "")) == placement_id
				and effect.get("garrison", {}) is Dictionary
			):
				return effect.get("garrison", {}).duplicate(true)
	return {}

func _set_enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String, pressure: int) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			state["pressure"] = pressure
			states[index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("River Pass is missing the Mireclaw enemy-pressure state.")

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
