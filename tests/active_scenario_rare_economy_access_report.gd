extends Node

const REPORT_SCHEMA := "active_scenario_rare_economy_access_report_v1"
const STOCKPILE_KEYS := [
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
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	var scenario_count := 0
	var rare_counts := {}
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for town in _player_towns(scenario):
			var row := _run_town_case(String(scenario_id), town)
			cases.append(row)
			var rare_id := String(row.get("rare_resource_id", ""))
			if rare_id != "":
				rare_counts[rare_id] = int(rare_counts.get(rare_id, 0)) + 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					scenario_id,
					String(town.get("placement_id", "")),
					String(row.get("error", "unknown error")),
				])
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"active_scenario_count": scenario_count,
		"player_town_case_count": cases.size(),
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"rare_resource_case_counts": rare_counts,
		"cases": cases,
		"errors": _errors,
		"caveats": [
			"Fixture positions the active hero on each selected rare-resource source to verify the live resource capture and income rules deterministically.",
			"This validates active authored scenario economy access; route safety, battle pacing, and final scenario-wide balance remain covered by separate gates.",
			"Rare resources remain authored-source driven and are not bought through normal town markets.",
		],
	}
	print("ACTIVE_SCENARIO_RARE_ECONOMY_ACCESS_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(scenario_id: String, authored_town: Dictionary) -> Dictionary:
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var rare_id := String(profile.get("rare_resource_id", ""))
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": String(authored_town.get("placement_id", "")),
		"town_id": town_id,
		"rare_resource_id": rare_id,
	}
	if town_template.is_empty():
		base_row["error"] = "missing town template"
		return base_row
	if rare_id not in RARE_RESOURCE_IDS:
		base_row["error"] = "town development_balance missing live rare_resource_id"
		return base_row

	var session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)

	var source := _matching_rare_source(session, rare_id)
	if source.is_empty():
		base_row["error"] = "runtime session missing matching rare source"
		base_row["runtime_resource_node_count"] = session.overworld.get("resource_nodes", []).size()
		return base_row

	var placement_id := String(source.get("placement_id", ""))
	var before_claim := _resources(session)
	_move_to_resource(session, placement_id)
	var claim_result: Dictionary = OverworldRules.collect_active_resource(session)
	if not bool(claim_result.get("ok", false)):
		base_row["error"] = "OverworldRules.collect_active_resource failed: %s" % String(claim_result.get("message", ""))
		base_row["resource_placement_id"] = placement_id
		base_row["site_id"] = String(source.get("site_id", ""))
		return base_row

	var after_claim := _resources(session)
	var claim_delta := int(after_claim.get(rare_id, 0)) - int(before_claim.get(rare_id, 0))
	var expected_claim := int(source.get("claim_amount", 0))
	if expected_claim > 0 and claim_delta < expected_claim:
		base_row["error"] = "claim reward did not increase rare resource"
		base_row["expected_claim_amount"] = expected_claim
		base_row["claim_delta"] = claim_delta
		return base_row

	var node_after_claim := _resource_node(session, placement_id)
	var controller_after_claim := String(node_after_claim.get("collected_by_faction_id", ""))
	if controller_after_claim != "player":
		base_row["error"] = "claimed rare site was not controlled by player"
		base_row["controller_after_claim"] = controller_after_claim
		return base_row

	var controlled_income := OverworldRules.controlled_resource_site_income(session, "player")
	var expected_income := int(source.get("income_amount", 0))
	if expected_income > 0 and int(controlled_income.get(rare_id, 0)) < expected_income:
		base_row["error"] = "controlled_resource_site_income missing rare income"
		base_row["expected_income_amount"] = expected_income
		base_row["controlled_income"] = controlled_income
		return base_row

	var turn_result: Dictionary = OverworldRules.end_turn(session)
	if not bool(turn_result.get("ok", false)):
		base_row["error"] = "OverworldRules.end_turn failed: %s" % String(turn_result.get("message", ""))
		return base_row
	var after_income := _resources(session)
	var income_delta := int(after_income.get(rare_id, 0)) - int(after_claim.get(rare_id, 0))
	if expected_income > 0 and income_delta < expected_income:
		base_row["error"] = "next-day income did not increase rare resource"
		base_row["expected_income_amount"] = expected_income
		base_row["income_delta"] = income_delta
		return base_row

	base_row["ok"] = true
	base_row["resource_placement_id"] = placement_id
	base_row["site_id"] = String(source.get("site_id", ""))
	base_row["site_name"] = String(source.get("site_name", ""))
	base_row["claim_rewards"] = source.get("claim_rewards", {})
	base_row["control_income"] = source.get("control_income", {})
	base_row["resources_before_claim"] = before_claim
	base_row["resources_after_claim"] = after_claim
	base_row["resources_after_income"] = after_income
	base_row["claim_delta"] = claim_delta
	base_row["income_delta"] = income_delta
	base_row["controlled_income_after_claim"] = controlled_income
	base_row["claim_message"] = String(claim_result.get("message", ""))
	base_row["turn_message"] = String(turn_result.get("message", ""))
	base_row["resource_income_summary"] = String(turn_result.get("resource_income_summary", ""))
	base_row["day_after_income"] = int(session.day)
	return base_row

func _is_active_authored_scenario(scenario: Dictionary) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false))

func _player_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			result.append(town)
	return result

func _matching_rare_source(session, rare_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site_id := String(node.get("site_id", ""))
		var site := ContentService.get_resource_site(site_id)
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var claim_amount := int(claim_rewards.get(rare_id, 0))
		var income_amount := int(control_income.get(rare_id, 0))
		if claim_amount <= 0 and income_amount <= 0:
			continue
		return {
			"placement_id": String(node.get("placement_id", "")),
			"site_id": site_id,
			"site_name": String(site.get("name", "")),
			"claim_rewards": claim_rewards,
			"control_income": control_income,
			"claim_amount": claim_amount,
			"income_amount": income_amount,
		}
	return {}

func _move_to_resource(session, placement_id: String) -> void:
	var node := _resource_node(session, placement_id)
	_set_hero_position(session, int(node.get("x", 0)), int(node.get("y", 0)))

func _set_hero_position(session, x: int, y: int) -> void:
	session.overworld["hero_position"] = {"x": x, "y": y}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.hero_id):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["position"] = {"x": x, "y": y}
			heroes[index] = roster_hero
			break
	session.overworld["player_heroes"] = heroes

func _resource_node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _resources(session) -> Dictionary:
	var result := {}
	for key in STOCKPILE_KEYS:
		result[String(key)] = int(session.overworld.get("resources", {}).get(String(key), 0))
	return result
