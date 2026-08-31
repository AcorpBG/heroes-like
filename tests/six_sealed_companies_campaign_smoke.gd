extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_SEALED_COMPANIES_CAMPAIGN_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_sealed_companies_campaign_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CAMPAIGN_ID := "campaign_six_sealed_companies"
const CASES := [
	{"scenario_id":"pikeward-ashcharter-veteran-muster","prefix":"ashcharter","hero_id":"hero_torren","site_id":"site_ash_charter_rollhouse","placement_id":"ashcharter_veteran_muster","witness_flag":"sealed_companies_ashcharter_roll_entered","targets":{"unit_embercourt_lantern_sappers":4,"unit_embercourt_ash_oath_bailiffs":2,"unit_embercourt_charter_colossus":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/ashcharter_seal.png"},
	{"scenario_id":"chainboom-gorefen-veteran-muster","prefix":"gorefenring","hero_id":"hero_mireclaw_kessa_chainboom","site_id":"site_gorefen_chain_ring","placement_id":"gorefenring_veteran_muster","witness_flag":"sealed_companies_gorefen_chain_bound","targets":{"unit_mireclaw_ferrychain_lashers":2,"unit_mireclaw_gorefen_rippers":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/gorefen_ring_seal.png"},
	{"scenario_id":"glassmarshal-daybreak-veteran-muster","prefix":"daybreakprism","hero_id":"hero_sunvault_ilyr_glassmarshal","site_id":"site_mirror_daybreak_drill_prism","placement_id":"daybreakprism_veteran_muster","witness_flag":"sealed_companies_daybreak_prism_aligned","targets":{"unit_sunvault_mirror_duelists":3,"unit_sunvault_daybreak_colossus":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/daybreak_prism_seal.png"},
	{"scenario_id":"bramblehound-worldroot-veteran-muster","prefix":"fivebough","hero_id":"hero_thornwake_silsa_bramblehound","site_id":"site_five_bough_veteran_grove","placement_id":"fivebough_veteran_muster","witness_flag":"sealed_companies_five_bough_rooted","targets":{"unit_thornwake_pollenhook_whistlers":6,"unit_thornwake_bramblekite_needlers":4,"unit_thornwake_seedshield_wardens":3,"unit_thornwake_graft_matriarchs":1,"unit_thornwake_worldroot_bastion":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/five_bough_seal.png"},
	{"scenario_id":"pitmarshal-foundry-veteran-muster","prefix":"threegauge","hero_id":"hero_brasshollow_selka_pitmarshal","site_id":"site_three_gauge_chapter_foundry","placement_id":"threegauge_veteran_muster","witness_flag":"sealed_companies_three_gauges_certified","targets":{"unit_brasshollow_quenchspool_slingers":4,"unit_brasshollow_gaugefire_arbalists":3,"unit_brasshollow_foundry_saint":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/three_gauge_seal.png"},
	{"scenario_id":"keelwarden-fogkeel-veteran-muster","prefix":"fogkeel","hero_id":"hero_veilmourn_jessa_keelwarden","rival_hero_id":"hero_mireclaw_edda_rotlamp","site_id":"site_fog_keel_lastwatch_mooring","placement_id":"fogkeel_veteran_muster","witness_flag":"sealed_companies_lastwatch_sounded","targets":{"unit_veilmourn_wakechain_boarders":3,"unit_veilmourn_mirrorkeel_reavers":1,"unit_veilmourn_fogbound_leviathan":1},"seal_path":"res://art/campaigns/runtime/chapter_seals/fogkeel_bell_seal.png"},
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
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	_profile = CampaignRulesScript.normalize_profile({})
	_validate_campaign_browser_art()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var campaign_complete: bool = CampaignRulesScript._campaign_is_completed(_profile, CAMPAIGN_ID)
	_expect(campaign_complete, "The Six Sealed Companies did not complete after all six exact victories.")
	var unique_units := {}
	for row_value in _rows:
		for unit_id_value in row_value.get("target_unit_ids", []):
			unique_units[String(unit_id_value)] = true
	var report := {
		"ok":_errors.is_empty(),
		"case_count":CASES.size(),
		"exact_campaign_launch_count":_count_rows("exact_campaign_launch"),
		"exact_lead_count":_count_rows("exact_lead"),
		"resource_only_carryover_count":_count_rows("resource_only_carryover"),
		"production_battle_count":_rows.reduce(func(total,row): return total + int(row.get("production_battle_count",0)),0),
		"live_muster_claim_count":_count_rows("live_muster_claim"),
		"target_unit_count":unique_units.size(),
		"witness_handoff_count":_count_rows("witness_exact"),
		"scenario_victory_count":_count_rows("scenario_victory"),
		"save_round_trip_count":_count_rows("save_round_trip_exact"),
		"campaign_art_identity_count":7,
		"campaign_complete":campaign_complete,
		"save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true,
		"rows":_rows,
		"errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"live_muster_claim_count":6,"target_unit_count":18,"witness_handoff_count":6,"scenario_victory_count":6,"save_round_trip_count":6,"campaign_art_identity_count":7,"campaign_complete":true,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_campaign_browser_art() -> void:
	var browser_entries := CampaignRulesScript.build_campaign_browser_entries(_profile)
	var matches := browser_entries.filter(func(row): return row is Dictionary and String(row.get("campaign_id", "")) == CAMPAIGN_ID)
	_expect(matches.size() == 1, "The Six Sealed Companies is absent from the production campaign browser.")
	if matches.size() == 1:
		_expect(String(matches[0].get("emblem_path", "")) == "res://art/campaigns/runtime/emblems/six_sealed_companies.png" and String(matches[0].get("emblem_alt_text", "")).length() >= 80, "The campaign browser lost the exact emblem or accessible description.")
	var chapter_entries := CampaignRulesScript.build_campaign_chapter_entries(_profile, CAMPAIGN_ID)
	_expect(chapter_entries.size() == 6, "The Six Sealed Companies browser must expose exactly six chapters.")
	var art_paths := ["res://art/campaigns/runtime/emblems/six_sealed_companies.png"]
	for case_value in CASES:
		art_paths.append(String(case_value.get("seal_path", "")))
	var hashes := {}
	var contact := Image.create(512,128,false,Image.FORMAT_RGBA8)
	contact.fill(Color(0.01,0.025,0.055,1.0))
	for index in range(art_paths.size()):
		var path := String(art_paths[index])
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var expected_size := Vector2i(128,128) if index == 0 else Vector2i(64,64)
		_expect(not image.is_empty() and image.get_size() == expected_size and load(path) is Texture2D, "%s did not resolve as exact campaign-browser art." % path)
		hashes[FileAccess.get_sha256(ProjectSettings.globalize_path(path))] = true
		if not image.is_empty():
			contact.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO if index == 0 else Vector2i(128 + (index - 1) * 64,32))
	_expect(hashes.size() == 7, "The campaign emblem and six chapter seals must remain byte-distinct.")
	_expect(contact.save_png(OUTPUT_DIR + "/campaign_emblem_and_seals.png") == OK, "Could not save the campaign art contact sheet.")


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var action := CampaignRulesScript.build_chapter_action(_profile,CAMPAIGN_ID,scenario_id)
	_expect(not bool(action.get("disabled",true)), "%s did not unlock from the exact previous muster witness." % scenario_id)
	var baseline = ScenarioFactory.create_session(scenario_id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var session = CampaignRulesScript.build_session(_profile,scenario_id,"normal",CAMPAIGN_ID)
	_expect(session != null, "%s did not construct through campaign authority." % scenario_id)
	if session == null or baseline == null:
		return
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.normalize_overworld_state(baseline)
	var exact_campaign_launch: bool = session.launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == CAMPAIGN_ID
	var exact_lead: bool = String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and scenario.get("selection",{}).get("availability",{}) == {"campaign":true,"skirmish":true}
	_expect(exact_campaign_launch, "%s lost its exact campaign launch identity." % scenario_id)
	_expect(exact_lead, "%s lost its exact veteran-muster lead hero." % scenario_id)
	var resource_only_carryover := _validate_carryover(session,baseline,scenario_id)

	var focus := _first_encounter(session)
	view.set_map_state(session,session.overworld.get("map",[]),OverworldRules.derive_map_size(session),Vector2i(int(focus.get("x",0)),int(focus.get("y",0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var prefix := String(case.get("prefix", ""))
	var production_battle_count := 0
	for placement_id in ["%s_west_company" % prefix,"%s_south_company" % prefix,"%s_muster_guard" % prefix]:
		var expected_rival := String(case.get("rival_hero_id", "")) if placement_id.ends_with("_muster_guard") else ""
		if _resolve_production_battle(session,placement_id,expected_rival):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s resolved %d of its three production battles." % [scenario_id,production_battle_count])
	if production_battle_count != 3:
		return

	var targets: Dictionary = case.get("targets", {})
	var before := _army_counts(session,targets.keys())
	var node_result := _resource_node_result(session,String(case.get("placement_id", "")))
	var node: Dictionary = node_result.get("node",{})
	_set_active_hero_position(session,Vector2i(int(node.get("x",0)),int(node.get("y",0))))
	var claim := OverworldRules._collect_resource_node_result(session,node_result,true)
	var live_muster_claim: bool = bool(claim.get("ok",false)) and _army_delta_exact(before,_army_counts(session,targets.keys()),targets)
	_expect(live_muster_claim, "%s did not recruit every target company through its live guarded muster: %s" % [scenario_id,JSON.stringify(claim)])
	_expect(ScenarioRulesScript.is_objective_met(session,"%s_assemble_veterans" % prefix,"victory"), "%s did not satisfy its exact veteran-company army objective." % scenario_id)
	for _index in range(3):
		ScenarioScriptRulesScript.process_hooks(session)
	var witness_exact: bool = bool(session.flags.get(String(case.get("witness_flag", "")),false))
	_expect(witness_exact, "%s did not persist its exact muster-seal witness." % scenario_id)
	var outcome := ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(outcome.get("status",session.scenario_status)) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory, "%s did not complete after three battles, control, and exact roster assembly: %s" % [scenario_id,JSON.stringify(outcome)])
	var restored := _clone_session(session)
	var save_round_trip_exact: bool = restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_round_trip_exact, "%s did not round-trip exactly through save version %d." % [scenario_id,SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"target_unit_ids":targets.keys(),"exact_campaign_launch":exact_campaign_launch,"exact_lead":exact_lead,"resource_only_carryover":resource_only_carryover,"production_battle_count":production_battle_count,"live_muster_claim":live_muster_claim,"witness_exact":witness_exact,"scenario_victory":scenario_victory,"save_round_trip_exact":save_round_trip_exact,"capture_path":capture_path})
	_expected_carryover = _carryover_from_resources(session.overworld.get("resources",{}))
	_previous_scenario_id = scenario_id
	_previous_witness_flag = String(case.get("witness_flag", ""))
	_profile = CampaignRulesScript.record_session_completion(_profile,session)


func _validate_carryover(session, baseline, scenario_id: String) -> bool:
	if _previous_scenario_id == "":
		return true
	var exact := String(session.flags.get("campaign_previous_scenario_id", "")) == _previous_scenario_id and bool(session.flags.get("carryover_%s" % _previous_witness_flag,false))
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
	_expect(exact, "%s imported state beyond the previous witness and capped common resources." % scenario_id)
	return exact


func _carryover_from_resources(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {
		"gold":mini(500,int(floor(maxi(0,int(resources.get("gold",0))) * 0.12))),
		"wood":mini(2,int(floor(maxi(0,int(resources.get("wood",0))) * 0.12))),
		"ore":mini(2,int(floor(maxi(0,int(resources.get("ore",0))) * 0.12))),
	}


func _resolve_production_battle(session: SessionStateStoreScript.SessionData, placement_id: String, expected_rival_hero_id: String = "") -> bool:
	var placement := _encounter(session,placement_id)
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session,placement)
	if payload.is_empty():
		return false
	if expected_rival_hero_id != "":
		var enemy_hero: Dictionary = payload.get("enemy_hero",{}) if payload.get("enemy_hero",{}) is Dictionary else {}
		_expect(String(enemy_hero.get("roster_hero_id", "")) == expected_rival_hero_id, "%s did not hydrate the final named rival %s." % [placement_id,expected_rival_hero_id])
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks",[]).size()):
		var stack = session.battle.get("stacks",[])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result := BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session,placement)


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters",[]):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _first_encounter(session) -> Dictionary:
	for value in session.overworld.get("encounters",[]):
		if value is Dictionary:
			return value
	return {}


func _army_count(session, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("army",{}).get("stacks",[]):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count",0))
	return total


func _army_counts(session, unit_ids: Array) -> Dictionary:
	var result := {}
	for unit_id_value in unit_ids:
		result[String(unit_id_value)] = _army_count(session,String(unit_id_value))
	return result


func _army_delta_exact(before: Dictionary, after: Dictionary, expected: Dictionary) -> bool:
	for unit_id_value in expected.keys():
		var unit_id := String(unit_id_value)
		if int(after.get(unit_id,0)) - int(before.get(unit_id,0)) != int(expected.get(unit_id_value,0)):
			return false
	return true


func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active: Dictionary = session.overworld.get("hero",{})
	active["position"] = position.duplicate(true)
	session.overworld["hero"] = active
	var heroes: Array = session.overworld.get("player_heroes",[])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _clone_session(session) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("SIX_SEALED_COMPANIES_CAPTURE_DIR")
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
