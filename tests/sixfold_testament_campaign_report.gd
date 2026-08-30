extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIXFOLD_TESTAMENT_CAMPAIGN_REPORT"
const OUTPUT_DIR := "res://.artifacts/sixfold_testament_campaign_report"
const CAMPAIGN_ID := "campaign_sixfold_testament"
const TABLE_ID := "artifact_source_guarded_sites_faction_relics"
const CASES := [
	{"scenario_id":"rainledger-cinder-convergence","faction_id":"faction_embercourt","hero_id":"hero_embercourt_belis_rainledger","army_id":"army_belis_grand_convergence_company","site_id":"site_lantern_crown_nave","site_placement_id":"rainledger_lantern_crown_nave","guard_placement_id":"rainledger_lantern_crown_guard","guard_encounter_id":"encounter_lantern_warren_watch","artifact_id":"artifact_lockfire_assize_seal","flag":"lantern_crown_nave_consecrated","battle_count":7},
	{"scenario_id":"fenwake-bogbell-convergence","faction_id":"faction_mireclaw","hero_id":"hero_mireclaw_zhorra_fenwake","army_id":"army_zhorra_grand_convergence_company","site_id":"site_hive_of_reeds","site_placement_id":"fenwake_hive_of_reeds","guard_placement_id":"fenwake_hive_of_reeds_guard","guard_encounter_id":"encounter_bogbell_croft_watch","artifact_id":"artifact_miremoon_hunt_drum","flag":"hive_of_reeds_reclaimed","battle_count":7},
	{"scenario_id":"halometer-icehook-convergence","faction_id":"faction_sunvault","hero_id":"hero_sunvault_mirro_halometer","army_id":"army_mirro_grand_convergence_company","site_id":"site_glassbound_eyrie","site_placement_id":"halometer_glassbound_eyrie","guard_placement_id":"halometer_glassbound_eyrie_guard","guard_encounter_id":"encounter_cliffhawk_roost_watch","artifact_id":"artifact_noonglass_orrery","flag":"glassbound_eyrie_secured","battle_count":7},
	{"scenario_id":"graftsibyl-lantern-convergence","faction_id":"faction_thornwake","hero_id":"hero_thornwake_nara_graftsibyl","army_id":"army_nara_grand_convergence_company","site_id":"site_rootwarden_stockade","site_placement_id":"graftsibyl_rootwarden_stockade","guard_placement_id":"graftsibyl_rootwarden_stockade_guard","guard_encounter_id":"encounter_bramble_hedge_watch","artifact_id":"artifact_worldroot_covenant_heartwood","flag":"rootwarden_stockade_reclaimed","battle_count":7},
	{"scenario_id":"debtrune-default-convergence","faction_id":"faction_brasshollow","hero_id":"hero_brasshollow_harro_debtrune","army_id":"army_harro_grand_convergence_company","site_id":"site_rust_choir_foundry","site_placement_id":"debtrune_rust_choir_foundry","guard_placement_id":"debtrune_rust_choir_foundry_guard","guard_encounter_id":"encounter_cinder_kiln_watch","artifact_id":"artifact_seventh_clause_pressure_key","flag":"rust_choir_foundry_silenced","battle_count":8},
	{"scenario_id":"nightchart-meridian-convergence","faction_id":"faction_veilmourn","hero_id":"hero_veilmourn_orso_nightchart","army_id":"army_orso_grand_convergence_company","site_id":"site_salt_wight_convoy","site_placement_id":"nightchart_salt_wight_convoy","guard_placement_id":"nightchart_salt_wight_convoy_guard","guard_encounter_id":"encounter_saltpan_camp_watch","artifact_id":"artifact_last_bell_tideglass","flag":"salt_wight_convoy_cleared","battle_count":7},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == CASES.size(), "Sixfold Testament is not a complete six-chapter campaign.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	var profile := CampaignRulesScript.normalize_profile({})
	var expected_carryover := {}
	var previous_artifact_id := ""
	var previous_scenario_id := ""
	var previous_flag := ""
	for index in range(CASES.size()):
		var case: Dictionary = CASES[index]
		var scenario_id := String(case.get("scenario_id", ""))
		var action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, scenario_id)
		_expect(not bool(action.get("disabled", true)), "%s did not unlock from the exact preceding victory and guarded-road flag." % scenario_id)
		var baseline = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		var session = CampaignRulesScript.build_session(profile, scenario_id, "normal", CAMPAIGN_ID)
		_expect(session != null and session.scenario_id == scenario_id, "%s did not build as a campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_validate_opening(session, baseline, case, expected_carryover, previous_scenario_id, previous_flag, previous_artifact_id, index)
		_validate_scenario_contract(session, case)
		_validate_battles(session, case)
		_validate_guarded_relic(session, case)
		session.scenario_status = "victory"
		session.scenario_summary = "%s completed with its guarded testimony." % scenario_id
		_validate_save_round_trip(session)
		await _capture_map(view, session, case)
		expected_carryover = _expected_carryover(session.overworld.get("resources", {}))
		previous_artifact_id = String(case.get("artifact_id", ""))
		previous_scenario_id = scenario_id
		previous_flag = String(case.get("flag", ""))
		profile = CampaignRulesScript.record_session_completion(profile, session)
	_validate_art(campaign)
	_expect(CampaignRulesScript._campaign_is_completed(profile, CAMPAIGN_ID), "Sixfold Testament did not complete after all six exact victories.")
	var battle_total: int = int(_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0))
	var report := {
		"ok":_errors.is_empty(), "campaign_id":CAMPAIGN_ID, "scenario_count":_rows.size(),
		"battle_payload_count":battle_total, "guarded_relic_count":_rows.filter(func(row): return bool(row.get("guarded_relic_claimed", false))).size(),
		"cross_faction_resource_only_carryover":_errors.is_empty(), "save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"scenario_count":6,"battle_payload_count":battle_total,"guarded_relic_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_opening(session, baseline, case: Dictionary, expected_carryover: Dictionary, previous_scenario_id: String, previous_flag: String, previous_artifact_id: String, index: int) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	_expect(session.launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == CAMPAIGN_ID, "%s lost its campaign launch identity." % scenario_id)
	_expect(String(session.overworld.get("active_hero_id", "")) == String(case.get("hero_id", "")), "%s launched with the wrong commander." % scenario_id)
	if index == 0:
		return
	_expect(String(session.flags.get("campaign_previous_scenario_id", "")) == previous_scenario_id and bool(session.flags.get("carryover_%s" % previous_flag, false)), "%s did not import exact prior testimony." % scenario_id)
	var actual_resources: Dictionary = session.overworld.get("resources", {})
	var baseline_resources: Dictionary = baseline.overworld.get("resources", {})
	for resource_id in ["gold", "wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]:
		var delta := int(actual_resources.get(resource_id, 0)) - int(baseline_resources.get(resource_id, 0))
		_expect(delta == int(expected_carryover.get(resource_id, 0)), "%s imported unexpected %s carryover: %d." % [scenario_id, resource_id, delta])
	var hero: Dictionary = session.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline.overworld.get("hero", {})
	_expect(int(hero.get("level", 0)) == int(baseline_hero.get("level", 0)), "%s inherited another commander's progression." % scenario_id)
	_expect(hero.get("spellbook", {}).get("known_spell_ids", []) == baseline_hero.get("spellbook", {}).get("known_spell_ids", []), "%s inherited another commander's spells." % scenario_id)
	_expect(JSON.stringify(hero.get("artifacts", {})) == JSON.stringify(baseline_hero.get("artifacts", {})), "%s inherited another commander's artifacts." % scenario_id)
	_expect(previous_artifact_id not in ArtifactRules.owned_artifact_ids(hero), "%s carried the prior faction relic into a new command." % scenario_id)


func _validate_scenario_contract(session, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var size: Dictionary = scenario.get("map_size", {})
	_expect(Vector2i(int(size.get("width", 0)), int(size.get("height", 0))) == Vector2i(14, 9), "%s lost its 14x9 authored map." % scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and String(scenario.get("player_army_id", "")) == String(case.get("army_id", "")), "%s lost its exact faction, hero, or army." % scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == 17 and (scenario.get("towns", []) as Array).size() == 2, "%s lost its 17-site / two-town campaign breadth." % scenario_id)
	_expect((scenario.get("encounters", []) as Array).size() == int(case.get("battle_count", 0)), "%s lost an authored battle front." % scenario_id)


func _validate_battles(session, case: Dictionary) -> void:
	var count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
		_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
		if not battle.is_empty():
			count += 1
	_expect(count == int(case.get("battle_count", 0)), "%s constructed %d battle payloads instead of %d." % [session.scenario_id, count, int(case.get("battle_count", 0))])
	_rows.append({"scenario_id":session.scenario_id,"battle_count":count,"guarded_relic_claimed":false,"save_round_trip_exact":false})


func _validate_guarded_relic(session, case: Dictionary) -> void:
	var site_placement_id := String(case.get("site_placement_id", ""))
	var guard_placement_id := String(case.get("guard_placement_id", ""))
	var node_result := _resource_node_result(session, site_placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var guard := _encounter(session, guard_placement_id)
	_expect(String(node.get("guard_front_id", "")) == guard_placement_id and String(guard.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s lost its exact guard ownership." % site_placement_id)
	_expect(String(site.get("guarded_reward_contract", {}).get("artifact_reward_table_id", "")) == TABLE_ID, "%s lost the faction relic table." % site_placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, false)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before its guard." % site_placement_id)
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	resolved.append(guard_placement_id)
	session.overworld["resolved_encounters"] = resolved
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), false)
	var artifact_id := String(case.get("artifact_id", ""))
	var claimed_node: Dictionary = _resource_node_result(session, site_placement_id).get("node", {})
	_expect(bool(claim.get("ok", false)) and bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not claim its guarded testimony." % site_placement_id)
	_expect(artifact_id in ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {})), "%s did not grant %s." % [site_placement_id, artifact_id])
	_expect(String(claimed_node.get("artifact_reward_id", "")) == artifact_id and String(claimed_node.get("artifact_reward_table_id", "")) == TABLE_ID and String(claimed_node.get("artifact_reward_claimed_by_faction_id", "")) == "player", "%s lost deterministic relic provenance." % site_placement_id)
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), false)
	_expect(not bool(repeat.get("ok", true)), "%s granted its guarded relic twice." % site_placement_id)
	if not _rows.is_empty():
		_rows[-1]["guarded_relic_claimed"] = bool(claim.get("ok", false))
		_rows[-1]["artifact_id"] = artifact_id


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var exact: bool = restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(exact, "%s did not round-trip exactly through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])
	if not _rows.is_empty():
		_rows[-1]["save_round_trip_exact"] = exact


func _expected_carryover(resources: Variant) -> Dictionary:
	var source: Dictionary = resources if resources is Dictionary else {}
	return {
		"gold":mini(600, int(floor(maxi(0, int(source.get("gold", 0))) * 0.2))),
		"wood":mini(2, int(floor(maxi(0, int(source.get("wood", 0))) * 0.2))),
		"ore":mini(2, int(floor(maxi(0, int(source.get("ore", 0))) * 0.2))),
	}


func _capture_map(view: Control, session, case: Dictionary) -> void:
	_reveal_all(session)
	var node: Dictionary = _resource_node_result(session, String(case.get("site_placement_id", ""))).get("node", {})
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, String(case.get("scenario_id", ""))]
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "Could not capture %s." % session.scenario_id)


