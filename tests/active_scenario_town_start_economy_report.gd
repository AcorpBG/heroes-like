extends Node

const REPORT_SCHEMA := "active_scenario_town_start_economy_report_v1"
const EARLY_DAYS := 7
const MIN_EARLY_BUILDS_PER_TOWN := 3
const FALLBACK_HERO_ID := "hero_lyra"
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
	var town_case_count := 0
	var early_ready_case_count := 0
	var common_spend_case_count := 0
	var same_day_guard_case_count := 0
	var full_stockpile_case_count := 0
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for authored_town in _player_towns(scenario):
			var row := _run_town_case(String(scenario_id), authored_town)
			rows.append(row)
			town_case_count += 1
			if bool(row.get("early_build_ready", false)):
				early_ready_case_count += 1
			if bool(row.get("common_spend_observed", false)):
				common_spend_case_count += 1
			if bool(row.get("same_day_guard_observed", false)):
				same_day_guard_case_count += 1
			if bool(row.get("full_stockpile_normalized", false)):
				full_stockpile_case_count += 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed natural start economy: %s" % [
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
		"player_town_case_count": town_case_count,
		"early_ready_case_count": early_ready_case_count,
		"common_spend_case_count": common_spend_case_count,
		"same_day_guard_case_count": same_day_guard_case_count,
		"full_stockpile_case_count": full_stockpile_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"common_resource_ids": COMMON_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"This report uses natural active-scenario starts without injected source capture.",
			"It proves first-week town economy readiness, not full campaign balance, route safety, or final encounter pacing.",
		],
	}
	print("ACTIVE_SCENARIO_TOWN_START_ECONOMY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(scenario_id: String, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
	}
	if town_template.is_empty():
		base_row["error"] = "missing town template"
		return base_row
	if faction.is_empty():
		base_row["error"] = "missing faction template"
		return base_row
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var source_session = session
	if source_session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(source_session)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing player town placement"
		return base_row
	session = _build_start_economy_session(scenario_id, source_session, source_town)
	var select_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(select_result.get("ok", false)):
		base_row["error"] = "unable to select town: %s" % String(select_result.get("message", ""))
		return base_row
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var signature_order := _signature_order(faction)
	var build_log := []
	var stalled_days := []
	var common_spend_observed := false
	var same_day_guard_observed := false
	var build_actions_blocked_after_build := false
	var full_stockpile_normalized := _stockpile_has_all_live_resources(session)
	var starting_resources := _resources(session)
	for day_index in range(EARLY_DAYS):
		OverworldRules.set_active_town_visit(session, placement_id)
		full_stockpile_normalized = full_stockpile_normalized and _stockpile_has_all_live_resources(session)
		var selected_id := _select_building_id(session, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_direct_affordable_build",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		else:
			var before_resources := _resources(session)
			var building := ContentService.get_building(selected_id)
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
				var common_delta := _common_resource_spend(building.get("cost", {}), before_resources, after_resources)
				if not common_delta.is_empty():
					common_spend_observed = true
				var same_day_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
				if not bool(same_day_result.get("ok", true)) and String(same_day_result.get("message", "")).contains("already completed a build order today"):
					same_day_guard_observed = true
				build_actions_blocked_after_build = TownRules.get_build_actions(session).is_empty()
				build_log.append({
					"day": int(session.day),
					"building_id": selected_id,
					"common_spend": common_delta,
					"resources_before": before_resources,
					"resources_after": after_resources,
				})
		if day_index < EARLY_DAYS - 1:
			var turn_result: Dictionary = OverworldRules.end_turn(session)
			if not bool(turn_result.get("ok", false)):
				stalled_days.append({
					"day": int(session.day),
					"reason": "end_turn_failed",
					"message": String(turn_result.get("message", "")),
				})
	var early_ready := build_log.size() >= MIN_EARLY_BUILDS_PER_TOWN
	base_row["ok"] = early_ready and common_spend_observed and same_day_guard_observed and build_actions_blocked_after_build and full_stockpile_normalized
	base_row["early_build_ready"] = early_ready
	base_row["build_count"] = build_log.size()
	base_row["common_spend_observed"] = common_spend_observed
	base_row["same_day_guard_observed"] = same_day_guard_observed
	base_row["build_actions_blocked_after_build"] = build_actions_blocked_after_build
	base_row["full_stockpile_normalized"] = full_stockpile_normalized
	base_row["starting_resources"] = starting_resources
	base_row["ending_resources"] = _resources(session)
	base_row["build_log"] = build_log
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _case_error(base_row)
	return base_row

func _build_start_economy_session(scenario_id: String, source_session, source_town: Dictionary):
	var source_hero: Dictionary = source_session.overworld.get("hero", {}) if source_session.overworld.get("hero", {}) is Dictionary else {}
	var hero_id := String(source_hero.get("id", FALLBACK_HERO_ID))
	var hero := source_hero.duplicate(true)
	if hero.is_empty():
		var hero_template := ContentService.get_hero(hero_id)
		hero = HeroCommandRules.build_hero_from_template(
			hero_template,
			{"x": int(source_town.get("x", 0)), "y": int(source_town.get("y", 0))},
			{"id": "town_start_economy_army", "name": "Town Start Economy Army", "stacks": []},
			"normal"
		)
	hero["is_primary"] = true
	hero["x"] = int(source_town.get("x", 0))
	hero["y"] = int(source_town.get("y", 0))
	var town_state := source_town.duplicate(true)
	town_state["owner"] = "player"
	if not (town_state.get("built_buildings", []) is Array):
		var town_template := ContentService.get_town(String(town_state.get("town_id", "")))
		town_state["built_buildings"] = _string_array(town_template.get("starting_building_ids", []))
	if not (town_state.get("available_recruits", {}) is Dictionary):
		town_state["available_recruits"] = {}
	town_state["last_build_day"] = int(town_state.get("last_build_day", 0))
	var overworld := {
		"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": hero_id,
		"player_heroes": [hero],
		"hero_position": {"x": int(town_state.get("x", 0)), "y": int(town_state.get("y", 0))},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _normalized_resources(source_session.overworld.get("resources", {})),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": _copy_resource_nodes(source_session.overworld.get("resource_nodes", [])),
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"active_scenario_town_start_economy_%s_%s" % [scenario_id, String(town_state.get("placement_id", ""))],
		scenario_id,
		hero_id,
		int(source_session.day),
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	return session

func _case_error(row: Dictionary) -> String:
	if not bool(row.get("early_build_ready", false)):
		return "fewer than %d natural first-week builds" % MIN_EARLY_BUILDS_PER_TOWN
	if not bool(row.get("common_spend_observed", false)):
		return "natural first-week construction did not spend wood or ore"
	if not bool(row.get("same_day_guard_observed", false)):
		return "one-build-per-day guard was not observed"
	if not bool(row.get("build_actions_blocked_after_build", false)):
		return "build actions were not blocked after a same-day build"
	if not bool(row.get("full_stockpile_normalized", false)):
		return "natural scenario start did not normalize all live stockpile resources"
	return "unknown"

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

func _common_resource_spend(cost_value: Variant, before: Dictionary, after: Dictionary) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var spent := {}
	for resource_id in COMMON_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) <= 0:
			continue
		var delta := int(before.get(resource_id, 0)) - int(after.get(resource_id, 0))
		if delta > 0:
			spent[resource_id] = delta
	return spent

func _stockpile_has_all_live_resources(session) -> bool:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		if not resources.has(resource_id):
			return false
	return true

func _normalized_resources(resources: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(resources.get(String(resource_id), 0))
	return result

func _resources(session) -> Dictionary:
	var result := {}
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[resource_id] = int(resources.get(resource_id, 0))
	return result

func _copy_resource_nodes(nodes: Variant) -> Array:
	var result := []
	if not (nodes is Array):
		return result
	for node in nodes:
		if node is Dictionary:
			result.append(node.duplicate(true))
	return result

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _player_towns(scenario: Dictionary) -> Array:
	var rows := []
	for town_value in scenario.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
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
