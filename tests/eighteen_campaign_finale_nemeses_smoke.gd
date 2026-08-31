extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "EIGHTEEN_CAMPAIGN_FINALE_NEMESES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/eighteen_campaign_finale_nemeses_smoke"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/campaign_finale_nemeses/campaign_finale_nemeses_atlas.png"
const ATLAS_SHA256 := "c8b248faf75993aed042661b85a9418fbd70d5bc25039ac8b828b6cd4c5ef8f6"

const CASES := [
	{"scenario_id":"fen-crown","placement_id":"fen_crown_bone_ferry_watch","objective_id":"break_bone_ferry_watch","encounter_id":"encounter_fenwake_crown_drum_verdict","army_id":"army_fen_crown_fenwake_nemesis","hero_id":"hero_mireclaw_zhorra_fenwake","faction_id":"faction_mireclaw","field_objective_id":"fenwake_crown_drum","field_objective_type":"ritual_pylon","reward_id":"peatwax","gold":300,"victory_flag":"finale_nemesis_fenwake_broken","asset_id":"encounter_finale_nemesis_fenwake_crown_drum","atlas_x":0,"source_name":"fenwake_crown_drum.png","source_sha256":"9099b4c4c94423f79fc21a04c193541a8dfd1944add2e01f3b9e3e071d5b7915","x":8,"y":0,"difficulty":"high","seed":3203,"optional_expected":false},
	{"scenario_id":"nightglass-redoubt","placement_id":"nightglass_bone_ferry_watch","objective_id":"break_bone_ferry_screen","encounter_id":"encounter_votivejaw_nightglass_bite","army_id":"army_nightglass_votivejaw_nemesis","hero_id":"hero_mireclaw_nix_votivejaw","faction_id":"faction_mireclaw","field_objective_id":"votivejaw_nightglass_teeth","field_objective_type":"hazard_zone","reward_id":"peatwax","gold":310,"victory_flag":"finale_nemesis_votivejaw_broken","asset_id":"encounter_finale_nemesis_votivejaw_nightglass_shrine","atlas_x":48,"source_name":"votivejaw_nightglass_shrine.png","source_sha256":"1203b0789f16255f179899e45bcd79844871b8101d0056db262c6f8bc9e4ba2d","x":9,"y":0,"difficulty":"high","seed":6203,"optional_expected":false},
	{"scenario_id":"lockmarsh-surge","placement_id":"lockmarsh_archive_wardens","objective_id":"break_archive_wardens","encounter_id":"encounter_lockmaster_archive_seal","army_id":"army_lockmarsh_lockmaster_nemesis","hero_id":"hero_embercourt_saren_lockmaster","faction_id":"faction_embercourt","field_objective_id":"lockmaster_archive_gate","field_objective_type":"breach_point","reward_id":"embergrain","gold":260,"victory_flag":"finale_nemesis_lockmaster_broken","asset_id":"encounter_finale_nemesis_lockmaster_archive_gate","atlas_x":96,"source_name":"lockmaster_archive_gate.png","source_sha256":"7789c1632813f5aabe55f0022ceb51644e3ef305cd241bdb3e2b61db3b677bd5","x":6,"y":5,"difficulty":"medium","seed":9203,"optional_expected":false},
	{"scenario_id":"daybreak-spire","placement_id":"daybreak_bone_ferry_watch","objective_id":"break_bone_ferry_watch","encounter_id":"encounter_chainboom_daybreak_snare","army_id":"army_daybreak_chainboom_nemesis","hero_id":"hero_mireclaw_kessa_chainboom","faction_id":"faction_mireclaw","field_objective_id":"chainboom_daybreak_chain","field_objective_type":"obstruction_line","reward_id":"peatwax","gold":310,"victory_flag":"finale_nemesis_chainboom_broken","asset_id":"encounter_finale_nemesis_chainboom_daybreak_prism","atlas_x":144,"source_name":"chainboom_daybreak_prism.png","source_sha256":"b01b0f00d8df0817a1a930e1e82d4fe81f02b33f24aa76c28460f122f18f509b","x":8,"y":0,"difficulty":"high","seed":13203,"optional_expected":false},
	{"scenario_id":"ninefold-confluence","placement_id":"ninefold_orevein_exactors","objective_id":"","encounter_id":"encounter_ironclause_ninefold_assize","army_id":"army_ninefold_ironclause_nemesis","hero_id":"hero_brasshollow_marka_ironclause","faction_id":"faction_brasshollow","field_objective_id":"ironclause_nine_tallies","field_objective_type":"supply_post","reward_id":"brass_scrip","gold":270,"victory_flag":"finale_nemesis_ironclause_broken","asset_id":"encounter_finale_nemesis_ironclause_ninefold_pylon","atlas_x":192,"source_name":"ironclause_ninefold_pylon.png","source_sha256":"4b7634e32aae6071bc6ee228f5f196e6dcd71b0257156763fa38872bfaadfa0f","x":37,"y":48,"difficulty":"medium","seed":16404,"optional_expected":true},
	{"scenario_id":"charter-bastion-counterseal","placement_id":"counterseal_aurora_battery","objective_id":"clear_counterseal_aurora_battery","encounter_id":"encounter_glassmarshal_counterseal_battery","army_id":"army_counterseal_glassmarshal_nemesis","hero_id":"hero_sunvault_ilyr_glassmarshal","faction_id":"faction_sunvault","field_objective_id":"glassmarshal_counterseal_sight","field_objective_type":"lane_battery","reward_id":"aetherglass","gold":320,"victory_flag":"finale_nemesis_glassmarshal_broken","asset_id":"encounter_finale_nemesis_glassmarshal_counterseal_sight","atlas_x":240,"source_name":"glassmarshal_counterseal_sight.png","source_sha256":"37f79054de7d5cac716d475c5ce2eee03bb05694edf9decd1fc1ba2f67a5618a","x":8,"y":0,"difficulty":"high","seed":24103,"optional_expected":false},
	{"scenario_id":"worldroot-crown-covenant","placement_id":"covenant_daylight_crown","objective_id":"break_daylight_crown","encounter_id":"encounter_halometer_daylight_crown","army_id":"army_worldroot_halometer_nemesis","hero_id":"hero_sunvault_mirro_halometer","faction_id":"faction_sunvault","field_objective_id":"halometer_crown_calibration","field_objective_type":"signal_beacon","reward_id":"aetherglass","gold":340,"victory_flag":"finale_nemesis_halometer_broken","asset_id":"encounter_finale_nemesis_halometer_daylight_dial","atlas_x":288,"source_name":"halometer_daylight_dial.png","source_sha256":"fe1e1027bccb95a327c602365736b94410dcea364b34fe710f9ca7a635071f6f","x":13,"y":3,"difficulty":"high","seed":31304,"optional_expected":false},
	{"scenario_id":"furnace-reckoning","placement_id":"reckoning_front_2","objective_id":"reckoning_front_two","encounter_id":"encounter_vowless_drowned_requiem","army_id":"army_furnace_vowless_nemesis","hero_id":"hero_veilmourn_nacre_vowless","faction_id":"faction_veilmourn","field_objective_id":"vowless_empty_oath_bell","field_objective_type":"ritual_pylon","reward_id":"memory_salt","gold":340,"victory_flag":"finale_nemesis_vowless_broken","asset_id":"encounter_finale_nemesis_vowless_drowned_oath_bell","atlas_x":336,"source_name":"vowless_drowned_oath_bell.png","source_sha256":"4d8b3c6a58e688797ce4651d3189b51cb646b1f8aa4c0072ab8f6de40d4e6de0","x":7,"y":2,"difficulty":"high","seed":32302,"optional_expected":false},
	{"scenario_id":"three-harbors-sounding","placement_id":"lastbell_front_2","objective_id":"lastbell_front_two","encounter_id":"encounter_debtrune_lastbell_audit","army_id":"army_lastbell_debtrune_nemesis","hero_id":"hero_brasshollow_harro_debtrune","faction_id":"faction_brasshollow","field_objective_id":"debtrune_lastbell_ledger","field_objective_type":"supply_post","reward_id":"brass_scrip","gold":340,"victory_flag":"finale_nemesis_debtrune_broken","asset_id":"encounter_finale_nemesis_debtrune_lastbell_ledger","atlas_x":384,"source_name":"debtrune_lastbell_ledger.png","source_sha256":"66871399dcb4d4b2ce94d8b3faaa5a3fefb62555d0f5c62f259efdb65294721e","x":7,"y":2,"difficulty":"high","seed":32602,"optional_expected":false},
	{"scenario_id":"three-banner-field-commission","placement_id":"commission_fenbell_chainstalkers","objective_id":"commission_fenbell_chainstalkers","encounter_id":"encounter_mudkeel_fenbell_commission","army_id":"army_three_banner_mudkeel_nemesis","hero_id":"hero_mireclaw_brakka_mudkeel","faction_id":"faction_mireclaw","field_objective_id":"mudkeel_fenbell_plate","field_objective_type":"cover_line","reward_id":"peatwax","gold":270,"victory_flag":"finale_nemesis_mudkeel_broken","asset_id":"encounter_finale_nemesis_mudkeel_fenbell_shield","atlas_x":432,"source_name":"mudkeel_fenbell_shield.png","source_sha256":"95fe09d94f1d6591baa2513e6db665df26b69943bf3dd39780c133130ceec743","x":9,"y":6,"difficulty":"medium","seed":30702,"optional_expected":false},
	{"scenario_id":"mistcorsair-graftwake-raid","placement_id":"mistcorsair_graftwake_cordon","objective_id":"break_graftwake_cordon","encounter_id":"encounter_graftsibyl_wake_cordon","army_id":"army_graftwake_graftsibyl_nemesis","hero_id":"hero_thornwake_nara_graftsibyl","faction_id":"faction_thornwake","field_objective_id":"graftsibyl_wake_arch","field_objective_type":"cover_line","reward_id":"verdant_grafts","gold":270,"victory_flag":"finale_nemesis_graftsibyl_broken","asset_id":"encounter_finale_nemesis_graftsibyl_prophecy_arch","atlas_x":480,"source_name":"graftsibyl_prophecy_arch.png","source_sha256":"5a9c45b528f7835981b5d392b145dfe5d2b1ea7619a2ffeacfdd3f8edd8c5d76","x":8,"y":4,"difficulty":"medium","seed":25603,"optional_expected":false},
	{"scenario_id":"daynote-kite-signal-accord","placement_id":"daynote_screen_c","objective_id":"clear_daynote_screen_c","encounter_id":"encounter_seedseer_kite_root_omen","army_id":"army_daynote_seedseer_nemesis","hero_id":"hero_thornwake_veyra_seedseer","faction_id":"faction_thornwake","field_objective_id":"seedseer_kite_eye","field_objective_type":"hazard_zone","reward_id":"verdant_grafts","gold":270,"victory_flag":"finale_nemesis_seedseer_broken","asset_id":"encounter_finale_nemesis_seedseer_root_kite","atlas_x":528,"source_name":"seedseer_root_kite.png","source_sha256":"ae7142561446a54005d42112b2c1363c131699736ec4ef4abf50e00c092e1eb0","x":8,"y":1,"difficulty":"medium","seed":26123,"optional_expected":false},
	{"scenario_id":"mossvein-switchback-circuit","placement_id":"mossvein_relay_d","objective_id":"clear_mossvein_relay_d","encounter_id":"encounter_gaugesavant_switchback_proof","army_id":"army_mossvein_gaugesavant_nemesis","hero_id":"hero_brasshollow_lina_gaugesavant","faction_id":"faction_brasshollow","field_objective_id":"gaugesavant_switchback_dial","field_objective_type":"signal_beacon","reward_id":"brass_scrip","gold":280,"victory_flag":"finale_nemesis_gaugesavant_broken","asset_id":"encounter_finale_nemesis_gaugesavant_precision_gauge","atlas_x":576,"source_name":"gaugesavant_precision_gauge.png","source_sha256":"218f95536ed27b48c36d7f29ff15f517ea29106052a65c1e168e45a15b76df2b","x":10,"y":5,"difficulty":"medium","seed":26234,"optional_expected":false},
	{"scenario_id":"ashmeter-dustjack-circuit","placement_id":"ashmeter_relay_d","objective_id":"clear_ashmeter_relay_d","encounter_id":"encounter_keelwarden_dustjack_screen","army_id":"army_ashmeter_keelwarden_nemesis","hero_id":"hero_veilmourn_jessa_keelwarden","faction_id":"faction_veilmourn","field_objective_id":"keelwarden_dustjack_keel","field_objective_type":"obstruction_line","reward_id":"memory_salt","gold":280,"victory_flag":"finale_nemesis_keelwarden_broken","asset_id":"encounter_finale_nemesis_keelwarden_fog_shield","atlas_x":624,"source_name":"keelwarden_fog_shield.png","source_sha256":"5e11063e9198980cfaf5f5aa591024fd3211e74556f25335ab607ef3ffbb6e85","x":10,"y":5,"difficulty":"medium","seed":26244,"optional_expected":false},
	{"scenario_id":"obituaryink-frostwharf-house","placement_id":"obituaryink_screen_b","objective_id":"clear_obituaryink_screen_b","encounter_id":"encounter_beaconscribe_frostwharf_writ","army_id":"army_frostwharf_beaconscribe_nemesis","hero_id":"hero_embercourt_jorun_beaconscribe","faction_id":"faction_embercourt","field_objective_id":"beaconscribe_frost_quill","field_objective_type":"signal_beacon","reward_id":"embergrain","gold":270,"victory_flag":"finale_nemesis_beaconscribe_broken","asset_id":"encounter_finale_nemesis_beaconscribe_quill_beacon","atlas_x":672,"source_name":"beaconscribe_quill_beacon.png","source_sha256":"57aa2c24c4705cd45b788d4fed95db19a070b530b1537d1bfa04d03f4627184c","x":6,"y":3,"difficulty":"medium","seed":26052,"optional_expected":false},
	{"scenario_id":"cinderquill-fenhound-lexicon","placement_id":"cinderquill_screen_c","objective_id":"clear_cinderquill_screen_c","encounter_id":"encounter_reedscript_fenhound_lexicon","army_id":"army_fenhound_reedscript_nemesis","hero_id":"hero_mireclaw_pell_reedscript","faction_id":"faction_mireclaw","field_objective_id":"reedscript_fenhound_codex","field_objective_type":"supply_post","reward_id":"peatwax","gold":270,"victory_flag":"finale_nemesis_reedscript_broken","asset_id":"encounter_finale_nemesis_reedscript_antler_codex","atlas_x":720,"source_name":"reedscript_antler_codex.png","source_sha256":"0bedb139ab718b7aeae689012480a9e9cc2e7df6b6c11f12b8dae73c5308e997","x":8,"y":1,"difficulty":"medium","seed":26103,"optional_expected":false},
	{"scenario_id":"reedscript-reedbarge-circuit","placement_id":"reedscript_relay_d","objective_id":"clear_reedscript_relay_d","encounter_id":"encounter_lenscaptain_reedbarge_survey","army_id":"army_reedbarge_lenscaptain_nemesis","hero_id":"hero_sunvault_dovan_lenscaptain","faction_id":"faction_sunvault","field_objective_id":"lenscaptain_reedbarge_mast","field_objective_type":"lane_battery","reward_id":"aetherglass","gold":280,"victory_flag":"finale_nemesis_lenscaptain_broken","asset_id":"encounter_finale_nemesis_lenscaptain_survey_mast","atlas_x":768,"source_name":"lenscaptain_survey_mast.png","source_sha256":"9431cc05f5d364d81e64d422e7211b42d56ef3bba3bfc530c05725473f553657","x":10,"y":5,"difficulty":"medium","seed":26214,"optional_expected":false},
	{"scenario_id":"sunvein-crystal-sump-circuit","placement_id":"sunvein_relay_d","objective_id":"clear_sunvein_relay_d","encounter_id":"encounter_loamchant_crystal_sump_binding","army_id":"army_crystal_sump_loamchant_nemesis","hero_id":"hero_thornwake_elian_loamchant","faction_id":"faction_thornwake","field_objective_id":"loamchant_sump_harp","field_objective_type":"ritual_pylon","reward_id":"verdant_grafts","gold":280,"victory_flag":"finale_nemesis_loamchant_broken","asset_id":"encounter_finale_nemesis_loamchant_crystal_harp","atlas_x":816,"source_name":"loamchant_crystal_harp.png","source_sha256":"21bbdd58e6644461ae27f2ea3d6a5626bb5dfeb1b502f600bc89a2185e9699fa","x":10,"y":5,"difficulty":"medium","seed":26224,"optional_expected":false},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not image.is_empty() and image.get_size() == Vector2i(864, 48) and image.detect_alpha() != Image.ALPHA_NONE, "Campaign-finale nemesis atlas must remain a transparent 864x48 strip.")
	_expect(FileAccess.get_sha256(ATLAS_PATH) == ATLAS_SHA256, "Campaign-finale nemesis atlas bytes changed.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, case_value.get("encounter_id", "")])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, case_value.get("encounter_id", "")])
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"named_finale_nemesis_count":CASES.size(),"atlas_path":ATLAS_PATH,"atlas_size":[864,48],"atlas_sha256":ATLAS_SHA256,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var hero_id := String(case.get("hero_id", ""))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	var placement := _encounter(session, placement_id)
	var commander_seed: Dictionary = placement.get("enemy_commander_state", {}) if placement.get("enemy_commander_state", {}) is Dictionary else {}
	var placement_exact := String(placement.get("encounter_id", "")) == encounter_id and bool(placement.get("prefer_identity_landmark", false)) and String(commander_seed.get("roster_hero_id", "")) == hero_id and String(placement.get("spawned_by_faction_id", "")) == String(case.get("faction_id", "")) and int(placement.get("x", -1)) == int(case.get("x", -2)) and int(placement.get("y", -1)) == int(case.get("y", -2)) and String(placement.get("difficulty", "")) == String(case.get("difficulty", "")) and int(placement.get("combat_seed", -1)) == int(case.get("seed", -2)) and not placement.has("enemy_army")
	_expect(placement_exact, "%s lost its preserved placement data or fixed named-nemesis identity." % encounter_id)
	var encounter := ContentService.get_encounter(encounter_id)
	var army := ContentService.get_army_group(String(case.get("army_id", "")))
	var hero := ContentService.get_hero(hero_id)
	var objective := _objective(encounter.get("field_objectives", []), String(case.get("field_objective_id", "")))
	var army_exact := String(encounter.get("enemy_group_id", "")) == String(case.get("army_id", "")) and String(army.get("faction_id", "")) == String(case.get("faction_id", "")) and (army.get("stacks", []) as Array).size() == 3
	_expect(army_exact, "%s lost its exact three-stack production faction army." % encounter_id)
	_expect(String(encounter.get("enemy_commander", {}).get("roster_hero_id", "")) == hero_id and String(objective.get("type", "")) == String(case.get("field_objective_type", "")), "%s lost its roster hero or tactical objective." % encounter_id)
	var source_path := "res://art/overworld/source/generated/encounters/campaign_finale_nemeses/%s" % String(case.get("source_name", ""))
	_expect(FileAccess.get_sha256(source_path) == String(case.get("source_sha256", "")), "%s source provenance changed." % encounter_id)
	_set_active_hero_position(session, Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and String(presentation.get("identity_encounter_path", "")) == ATLAS_PATH and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == Rect2(float(case.get("atlas_x", 0)), 0.0, 48.0, 48.0) and texture.atlas.get_size() == Vector2(864, 48)
	_expect(exact_art, "%s did not resolve its exact campaign-finale landmark frame." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)
	var resources_before := (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	_expect(not battle.is_empty() and String(battle.get("enemy_army_id", "")) == String(case.get("army_id", "")), "%s did not construct its exact live battle." % encounter_id)
	if battle.is_empty():
		return
	var enemy_hero: Dictionary = battle.get("enemy_hero", {}) if battle.get("enemy_hero", {}) is Dictionary else {}
	var enemy_payload: Dictionary = battle.get("enemy_hero_payload", {}) if battle.get("enemy_hero_payload", {}) is Dictionary else {}
	var known_spells: Array = enemy_hero.get("spellbook", {}).get("known_spell_ids", []) if enemy_hero.get("spellbook", {}) is Dictionary else []
	var portrait_path := String(ContentService.get_hero_art(hero_id).get("portrait", ""))
	var expected_commander := EnemyAdventureRulesScript.build_roster_commander_state(
		hero_id,
		String(case.get("faction_id", "")),
		commander_seed
	)
	var commander_checks := {
		"state_roster_id": String(enemy_hero.get("roster_hero_id", "")) == hero_id,
		"payload_roster_id": String(enemy_payload.get("roster_hero_id", "")) == hero_id,
		"name": String(enemy_hero.get("name", "")) == String(hero.get("name", "")),
		"command": enemy_hero.get("command", {}) == expected_commander.get("command", {}),
		"command_base_floor": _command_at_least(enemy_hero.get("command", {}), hero.get("command", {})),
		"spellbook": known_spells == hero.get("starting_spell_ids", []),
		"specialties": _specialty_ids(enemy_hero.get("specialties", [])) == hero.get("starting_specialties", []),
		"traits": enemy_hero.get("battle_traits", []) == hero.get("battle_traits", []),
		"portrait": load(portrait_path) is Texture2D,
	}
	var commander_exact: bool = commander_checks.values().all(func(value): return bool(value))
	_expect(commander_exact, "%s did not hydrate canonical roster details: %s" % [encounter_id, JSON.stringify(commander_checks)])
	session.battle = battle
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution := BattleRulesScript.resolve_if_battle_ready(session)
	var resources_after: Dictionary = session.overworld.get("resources", {})
	var reward_id := String(case.get("reward_id", ""))
	var reward_exact := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0)) == int(case.get("gold", -1)) and int(resources_after.get(reward_id, 0)) - int(resources_before.get(reward_id, 0)) == 1
	var objective_id := String(case.get("objective_id", ""))
	var optional_expected := bool(case.get("optional_expected", false))
	var authored_objective_reference := _scenario_victory_references_placement(scenario_id, placement_id)
	_expect(authored_objective_reference != optional_expected, "%s changed its authored mandatory or optional finale role." % encounter_id)
	var objective_met := objective_id == "" or ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement) and objective_met and reward_exact and bool(session.flags.get(String(case.get("victory_flag", "")), false)), "%s did not resolve its objective, reward, or victory flag through live authority." % encounter_id)
	var authority := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority)
	var save_exact := restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"encounter_id":encounter_id,"hero_id":hero_id,"placement_exact":placement_exact,"army_exact":army_exact,"named_commander_exact":commander_exact,"commander_checks":commander_checks,"objective_met":objective_met,"optional_expected":optional_expected,"authored_objective_reference":authored_objective_reference,"reward_exact":reward_exact,"exact_art":exact_art,"capture_path":capture_path,"save_round_trip_exact":save_exact})
	SessionState.set_active_session(null)