func _reveal_all(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {"visible_tiles":visible_tiles,"explored_tiles":explored_tiles,"visible_count":map_size.x*map_size.y,"explored_count":map_size.x*map_size.y,"total_tiles":map_size.x*map_size.y}


func _validate_art(campaign: Dictionary) -> void:
	var records := [{"path":String(campaign.get("emblem_path", "")),"size":Vector2i(128,128),"hash":String(campaign.get("emblem_runtime_sha256", ""))}]
	for chapter_value in campaign.get("scenarios", []):
		var chapter: Dictionary = chapter_value
		records.append({"path":String(chapter.get("seal_path", "")),"size":Vector2i(64,64),"hash":String(chapter.get("seal_runtime_sha256", ""))})
	var hashes := {}
	var strip := Image.create(512, 192, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0,0,0,0))
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var path := String(record.get("path", ""))
		var absolute := ProjectSettings.globalize_path(path)
		var image := Image.load_from_file(absolute)
		var digest := FileAccess.get_sha256(absolute)
		_expect(not image.is_empty() and image.get_size() == record.get("size") and image.detect_alpha() != Image.ALPHA_NONE and digest == String(record.get("hash", "")), "%s lost its exact alpha-safe runtime art." % path)
		hashes[digest] = true
		if not image.is_empty():
			var position := Vector2i(0,0) if index == 0 else Vector2i(128 + ((index - 1) % 4) * 64, ((index - 1) / 4) * 64)
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), position)
	_expect(hashes.size() == 7, "The Sixfold Testament campaign art is not seven byte-distinct identities.")
	_expect(strip.save_png("%s/campaign_emblem_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the Sixfold Testament art strip.")


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


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
