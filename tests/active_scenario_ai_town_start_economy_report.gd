extends Node

const REPORT_SCHEMA := "active_scenario_ai_town_start_economy_report_v1"
const EARLY_DAYS := 7
const MIN_EARLY_BUILDS_PER_TOWN := 3
const HERO_ID := "hero_lyra"
const COMMON_RESOURCE_IDS := ["wood", "ore"]
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

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario_count := 0
	var enemy_town_case_count := 0
	var early_ready_case_count := 0
	var common_spend_case_count := 0
	var same_day_guard_case_count := 0
	var full_treasury_case_count := 0
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for authored_town in _enemy_towns(scenario):
			var row := _run_enemy_town_case(String(scenario_id), scenario, authored_town)
			rows.append(row)
			enemy_town_case_count += 1
			if bool(row.get("early_build_ready", false)):
				early_ready_case_count += 1
			if bool(row.get("common_spend_observed", false)):
				common_spend_case_count += 1
			if bool(row.get("same_day_guard_observed", false)):
				same_day_guard_case_count += 1
			if bool(row.get("full_treasury_normalized", false)):
				full_treasury_case_count += 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed natural AI town start economy: %s" % [
					String(row.get("scenario_id", scenario_id)),
					String(row.get("town_placement_id", authored_town.get("placement_id", ""))),
					String(row.get("error", "unknown")),
				])
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"early_days": EARLY_DAYS,
		"min_early_builds_per_town": MIN_EARLY_BUILDS_PER_TOWN,
		"active_scenario_count": scenario_count,
		"enemy_town_case_count": enemy_town_case_count,
		"early_ready_case_count": early_ready_case_count,
		"common_spend_case_count": common_spend_case_count,
		"same_day_guard_case_count": same_day_guard_case_count,
		"full_treasury_case_count": full_treasury_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"common_resource_ids": COMMON_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"This report uses natural active-scenario enemy town starts without injected source capture.",
			"Construction runs through EnemyTurnRules.run_enemy_town_economy_turn and the same one-build-per-town-per-turn guard used by active AI turns.",
			"It proves first-week enemy town economy readiness, not final strategic AI quality, campaign balance, route safety, or encounter pacing.",
		],
	}
	print("ACTIVE_SCENARIO_AI_TOWN_START_ECONOMY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_enemy_town_case(scenario_id: String, scenario: Dictionary, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction_id := _town_controller_faction_id(authored_town, town_template)
	var faction := ContentService.get_faction(faction_id)
	var config := _enemy_config_for_faction(scenario, faction_id)
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": faction_id,
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

	var source_session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if source_session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(source_session)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing enemy town placement"
		return base_row
	var source_enemy_state := _enemy_state(source_session, faction_id)
	if source_enemy_state.is_empty():
		base_row["error"] = "runtime scenario session missing enemy state"
		return base_row

	var session = _build_start_economy_session(scenario_id, source_session, source_town, source_enemy_state, faction_id)
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var build_log := []
	var stalled_days := []
	var common_spend_observed := false
	var same_day_guard_observed := false
	var full_treasury_normalized := _enemy_treasury_has_all_live_keys(session, faction_id)
	var natural_starting_treasury := _resources(_enemy_state(session, faction_id).get("treasury", {}))
	for day_index in range(EARLY_DAYS):
		full_treasury_normalized = full_treasury_normalized and _enemy_treasury_has_all_live_keys(session, faction_id)
		var before_treasury := _resources(_enemy_state(session, faction_id).get("treasury", {}))
		var expected_income := _enemy_daily_income(session, placement_id, faction_id)
		var before_built := _town_building_ids(_town(session, placement_id))
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(session, faction_id)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "enemy_turn_failed",
				"message": String(turn_result.get("message", "")),
			})
		var after_treasury := _resources(_enemy_state(session, faction_id).get("treasury", {}))
		var after_built := _town_building_ids(_town(session, placement_id))
		var built_today := _new_buildings(before_built, after_built)
		if built_today.is_empty():
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_enemy_build_selected",
				"treasury_before": before_treasury,
				"expected_income": expected_income,
				"treasury_after": after_treasury,
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		else:
			for building_id in built_today:
				var building := ContentService.get_building(String(building_id))
				var common_cost := _common_resource_cost(building.get("cost", {}))
				if not common_cost.is_empty():
					common_spend_observed = true
				build_log.append({
					"day": int(session.day),
					"building_id": String(building_id),
					"cost": building.get("cost", {}),
					"common_spend": common_cost,
					"treasury_before": before_treasury,
					"expected_income": expected_income,
					"treasury_after": after_treasury,
				})
			if not same_day_guard_observed:
				var second_session = _clone_session(session)
				var second_built_before := _town_building_ids(_town(second_session, placement_id)).size()
				var second_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(second_session, faction_id)
				var second_built_after := _town_building_ids(_town(second_session, placement_id)).size()
				var second_events: Array = second_result.get("events", []) if second_result.get("events", []) is Array else []
				same_day_guard_observed = (
					second_built_after == second_built_before
					and _event_count(second_events, "ai_town_built") == 0
				)
		if day_index < EARLY_DAYS - 1:
			session.day += 1
	var early_ready := build_log.size() >= MIN_EARLY_BUILDS_PER_TOWN
	base_row["ok"] = early_ready and common_spend_observed and same_day_guard_observed and full_treasury_normalized
	base_row["early_build_ready"] = early_ready
	base_row["build_count"] = build_log.size()
	base_row["common_spend_observed"] = common_spend_observed
	base_row["same_day_guard_observed"] = same_day_guard_observed
	base_row["full_treasury_normalized"] = full_treasury_normalized
	base_row["natural_starting_treasury"] = natural_starting_treasury
	base_row["ending_treasury"] = _resources(_enemy_state(session, faction_id).get("treasury", {}))
	base_row["build_log"] = build_log
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _case_error(base_row)
	return base_row

