extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "EIGHT_COMMANDER_DOCTRINE_EXPEDITIONS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/eight_commander_doctrine_expeditions_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/commander_doctrine_expeditions_atlas.png"
const BATCH_ID := "content-eight-commander-doctrine-expeditions-10184"
const CASES := [
	{"scenario_id":"heatpriest-quench-censer-expedition","prefix":"heatdoctrine","hero_id":"hero_brasshollow_odrik_heatpriest","faction_id":"faction_brasshollow","site_id":"site_heatpriest_quench_censer","asset_id":"resource_site_doctrine_heatpriest_quench_censer","region":Rect2(0,0,48,48),"command_key":"power"},
	{"scenario_id":"fenhook-blind-levee-expedition","prefix":"fenhookdoctrine","hero_id":"hero_tarn","faction_id":"faction_mireclaw","site_id":"site_fenhook_blind_levee_snare","asset_id":"resource_site_doctrine_fenhook_blind_levee_snare","region":Rect2(48,0,48,48),"command_key":"attack"},
	{"scenario_id":"choirward-resonance-bastion-expedition","prefix":"choirwarddoctrine","hero_id":"hero_thalen","faction_id":"faction_sunvault","site_id":"site_choirward_resonance_bastion","asset_id":"resource_site_doctrine_choirward_resonance_bastion","region":Rect2(96,0,48,48),"command_key":"defense"},
	{"scenario_id":"mirrorstep-parallax-gate-expedition","prefix":"mirrorstepdoctrine","hero_id":"hero_varis","faction_id":"faction_sunvault","site_id":"site_mirrorstep_parallax_gate","asset_id":"resource_site_doctrine_mirrorstep_parallax_gate","region":Rect2(144,0,48,48),"command_key":"attack"},
	{"scenario_id":"mossvein-memory-cairn-expedition","prefix":"mossveindoctrine","hero_id":"hero_thornwake_ralka_mossvein","faction_id":"faction_thornwake","site_id":"site_mossvein_memory_cairn","asset_id":"resource_site_doctrine_mossvein_memory_cairn","region":Rect2(192,0,48,48),"command_key":"knowledge"},
	{"scenario_id":"bramble-hound-pursuit-kennel-expedition","prefix":"bramblehounddoctrine","hero_id":"hero_thornwake_silsa_bramblehound","faction_id":"faction_thornwake","site_id":"site_bramble_hound_pursuit_kennel","asset_id":"resource_site_doctrine_bramble_hound_pursuit_kennel","region":Rect2(240,0,48,48),"command_key":"attack"},
	{"scenario_id":"rootwright-living-span-expedition","prefix":"rootwrightdoctrine","hero_id":"hero_thornwake_tova_rootwright","faction_id":"faction_thornwake","site_id":"site_rootwright_living_span","asset_id":"resource_site_doctrine_rootwright_living_span","region":Rect2(288,0,48,48),"command_key":"defense"},
	{"scenario_id":"nightchart-false-star-orrery-expedition","prefix":"nightchartdoctrine","hero_id":"hero_veilmourn_orso_nightchart","faction_id":"faction_veilmourn","site_id":"site_nightchart_false_star_orrery","asset_id":"resource_site_doctrine_nightchart_false_star_orrery","region":Rect2(336,0,48,48),"command_key":"knowledge"},
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
	_expect(atlas != null and atlas.get_size() == Vector2(384, 48), "Commander Doctrine Expeditions atlas must remain exactly 384x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(), "exact_launch_count":_count_rows("exact_launch"),
		"production_battle_count":_sum_rows("production_battles"), "production_claim_count":_count_rows("production_claim"),
		"exact_art_count":_count_rows("exact_art"), "objective_victory_count":_count_rows("objective_victory"),
		"save_round_trip_count":_count_rows("save_round_trip"), "capture_count":_count_rows("capture_written"),
		"save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":8,"production_battle_count":32,"production_claim_count":8,"objective_victory_count":8,"save_round_trip_count":8,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s could not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var exact_launch: bool = (
		String(session.hero_id) == String(case.get("hero_id", ""))
		and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", ""))
		and String(scenario.get("content_batch_id", "")) == BATCH_ID
		and int(scenario.get("map_size", {}).get("width", 0)) == 18
		and int(scenario.get("map_size", {}).get("height", 0)) == 12
		and session.overworld.get("army", {}).get("stacks", []).size() == 5
		and scenario.get("towns", []).size() == 2
		and scenario.get("encounters", []).size() == 4
		and scenario.get("resource_nodes", []).size() == 10
		and scenario.get("script_hooks", []).size() == 5
		and scenario.get("objectives", {}).get("victory", []).size() == 6
	)
	_expect(exact_launch, "%s lost its exact 18x12, hero, faction, five-stack, two-town, four-front doctrine contract." % scenario_id)

	var node_result := _resource_node_result(session, "%s_landmark" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact doctrine-landmark atlas region." % scenario_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var production_battles := 0
	for index in range(1, 5):
		var placement_id := "%s_front_%d" % [prefix, index]
		var battle_probe := _clone_session(session)
		if _resolve_front(battle_probe, placement_id):
			production_battles += 1
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			if placement_id not in resolved:
				resolved.append(placement_id)
			session.overworld["resolved_encounters"] = resolved
	_expect(production_battles == 4, "%s did not win all four production battle probes." % scenario_id)

	var command_key := String(case.get("command_key", ""))
	var command_before := int(session.overworld.get("hero", {}).get("command", {}).get(command_key, 0))
	var xp_before := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var claimed_state := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var flag := String(site.get("claim_flags", {}).keys()[0])
	var production_claim: bool = (
		bool(claim.get("ok", false)) and bool(session.flags.get(flag, false))
		and int(session.overworld.get("hero", {}).get("experience", 0)) == xp_before + 250
		and claim.get("shrine_effects", {}).get("hero_command_bonus", {}) == {command_key:1}
		and int(session.overworld.get("hero", {}).get("command", {}).get(command_key, 0)) >= command_before + 1
		and not bool(repeat.get("ok", true)) and session.to_dict() == claimed_state
	)
	_expect(production_claim, "%s did not grant its exact one-time +250 XP, flag, and command doctrine." % scenario_id)

	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var objective_victory: bool = String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 6 and session.day < 19
	_expect(objective_victory, "%s did not complete all six live objectives: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_round_trip: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and _met_victory_objective_count(restored, scenario_id) == 6
	_expect(save_round_trip, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_launch":exact_launch,"production_battles":production_battles,"production_claim":production_claim,"exact_art":exact_art,"objective_victory":objective_victory,"save_round_trip":save_round_trip,"capture_written":capture_path != "","capture_path":capture_path,"completion_day":session.day})
	SessionState.set_active_session(null)


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = tile.x
	hero["y"] = tile.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["x"] = tile.x
			roster_hero["y"] = tile.y
			roster_hero["position"] = position.duplicate(true)
			heroes[index] = roster_hero
	session.overworld["player_heroes"] = heroes


func _met_victory_objective_count(session: SessionStateStoreScript.SessionData, scenario_id: String) -> int:
	var met := 0
	for value in ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", []):
		if value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(value.get("id", "")), "victory"):
			met += 1
	return met


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var result := SessionStateStoreScript.SessionData.new()
	result.from_dict(source.to_dict())
	return result


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("EIGHT_COMMANDER_DOCTRINE_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _sum_rows(key: String) -> int:
	return _rows.reduce(func(total, row): return total + int(row.get(key, 0)), 0)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])
