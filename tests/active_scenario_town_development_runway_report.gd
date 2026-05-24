extends Node

const REPORT_SCHEMA := "active_scenario_town_development_runway_report_v1"
const TARGET_TURNS := 30
const HERO_ID := "hero_lyra"
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
const COMMON_MARKET_RESOURCE_IDS := ["wood", "ore"]
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
	var only_scenario := OS.get_environment("ACTIVE_SCENARIO_TOWN_RUNWAY_ONLY")
	var scenario_count := 0
	var town_case_count := 0
	var completed_case_count := 0
	var rare_spend_case_count := 0
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		if only_scenario != "" and String(scenario_id) != only_scenario:
			continue
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for authored_town in _player_towns(scenario):
			var row := _run_town_case(String(scenario_id), authored_town)
			rows.append(row)
			town_case_count += 1
			if bool(row.get("completed", false)):
				completed_case_count += 1
			if bool(row.get("rare_spend_observed", false)):
				rare_spend_case_count += 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					String(scenario_id),
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown runway failure")),
				])
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"target_turns": TARGET_TURNS,
		"active_scenario_count": scenario_count,
		"player_town_case_count": town_case_count,
		"completed_case_count": completed_case_count,
		"rare_spend_case_count": rare_spend_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"common_market_resource_ids": COMMON_MARKET_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"The report boots active authored scenarios and secures authored economy sources to isolate town development runway from route safety and encounter pacing.",
			"Construction still runs through live OverworldRules.build_in_active_town and TownRules.get_build_actions surfaces.",
			"This is active-scenario economy runway evidence, not final scenario-wide route balance or campaign pacing approval.",
		],
	}
	print("ACTIVE_SCENARIO_TOWN_DEVELOPMENT_RUNWAY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(scenario_id: String, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
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
	var source_evidence := _secure_development_sources(source_session, required_resource_ids)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing player town placement"
		base_row["source_evidence"] = source_evidence
		return base_row
	var session = _build_runway_session(scenario_id, source_town, source_session.overworld.get("resources", {}), source_evidence)
	var select_result := _set_active_town(session, placement_id)
	if not bool(select_result.get("ok", false)):
		base_row["error"] = "unable to select player town: %s" % String(select_result.get("message", ""))
		base_row["source_evidence"] = source_evidence
		return base_row

	var signature_order := _signature_order(faction)
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_reject_ok := false
	var build_actions_after_build_blocked := false
	var market_common_only := true

	for _turn in range(target_turns):
		_set_active_town(session, placement_id)
		var selected_id := _select_building_id(session, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_affordable_build_action",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		else:
			var before_resources := _resources(session)
			var selected_building := ContentService.get_building(selected_id)
			var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
			if not bool(build_result.get("ok", false)):
				stalled_days.append({
					"day": int(session.day),
					"reason": "build_failed",
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
				})
			else:
				var after_resources := _resources(session)
				var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
				if not rare_delta.is_empty():
					rare_spend_events.append({
						"day": int(session.day),
						"building_id": selected_id,
						"spent": rare_delta,
					})
				var same_day_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
				if not bool(same_day_result.get("ok", true)) and String(same_day_result.get("message", "")).contains("already completed a build order today"):
					same_day_reject_ok = true
				build_actions_after_build_blocked = TownRules.get_build_actions(session).is_empty()
				build_log.append({
					"day": int(session.day),
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
					"resources_before": before_resources,
					"resources_after": after_resources,
				})
				market_common_only = market_common_only and _market_actions_common_only(session)
				if _missing_buildings(session, placement_id, target_buildings).is_empty():
					break
		var turn_result: Dictionary = OverworldRules.end_turn(session)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "end_turn_failed",
				"message": String(turn_result.get("message", "")),
			})

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	base_row["ok"] = (
		completed
		and same_day_reject_ok
		and build_actions_after_build_blocked
		and not rare_spend_events.is_empty()
		and market_common_only
		and _source_covers_required_resources(source_evidence, required_resource_ids)
	)
	base_row["completed"] = completed
	base_row["completion_day"] = int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0
	base_row["build_count"] = build_log.size()
	base_row["missing_buildings"] = missing
	base_row["same_day_reject_ok"] = same_day_reject_ok
	base_row["build_actions_after_build_blocked"] = build_actions_after_build_blocked
	base_row["rare_spend_observed"] = not rare_spend_events.is_empty()
	base_row["rare_spend_events"] = rare_spend_events
	base_row["market_common_only"] = market_common_only
	base_row["source_evidence"] = source_evidence
	base_row["ending_resources"] = _resources(session)
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	base_row["build_log"] = build_log
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _runway_error(base_row)
	return base_row

