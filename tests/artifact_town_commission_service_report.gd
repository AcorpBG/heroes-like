extends Node

const REPORT_ID := "ARTIFACT_TOWN_COMMISSION_SERVICE_REPORT"
const TABLE_ID := "artifact_source_town_landmark_services"
const SAVE_SLOT := 3
const CASES := [
	{
		"scenario_id": "river-pass",
		"placement_id": "riverwatch_hold",
		"faction_id": "faction_embercourt",
		"building_id": "building_embercourt_lockhouse_tally",
		"artifact_id": "artifact_tollstone_ring",
		"cost": {"gold": 1200, "wood": 1},
	},
	{
		"scenario_id": "orevein-contract",
		"placement_id": "orevein_gantry",
		"faction_id": "faction_brasshollow",
		"building_id": "building_brasshollow_scalehouse",
		"artifact_id": "artifact_pressure_gauge_reliquary",
		"cost": {"gold": 1400, "ore": 2},
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	for case_value in CASES:
		var result := _eligible_case(case_value, cases.is_empty())
		if result.is_empty():
			return
		cases.append(result)
	var insufficient := _insufficient_resource_case()
	if insufficient.is_empty():
		return
	var ineligible := _ineligible_faction_case()
	if ineligible.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"cases": cases,
		"insufficient_resource_case": insufficient,
		"ineligible_faction_case": ineligible,
		"save_version": SessionStateStore.SAVE_VERSION,
		"runtime_policy": {
			"player_town_service_live": true,
			"one_time_per_town": true,
			"common_resource_costs": true,
			"auto_equip": true,
			"ai_valuation_behavior": false,
			"rare_resource_activation": false,
			"save_version_bump": false,
		},
	})])
	get_tree().quit(0)

func _eligible_case(case_data: Dictionary, test_save_resume: bool) -> Dictionary:
	var session = _session(String(case_data.get("scenario_id", "")), String(case_data.get("placement_id", "")))
	var building_id := String(case_data.get("building_id", ""))
	var artifact_id := String(case_data.get("artifact_id", ""))
	if not _commission_action(session, building_id).is_empty():
		_fail("Unbuilt town service exposed a commission action for %s." % building_id)
		return {}
	var build_result: Dictionary = TownRules.build_active_town(session, building_id)
	if not bool(build_result.get("ok", false)):
		_fail("Could not build %s: %s" % [building_id, JSON.stringify(build_result)])
		return {}
	var action := _commission_action(session, building_id)
	if action.is_empty() or bool(action.get("disabled", true)) \
			or String(action.get("artifact_id", "")) != artifact_id \
			or String(action.get("artifact_reward_table_id", "")) != TABLE_ID \
			or not _cost_matches(action.get("cost", {}), case_data.get("cost", {})):
		_fail("Built town service did not expose its authored commission: %s" % JSON.stringify(action))
		return {}
	var resources_before := _resources(session)
	var result: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:%s" % building_id)
	if not bool(result.get("ok", false)) or String(result.get("artifact_id", "")) != artifact_id:
		_fail("Town artifact commission failed: %s" % JSON.stringify(result))
		return {}
	if not _cost_spent_exactly(resources_before, _resources(session), case_data.get("cost", {})):
		_fail("Town artifact commission did not spend the exact authored cost.")
		return {}
	var hero: Dictionary = session.overworld.get("hero", {})
	if artifact_id not in ArtifactRules.owned_artifact_ids(hero) or not _artifact_equipped(hero, artifact_id):
		_fail("Commissioned artifact was not owned and auto-equipped: %s" % JSON.stringify(hero.get("artifacts", {})))
		return {}
	var town := _town(session, String(case_data.get("placement_id", "")))
	if not _provenance_matches(town, case_data):
		_fail("Town commission provenance is incomplete: %s" % JSON.stringify(town))
		return {}
	if not _commission_action(session, building_id).is_empty():
		_fail("Completed town service still exposed a commission action.")
		return {}
	var resources_after := _resources(session)
	var repeat: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:%s" % building_id)
	if bool(repeat.get("ok", false)) or _resources(session) != resources_after:
		_fail("Repeated town commission was not blocked without charge: %s" % JSON.stringify(repeat))
		return {}
	var save_resume_preserved := false
	if test_save_resume:
		var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
		var restored = SaveService.restore_manual_session(SAVE_SLOT)
		if not bool(save_result.get("ok", false)) or restored == null:
			_fail("Town commission did not save and restore: %s" % JSON.stringify(save_result))
			return {}
		OverworldRules.normalize_overworld_state(restored)
		_set_active_town(restored, String(case_data.get("placement_id", "")))
		var restored_town := _town(restored, String(case_data.get("placement_id", "")))
		var restored_hero: Dictionary = restored.overworld.get("hero", {})
		save_resume_preserved = (
			int(restored.save_version) == int(SessionStateStore.SAVE_VERSION)
			and _provenance_matches(restored_town, case_data)
			and artifact_id in ArtifactRules.owned_artifact_ids(restored_hero)
			and _artifact_equipped(restored_hero, artifact_id)
			and _resources(restored) == resources_after
			and _commission_action(restored, building_id).is_empty()
		)
		if not save_resume_preserved:
			_fail("Town artifact commission state changed across save/resume.")
			return {}
	return {
		"scenario_id": String(case_data.get("scenario_id", "")),
		"building_id": building_id,
		"artifact_id": artifact_id,
		"table_id": TABLE_ID,
		"cost": case_data.get("cost", {}).duplicate(true),
		"auto_equipped": true,
		"one_time_blocked": true,
		"provenance_persisted": true,
		"save_resume_preserved": save_resume_preserved,
	}