func _build_start_economy_session(scenario_id: String, source_session, source_town: Dictionary, source_enemy_state: Dictionary, faction_id: String):
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 0, "y": 0},
		{"id": "ai_town_start_economy_observer_army", "name": "AI Town Start Economy Observer", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var town_state := source_town.duplicate(true)
	town_state["owner"] = "enemy"
	town_state["controlling_faction_id"] = faction_id
	if not (town_state.get("built_buildings", []) is Array):
		var town_template := ContentService.get_town(String(town_state.get("town_id", "")))
		town_state["built_buildings"] = _string_array(town_template.get("starting_building_ids", []))
	if not (town_state.get("available_recruits", {}) is Dictionary):
		town_state["available_recruits"] = {}
	town_state["last_build_day"] = int(town_state.get("last_build_day", 0))
	var enemy_state := source_enemy_state.duplicate(true)
	enemy_state["faction_id"] = faction_id
	enemy_state["treasury"] = _resources(enemy_state.get("treasury", {}))
	var overworld := {
		"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": HERO_ID,
		"player_heroes": [hero],
		"hero_position": {"x": 0, "y": 0},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _blank_resources(),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": _copy_resource_nodes(source_session.overworld.get("resource_nodes", [])),
		"artifact_nodes": [],
		"enemy_states": [enemy_state],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"active_scenario_ai_town_start_economy_%s_%s" % [scenario_id, String(town_state.get("placement_id", ""))],
		scenario_id,
		HERO_ID,
		int(source_session.day),
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	return session

func _case_error(row: Dictionary) -> String:
	if not bool(row.get("early_build_ready", false)):
		return "fewer than %d natural first-week AI builds" % MIN_EARLY_BUILDS_PER_TOWN
	if not bool(row.get("common_spend_observed", false)):
		return "natural first-week AI construction did not spend wood or ore"
	if not bool(row.get("same_day_guard_observed", false)):
		return "one-build-per-town-per-turn guard was not observed"
	if not bool(row.get("full_treasury_normalized", false)):
		return "natural enemy treasury did not normalize all nine live resource ids"
	return "unknown"

func _enemy_daily_income(session, placement_id: String, faction_id: String) -> Dictionary:
	var income := _blank_resources()
	var town := _town(session, placement_id)
	if not town.is_empty():
		income = _add_resource_sets(income, OverworldRules.town_income(town, session))
	income = _add_resource_sets(income, OverworldRules.controlled_resource_site_income(session, faction_id))
	return income

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

func _town_building_ids(town: Dictionary) -> Array:
	return _string_array(town.get("built_buildings", []))

func _new_buildings(before: Array, after: Array) -> Array:
	var result := []
	for building_id in after:
		if String(building_id) not in before:
			result.append(String(building_id))
	return result

func _event_count(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			count += 1
	return count

func _common_resource_cost(cost_value: Variant) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var result := {}
	for resource_id in COMMON_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) > 0:
			result[resource_id] = int(cost.get(resource_id, 0))
	return result

func _town_controller_faction_id(authored_town: Dictionary, town_template: Dictionary) -> String:
	var faction_id := String(authored_town.get("controlling_faction_id", ""))
	if faction_id == "":
		faction_id = String(town_template.get("faction_id", ""))
	return faction_id

func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

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

func _copy_resource_nodes(nodes: Variant) -> Array:
	var result := []
	if not (nodes is Array):
		return result
	for node in nodes:
		if node is Dictionary:
			result.append(node.duplicate(true))
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

func _clone_session(session):
	var clone = SessionStateStore.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone

func _enemy_towns(scenario: Dictionary) -> Array:
	var rows := []
	for town_value in scenario.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "enemy":
			rows.append(town_value)
	return rows

func _is_active_authored_scenario(scenario: Dictionary) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false))

func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		result.append(String(item))
	return result