func _build_runway_session(scenario_id: String, source_town: Dictionary, resources: Dictionary, source_evidence: Dictionary):
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": int(source_town.get("x", 0)), "y": int(source_town.get("y", 0))},
		{"id": "active_runway_army", "name": "Active Runway Army", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var town_state := source_town.duplicate(true)
	town_state["owner"] = "player"
	if not (town_state.get("built_buildings", []) is Array):
		var town_template := ContentService.get_town(String(town_state.get("town_id", "")))
		town_state["built_buildings"] = _string_array(town_template.get("starting_building_ids", []))
	if not (town_state.get("available_recruits", {}) is Dictionary):
		town_state["available_recruits"] = {}
	town_state["last_build_day"] = 0
	var overworld := {
		"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": HERO_ID,
		"player_heroes": [hero],
		"hero_position": {"x": int(town_state.get("x", 0)), "y": int(town_state.get("y", 0))},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _normalized_resources(resources),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": source_evidence.get("secured_resource_nodes", []),
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"active_scenario_development_runway_%s_%s" % [scenario_id, String(town_state.get("placement_id", ""))],
		"",
		HERO_ID,
		1,
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	return session

func _secure_development_sources(session, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
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
			node["collected_by_faction_id"] = "player"
		if not relevant_claims.is_empty() and not bool(node.get("collected", false)):
			_add_to_session_resources(session, relevant_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
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
		"resources_after_claims": _resources(session),
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _runway_error(row: Dictionary) -> String:
	if not bool(row.get("completed", false)):
		return "town did not complete its active-scenario development runway"
	if not bool(row.get("same_day_reject_ok", false)):
		return "same-day second build was not rejected"
	if not bool(row.get("build_actions_after_build_blocked", false)):
		return "build action surface did not block after same-day build"
	if not bool(row.get("rare_spend_observed", false)):
		return "high-tier rare-resource spend was not observed"
	if not bool(row.get("market_common_only", false)):
		return "market actions included non-common resources"
	if not _source_covers_required_resources(row.get("source_evidence", {}), row.get("required_resource_ids", [])):
		return "secured scenario sources did not cover required build resources"
	return "unknown runway failure"

func _source_covers_required_resources(source_evidence: Dictionary, required_resource_ids: Array) -> bool:
	var secured := _string_array(source_evidence.get("secured_resource_ids", []))
	for resource_id in required_resource_ids:
		if String(resource_id) in ["gold"]:
			continue
		if String(resource_id) not in secured:
			return false
	return true

func _select_building_id(session, target_buildings: Array, signature_order: Dictionary) -> String:
	var actions := []
	for action_value in TownRules.get_build_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			continue
		var building_id := String(action.get("id", "")).trim_prefix("build:")
		if building_id in target_buildings:
			actions.append(building_id)
	actions.sort_custom(func(a, b): return _build_sort_key(a, target_buildings, signature_order) < _build_sort_key(b, target_buildings, signature_order))
	return String(actions[0]) if not actions.is_empty() else ""

func _build_sort_key(building_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var signature_rank := int(signature_order.get(building_id, 99))
	var target_rank := target_buildings.find(building_id)
	if target_rank < 0:
		target_rank = 999
	return "%03d:%03d:%s" % [signature_rank, target_rank, building_id]

func _signature_order(faction: Dictionary) -> Dictionary:
	var order := {}
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	for index in range(signature_ids.size()):
		order[signature_ids[index]] = index + 1
	return order

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

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _set_active_town(session, placement_id: String) -> Dictionary:
	return OverworldRules.set_active_town_visit(session, placement_id)

func _market_actions_common_only(session) -> bool:
	for action_value in TownRules.get_market_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var resource_id := String(action.get("resource_id", ""))
		if resource_id != "" and resource_id not in COMMON_MARKET_RESOURCE_IDS:
			return false
	return true

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

func _rare_resource_spend(cost_value: Variant, before: Dictionary, after: Dictionary) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var spent := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) <= 0:
			continue
		var delta := int(before.get(resource_id, 0)) - int(after.get(resource_id, 0))
		if delta > 0:
			spent[resource_id] = delta
	return spent

func _filter_resources(resources: Dictionary, allowed: Array) -> Dictionary:
	var result := {}
	for resource_id in resources.keys():
		var id := String(resource_id)
		if id in allowed and int(resources.get(resource_id, 0)) > 0:
			result[id] = int(resources.get(resource_id, 0))
	return result

func _add_to_session_resources(session, resources: Dictionary) -> void:
	var pool: Dictionary = session.overworld.get("resources", {})
	for resource_id in resources.keys():
		var id := String(resource_id)
		pool[id] = int(pool.get(id, 0)) + int(resources.get(resource_id, 0))
	session.overworld["resources"] = pool

func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := left.duplicate(true)
	for resource_id in right.keys():
		var id := String(resource_id)
		result[id] = int(result.get(id, 0)) + int(right.get(resource_id, 0))
	return result

func _resources(session) -> Dictionary:
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(session.overworld.get("resources", {}).get(String(resource_id), 0))
	return result

func _normalized_resources(resources: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(resources.get(String(resource_id), 0))
	return result

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
