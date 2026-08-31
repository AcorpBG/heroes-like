extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "GREAT_WORK_CHARTER_RACES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/great_work_charter_races_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/great_work_charter_races_atlas.png"
const CASES := [
	{"scenario_id":"rainwrit-stormseal-charter-race","prefix":"rainwritworks","faction_id":"faction_embercourt","town_id":"town_rainwrit_bastion","building_id":"building_embercourt_rainwrit_stormseal_treasury","site_id":"site_rainwrit_stormseal_survey_cairn","asset_id":"resource_site_great_work_rainwrit_survey_cairn","region":Rect2(0,0,48,48)},
	{"scenario_id":"hollowreed-moonwax-charter-race","prefix":"hollowreedworks","faction_id":"faction_mireclaw","town_id":"town_hollowreed_sanctuary","building_id":"building_mireclaw_hollowreed_moonwax_ossuary","site_id":"site_hollowreed_moonwax_foundation_totem","asset_id":"resource_site_great_work_hollowreed_foundation_totem","region":Rect2(48,0,48,48)},
	{"scenario_id":"meridian-seven-facet-charter-race","prefix":"meridianworks","faction_id":"faction_sunvault","town_id":"town_meridian_choirhold","building_id":"building_sunvault_meridian_seven_facet_orrery","site_id":"site_meridian_seven_line_plumb_prism","asset_id":"resource_site_great_work_meridian_plumb_prism","region":Rect2(96,0,48,48)},
	{"scenario_id":"crownroot-heartseed-charter-race","prefix":"crownrootworks","faction_id":"faction_thornwake","town_id":"town_crownroot_refuge","building_id":"building_thornwake_crownroot_heartseed_parliament","site_id":"site_crownroot_heartseed_boundary_arbor","asset_id":"resource_site_great_work_crownroot_boundary_arbor","region":Rect2(144,0,48,48)},
	{"scenario_id":"blackbell-grand-assay-charter-race","prefix":"blackbellworks","faction_id":"faction_brasshollow","town_id":"town_blackbell_foundry","building_id":"building_brasshollow_blackbell_grand_assay_bell","site_id":"site_blackbell_grand_assay_tripod","asset_id":"resource_site_great_work_blackbell_assay_tripod","region":Rect2(192,0,48,48)},
	{"scenario_id":"pale-sounding-last-memory-charter-race","prefix":"palesoundingworks","faction_id":"faction_veilmourn","town_id":"town_pale_sounding_harbor","building_id":"building_veilmourn_pale_sounding_last_memory_beacon","site_id":"site_pale_sounding_last_memory_marker","asset_id":"resource_site_great_work_pale_sounding_marker","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Great-Work survey atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"exact_art_count": _rows.filter(func(row): return bool(row.get("exact_art", false))).size(),
		"missing_building_control_count": _rows.filter(func(row): return bool(row.get("missing_building_control", false))).size(),
		"wrong_owner_control_count": _rows.filter(func(row): return bool(row.get("wrong_owner_control", false))).size(),
		"survey_claim_count": _rows.filter(func(row): return bool(row.get("survey_claim", false))).size(),
		"survey_guard_victory_count": _rows.filter(func(row): return bool(row.get("survey_guard_victory", false))).size(),
		"scoped_dependency_count": _rows.filter(func(row): return bool(row.get("scoped_dependency", false))).size(),
		"production_build_victory_count": _rows.filter(func(row): return bool(row.get("production_build_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_build_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var placement_id := "%s_home" % prefix
	var building_id := String(case.get("building_id", ""))
	var objective_id := "%s_complete_great_work" % prefix
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	var town := _town(session, placement_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s launched the wrong faction." % scenario_id)
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")) and String(town.get("owner", "")) == "player", "%s lost its player-owned Horizon citadel." % scenario_id)
	var initial_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var missing_building_control := String(initial_result.get("status", "")) == "in_progress" and not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(missing_building_control, "%s began complete without its Great Work." % scenario_id)

	var wrong_owner_probe := _clone_session(session)
	var wrong_town := _town(wrong_owner_probe, placement_id)
	var wrong_built: Array = wrong_town.get("built_buildings", []).duplicate(true)
	wrong_built.append(building_id)
	wrong_town["built_buildings"] = wrong_built
	wrong_town["owner"] = "enemy"
	var wrong_result: Dictionary = ScenarioRulesScript.evaluate_session(wrong_owner_probe)
	var wrong_owner_control := String(wrong_result.get("status", "")) != "victory" and not ScenarioRulesScript.is_objective_met(wrong_owner_probe, objective_id, "victory")
	_expect(wrong_owner_control, "%s accepted a rival-owned Great Work." % scenario_id)

	var node_result := _resource_node_result(session, "%s_survey" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	_expect(String(node.get("site_id", "")) == String(case.get("site_id", "")) and String(site.get("runtime_boundary", {}).get("status", "")) == "great_work_survey_live", "%s lost its exact survey placement or contract." % scenario_id)
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact survey atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var survey_guard_victory := _resolve_guard(session, "%s_survey_guard" % prefix)
	_expect(survey_guard_victory, "%s did not clear its production survey guard." % scenario_id)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_survey" % prefix), true)
	var resources_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var survey_claim: bool = bool(claim.get("ok", false)) and _delta_contains(resources_before, resources_after, site.get("claim_rewards", {}))
	_expect(survey_claim, "%s did not grant its exact survey stores: %s" % [scenario_id, JSON.stringify(claim)])
	var claim_authority := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_survey" % prefix), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == claim_authority, "%s repeat survey claim mutated authority." % scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"town_building_built","town_placement_ids":[placement_id],"building_ids":[building_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose exact town/building objective dependencies: %s" % [scenario_id, JSON.stringify(scoped_profile)])

	town = _town(session, placement_id)
	_move_active_hero_to_town(session, town)
	var visit := OverworldRules.set_active_town_visit(session, placement_id)
	_expect(bool(visit.get("ok", false)), "%s could not establish its production Town visit." % scenario_id)
	var built_ids: Array = []
	var built_ok := _ensure_building(session, building_id, {}, built_ids)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var production_build_victory: bool = built_ok and String(victory_result.get("status", "")) == "victory" and ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and building_id in _town(session, placement_id).get("built_buildings", []) and session.day < 24
	_expect(production_build_victory, "%s did not win through its production build chain: day=%d result=%s" % [scenario_id, session.day, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and building_id in _town(restored, placement_id).get("built_buildings", [])
	_expect(save_exact, "%s did not preserve its completed Great Work through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"missing_building_control":missing_building_control,"wrong_owner_control":wrong_owner_control,"survey_guard_victory":survey_guard_victory,"survey_claim":survey_claim,"scoped_dependency":scoped_dependency,"production_build_victory":production_build_victory,"dependency_build_count":built_ids.size(),"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _ensure_building(session: SessionStateStoreScript.SessionData, building_id: String, trail: Dictionary, built_ids: Array) -> bool:
	var active := TownRules.get_active_town(session)
	if building_id in active.get("built_buildings", []):
		return true
	if trail.has(building_id):
		_expect(false, "Build dependency cycle reached %s." % building_id)
		return false
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		_expect(false, "Missing dependency building %s." % building_id)
		return false
	var next_trail := trail.duplicate()
	next_trail[building_id] = true
	var dependencies: Array = building.get("requires", []).duplicate(true)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in dependencies:
		dependencies.append(upgrade_from)
	for dependency_value in dependencies:
		if not _ensure_building(session, String(dependency_value), next_trail, built_ids):
			return false
	session.day += 1
	var result := TownRules.build_active_town(session, building_id)
	if not bool(result.get("ok", false)):
		_expect(false, "Could not build %s on Day %d: %s" % [building_id, session.day, JSON.stringify(result)])
		return false
	built_ids.append(building_id)
	return true


func _resolve_guard(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _resource_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _move_active_hero_to_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	var position := {"x":int(town.get("x", 0)),"y":int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = int(position.x)
	hero["y"] = int(position.y)
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _delta_contains(before: Dictionary, after: Dictionary, expected: Variant) -> bool:
	if not (expected is Dictionary):
		return false
	for key_value in expected.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) < int(expected.get(key_value, 0)):
			return false
	return true


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("GREAT_WORK_CHARTER_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
