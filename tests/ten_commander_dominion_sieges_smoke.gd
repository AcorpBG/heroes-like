extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "TEN_COMMANDER_DOMINION_SIEGES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/ten_commander_dominion_sieges_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/commander_dominion_sieges_atlas.png"
const BATCH_ID := "content-ten-commander-dominion-sieges-10184"
const CASES := [
	["vellum-quenchline-dominion-siege","quenchline","resource_site_dominion_quench_cantilever_gauge","brass_scrip",0],
	["vellum-counterweight-verdict","counterweight","resource_site_dominion_counterweight_verdict_press","brass_scrip",1],
	["orrik-blackwake-toll-siege","blackwake","resource_site_dominion_blackwake_toll_tusk","peatwax",2],
	["orrik-moonchain-verdict","moonchain","resource_site_dominion_moonchain_raid_ledger","peatwax",3],
	["thir-last-margin-siege","lastmargin","resource_site_dominion_last_margin_mast","memory_salt",4],
	["thir-drowned-name-verdict","drownedname","resource_site_dominion_drowned_name_archive","memory_salt",5],
	["zhorra-crown-drum-siege","crowndrum","resource_site_dominion_crown_drum_dais","peatwax",6],
	["zhorra-undertow-verdict","undertow","resource_site_dominion_fenwake_undertow_beacon","peatwax",7],
	["mirro-nine-ray-siege","nineray","resource_site_dominion_nine_ray_halo_range","aetherglass",8],
	["mirro-meridian-shadow-verdict","shadowdial","resource_site_dominion_meridian_shadow_dial","aetherglass",9],
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(480, 48), "Dominion-siege atlas must remain exactly 480x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case in CASES:
		await _run_case(view, case)
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(), "exact_launch_count":_count_rows("exact_launch"),
		"production_battle_count":_sum_rows("production_battles"), "production_claim_count":_count_rows("production_claim"),
		"town_capture_count":_count_rows("town_capture"), "exact_art_count":_count_rows("exact_art"),
		"objective_victory_count":_count_rows("objective_victory"), "save_round_trip_count":_count_rows("save_round_trip"),
		"capture_count":_count_rows("capture_written"), "save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":10,"production_battle_count":10,"production_claim_count":10,"town_capture_count":10,"objective_victory_count":10,"save_round_trip_count":10,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Array) -> void:
	var scenario_id := String(case[0])
	var prefix := String(case[1])
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s could not create a live skirmish session." % scenario_id)
	if session == null: return
	OverworldRules.normalize_overworld_state(session)
	var contract: Dictionary = scenario.get("commander_dominion_siege", {})
	var expected_height := 14 if int(case[4]) % 2 == 0 else 16
	var exact_launch: bool = (
		String(session.hero_id) == String(scenario.get("hero_id", ""))
		and String(scenario.get("content_batch_id", "")) == BATCH_ID
		and scenario.get("selection", {}).get("availability", {}) == {"campaign":false,"skirmish":true}
		and int(scenario.get("map_size", {}).get("width", 0)) == 22
		and int(scenario.get("map_size", {}).get("height", 0)) == expected_height
		and session.overworld.get("army", {}).get("stacks", []).size() == 5
		and scenario.get("towns", []).size() == 3 and scenario.get("encounters", []).size() == 5
		and scenario.get("resource_nodes", []).size() == (12 if expected_height == 14 else 14)
		and scenario.get("script_hooks", []).size() == 6
		and scenario.get("objectives", {}).get("victory", []).size() == 8
	)
	_expect(exact_launch, "%s launch mismatch: %s" % [scenario_id, JSON.stringify(scenario.get("map_size", {}))])

	var node_result := _resource_node_result(session, "%s_landmark" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var texture = view.call("_object_texture_for_asset", view.call("_resource_asset_id", node))
	var exact_art: bool = String(view.call("_resource_asset_id", node)) == String(case[2]) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == Rect2(int(case[4]) * 48, 0, 48, 48)
	_expect(exact_art, "%s did not resolve its exact siege-command atlas region." % scenario_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules.refresh_fog_of_war(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var production_battles := 1 if _resolve_front(_clone_session(session), "%s_front_1" % prefix) else 0
	for index in range(1, 6):
		var resolved: Array = session.overworld.get("resolved_encounters", [])
		resolved.append("%s_front_%d" % [prefix, index])
		session.overworld["resolved_encounters"] = resolved
	_expect(production_battles == 1, "%s did not win its representative real battle probe." % scenario_id)

	var claim_units: Array = contract.get("claim_unit_ids", [])
	var unit_a := String(claim_units[0])
	var unit_b := String(claim_units[1])
	var relief_unit := String(contract.get("relief_unit_id", ""))
	var rare_key := String(case[3])
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var unit_a_before := _army_unit_count(session, unit_a)
	var unit_b_before := _army_unit_count(session, unit_b)
	var xp_before := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var claimed_state := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var site := ContentService.get_resource_site(String(contract.get("landmark_site_id", "")))
	var flag := String(site.get("claim_flags", {}).keys()[0])
	var expected_a := 3 + (2 if unit_a == relief_unit else 0)
	var expected_b := 1 + (2 if unit_b == relief_unit else 0)
	var production_claim: bool = (
		bool(claim.get("ok", false)) and bool(session.flags.get(flag, false))
		and int(session.overworld.get("hero", {}).get("experience", 0)) == xp_before + 300
		and int(session.overworld.get("resources", {}).get("gold", 0)) == int(resources_before.get("gold", 0)) + 2650
		and int(session.overworld.get("resources", {}).get(rare_key, 0)) == int(resources_before.get(rare_key, 0)) + 3
		and _army_unit_count(session, unit_a) == unit_a_before + expected_a
		and _army_unit_count(session, unit_b) == unit_b_before + expected_b
		and not bool(repeat.get("ok", true)) and session.to_dict() == claimed_state
	)
	_expect(production_claim, "%s one-time integrated claim payload changed." % scenario_id)

	var capture_message := OverworldRules.capture_town_by_placement(session, "%s_enemy_town" % prefix)
	var town_capture := capture_message != ""
	_expect(town_capture, "%s hostile town did not transfer through live capture authority." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var deadline := 26 if expected_height == 14 else 30
	var objective_victory: bool = String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 8 and session.day < deadline
	_expect(objective_victory, "%s did not complete all eight live objectives: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored: SessionStateStoreScript.SessionData = _clone_session(session)
	var save_round_trip: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and _met_victory_objective_count(restored, scenario_id) == 8
	_expect(save_round_trip, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_launch":exact_launch,"production_battles":production_battles,"production_claim":production_claim,"town_capture":town_capture,"exact_art":exact_art,"objective_victory":objective_victory,"save_round_trip":save_round_trip,"capture_written":capture_path != "","capture_path":capture_path,"completion_day":session.day})
	SessionState.set_active_session(null)


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty(): return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty(): return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id: return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id: return value
	return {}


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = tile.x; hero["y"] = tile.y; hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["x"] = tile.x; roster_hero["y"] = tile.y; roster_hero["position"] = position.duplicate(true)
			heroes[index] = roster_hero
	session.overworld["player_heroes"] = heroes


func _met_victory_objective_count(session, scenario_id: String) -> int:
	var met := 0
	for value in ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", []):
		if value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(value.get("id", "")), "victory"): met += 1
	return met


func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var result := SessionStateStoreScript.SessionData.new()
	result.from_dict(source.to_dict())
	return result


func _army_unit_count(session, unit_id: String) -> int:
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id: return int(stack.get("count", 0))
	return 0


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("TEN_COMMANDER_DOMINION_SIEGES_CAPTURE_DIR")
	if directory == "": return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int: return _rows.filter(func(row): return bool(row.get(key, false))).size()
func _sum_rows(key: String) -> int: return _rows.reduce(func(total, row): return total + int(row.get(key, 0)), 0)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: _errors.append("Could not write %s." % path); return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message); push_error("%s %s" % [REPORT_ID, message])
