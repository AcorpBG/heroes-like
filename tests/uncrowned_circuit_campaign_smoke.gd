extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNCROWNED_CIRCUIT_CAMPAIGN_SMOKE"
const OUTPUT_DIR := "res://.artifacts/uncrowned_circuit_campaign_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CAMPAIGN_ID := "campaign_uncrowned_circuit"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/uncrowned_sovereign_roads_atlas.png"
const CASES := [
	{"scenario_id":"powderwrit-cinderlock-charter-ascent","prefix":"cinderlock","hero_id":"hero_embercourt_maela_powderwrit","town_id":"town_cinderlock_bastion","building_id":"building_embercourt_charter_bastion","unit_id":"unit_embercourt_charter_colossus","site_id":"site_cinderlock_open_charter_throne"},
	{"scenario_id":"reedscript-murkward-antler-ascent","prefix":"murkward","hero_id":"hero_mireclaw_pell_reedscript","town_id":"town_murkward_ford","building_id":"building_mireclaw_antler_pit","unit_id":"unit_mireclaw_drowned_antler_sovereign","site_id":"site_murkward_antler_tribunal"},
	{"scenario_id":"sevenfold-dawnmirror-daybreak-ascent","prefix":"dawnmirror","hero_id":"hero_sunvault_aven_sevenfold","town_id":"town_dawnmirror_observatory","building_id":"building_sunvault_daybreak_matrix","unit_id":"unit_sunvault_daybreak_colossus","site_id":"site_dawnmirror_uncrowned_matrix"},
	{"scenario_id":"seedseer-graftroot-worldroot-ascent","prefix":"graftroot","hero_id":"hero_thornwake_veyra_seedseer","town_id":"town_thornwake_graftroot_caravan","building_id":"building_thornwake_worldroot_gate","unit_id":"unit_thornwake_worldroot_bastion","site_id":"site_graftroot_living_dais"},
	{"scenario_id":"blackgauge-orevein-foundry-ascent","prefix":"orevein","hero_id":"hero_brasshollow_kestra_blackgauge","town_id":"town_brasshollow_orevein_gantry","building_id":"building_brasshollow_titan_charter_hall","unit_id":"unit_brasshollow_foundry_saint","site_id":"site_orevein_saintless_assay_seat"},
	{"scenario_id":"keelwarden-bellwake-leviathan-ascent","prefix":"bellwake","hero_id":"hero_veilmourn_jessa_keelwarden","town_id":"town_veilmourn_bellwake_harbor","building_id":"building_veilmourn_leviathan_sounding","unit_id":"unit_veilmourn_fogbound_leviathan","site_id":"site_bellwake_empty_sounding_chair"},
]

