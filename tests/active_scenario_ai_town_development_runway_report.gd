extends Node

const REPORT_SCHEMA := "active_scenario_ai_town_development_runway_report_v1"
const TARGET_TURNS := 30
const LIVE_STOCKPILE_RESOURCE_IDS := [
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
	var only_scenario := OS.get_environment("ACTIVE_SCENARIO_AI_TOWN_RUNWAY_ONLY")
	var scenario_count := 0
	var town_case_count := 0
	var completed_case_count := 0
	var rare_spend_case_count := 0
	var same_day_guard_case_count := 0
	var full_session_case_count := 0
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		if only_scenario != "" and String(scenario_id) != only_scenario:
			continue
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for authored_town in _enemy_towns(scenario):
			var row := _run_enemy_town_case(String(scenario_id), scenario, authored_town)
			rows.append(row)
			town_case_count += 1
			if bool(row.get("completed", false)):
				completed_case_count += 1
			if bool(row.get("rare_spend_observed", false)):
				rare_spend_case_count += 1
			if bool(row.get("same_day_second_build_blocked", false)):
				same_day_guard_case_count += 1
			if bool(row.get("full_session_used", false)):
				full_session_case_count += 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					String(scenario_id),
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown AI runway failure")),
				])
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"target_turns": TARGET_TURNS,
		"active_scenario_count": scenario_count,
		"enemy_town_case_count": town_case_count,
		"completed_case_count": completed_case_count,
		"rare_spend_case_count": rare_spend_case_count,
		"same_day_guard_case_count": same_day_guard_case_count,
		"full_session_case_count": full_session_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"The report boots active authored scenarios and secures scenario-authored economy sources for the target enemy town faction.",
			"Construction now runs inside the full scenario session state with authored map, resource nodes, encounters, and enemy states preserved.",
			"Construction runs through EnemyTurnRules.run_enemy_town_economy_turn and EnemyTurnRules.town_governor_pressure_report for the target faction.",
			"This is AI town-development economy runway evidence, not final strategic AI quality, route safety, encounter pacing, or campaign balance approval.",
		],
	}
	print("ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_enemy_town_case(scenario_id: String, scenario: Dictionary, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction_id := String(authored_town.get("controlling_faction_id", town_template.get("faction_id", "")))
	if faction_id == "":
		faction_id = String(town_template.get("faction_id", ""))
	var config := _enemy_config_for_faction(scenario, faction_id)
	var faction := ContentService.get_faction(faction_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": faction_id,
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"required_resource_ids": required_resource_ids,
		"rare_resource_id": String(profile.get("rare_resource_id", "")),
	}
	if town_template.is_empty():
		base_row["error"] = "missing town template"
		return base_row
	if faction.is_empty():
		base_row["error"] = "missing faction template"
		return base_row
	if config.is_empty():
		base_row["error"] = "missing enemy faction config"
		return base_row
	if target_buildings.is_empty():
		base_row["error"] = "town has no buildable development target"
		return base_row
	if String(profile.get("rare_resource_id", "")) not in RARE_RESOURCE_IDS:
		base_row["error"] = "town development_balance missing live rare_resource_id"
		return base_row

	var source_session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if source_session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(source_session)
	var source_evidence := _secure_development_sources(source_session, faction_id, required_resource_ids)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing enemy town placement"
		base_row["source_evidence"] = source_evidence
		return base_row
	var session = source_session
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	_seed_enemy_treasury(session, faction_id, source_evidence.get("resources_after_claims", {}))
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_second_build_blocked := false
	var rare_treasury_tracked := _enemy_treasury_has_all_live_keys(session, faction_id)
	var governor_report := EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
	var governor_report_seen := int(governor_report.get("town_count", 0)) > 0

	for _turn in range(target_turns):
		var before_state := _enemy_state(session, faction_id)
		var before_treasury := _resources(before_state.get("treasury", {}))
		var expected_income := _enemy_daily_income(session, placement_id, faction_id)
		var before_built := _town_building_ids(_town(session, placement_id))
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(session, faction_id)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "enemy_turn_failed",
				"message": String(turn_result.get("message", "")),
			})
		var after_state := _enemy_state(session, faction_id)
		var after_treasury := _resources(after_state.get("treasury", {}))
		var after_built := _town_building_ids(_town(session, placement_id))
		var built_today := _new_buildings(before_built, after_built)
		for building_id in built_today:
			var building := ContentService.get_building(String(building_id))
			var rare_cost := _rare_cost(building.get("cost", {}))
			if not rare_cost.is_empty():
				rare_spend_events.append({
					"day": int(session.day),
					"building_id": String(building_id),
					"spent": rare_cost,
					"treasury_before": before_treasury,
					"expected_income": expected_income,
					"treasury_after": after_treasury,
				})
			build_log.append({
				"day": int(session.day),
				"building_id": String(building_id),
				"cost": building.get("cost", {}),
				"treasury_before": before_treasury,
				"expected_income": expected_income,
				"treasury_after": after_treasury,
			})
		if not built_today.is_empty() and not same_day_second_build_blocked:
			var second_session = _clone_session(session)
			var built_count_before_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(second_session, faction_id)
			var built_count_after_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_events: Array = second_result.get("events", []) if second_result.get("events", []) is Array else []
			same_day_second_build_blocked = (
				built_count_after_second == built_count_before_second
				and _target_town_event_count(second_events, "ai_town_built", placement_id) == 0
			)
		if _missing_buildings(session, placement_id, target_buildings).is_empty():
			break
		if built_today.is_empty():
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_enemy_build_selected",
				"treasury": after_treasury,
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		session.day += 1

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	base_row["ok"] = (
		completed
		and same_day_second_build_blocked
		and not rare_spend_events.is_empty()
		and rare_treasury_tracked
		and governor_report_seen
		and String(session.scenario_id) == scenario_id
		and _source_covers_required_resources(source_evidence, required_resource_ids)
	)
	base_row["completed"] = completed
	base_row["completion_day"] = int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0
	base_row["build_count"] = build_log.size()
	base_row["missing_buildings"] = missing
	base_row["same_day_second_build_blocked"] = same_day_second_build_blocked
	base_row["rare_treasury_tracked"] = rare_treasury_tracked
	base_row["governor_report_seen"] = governor_report_seen
	base_row["rare_spend_observed"] = not rare_spend_events.is_empty()
	base_row["rare_spend_events"] = rare_spend_events
	base_row["source_evidence"] = source_evidence
	base_row["full_session_used"] = String(session.scenario_id) == scenario_id
	base_row["scenario_map_size"] = _map_size_payload(OverworldRules.derive_map_size(session))
	base_row["scenario_resource_node_count"] = _array_size(session.overworld.get("resource_nodes", []))
	base_row["scenario_encounter_count"] = _array_size(session.overworld.get("encounters", []))
	base_row["scenario_enemy_state_count"] = _array_size(session.overworld.get("enemy_states", []))
	base_row["ending_treasury"] = _resources(_enemy_state(session, faction_id).get("treasury", {}))
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	base_row["build_log"] = build_log
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _runway_error(base_row)
	return base_row

