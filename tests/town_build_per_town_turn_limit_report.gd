extends Node

const REPORT_SCHEMA := "town_build_per_town_turn_limit_report_v1"
const HERO_ID := "hero_mira"
const TOWN_A_PLACEMENT_ID := "per_town_limit_riverwatch"
const TOWN_B_PLACEMENT_ID := "per_town_limit_duskfen"
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
	var session = _build_runtime_session()
	var town_a_before := _run_town_build(session, TOWN_A_PLACEMENT_ID)
	var town_a_second_result: Dictionary = OverworldRules.build_in_active_town(session, String(town_a_before.get("building_id", "")))
	var town_a_actions_after_build := TownRules.get_build_actions(session)
	var town_b_same_day := _run_town_build(session, TOWN_B_PLACEMENT_ID)
	var town_b_second_result: Dictionary = OverworldRules.build_in_active_town(session, String(town_b_same_day.get("building_id", "")))
	var town_b_actions_after_build := TownRules.get_build_actions(session)
	var town_a_after_b := _town(session, TOWN_A_PLACEMENT_ID)
	var town_b_after_b := _town(session, TOWN_B_PLACEMENT_ID)
	session.day = int(session.day) + 1
	var town_a_next_day_actions := _build_action_count(session, TOWN_A_PLACEMENT_ID)
	var town_b_next_day_actions := _build_action_count(session, TOWN_B_PLACEMENT_ID)
	var report := {
		"schema": REPORT_SCHEMA,
		"ok": false,
		"session_day_after_same_day_builds": int(session.day) - 1,
		"town_a": town_a_before,
		"town_b": town_b_same_day,
		"same_town_a_second_build_blocked": _same_day_blocked(town_a_second_result),
		"same_town_b_second_build_blocked": _same_day_blocked(town_b_second_result),
		"town_a_actions_after_build_count": town_a_actions_after_build.size(),
		"town_b_actions_after_build_count": town_b_actions_after_build.size(),
		"town_b_same_day_build_ok": bool(town_b_same_day.get("ok", false)),
		"town_a_last_build_day": int(town_a_after_b.get("last_build_day", 0)),
		"town_b_last_build_day": int(town_b_after_b.get("last_build_day", 0)),
		"town_a_next_day_build_action_count": town_a_next_day_actions,
		"town_b_next_day_build_action_count": town_b_next_day_actions,
		"errors": _errors,
		"caveats": [
			"This report proves the construction limit is stored on each town, not as a global player build lock.",
			"It uses a two-town live runtime session and live OverworldRules.build_in_active_town calls.",
			"It is a construction-rule gate, not final town cost tuning or campaign pacing approval.",
		],
	}
	if not bool(town_a_before.get("ok", false)):
		_errors.append("first town build failed: %s" % String(town_a_before.get("message", "")))
	if not _same_day_blocked(town_a_second_result):
		_errors.append("same-town second build was not blocked for town A")
	if town_a_actions_after_build.size() != 0:
		_errors.append("town A still exposed build actions after same-day build")
	if not bool(town_b_same_day.get("ok", false)):
		_errors.append("town B could not build on the same day after town A")
	if not _same_day_blocked(town_b_second_result):
		_errors.append("same-town second build was not blocked for town B")
	if town_b_actions_after_build.size() != 0:
		_errors.append("town B still exposed build actions after same-day build")
	if int(town_a_after_b.get("last_build_day", 0)) != int(report.get("session_day_after_same_day_builds", 0)):
		_errors.append("town A last_build_day was not stamped independently")
	if int(town_b_after_b.get("last_build_day", 0)) != int(report.get("session_day_after_same_day_builds", 0)):
		_errors.append("town B last_build_day was not stamped independently")
	if town_a_next_day_actions <= 0:
		_errors.append("town A did not expose next-day build actions")
	if town_b_next_day_actions <= 0:
		_errors.append("town B did not expose next-day build actions")
	report["errors"] = _errors
	report["ok"] = _errors.is_empty()
	print("TOWN_BUILD_PER_TOWN_TURN_LIMIT_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_build(session, placement_id: String) -> Dictionary:
	var select_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(select_result.get("ok", false)):
		return {
			"ok": false,
			"placement_id": placement_id,
			"message": String(select_result.get("message", "")),
		}
	var actions := TownRules.get_build_actions(session)
	if actions.is_empty():
		return {
			"ok": false,
			"placement_id": placement_id,
			"message": "no build actions",
		}
	var action: Dictionary = actions[0]
	var building_id := String(action.get("id", "")).trim_prefix("build:")
	var before_town := _town(session, placement_id)
	var before_count := _string_array(before_town.get("built_buildings", [])).size()
	var result: Dictionary = OverworldRules.build_in_active_town(session, building_id)
	var after_town := _town(session, placement_id)
	return {
		"ok": bool(result.get("ok", false)),
		"placement_id": placement_id,
		"building_id": building_id,
		"message": String(result.get("message", "")),
		"built_count_before": before_count,
		"built_count_after": _string_array(after_town.get("built_buildings", [])).size(),
		"last_build_day": int(after_town.get("last_build_day", 0)),
	}

func _build_action_count(session, placement_id: String) -> int:
	var select_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(select_result.get("ok", false)):
		return 0
	return TownRules.get_build_actions(session).size()

func _same_day_blocked(result: Dictionary) -> bool:
	return (
		not bool(result.get("ok", true))
		and String(result.get("message", "")).contains("already completed a build order today")
	)

func _build_runtime_session():
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 0, "y": 0},
		{"id": "per_town_limit_army", "name": "Per-Town Limit Army", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var overworld := {
		"map": [
			["grass", "grass", "grass"],
			["grass", "grass", "grass"],
			["grass", "grass", "grass"],
		],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": HERO_ID,
		"player_heroes": [hero],
		"hero_position": {"x": 0, "y": 0},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _rich_resources(),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [
			_town_state(TOWN_A_PLACEMENT_ID, "town_riverwatch", 0, 0),
			_town_state(TOWN_B_PLACEMENT_ID, "town_duskfen", 1, 0),
		],
		"resource_nodes": [],
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"town_build_per_town_turn_limit",
		"",
		HERO_ID,
		0,
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.day = 5
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	return session

func _town_state(placement_id: String, town_id: String, x: int, y: int) -> Dictionary:
	var town_template := ContentService.get_town(town_id)
	return {
		"placement_id": placement_id,
		"town_id": town_id,
		"x": x,
		"y": y,
		"owner": "player",
		"controlling_faction_id": "",
		"built_buildings": _string_array(town_template.get("starting_building_ids", [])),
		"available_recruits": {},
		"garrison": town_template.get("garrison", []).duplicate(true) if town_template.get("garrison", []) is Array else [],
		"recovery": {},
		"front": {},
		"occupation": {},
		"last_build_day": 0,
	}

func _rich_resources() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[resource_id] = 999999
	return resources

func _town(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _string_array(values: Variant) -> Array:
	var result := []
	if not (values is Array):
		return result
	for value in values:
		result.append(String(value))
	return result
