extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "CHARTERLESS_COMPACT_CAMPAIGN_SMOKE"
const OUTPUT_DIR := "res://.artifacts/charterless_compact_campaign_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CAMPAIGN_ID := "campaign_charterless_compact"
const CASES := [
	{"scenario_id":"tidehook-reedwake-commission","hero_id":"hero_veilmourn_olan_tidehook","mechanic":"field_commission","prefix":"tidehook","witness_flag":"charterless_reedwake_noted","seal_path":"res://art/campaigns/runtime/chapter_seals/reedwake_blank_slate.png"},
	{"scenario_id":"blackgauge-double-assay","hero_id":"hero_brasshollow_kestra_blackgauge","mechanic":"twin_hold","prefix":"gaugevigil","witness_flag":"charterless_double_assay_proven","seal_path":"res://art/campaigns/runtime/chapter_seals/double_assay_witness.png"},
	{"scenario_id":"sevenfold-meridian-three-prism-garrison-warrant","hero_id":"hero_sunvault_aven_sevenfold","mechanic":"garrison_warrant","prefix":"meridianwarrant","witness_flag":"charterless_meridian_garrison_recorded","seal_path":"res://art/campaigns/runtime/chapter_seals/three_prism_warrant.png"},
	{"scenario_id":"reedcaller-fenhound-pursuit-assembly","hero_id":"hero_mireclaw_rhask_reedcaller","mechanic":"regalia_assembly","prefix":"fenhoundassembly","witness_flag":"charterless_fenhound_regalia_witnessed","seal_path":"res://art/campaigns/runtime/chapter_seals/fenhound_regalia.png"},
	{"scenario_id":"boltroot-briarwheel-border-oath-seizure","hero_id":"hero_thornwake_bryn_boltroot","mechanic":"border_standards","prefix":"threeseed","witness_flag":"charterless_briarwheel_standards_entered","seal_path":"res://art/campaigns/runtime/chapter_seals/rooted_standard.png"},
	{"scenario_id":"powderwrit-tollreaver-rival-banner-challenge","hero_id":"hero_embercourt_maela_powderwrit","mechanic":"named_rival","prefix":"tollmoon","witness_flag":"charterless_tollmoon_charter_sealed","seal_path":"res://art/campaigns/runtime/chapter_seals/tollmoon_final_charter.png","rival_hero_id":"hero_orrik"},
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
	_expect(campaign_complete, "The Charterless Compact did not complete after all six chapter victories.")
	var report := {
		"ok":_errors.is_empty(),
		"case_count":CASES.size(),
		"exact_campaign_launch_count":_count_rows("exact_campaign_launch"),
		"exact_lead_count":_count_rows("exact_lead"),
		"mechanic_completion_count":_count_rows("mechanic_complete"),
		"witness_handoff_count":_count_rows("witness_exact"),
		"resource_only_carryover_count":_count_rows("resource_only_carryover"),
		"production_battle_count":_rows.reduce(func(total,row): return total + int(row.get("production_battle_count",0)),0),
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
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"mechanic_completion_count":6,"production_battle_count":18,"scenario_victory_count":6,"campaign_art_identity_count":7,"campaign_complete":true,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_campaign_browser_art() -> void:
	var browser_entries := CampaignRulesScript.build_campaign_browser_entries(_profile)
	var matches := browser_entries.filter(func(row): return row is Dictionary and String(row.get("campaign_id", "")) == CAMPAIGN_ID)
	_expect(matches.size() == 1, "The Charterless Compact is absent from the production campaign browser.")
	if matches.size() == 1:
		_expect(String(matches[0].get("emblem_path", "")) == "res://art/campaigns/runtime/emblems/charterless_compact.png" and String(matches[0].get("emblem_alt_text", "")).length() >= 80, "The campaign browser lost the Charterless Compact emblem or accessible description.")
	var chapter_entries := CampaignRulesScript.build_campaign_chapter_entries(_profile, CAMPAIGN_ID)
	_expect(chapter_entries.size() == 6, "The Charterless Compact browser must expose exactly six chapters.")
	var art_paths := ["res://art/campaigns/runtime/emblems/charterless_compact.png"]
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
		var hash := FileAccess.get_sha256(ProjectSettings.globalize_path(path))
		hashes[hash] = true
		if not image.is_empty():
			var position := Vector2i.ZERO if index == 0 else Vector2i(128 + (index - 1) * 64,32)
			contact.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),position)
	_expect(hashes.size() == 7, "The campaign emblem and six chapter seals must remain byte-distinct.")
	_expect(contact.save_png(OUTPUT_DIR + "/campaign_emblem_and_seals.png") == OK, "Could not save the Charterless Compact art contact sheet.")


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var action := CampaignRulesScript.build_chapter_action(_profile,CAMPAIGN_ID,scenario_id)
	_expect(not bool(action.get("disabled",true)), "%s did not unlock from the exact previous witness." % scenario_id)
	var baseline = ScenarioFactory.create_session(scenario_id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var session = CampaignRulesScript.build_session(_profile,scenario_id,"normal",CAMPAIGN_ID)
	_expect(session != null, "%s did not construct through campaign authority." % scenario_id)
	if session == null or baseline == null:
		return
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.normalize_overworld_state(baseline)
	var exact_campaign_launch: bool = session.launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == CAMPAIGN_ID
	var exact_lead: bool = String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and scenario.get("selection",{}).get("availability",{}) == {"campaign":true,"skirmish":true}
	_expect(exact_campaign_launch, "%s lost its campaign launch identity." % scenario_id)
	_expect(exact_lead, "%s lost its exact previously campaign-absent lead hero." % scenario_id)
	var resource_only_carryover := _validate_carryover(session,baseline,scenario_id)

	var focus := _first_encounter(session)
	view.set_map_state(session,session.overworld.get("map",[]),OverworldRules.derive_map_size(session),Vector2i(int(focus.get("x",0)),int(focus.get("y",0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var production_battle_count := _resolve_all_authored_battles(session,case)
	_expect(production_battle_count == 3, "%s did not resolve its three production battles." % scenario_id)
	var mechanic_complete := _complete_mechanic(session,case)
	_expect(mechanic_complete, "%s did not complete its %s mechanic through production authority." % [scenario_id,String(case.get("mechanic", ""))])
	for _index in range(3):
		ScenarioScriptRulesScript.process_hooks(session)
	var witness_exact: bool = bool(session.flags.get(String(case.get("witness_flag", "")),false))
	_expect(witness_exact, "%s did not persist its exact charterless witness." % scenario_id)
	var result := ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(result.get("status",session.scenario_status)) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory, "%s did not complete after its production mechanic and battles: %s" % [scenario_id,JSON.stringify(result)])
	var restored := _clone_session(session)
	var save_round_trip_exact: bool = restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_round_trip_exact, "%s did not round-trip exactly through save version %d." % [scenario_id,SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"mechanic":String(case.get("mechanic", "")),"exact_campaign_launch":exact_campaign_launch,"exact_lead":exact_lead,"resource_only_carryover":resource_only_carryover,"production_battle_count":production_battle_count,"mechanic_complete":mechanic_complete,"witness_exact":witness_exact,"scenario_victory":scenario_victory,"save_round_trip_exact":save_round_trip_exact,"capture_path":capture_path})
	_expected_carryover = _carryover_from_resources(session.overworld.get("resources",{}))
	_previous_scenario_id = scenario_id
	_previous_witness_flag = String(case.get("witness_flag", ""))
	_profile = CampaignRulesScript.record_session_completion(_profile,session)


func _validate_carryover(session, baseline, scenario_id: String) -> bool:
	if _previous_scenario_id == "":
		return true
	var exact := String(session.flags.get("campaign_previous_scenario_id", "")) == _previous_scenario_id and bool(session.flags.get("carryover_%s" % _previous_witness_flag,false))
	var actual_resources: Dictionary = session.overworld.get("resources",{})
	var baseline_resources: Dictionary = baseline.overworld.get("resources",{})
	for resource_id in ["gold","wood","ore","aetherglass","embergrain","peatwax","verdant_grafts","brass_scrip","memory_salt"]:
		var delta := int(actual_resources.get(resource_id,0)) - int(baseline_resources.get(resource_id,0))
		exact = exact and delta == int(_expected_carryover.get(resource_id,0))
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


func _resolve_all_authored_battles(session, case: Dictionary) -> int:
	var count := 0
	var original: Array = session.overworld.get("encounters",[]).duplicate(true)
	for placement_value in original:
		if not (placement_value is Dictionary):
			continue
		var placement_id := String(placement_value.get("placement_id", ""))
		var placement := _encounter(session,placement_id)
		var battle := BattleRulesScript.create_battle_payload(session,placement)
		if String(case.get("mechanic", "")) == "named_rival" and placement_id == "%s_named_rival" % String(case.get("prefix", "")):
			var enemy_hero: Dictionary = battle.get("enemy_hero",{}) if battle.get("enemy_hero",{}) is Dictionary else {}
			_expect(String(enemy_hero.get("roster_hero_id", "")) == String(case.get("rival_hero_id", "")), "The finale did not hydrate Orrik Tollreaver as its exact named rival.")
		if battle.is_empty():
			continue
		session.battle = battle
		session.game_state = "battle"
		for index in range(session.battle.get("stacks",[]).size()):
			var stack = session.battle.get("stacks",[])[index]
			if stack is Dictionary and String(stack.get("side", "")) == "enemy":
				stack["total_health"] = 0
				session.battle["stacks"][index] = stack
		var result := BattleRulesScript.resolve_if_battle_ready(session)
		if String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters",[]):
			count += 1
	return count


func _complete_mechanic(session, case: Dictionary) -> bool:
	var mechanic := String(case.get("mechanic", ""))
	var prefix := String(case.get("prefix", ""))
	match mechanic:
		"field_commission":
			ScenarioScriptRulesScript.process_hooks(session)
			var message := OverworldRules.capture_town_by_placement(session,"%s_enemy_town" % prefix)
			ScenarioScriptRulesScript.process_hooks(session)
			return message != "" and bool(session.flags.get("%s_commission_recorded" % prefix,false))
		"twin_hold":
			session.day = 11
			var turn := OverworldRules.end_turn(session)
			return bool(turn.get("ok",false)) and session.day == 12 and _all_victory_objectives_met(session)
		"garrison_warrant":
			ScenarioScriptRulesScript.process_hooks(session)
			var claim := OverworldRules._collect_resource_node_result(session,_resource_node_result(session,"%s_warrant" % prefix),true)
			var scenario := ContentService.get_scenario(String(case.get("scenario_id", "")))
			var objective: Dictionary = scenario.get("objectives",{}).get("victory",[])[0]
			var home := _town(session,"%s_home" % prefix)
			_move_active_hero_to_town(session,home)
			var transferred := 0
			for requirement_value in objective.get("requirements",[]):
				var requirement: Dictionary = requirement_value
				var result := HeroCommandRulesScript.transfer_town_stack(session,home,String(session.overworld.get("active_hero_id", "")),"garrison",String(requirement.get("unit_id", "")),"all")
				transferred += 1 if bool(result.get("ok",false)) else 0
			return bool(claim.get("ok",false)) and transferred == objective.get("requirements",[]).size() and ScenarioRulesScript.is_objective_met(session,String(objective.get("id", "")),"victory")
		"regalia_assembly":
			return _complete_regalia(session,prefix,String(case.get("scenario_id", "")))
		"border_standards":
			var claims := 0
			for suffix in ["west","south","east"]:
				var result := OverworldRules._collect_resource_node_result(session,_resource_node_result(session,"%s_standard_%s" % [prefix,suffix]),true)
				claims += 1 if bool(result.get("ok",false)) else 0
			return claims == 3 and _all_victory_objectives_met(session)
		"named_rival":
			var claims := 0
			for suffix in ["west","south","east"]:
				var result := OverworldRules._collect_resource_node_result(session,_resource_node_result(session,"%s_banner_%s" % [prefix,suffix]),true)
				claims += 1 if bool(result.get("ok",false)) else 0
			var message := OverworldRules.capture_town_by_placement(session,"%s_rival_town" % prefix)
			return claims == 3 and message != "" and _all_victory_objectives_met(session)
	return false


func _complete_regalia(session, prefix: String, scenario_id: String) -> bool:
	var scenario := ContentService.get_scenario(scenario_id)
	var objective: Dictionary = scenario.get("objectives",{}).get("victory",[])[0]
	var set_id := String(objective.get("set_id", ""))
	var set_definition := ArtifactRulesScript.artifact_set_record(set_id)
	var pieces: Array = set_definition.get("piece_ids",[])
	if pieces.size() != 3:
		return false
	for index in range(2):
		var node_id := "%s_%s_piece" % [prefix,"first" if index == 0 else "second"]
		var claim := OverworldRules._collect_artifact_node_result(session,_artifact_node_result(session,node_id),true)
		if not bool(claim.get("ok",false)):
			return false
		if not _stow_piece(session,String(pieces[index])):
			return false
	var reliquary := OverworldRules._collect_resource_node_result(session,_resource_node_result(session,"%s_reliquary" % prefix),true)
	if not bool(reliquary.get("ok",false)) or not _stow_piece(session,String(pieces[2])):
		return false
	for piece_value in pieces:
		var equip := OverworldRules.equip_artifact(session,String(piece_value))
		if not bool(equip.get("ok",false)):
			return false
	return ScenarioRulesScript.is_objective_met(session,String(objective.get("id", "")),"victory")


func _stow_piece(session, artifact_id: String) -> bool:
	var location := ArtifactRulesScript.locate_artifact(session.overworld.get("hero",{}),artifact_id)
	if String(location.get("location", "")) == "inventory":
		return true
	if String(location.get("location", "")) != "equipped":
		return false
	var result := OverworldRules.unequip_artifact(session,String(location.get("slot", "")))
	return bool(result.get("ok",false))


func _all_victory_objectives_met(session) -> bool:
	var scenario := ContentService.get_scenario(String(session.scenario_id))
	for objective_value in scenario.get("objectives",{}).get("victory",[]):
		if objective_value is Dictionary and not ScenarioRulesScript.is_objective_met(session,String(objective_value.get("id", "")),"victory"):
			return false
	return true


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var position := {"x":int(town.get("x",0)),"y":int(town.get("y",0))}
	var heroes: Array = session.overworld.get("player_heroes",[])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRulesScript.hero_by_id(session,hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["hero_position"] = position.duplicate(true)
	HeroCommandRulesScript.normalize_session(session)


func _first_encounter(session) -> Dictionary:
	for value in session.overworld.get("encounters",[]):
		if value is Dictionary:
			return value
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters",[]):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _town(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns",[]):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _artifact_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _clone_session(session) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("CHARTERLESS_COMPACT_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key,false))).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID,message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload,"  "))