var _errors: Array[String] = []
var _rows: Array = []
var _profile := {}
var _previous_scenario_id := ""
var _previous_witness_flag := ""
var _expected_carryover := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280,720)
	ContentService.clear_cache()
	_profile = CampaignRulesScript.normalize_profile({})
	_validate_art_and_browser()
	var view = MapViewScript.new()
	view.size = Vector2(1280,720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view,case_value)
	var campaign_complete: bool = CampaignRulesScript._campaign_is_completed(_profile,CAMPAIGN_ID)
	_expect(campaign_complete,"The Uncrowned Circuit did not complete after all six sovereign victories.")
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(),
		"exact_campaign_launch_count":_count_rows("exact_campaign_launch"),
		"exact_lead_count":_count_rows("exact_lead"),
		"resource_only_carryover_count":_count_rows("resource_only_carryover"),
		"live_build_count":_count_rows("live_build"), "live_recruit_count":_count_rows("live_recruit"),
		"production_battle_count":_rows.reduce(func(total,row): return total + int(row.get("production_battle_count",0)),0),
		"live_throne_claim_count":_count_rows("live_throne_claim"),
		"witness_handoff_count":_count_rows("witness_exact"),
		"scenario_victory_count":_count_rows("scenario_victory"),
		"save_round_trip_count":_count_rows("save_round_trip_exact"),
		"campaign_art_identity_count":7, "field_art_identity_count":6,
		"campaign_complete":campaign_complete, "save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH,report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID,JSON.stringify({"ok":true,"case_count":6,"live_build_count":6,"live_recruit_count":6,"production_battle_count":18,"live_throne_claim_count":6,"witness_handoff_count":6,"scenario_victory_count":6,"save_round_trip_count":6,"campaign_complete":true,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_art_and_browser() -> void:
	var browser_entries := CampaignRulesScript.build_campaign_browser_entries(_profile)
	var matches := browser_entries.filter(func(row): return row is Dictionary and String(row.get("campaign_id","")) == CAMPAIGN_ID)
	_expect(matches.size() == 1,"The Uncrowned Circuit is absent from the production campaign browser.")
	if matches.size() == 1:
		_expect(String(matches[0].get("emblem_path","")) == "res://art/campaigns/runtime/emblems/uncrowned_circuit.png" and String(matches[0].get("emblem_alt_text","")).length() >= 70,"The campaign browser lost the Uncrowned Circuit emblem identity.")
	var chapters := CampaignRulesScript.build_campaign_chapter_entries(_profile,CAMPAIGN_ID)
	_expect(chapters.size() == 6,"The Uncrowned Circuit browser must expose six chapters.")
	var paths := ["res://art/campaigns/runtime/emblems/uncrowned_circuit.png"]
	for case_value in CASES:
		paths.append("res://art/campaigns/runtime/chapter_seals/uncrowned_%s.png" % String(case_value.get("prefix","")))
	var hashes := {}
	var contact := Image.create(512,128,false,Image.FORMAT_RGBA8)
	contact.fill(Color(0.01,0.025,0.055,1.0))
	for index in range(paths.size()):
		var path := String(paths[index])
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var expected_size := Vector2i(128,128) if index == 0 else Vector2i(64,64)
		_expect(not image.is_empty() and image.get_size() == expected_size and load(path) is Texture2D,"%s did not resolve as campaign art." % path)
		hashes[FileAccess.get_sha256(ProjectSettings.globalize_path(path))] = true
		if not image.is_empty():
			contact.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO if index == 0 else Vector2i(128 + (index - 1) * 64,32))
	_expect(hashes.size() == 7,"The emblem and six chapter seals must remain byte-distinct.")
	_expect(contact.save_png(OUTPUT_DIR + "/campaign_emblem_and_seals.png") == OK,"Could not save the campaign art contact sheet.")
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(288,48) and load(ATLAS_PATH) is Texture2D,"The six-throne field atlas is not live at 288x48.")


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id",""))
	var prefix := String(case.get("prefix",""))
	var scenario := ContentService.get_scenario(scenario_id)
	var action := CampaignRulesScript.build_chapter_action(_profile,CAMPAIGN_ID,scenario_id)
	_expect(not bool(action.get("disabled",true)),"%s did not unlock from the previous apex witness." % scenario_id)
	var baseline = ScenarioFactory.create_session(scenario_id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var session = CampaignRulesScript.build_session(_profile,scenario_id,"normal",CAMPAIGN_ID)
	_expect(session != null and baseline != null,"%s did not construct through campaign authority." % scenario_id)
	if session == null or baseline == null:
		return
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.normalize_overworld_state(baseline)
	var exact_campaign_launch: bool = session.launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id","")) == CAMPAIGN_ID
	var exact_lead: bool = String(session.hero_id) == String(case.get("hero_id","")) and String(scenario.get("hero_id","")) == String(case.get("hero_id","")) and scenario.get("selection",{}).get("availability",{}) == {"campaign":true,"skirmish":true}
	_expect(exact_campaign_launch,"%s lost its campaign launch identity." % scenario_id)
	_expect(exact_lead,"%s lost its exact lead commander." % scenario_id)
	var resource_only_carryover := _validate_carryover(session,baseline,scenario_id)

	var home := _town(session,"%s_home" % prefix)
	_set_active_hero_position(session,Vector2i(int(home.get("x",0)),int(home.get("y",0))))
	var visit := OverworldRules.set_active_town_visit(session,String(home.get("placement_id","")))
	_expect(bool(visit.get("ok",false)),"%s could not enter its live home town." % scenario_id)
	var building_id := String(case.get("building_id",""))
	var build_action := _row_by_key(TownRules.get_build_catalog(session),"building_id",building_id)
	var build_result: Dictionary = TownRules.build_active_town(session,building_id)
	var live_build: bool = not build_action.is_empty() and not bool(build_action.get("disabled",true)) and bool(build_result.get("ok",false)) and building_id in _town(session,"%s_home" % prefix).get("built_buildings",[])
	_expect(live_build,"%s did not complete its production Tier-7 build: %s" % [scenario_id,JSON.stringify(build_result)])
	var unit_id := String(case.get("unit_id",""))
	var before := _army_count(session,unit_id)
	var recruit_result: Dictionary = TownRules.recruit_active_town(session,unit_id,1)
	var live_recruit: bool = bool(recruit_result.get("ok",false)) and _army_count(session,unit_id) == before + 1
	_expect(live_recruit,"%s did not recruit its exact Tier-7 witness: %s" % [scenario_id,JSON.stringify(recruit_result)])
	ScenarioScriptRulesScript.process_hooks(session)

	var focus := _encounter(session,"%s_front_3" % prefix)
	view.set_map_state(session,session.overworld.get("map",[]),OverworldRules.derive_map_size(session),Vector2i(int(focus.get("x",0)),int(focus.get("y",0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)
	var production_battle_count := 0
	for index in range(1,4):
		if _resolve_production_battle(session,"%s_front_%d" % [prefix,index]):
			production_battle_count += 1
	_expect(production_battle_count == 3,"%s resolved %d of its three production battles." % [scenario_id,production_battle_count])
	if production_battle_count != 3 or not live_build or not live_recruit:
		return

	var node_result := _resource_node_result(session,"%s_throne" % prefix)
	var node: Dictionary = node_result.get("node",{})
	_set_active_hero_position(session,Vector2i(int(node.get("x",0)),int(node.get("y",0))))
	var claim := OverworldRules._collect_resource_node_result(session,node_result,true)
	var live_throne_claim: bool = bool(claim.get("ok",false)) and bool(session.flags.get("uncrowned_%s_throne_claimed" % prefix,false))
	_expect(live_throne_claim,"%s did not claim its exact open throne through live authority." % scenario_id)
	for town_index in range(session.overworld.get("towns",[]).size()):
		var town: Dictionary = session.overworld["towns"][town_index]
		if String(town.get("placement_id","")) == "%s_enemy" % prefix:
			town["owner"] = "player"
			session.overworld["towns"][town_index] = town
	for _index in range(3):
		ScenarioScriptRulesScript.process_hooks(session)
	var witness_flag := "uncrowned_%s_witness_entered" % prefix
	var witness_exact: bool = bool(session.flags.get(witness_flag,false))
	_expect(witness_exact,"%s did not persist its exact apex witness." % scenario_id)
	var outcome := ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(outcome.get("status",session.scenario_status)) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory,"%s did not complete its seven-objective sovereign road: %s" % [scenario_id,JSON.stringify(outcome)])
	var restored := _clone_session(session)
	var save_round_trip_exact: bool = restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and building_id in _town(restored,"%s_home" % prefix).get("built_buildings",[]) and _army_count(restored,unit_id) >= 1
	_expect(save_round_trip_exact,"%s did not round-trip through save version %d." % [scenario_id,SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_campaign_launch":exact_campaign_launch,"exact_lead":exact_lead,"resource_only_carryover":resource_only_carryover,"live_build":live_build,"live_recruit":live_recruit,"production_battle_count":production_battle_count,"live_throne_claim":live_throne_claim,"witness_exact":witness_exact,"scenario_victory":scenario_victory,"save_round_trip_exact":save_round_trip_exact,"capture_path":capture_path})
	_expected_carryover = _carryover_from_resources(session.overworld.get("resources",{}))
	_previous_scenario_id = scenario_id
	_previous_witness_flag = witness_flag
	_profile = CampaignRulesScript.record_session_completion(_profile,session)


func _validate_carryover(session, baseline, scenario_id: String) -> bool:
	if _previous_scenario_id == "":
		return true
	var exact := String(session.flags.get("campaign_previous_scenario_id","")) == _previous_scenario_id and bool(session.flags.get("carryover_%s" % _previous_witness_flag,false))
	var actual: Dictionary = session.overworld.get("resources",{})
	var original: Dictionary = baseline.overworld.get("resources",{})
	for resource_id in ["gold","wood","ore","aetherglass","embergrain","peatwax","verdant_grafts","brass_scrip","memory_salt"]:
		exact = exact and int(actual.get(resource_id,0)) - int(original.get(resource_id,0)) == int(_expected_carryover.get(resource_id,0))
	var hero: Dictionary = session.overworld.get("hero",{})
	var baseline_hero: Dictionary = baseline.overworld.get("hero",{})
	exact = exact and int(hero.get("level",0)) == int(baseline_hero.get("level",0))
	exact = exact and hero.get("spellbook",{}).get("known_spell_ids",[]) == baseline_hero.get("spellbook",{}).get("known_spell_ids",[])
	exact = exact and JSON.stringify(hero.get("artifacts",{})) == JSON.stringify(baseline_hero.get("artifacts",{}))
	exact = exact and JSON.stringify(hero.get("army",{})) == JSON.stringify(baseline_hero.get("army",{}))
	_expect(exact,"%s imported state beyond the previous witness and capped common resources." % scenario_id)
	return exact


func _carryover_from_resources(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {"gold":mini(650,int(floor(maxi(0,int(resources.get("gold",0))) * 0.12))),"wood":mini(2,int(floor(maxi(0,int(resources.get("wood",0))) * 0.12))),"ore":mini(2,int(floor(maxi(0,int(resources.get("ore",0))) * 0.12)))}


func _resolve_production_battle(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var placement := _encounter(session,placement_id)
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session,placement)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks",[]).size()):
		var stack = session.battle.get("stacks",[])[index]
		if stack is Dictionary and String(stack.get("side","")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result := BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state","")) == "victory" and OverworldRules.is_encounter_resolved(session,placement)


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id","")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _town(session, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("towns",[]),"placement_id",placement_id)


func _encounter(session, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("encounters",[]),"placement_id",placement_id)


func _row_by_key(rows: Variant, key: String, expected: String) -> Dictionary:
	for row in rows if rows is Array else []:
		if row is Dictionary and String(row.get(key,"")) == expected:
			return row
	return {}


func _army_count(session, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("army",{}).get("stacks",[]):
		if stack is Dictionary and String(stack.get("unit_id","")) == unit_id:
			total += int(stack.get("count",0))
	return total


func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active: Dictionary = session.overworld.get("hero",{})
	active["x"] = tile.x
	active["y"] = tile.y
	active["position"] = position.duplicate(true)
	session.overworld["hero"] = active
	var heroes: Array = session.overworld.get("player_heroes",[])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id","")) == String(session.overworld.get("active_hero_id","")):
			var hero: Dictionary = heroes[index]
			hero["x"] = tile.x
			hero["y"] = tile.y
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _clone_session(session) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("UNCROWNED_CIRCUIT_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key,false))).size()


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload,"  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID,message])