func _clone_session(session):
	var clone = SessionStateStore.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone

func _seed_enemy_treasury(session, faction_id: String, resources: Dictionary) -> void:
	EnemyTurnRules.normalize_enemy_states(session)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if not (states[index] is Dictionary):
			continue
		var state: Dictionary = states[index]
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["treasury"] = _add_resource_sets(_resources(state.get("treasury", {})), _resources(resources))
		states[index] = state
		break
	session.overworld["enemy_states"] = states

func _secure_development_sources(session, faction_id: String, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var treasury := _blank_resources()
	var source_rows := []
	var secured_nodes := []
	var secured_resource_ids := {}
	var secured_income := {}
	var secured_claims := {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node: Dictionary = nodes[index]
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		if relevant_claims.is_empty() and relevant_income.is_empty():
			continue
		if bool(site.get("persistent_control", false)):
			node["collected_by_faction_id"] = faction_id
		if not relevant_claims.is_empty():
			treasury = _add_resource_sets(treasury, relevant_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
			node["collected_by_faction_id"] = faction_id
			secured_claims = _add_resource_sets(secured_claims, relevant_claims)
		if not relevant_income.is_empty() and bool(site.get("persistent_control", false)):
			secured_income = _add_resource_sets(secured_income, relevant_income)
		for resource_id in relevant_claims.keys():
			secured_resource_ids[String(resource_id)] = true
		for resource_id in relevant_income.keys():
			secured_resource_ids[String(resource_id)] = true
		source_rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"persistent_control": bool(site.get("persistent_control", false)),
			"claim_rewards": relevant_claims,
			"control_income": relevant_income,
		})
		secured_nodes.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"collected": bool(node.get("collected", false)),
			"collected_day": int(node.get("collected_day", 0)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
		})
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes
	return {
		"secured_source_count": source_rows.size(),
		"secured_resource_ids": _sorted_keys(secured_resource_ids),
		"secured_claims": secured_claims,
		"secured_daily_income": secured_income,
		"resources_after_claims": treasury,
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _enemy_daily_income(session, placement_id: String, faction_id: String) -> Dictionary:
	var income := _blank_resources()
	var town := _town(session, placement_id)
	if not town.is_empty():
		income = _add_resource_sets(income, OverworldRules.town_income(town, session))
	income = _add_resource_sets(income, OverworldRules.controlled_resource_site_income(session, faction_id))
	return income

func _runway_error(row: Dictionary) -> String:
	if not bool(row.get("completed", false)):
		return "enemy town did not complete its active-scenario AI development runway"
	if not bool(row.get("same_day_second_build_blocked", false)):
		return "enemy same-day second build was not blocked"
	if not bool(row.get("rare_spend_observed", false)):
		return "enemy high-tier rare-resource spend was not observed"
	if not bool(row.get("rare_treasury_tracked", false)):
		return "enemy treasury did not preserve all live stockpile resource keys"
	if not bool(row.get("governor_report_seen", false)):
		return "enemy town governor report did not cover the target faction"
	if not bool(row.get("full_session_used", false)):
		return "enemy development did not run inside the active scenario session"
	if not _source_covers_required_resources(row.get("source_evidence", {}), row.get("required_resource_ids", [])):
		return "secured scenario sources did not cover required enemy build resources"
	return "unknown AI runway failure"

func _source_covers_required_resources(source_evidence: Dictionary, required_resource_ids: Array) -> bool:
	var secured := _string_array(source_evidence.get("secured_resource_ids", []))
	for resource_id in required_resource_ids:
		if String(resource_id) in ["gold"]:
			continue
		if String(resource_id) not in secured:
			return false
	return true

func _enemy_treasury_has_all_live_keys(session, faction_id: String) -> bool:
	var treasury: Dictionary = _enemy_state(session, faction_id).get("treasury", {})
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		if String(resource_id) not in treasury:
			return false
	return true

func _open_building_ids(town: Dictionary, target_buildings: Array) -> Array:
	var result := []
	for building_id in target_buildings:
		if bool(OverworldRules.get_town_build_status(town, String(building_id)).get("buildable", false)):
			result.append(String(building_id))
	return result

func _missing_buildings(session, placement_id: String, target_buildings: Array) -> Array:
	var town := _town(session, placement_id)
	var built := _string_array(town.get("built_buildings", []))
	var missing := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			missing.append(String(building_id))
	return missing

func _new_buildings(before: Array, after: Array) -> Array:
	var result := []
	for building_id in after:
		if String(building_id) not in before:
			result.append(String(building_id))
	return result

func _town_building_ids(town: Dictionary) -> Array:
	return _string_array(town.get("built_buildings", []))

func _target_town_event_count(events: Array, event_type: String, town_placement_id: String) -> int:
	var count := 0
	for event in events:
		if (
			event is Dictionary
			and String(event.get("event_type", "")) == event_type
			and String(event.get("actor_id", "")) == town_placement_id
		):
			count += 1
	return count

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _required_build_resource_ids(target_buildings: Array) -> Array:
	var ids := {}
	for building_id in target_buildings:
		var building := ContentService.get_building(String(building_id))
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		for resource_id in cost.keys():
			var id := String(resource_id)
			if id in LIVE_STOCKPILE_RESOURCE_IDS:
				ids[id] = true
	return _sorted_keys(ids)

func _rare_cost(cost_value: Variant) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var result := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) > 0:
			result[resource_id] = int(cost.get(resource_id, 0))
	return result

func _filter_resources(resources: Dictionary, allowed: Array) -> Dictionary:
	var result := {}
	for resource_id in resources.keys():
		var id := String(resource_id)
		if id in allowed and int(resources.get(resource_id, 0)) > 0:
			result[id] = int(resources.get(resource_id, 0))
	return result

func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := _resources(left)
	for resource_id in right.keys():
		var id := String(resource_id)
		result[id] = int(result.get(id, 0)) + int(right.get(resource_id, 0))
	return result

func _resources(resources: Variant) -> Dictionary:
	var result := {}
	var source: Dictionary = resources if resources is Dictionary else {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(source.get(String(resource_id), 0))
	return result

func _blank_resources() -> Dictionary:
	return _resources({})

func _array_size(value: Variant) -> int:
	return value.size() if value is Array else 0

func _map_size_payload(size: Vector2i) -> Dictionary:
	return {"width": size.x, "height": size.y}

func _is_active_authored_scenario(scenario: Dictionary) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false))

func _enemy_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			result.append(town)
	return result

func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

func _string_array(values: Variant) -> Array:
	var result := []
	if not (values is Array):
		return result
	for value in values:
		result.append(String(value))
	return result

func _sorted_keys(values: Dictionary) -> Array:
	var keys := []
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys
