extends Node

const REPORT_SCHEMA := "town_unit_tier_runtime_surface_report_v1"
const TARGET_FACTION_COUNT := 6
const TARGET_TIER_COUNT := 7
const COMMON_RESOURCE_IDS := ["gold", "wood", "ore"]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
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
	var faction_rows := []
	var tier_case_count := 0
	var build_action_case_count := 0
	var starting_signature_case_count := 0
	var high_tier_rare_case_count := 0
	for faction_id in ContentService.get_content_ids(ContentService.FACTIONS_PATH):
		var faction := ContentService.get_faction(String(faction_id))
		if faction.is_empty():
			continue
		var faction_row := _run_faction_case(faction)
		faction_rows.append(faction_row)
		tier_case_count += int(faction_row.get("tier_case_count", 0))
		build_action_case_count += int(faction_row.get("build_action_case_count", 0))
		starting_signature_case_count += int(faction_row.get("starting_signature_case_count", 0))
		high_tier_rare_case_count += int(faction_row.get("high_tier_rare_case_count", 0))
		if not bool(faction_row.get("ok", false)):
			for error in faction_row.get("errors", []):
				_errors.append(String(error))
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"faction_count": faction_rows.size(),
		"tier_case_count": tier_case_count,
		"build_action_case_count": build_action_case_count,
		"starting_signature_case_count": starting_signature_case_count,
		"target_tier_count": TARGET_TIER_COUNT,
		"high_tier_rare_case_count": high_tier_rare_case_count,
		"common_resource_ids": COMMON_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"factions": faction_rows,
		"errors": _errors,
		"caveats": [
			"Fixture builds isolated town sessions to inspect live TownRules action metadata for each signature unit building.",
			"Seed-town starting signature buildings are already built, so they are validated through live recruit actions instead of build-menu availability.",
			"This validates runtime tier identity and cost classification, not final town UI layout or scenario-wide economy pacing.",
		],
	}
	print("TOWN_UNIT_TIER_RUNTIME_SURFACE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_faction_case(faction: Dictionary) -> Dictionary:
	var faction_errors := []
	var faction_id := String(faction.get("id", ""))
	var seed_town_id := String(faction.get("seed_town_id", ""))
	var town_template := ContentService.get_town(seed_town_id)
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	var ladder_ids := _string_array(faction.get("unit_ladder_ids", []))
	var rare_id := String(town_template.get("development_balance", {}).get("rare_resource_id", ""))
	var tier_rows := []
	var build_action_case_count := 0
	var starting_signature_case_count := 0
	var high_tier_rare_case_count := 0

	if signature_ids.size() != TARGET_TIER_COUNT:
		faction_errors.append("%s signature_building_ids must expose seven entries" % faction_id)
	if ladder_ids.size() != TARGET_TIER_COUNT:
		faction_errors.append("%s unit_ladder_ids must expose seven entries" % faction_id)
	if rare_id not in RARE_RESOURCE_IDS:
		faction_errors.append("%s seed town %s must expose a live rare_resource_id" % [faction_id, seed_town_id])

	for index in range(signature_ids.size()):
		var tier := index + 1
		var building_id := String(signature_ids[index])
		var expected_unit_id := String(ladder_ids[index]) if index < ladder_ids.size() else ""
		var tier_row := _run_tier_case(faction_id, town_template, building_id, expected_unit_id, tier, rare_id)
		tier_rows.append(tier_row)
		if bool(tier_row.get("requires_build_action", false)):
			build_action_case_count += 1
		if bool(tier_row.get("starting_signature_building", false)):
			starting_signature_case_count += 1
		if not bool(tier_row.get("ok", false)):
			faction_errors.append(String(tier_row.get("error", "unknown tier error")))
		if bool(tier_row.get("high_tier_rare_cost", false)):
			high_tier_rare_case_count += 1

	return {
		"ok": faction_errors.is_empty(),
		"faction_id": faction_id,
		"seed_town_id": seed_town_id,
		"rare_resource_id": rare_id,
		"tier_case_count": tier_rows.size(),
		"build_action_case_count": build_action_case_count,
		"starting_signature_case_count": starting_signature_case_count,
		"high_tier_rare_case_count": high_tier_rare_case_count,
		"tiers": tier_rows,
		"errors": faction_errors,
	}

func _run_tier_case(faction_id: String, town_template: Dictionary, building_id: String, expected_unit_id: String, tier: int, rare_id: String) -> Dictionary:
	var building := ContentService.get_building(building_id)
	var unit_id := String(building.get("unlock_unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var starting_building_ids := _string_array(town_template.get("starting_building_ids", []))
	var is_starting_signature := building_id in starting_building_ids
	var base_row := {
		"ok": false,
		"faction_id": faction_id,
		"town_id": String(town_template.get("id", "")),
		"building_id": building_id,
		"expected_tier": tier,
		"expected_unit_id": expected_unit_id,
		"unlocked_unit_id": unit_id,
		"rare_resource_id": rare_id,
		"starting_signature_building": is_starting_signature,
		"requires_build_action": not is_starting_signature,
	}
	if building.is_empty():
		base_row["error"] = "%s missing building %s" % [faction_id, building_id]
		return base_row
	if unit.is_empty():
		base_row["error"] = "%s building %s missing unlock unit" % [faction_id, building_id]
		return base_row
	if expected_unit_id != "" and unit_id != expected_unit_id:
		base_row["error"] = "%s tier %d building %s unlocks %s, expected %s" % [faction_id, tier, building_id, unit_id, expected_unit_id]
		return base_row
	if int(unit.get("tier", 0)) != tier:
		base_row["error"] = "%s unit %s has tier %d, expected %d" % [faction_id, unit_id, int(unit.get("tier", 0)), tier]
		return base_row

	var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
	var cost_ids := _string_array(cost.keys())
	var rare_cost_ids := []
	for resource_id in cost_ids:
		if resource_id in RARE_RESOURCE_IDS:
			rare_cost_ids.append(resource_id)
	for resource_id in cost_ids:
		if resource_id not in LIVE_STOCKPILE_RESOURCE_IDS:
			base_row["error"] = "%s/%s uses unsupported resource %s" % [faction_id, building_id, resource_id]
			return base_row
	if tier <= 4 and not rare_cost_ids.is_empty():
		base_row["error"] = "%s/%s tier %d must remain common-resource only" % [faction_id, building_id, tier]
		return base_row
	if tier >= 5 and rare_id not in rare_cost_ids:
		base_row["error"] = "%s/%s tier %d must cost faction rare %s" % [faction_id, building_id, tier, rare_id]
		return base_row

	var build_action := {}
	if not is_starting_signature:
		build_action = _build_action_for(town_template, building_id)
		if build_action.is_empty():
			base_row["error"] = "%s/%s did not surface a live build action" % [faction_id, building_id]
			return base_row
	var recruit_action := _recruit_action_for(town_template, building_id, unit_id)
	if recruit_action.is_empty():
		base_row["error"] = "%s/%s did not surface a live recruit action for %s" % [faction_id, building_id, unit_id]
		return base_row
	if not is_starting_signature:
		if int(build_action.get("unit_tier", 0)) != tier:
			base_row["error"] = "%s/%s build action unit_tier mismatch" % [faction_id, building_id]
			return base_row
		if String(build_action.get("unlocked_unit_id", "")) != unit_id:
			base_row["error"] = "%s/%s build action unlocked_unit_id mismatch" % [faction_id, building_id]
			return base_row
	if int(recruit_action.get("unit_tier", 0)) != tier:
		base_row["error"] = "%s/%s recruit action unit_tier mismatch" % [faction_id, building_id]
		return base_row
	if not is_starting_signature and not String(build_action.get("summary", "")).contains("Tier %d" % tier):
		base_row["error"] = "%s/%s build action summary missing tier label" % [faction_id, building_id]
		return base_row
	if not String(recruit_action.get("summary", "")).contains("Tier %d" % tier):
		base_row["error"] = "%s/%s recruit action summary missing tier label" % [faction_id, building_id]
		return base_row

	base_row["ok"] = true
	base_row["unit_name"] = String(unit.get("name", unit_id))
	base_row["building_name"] = String(building.get("name", building_id))
	base_row["category"] = String(building.get("category", ""))
	base_row["cost"] = cost
	base_row["common_cost_ids"] = _intersection(cost_ids, COMMON_RESOURCE_IDS)
	base_row["rare_cost_ids"] = rare_cost_ids
	base_row["high_tier_rare_cost"] = tier >= 5 and rare_id in rare_cost_ids
	base_row["build_action_status"] = "starting_building_already_built" if is_starting_signature else "available"
	if not is_starting_signature:
		base_row["build_action"] = _action_snapshot(build_action)
	base_row["recruit_action"] = _action_snapshot(recruit_action)
	return base_row

func _build_action_for(town_template: Dictionary, building_id: String) -> Dictionary:
	var session = _build_session(town_template, _prerequisite_buildings_for(building_id), {})
	for action in TownRules.get_build_actions(session):
		if action is Dictionary and String(action.get("id", "")) == "build:%s" % building_id:
			return action
	return {}

func _recruit_action_for(town_template: Dictionary, building_id: String, unit_id: String) -> Dictionary:
	var built := _prerequisite_buildings_for(building_id)
	if building_id not in built:
		built.append(building_id)
	var session = _build_session(town_template, built, {unit_id: 3})
	for action in TownRules.get_recruit_actions(session):
		if action is Dictionary and String(action.get("id", "")) == "recruit:%s" % unit_id:
			return action
	return {}

func _build_session(town_template: Dictionary, built_buildings: Array, available_recruits: Dictionary):
	var hero_template := ContentService.get_hero("hero_lyra")
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 0, "y": 0},
		{"id": "tier_surface_army", "name": "Tier Surface Army", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var town_state := {
		"placement_id": "tier_surface_town",
		"town_id": String(town_template.get("id", "")),
		"x": 0,
		"y": 0,
		"owner": "player",
		"controlling_faction_id": "",
		"built_buildings": built_buildings,
		"available_recruits": available_recruits,
		"garrison": [],
		"recovery": {},
		"front": {},
		"occupation": {},
		"last_build_day": 0,
	}
	var overworld := {
		"map": [["grass", "grass"], ["grass", "grass"]],
		"map_size": {"width": 2, "height": 2},
		"terrain_layers": {},
		"active_hero_id": "hero_lyra",
		"player_heroes": [hero],
		"hero_position": {"x": 0, "y": 0},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _deep_resources(),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": [],
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"town_unit_tier_runtime_surface_%s" % String(town_template.get("id", "")),
		"",
		"hero_lyra",
		0,
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	OverworldRules.normalize_overworld_state(session)
	var normalized_towns: Array = session.overworld.get("towns", [])
	if not normalized_towns.is_empty() and normalized_towns[0] is Dictionary:
		var normalized_town: Dictionary = normalized_towns[0]
		normalized_town["built_buildings"] = built_buildings
		normalized_town["available_recruits"] = available_recruits
		normalized_towns[0] = normalized_town
		session.overworld["towns"] = normalized_towns
	OverworldRules.set_active_town_visit(session, "tier_surface_town")
	return session

func _prerequisite_buildings_for(building_id: String) -> Array:
	var result := []
	_append_prerequisites(building_id, result)
	return result

func _append_prerequisites(building_id: String, result: Array) -> void:
	var building := ContentService.get_building(building_id)
	for required_id_value in building.get("requires", []):
		var required_id := String(required_id_value)
		_append_prerequisites(required_id, result)
		if required_id not in result:
			result.append(required_id)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		_append_prerequisites(upgrade_from, result)
		if upgrade_from not in result:
			result.append(upgrade_from)

func _deep_resources() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[String(resource_id)] = 9999
	return resources

func _action_snapshot(action: Dictionary) -> Dictionary:
	return {
		"id": String(action.get("id", "")),
		"unit_tier": int(action.get("unit_tier", 0)),
		"tier_label": String(action.get("tier_label", "")),
		"unlocked_unit_id": String(action.get("unlocked_unit_id", "")),
		"summary": String(action.get("summary", "")),
		"direct_affordable": bool(action.get("direct_affordable", false)),
		"direct_affordable_count": int(action.get("direct_affordable_count", 0)),
		"disabled": bool(action.get("disabled", false)),
	}

func _string_array(values: Variant) -> Array:
	var result := []
	if not (values is Array):
		return result
	for value in values:
		result.append(String(value))
	return result

func _intersection(values: Array, allowed: Array) -> Array:
	var result := []
	for value in values:
		if String(value) in allowed:
			result.append(String(value))
	return result
