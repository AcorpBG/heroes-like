extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_RELIC_PILGRIMAGES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/three_relic_pilgrimages_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const GUARDIAN_ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/three_relic_pilgrimages/three_relic_pilgrimages_atlas.png"
const ARTIFACT_ATLAS_PATH := "res://art/overworld/runtime/objects/artifacts/three_relic_pilgrimages/three_relic_pilgrimages_artifacts_atlas.png"
const CASES := [
	{"scenario_id":"lockfire-three-seal-pilgrimage","hero_id":"hero_seren","faction_id":"faction_embercourt","army_id":"army_lockglass_citation_field","prefix":"lockfirepilgrim","encounter_id":"encounter_lockfire_assize_reliquary","enemy_group_id":"army_lockfire_assize_reliquary","guardian_asset_id":"encounter_relic_lockfire_assize_reliquary","guardian_region":Rect2(0,0,48,48),"artifacts":["artifact_lockfire_assize_seal","artifact_rainwrit_beacon_seal","artifact_ashcrown_crownring"],"artifact_regions":[Rect2(0,0,48,48),Rect2(48,0,48,48),Rect2(96,0,48,48)]},
	{"scenario_id":"miremoon-three-beat-pilgrimage","hero_id":"hero_sable","faction_id":"faction_mireclaw","army_id":"army_sable_muckscript_hunt","prefix":"miremoonpilgrim","encounter_id":"encounter_miremoon_hunt_reliquary","enemy_group_id":"army_miremoon_hunt_reliquary","guardian_asset_id":"encounter_relic_miremoon_hunt_reliquary","guardian_region":Rect2(48,0,48,48),"artifacts":["artifact_miremoon_hunt_drum","artifact_hollowreed_moonfang_drum","artifact_miremoon_crown_tooth"],"artifact_regions":[Rect2(144,0,48,48),Rect2(192,0,48,48),Rect2(240,0,48,48)]},
	{"scenario_id":"noonglass-three-orbit-pilgrimage","hero_id":"hero_varis","faction_id":"faction_sunvault","army_id":"army_varis_mirrorstep_race","prefix":"noonglasspilgrim","encounter_id":"encounter_noonglass_orrery_reliquary","enemy_group_id":"army_noonglass_orrery_reliquary","guardian_asset_id":"encounter_relic_noonglass_orrery_reliquary","guardian_region":Rect2(96,0,48,48),"artifacts":["artifact_noonglass_orrery","artifact_meridian_choir_prism","artifact_noonshard_facet_pinion"],"artifact_regions":[Rect2(288,0,48,48),Rect2(336,0,48,48),Rect2(384,0,48,48)]},
	{"scenario_id":"worldroot-three-covenant-pilgrimage","hero_id":"hero_thornwake_tova_rootwright","faction_id":"faction_thornwake","army_id":"army_pollenhook_whistle_line","prefix":"worldrootpilgrim","encounter_id":"encounter_worldroot_covenant_reliquary","enemy_group_id":"army_worldroot_covenant_reliquary","guardian_asset_id":"encounter_relic_worldroot_covenant_reliquary","guardian_region":Rect2(144,0,48,48),"artifacts":["artifact_worldroot_covenant_heartwood","artifact_crownroot_oathseed_censer","artifact_rootvault_heartgrain_mantle"],"artifact_regions":[Rect2(432,0,48,48),Rect2(480,0,48,48),Rect2(528,0,48,48)]},
	{"scenario_id":"seventh-clause-three-key-pilgrimage","hero_id":"hero_brasshollow_marka_ironclause","faction_id":"faction_brasshollow","army_id":"army_orevein_contract_column","prefix":"clausepilgrim","encounter_id":"encounter_seventh_clause_reliquary","enemy_group_id":"army_seventh_clause_reliquary","guardian_asset_id":"encounter_relic_seventh_clause_reliquary","guardian_region":Rect2(192,0,48,48),"artifacts":["artifact_seventh_clause_pressure_key","artifact_blackbell_verdict_gauge","artifact_quenchbell_red_gauge_plate"],"artifact_regions":[Rect2(576,0,48,48),Rect2(624,0,48,48),Rect2(672,0,48,48)]},
	{"scenario_id":"last-bell-three-sounding-pilgrimage","hero_id":"hero_veilmourn_ivara_blacktide","faction_id":"faction_veilmourn","army_id":"army_bellwake_wreck_claimants","prefix":"lastbellpilgrim","encounter_id":"encounter_last_bell_tideglass_reliquary","enemy_group_id":"army_last_bell_tideglass_reliquary","guardian_asset_id":"encounter_relic_last_bell_tideglass_reliquary","guardian_region":Rect2(240,0,48,48),"artifacts":["artifact_last_bell_tideglass","artifact_pale_sounding_memory_bell","artifact_saltwake_resonance_bell"],"artifact_regions":[Rect2(720,0,48,48),Rect2(768,0,48,48),Rect2(816,0,48,48)]}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var guardian_atlas := load(GUARDIAN_ATLAS_PATH) as Texture2D
	var artifact_atlas := load(ARTIFACT_ATLAS_PATH) as Texture2D
	_expect(guardian_atlas != null and guardian_atlas.get_size() == Vector2(288, 48), "The guardian atlas must remain exactly 288x48.")
	_expect(artifact_atlas != null and artifact_atlas.get_size() == Vector2(864, 48), "The artifact field atlas must remain exactly 864x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"direct_lead_count": _rows.filter(func(row): return bool(row.get("direct_lead", false))).size(),
		"artifact_collection_count": _rows.reduce(func(total, row): return total + int(row.get("artifact_collections", 0)), 0),
		"scoped_dependency_count": _rows.reduce(func(total, row): return total + int(row.get("scoped_dependencies", 0)), 0),
		"battle_victory_count": _rows.reduce(func(total, row): return total + int(row.get("battle_victories", 0)), 0),
		"exact_guardian_art_count": _rows.filter(func(row): return bool(row.get("exact_guardian_art", false))).size(),
		"exact_artifact_art_count": _rows.reduce(func(total, row): return total + int(row.get("exact_artifact_art", 0)), 0),
		"missing_relic_control_count": _rows.filter(func(row): return bool(row.get("missing_relic_control", false))).size(),
		"transferred_relic_count": _rows.filter(func(row): return bool(row.get("transferred_relic", false))).size(),
		"scenario_victory_count": _rows.filter(func(row): return bool(row.get("scenario_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"artifact_collection_count":18,"battle_victory_count":18,"scenario_victory_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var direct_lead := not bool(availability.get("campaign", true)) and bool(availability.get("skirmish", false)) and String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("player_army_id", "")) == String(case.get("army_id", ""))
	_expect(direct_lead, "%s did not launch its exact hero, faction, and company." % scenario_id)
	_expect(scenario.get("artifact_nodes", []).size() == 3 and scenario.get("encounters", []).size() == 3 and scenario.get("script_hooks", []).size() == 6 and scenario.get("objectives", {}).get("victory", []).size() == 6 and scenario.get("objectives", {}).get("defeat", []).size() == 4, "%s lost its three-relic composition." % scenario_id)

	var encounter := _encounter(session, "%s_guardian_1" % prefix)
	var encounter_definition := ContentService.get_encounter(String(case.get("encounter_id", "")))
	_expect(String(encounter.get("encounter_id", "")) == String(case.get("encounter_id", "")) and String(encounter_definition.get("enemy_group_id", "")) == String(case.get("enemy_group_id", "")) and encounter_definition.get("field_objectives", []).size() == 1, "%s lost its guardian encounter, army, or field objective." % scenario_id)
	var encounter_tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(encounter_tile.x - 1, encounter_tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), encounter_tile)
	await get_tree().process_frame
	var encounter_presentation: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var guardian_texture = view.call("_object_texture_for_asset", String(case.get("guardian_asset_id", "")))
	var exact_guardian_art: bool = String(encounter_presentation.get("identity_encounter_asset_id", "")) == String(case.get("guardian_asset_id", "")) and bool(encounter_presentation.get("uses_identity_encounter_sprite", false)) and guardian_texture is AtlasTexture and guardian_texture.region == case.get("guardian_region", Rect2()) and guardian_texture.atlas is Texture2D and guardian_texture.atlas.resource_path == GUARDIAN_ATLAS_PATH
	_expect(exact_guardian_art, "%s guardian art did not reach the live renderer." % scenario_id)

	var artifact_collections := 0
	var scoped_dependencies := 0
	var exact_artifact_art := 0
	var missing_probe: SessionStateStoreScript.SessionData
	var artifact_ids: Array = case.get("artifacts", [])
	var artifact_regions: Array = case.get("artifact_regions", [])
	for index in range(artifact_ids.size()):
		var artifact_id := String(artifact_ids[index])
		var objective_id := "%s_recover_%d" % [prefix, index + 1]
		_expect(not ScenarioRulesScript.is_objective_met(session, objective_id, "victory"), "%s started with target relic %s already owned." % [scenario_id, artifact_id])
		var node_result := _artifact_node_result(session, "%s_relic_%d" % [prefix, index + 1])
		var node: Dictionary = node_result.get("node", {})
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		_set_active_hero_position(session, tile)
		OverworldRules._reveal_current_fog_sources(session)
		view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
		await get_tree().process_frame
		var tile_presentation: Dictionary = view.call("validation_tile_presentation", tile)
		var artifact_presentation: Dictionary = tile_presentation.get("artifact_presentation", {})
		var asset_id := "artifact_field_%s" % artifact_id.trim_prefix("artifact_")
		var artifact_texture = view.call("_object_texture_for_asset", asset_id)
		var art_exact: bool = String(artifact_presentation.get("artifact_id", "")) == artifact_id and String(artifact_presentation.get("sprite_asset_id", "")) == asset_id and bool(artifact_presentation.get("uses_distinct_field_sprite", false)) and artifact_texture is AtlasTexture and artifact_texture.region == artifact_regions[index] and artifact_texture.atlas is Texture2D and artifact_texture.atlas.resource_path == ARTIFACT_ATLAS_PATH
		if art_exact:
			exact_artifact_art += 1
		else:
			_error("%s relic %s did not render from its exact atlas region." % [scenario_id, artifact_id])
		var claim: Dictionary = OverworldRules._collect_artifact_node_result(session, node_result, true)
		if bool(claim.get("ok", false)):
			artifact_collections += 1
		else:
			_error("%s could not collect %s: %s" % [scenario_id, artifact_id, JSON.stringify(claim)])
		var scoped: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"artifact_collected","artifact_ids":[artifact_id]})
		var profile: Dictionary = scoped.get("profile", {})
		if String(profile.get("dependency_mode", "")) == "scoped" and int(profile.get("objectives_checked", 0)) >= 1 and ScenarioRulesScript.is_objective_met(session, objective_id, "victory"):
			scoped_dependencies += 1
		else:
			_error("%s relic %s did not use scoped objective dependency authority: %s" % [scenario_id, artifact_id, JSON.stringify(profile)])
		if index == 1:
			missing_probe = _clone_session(session)

	var missing_relic_control := false
	if missing_probe != null:
		_mark_all_guardians_resolved(missing_probe, prefix)
		var missing_result: Dictionary = ScenarioRulesScript.evaluate_session(missing_probe)
		missing_relic_control = String(missing_result.get("status", "")) == "in_progress" and not ScenarioRulesScript.is_objective_met(missing_probe, "%s_recover_3" % prefix, "victory")
	_expect(missing_relic_control, "%s won despite the third relic remaining missing." % scenario_id)

	var transfer_id := String(artifact_ids[2])
	var removal: Dictionary = ArtifactRulesScript.remove_owned_artifact(session.overworld.get("hero", {}), transfer_id)
	var secondary := {"id":"%s_relic_bearer" % prefix,"name":"Relic Bearer","artifacts":ArtifactRulesScript.normalize_hero_artifacts({})}
	var transfer_claim: Dictionary = ArtifactRulesScript.claim_artifact(secondary, transfer_id, "Transferred", false)
	if bool(removal.get("ok", false)) and bool(transfer_claim.get("ok", false)):
		session.overworld["hero"] = removal.get("hero", session.overworld.get("hero", {}))
		var heroes: Array = session.overworld.get("player_heroes", [])
		heroes.append(transfer_claim.get("hero", secondary))
		session.overworld["player_heroes"] = heroes
	var transferred_relic := not ArtifactRulesScript.has_artifact(session.overworld.get("hero", {}), transfer_id) and ScenarioRulesScript.is_objective_met(session, "%s_recover_3" % prefix, "victory")
	_expect(transferred_relic, "%s did not preserve relic ownership after transfer to another player hero." % scenario_id)

	var capture_path := await _capture_if_requested(scenario_id)
	var battle_victories := 0
	for index in range(1, 4):
		var placement_id := "%s_guardian_%d" % [prefix, index]
		var battle_session := _clone_session(session)
		if _resolve_front(battle_session, placement_id):
			battle_victories += 1
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			if placement_id not in resolved:
				resolved.append(placement_id)
			session.overworld["resolved_encounters"] = resolved
	_expect(battle_victories == 3, "%s did not win all three production guardian battles; victories=%d." % [scenario_id, battle_victories])
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 6
	_expect(scenario_victory, "%s did not complete its six-condition victory chain: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"direct_lead":direct_lead,"artifact_collections":artifact_collections,"scoped_dependencies":scoped_dependencies,"battle_victories":battle_victories,"exact_guardian_art":exact_guardian_art,"exact_artifact_art":exact_artifact_art,"missing_relic_control":missing_relic_control,"transferred_relic":transferred_relic,"scenario_victory":scenario_victory,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("Missing encounter placement %s." % placement_id)
		return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		_error("Could not construct production battle for %s." % placement_id)
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	var won: bool = bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])
	if not won:
		print("%s FRONT_FAILED %s %s" % [REPORT_ID, placement_id, JSON.stringify(result)])
	return won


func _artifact_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _mark_all_guardians_resolved(session: SessionStateStoreScript.SessionData, prefix: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	for index in range(1, 4):
		var placement_id := "%s_guardian_%d" % [prefix, index]
		if placement_id not in resolved:
			resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {})
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
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


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("THREE_RELIC_PILGRIMAGE_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "%s capture failed." % stem)
	return path


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