func _scenario_victory_references_placement(scenario_id: String, placement_id: String) -> bool:
	var scenario := ContentService.get_scenario(scenario_id)
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	for entry in objectives.get("victory", []):
		if entry is Dictionary and String(entry.get("type", "")) == "encounter_resolved" and String(entry.get("placement_id", "")) == placement_id:
			return true
	return false


func _specialty_ids(value: Variant) -> Array:
	var result := []
	for entry in value if value is Array else []:
		var specialty_id := String(entry.get("id", "")) if entry is Dictionary else String(entry)
		if specialty_id != "" and specialty_id not in result:
			result.append(specialty_id)
	return result


func _command_at_least(actual_value: Variant, base_value: Variant) -> bool:
	var actual: Dictionary = actual_value if actual_value is Dictionary else {}
	var base: Dictionary = base_value if base_value is Dictionary else {}
	for key in ["attack", "defense", "power", "knowledge"]:
		if int(actual.get(key, -1)) < int(base.get(key, 0)):
			return false
	return true


func _objective(value: Variant, objective_id: String) -> Dictionary:
	for entry in value if value is Array else []:
		if entry is Dictionary and String(entry.get("id", "")) == objective_id:
			return entry
	return {}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and String(entry.get("placement_id", "")) == placement_id:
			return entry
	return {}


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("CAMPAIGN_NEMESIS_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