func _insufficient_resource_case() -> Dictionary:
	var case_data: Dictionary = CASES[0]
	var session = _session(String(case_data.get("scenario_id", "")), String(case_data.get("placement_id", "")))
	var building_id := String(case_data.get("building_id", ""))
	var build_result: Dictionary = TownRules.build_active_town(session, building_id)
	if not bool(build_result.get("ok", false)):
		_fail("Insufficient-resource fixture could not build its service.")
		return {}
	var resources := _resources(session)
	resources["gold"] = 0
	resources["wood"] = 0
	session.overworld["resources"] = resources
	var action := _commission_action(session, building_id)
	var before := _resources(session)
	var result: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:%s" % building_id)
	if action.is_empty() or not bool(action.get("disabled", false)) \
			or bool(result.get("ok", false)) or _resources(session) != before \
			or String(_town(session, String(case_data.get("placement_id", ""))).get("artifact_reward_id", "")) != "":
		_fail("Unaffordable commission was not disabled and rejected without mutation: %s" % JSON.stringify(result))
		return {}
	return {"action_disabled": true, "direct_call_rejected": true, "no_charge": true, "no_reward": true}

func _ineligible_faction_case() -> Dictionary:
	var session = _session("mireford-skirmish", "graftroot_bridgehead")
	var towns: Array = session.overworld.get("towns", [])
	var town := _town(session, "graftroot_bridgehead").duplicate(true)
	var built: Array = town.get("built_buildings", []).duplicate(true)
	built.append("building_embercourt_lockhouse_tally")
	town["built_buildings"] = built
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == "graftroot_bridgehead":
			towns[index] = town
			break
	session.overworld["towns"] = towns
	OverworldRules.normalize_overworld_state(session)
	_set_active_town(session, "graftroot_bridgehead")
	var before := _resources(session)
	var action := _commission_action(session, "building_embercourt_lockhouse_tally")
	var result: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:building_embercourt_lockhouse_tally")
	if not action.is_empty() or bool(result.get("ok", false)) or _resources(session) != before:
		_fail("Thornwake town crossed the Embercourt town-table faction boundary: %s" % JSON.stringify(result))
		return {}
	return {"faction_id": "faction_thornwake", "action_hidden": true, "direct_call_rejected": true, "no_charge": true}

func _session(scenario_id: String, placement_id: String):
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	var resources := _resources(session)
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		resources[String(key)] = max(5000, int(resources.get(String(key), 0)))
	session.overworld["resources"] = resources
	_set_active_town(session, placement_id)
	return session

func _set_active_town(session, placement_id: String) -> void:
	var result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(result.get("ok", false)):
		_fail("Could not select active town %s: %s" % [placement_id, JSON.stringify(result)])

func _commission_action(session, building_id: String) -> Dictionary:
	for action_value in TownRules.get_artifact_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == "commission_artifact:%s" % building_id:
			return action_value
	return {}

func _town(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _resources(session) -> Dictionary:
	var value = session.overworld.get("resources", {})
	return value.duplicate(true) if value is Dictionary else {}

func _cost_spent_exactly(before: Dictionary, after: Dictionary, cost_value: Variant) -> bool:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(key)
		if int(after.get(resource_id, 0)) != int(before.get(resource_id, 0)) - int(cost.get(resource_id, 0)):
			return false
	return true

func _cost_matches(actual_value: Variant, expected_value: Variant) -> bool:
	var actual: Dictionary = actual_value if actual_value is Dictionary else {}
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(key)
		if int(actual.get(resource_id, 0)) != int(expected.get(resource_id, 0)):
			return false
	return true

func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var artifacts = hero.get("artifacts", {})
	var equipped = artifacts.get("equipped", {}) if artifacts is Dictionary else {}
	return equipped is Dictionary and artifact_id in equipped.values()

func _provenance_matches(town: Dictionary, case_data: Dictionary) -> bool:
	return (
		String(town.get("artifact_reward_id", "")) == String(case_data.get("artifact_id", ""))
		and String(town.get("artifact_reward_table_id", "")) == TABLE_ID
		and String(town.get("artifact_reward_source_key", "")) != ""
		and String(town.get("artifact_reward_claimed_by_owner", "")) == "player"
		and String(town.get("artifact_reward_claimed_by_faction_id", "")) == String(case_data.get("faction_id", ""))
		and int(town.get("artifact_reward_claimed_day", 0)) > 0
		and String(town.get("artifact_reward_service_building_id", "")) == String(case_data.get("building_id", ""))
	)

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "report_id": REPORT_ID, "error": message})])
	get_tree().quit(1)
