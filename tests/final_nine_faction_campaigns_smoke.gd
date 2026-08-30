extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FINAL_NINE_FACTION_CAMPAIGNS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/final_nine_faction_campaigns_smoke"
const ARCS := [
	{
		"campaign_id":"campaign_coalwater_ordinance",
		"cases":[
			{"scenario_id":"tollbrand-blackwake-levy", "hero_id":"hero_embercourt_helva_tollbrand", "faction_id":"faction_embercourt", "guard_id":"tollbrand_blackwake_levy", "proof_flag":"tollbrand_blackwake_obituary_mooring_broken", "hook_id":"tollbrand_boss_broken", "size":Vector2i(11,6), "node_count":10, "battle_count":3, "hook_count":5, "objective_count":4},
			{"scenario_id":"lockmaster-cinder-kiln", "hero_id":"hero_embercourt_saren_lockmaster", "faction_id":"faction_embercourt", "guard_id":"lockmaster_cinder_kiln_watch", "proof_flag":"lockmaster_cinder_kiln_watch_cleared", "hook_id":"lockmaster_watch_cleared", "size":Vector2i(11,6), "node_count":12, "battle_count":4, "hook_count":5, "objective_count":4},
			{"scenario_id":"cinderquill-fenhound-lexicon", "hero_id":"hero_embercourt_orra_cinderquill", "faction_id":"faction_embercourt", "guard_id":"cinderquill_fenhound_kennel_watch", "proof_flag":"cinderquill_fenhound_kennel_watch_secured", "hook_id":"cinderquill_watch_secured", "size":Vector2i(12,7), "node_count":12, "battle_count":4, "hook_count":6, "objective_count":5},
		]
	},
	{
		"campaign_id":"campaign_siltbound_writ",
		"cases":[
			{"scenario_id":"fenhook-daybreak-hunt", "hero_id":"hero_tarn", "faction_id":"faction_mireclaw", "guard_id":"fenhook_daybreak_hunt", "proof_flag":"fenhook_daybreak_reed_prism_broken", "hook_id":"fenhook_boss_broken", "size":Vector2i(11,6), "node_count":10, "battle_count":3, "hook_count":5, "objective_count":4},
			{"scenario_id":"tollreaver-roadward-lodge", "hero_id":"hero_orrik", "faction_id":"faction_mireclaw", "guard_id":"tollreaver_roadward_lodge_watch", "proof_flag":"tollreaver_roadward_lodge_watch_cleared", "hook_id":"tollreaver_watch_cleared", "size":Vector2i(11,6), "node_count":11, "battle_count":3, "hook_count":5, "objective_count":4},
			{"scenario_id":"reedscript-reedbarge-circuit", "hero_id":"hero_mireclaw_pell_reedscript", "faction_id":"faction_mireclaw", "guard_id":"reedscript_reedbarge_mooring_watch", "proof_flag":"reedscript_reedbarge_mooring_watch_secured", "hook_id":"reedscript_watch_secured", "size":Vector2i(13,8), "node_count":14, "battle_count":5, "hook_count":7, "objective_count":6},
		]
	},
	{
		"campaign_id":"campaign_broken_meridian",
		"cases":[
			{"scenario_id":"choirward-foundry-eclipse", "hero_id":"hero_thalen", "faction_id":"faction_sunvault", "guard_id":"choirward_foundry_eclipse", "proof_flag":"choirward_foundry_eclipse_gauge_broken", "hook_id":"choirward_boss_broken", "size":Vector2i(11,6), "node_count":10, "battle_count":3, "hook_count":5, "objective_count":4},
			{"scenario_id":"facetlane-cliffhawk-roost", "hero_id":"hero_sunvault_renn_facetlane", "faction_id":"faction_sunvault", "guard_id":"facetlane_cliffhawk_roost_watch", "proof_flag":"facetlane_cliffhawk_roost_watch_cleared", "hook_id":"facetlane_watch_cleared", "size":Vector2i(11,6), "node_count":10, "battle_count":3, "hook_count":5, "objective_count":4},
			{"scenario_id":"sunvein-crystal-sump-circuit", "hero_id":"hero_sunvault_calis_sunvein", "faction_id":"faction_sunvault", "guard_id":"sunvein_crystal_sump_watch", "proof_flag":"sunvein_crystal_sump_watch_secured", "hook_id":"sunvein_watch_secured", "size":Vector2i(13,8), "node_count":15, "battle_count":5, "hook_count":7, "objective_count":6},
		]
	},
]
const ART_RECORDS := [
	{"path":"res://art/campaigns/runtime/emblems/coalwater_ordinance.png", "size":Vector2i(128,128), "hash":"578193deb74feb4403c273033072ca21a9cfd30d28e8c77aa340534e04c6287d"},
	{"path":"res://art/campaigns/runtime/chapter_seals/blackwake_mooring_proof.png", "size":Vector2i(64,64), "hash":"0dbcefcc6d4d0cf4acf06d2f446dd49461efc6ac9d29bd7666ecb49d4bfe5eb1"},
	{"path":"res://art/campaigns/runtime/chapter_seals/cinder_kiln_warrant.png", "size":Vector2i(64,64), "hash":"45bba90037e56e42845f59ae9318666f599435d60ae98afe2303daf1f3ed7db0"},
	{"path":"res://art/campaigns/runtime/chapter_seals/fenhound_lexicon_proof.png", "size":Vector2i(64,64), "hash":"28ebb14d6ecb15b5a8c62937a48a368c8ca68ac27dd27d3e8d3d5b77638d8c4b"},
	{"path":"res://art/campaigns/runtime/emblems/siltbound_writ.png", "size":Vector2i(128,128), "hash":"f92e9d6dcbeade2115e584de4dfa29df7da4da2ae711ab742ec5ef21d7668843"},
	{"path":"res://art/campaigns/runtime/chapter_seals/daybreak_reed_prism.png", "size":Vector2i(64,64), "hash":"4d78a6ac4868df2fc9d31a218887ab5cd0fb0a7e2a5612bb8cb0087094fdc76c"},
	{"path":"res://art/campaigns/runtime/chapter_seals/roadward_lodge_toll.png", "size":Vector2i(64,64), "hash":"a6413f80baff8a2f45866a6cad127943e606447673f13631771d23fb24b61a08"},
	{"path":"res://art/campaigns/runtime/chapter_seals/reedbarge_relay_proof.png", "size":Vector2i(64,64), "hash":"41a6a28c2ced9e406a9448b0f979a99137bf70d173799070f74c5cae4148e241"},
	{"path":"res://art/campaigns/runtime/emblems/broken_meridian.png", "size":Vector2i(128,128), "hash":"cafc23931f0c9e3b964fb9d1932cd6e83b38bda950a52267d92bb6151484a8a8"},
	{"path":"res://art/campaigns/runtime/chapter_seals/foundry_eclipse_gauge.png", "size":Vector2i(64,64), "hash":"257133bad9e146b75cd62d0080007da6756d371611e6f8f66ff0d80d2b1a524c"},
	{"path":"res://art/campaigns/runtime/chapter_seals/cliffhawk_sightline.png", "size":Vector2i(64,64), "hash":"e375cdd145fdf3d9e160dde7d2b2eeeacbd5e27892d6191dbc53a4cf7c358b0f"},
	{"path":"res://art/campaigns/runtime/chapter_seals/crystal_sump_relay.png", "size":Vector2i(64,64), "hash":"7e50844b59d8a4562d26c92d40ea1cf030b989eab72b6fa2bef896f6db1357fc"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("%s START" % REPORT_ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for arc_value in ARCS:
		var arc: Dictionary = arc_value
		await _validate_arc(view, arc)
	_validate_art()
	var battle_total: int = int(_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0))
	var report := {"ok":_errors.is_empty(), "campaign_count":ARCS.size(), "scenario_count":_rows.size(), "battle_payload_count":battle_total, "proof_count":_rows.size(), "resource_only_carryover":_errors.is_empty(), "art_identity_count":ART_RECORDS.size(), "save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true, "campaign_count":3, "scenario_count":9, "battle_payload_count":battle_total, "proof_count":9, "art_identity_count":12, "save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_arc(view: Control, arc: Dictionary) -> void:
	var campaign_id := String(arc.get("campaign_id", ""))
	var cases: Array = arc.get("cases", [])
	var campaign := ContentService.get_campaign(campaign_id)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == cases.size(), "%s is not a complete three-chapter campaign." % campaign_id)
	var profile := CampaignRulesScript.normalize_profile({})
	var expected_carryover := {}
	var previous_scenario_id := ""
	var previous_proof_flag := ""
	for index in range(cases.size()):
		var case: Dictionary = cases[index]
		var scenario_id := String(case.get("scenario_id", ""))
		var action := CampaignRulesScript.build_chapter_action(profile, campaign_id, scenario_id)
		_expect(not bool(action.get("disabled", true)), "%s did not unlock from the preceding exact proof." % scenario_id)
		if index + 1 < cases.size():
			var locked_action := CampaignRulesScript.build_chapter_action(profile, campaign_id, String(cases[index + 1].get("scenario_id", "")))
			_expect(bool(locked_action.get("disabled", false)), "%s unlocked before %s was proved." % [String(cases[index + 1].get("scenario_id", "")), scenario_id])
		var baseline = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		var session = CampaignRulesScript.build_session(profile, scenario_id, "normal", campaign_id)
		_expect(session != null and session.scenario_id == scenario_id, "%s did not build as a campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_validate_opening(session, baseline, case, expected_carryover, previous_scenario_id, previous_proof_flag, index, campaign_id)
		_validate_contract(session, case)
		var battle_count := _validate_battles(session, case)
		_validate_proof(session, case)
		session.scenario_status = "victory"
		session.scenario_summary = "%s recorded its exact campaign proof." % scenario_id
		_validate_save_round_trip(session)
		await _capture_map(view, session, case, campaign_id)
		expected_carryover = _expected_carryover(session.overworld.get("resources", {}))
		previous_scenario_id = scenario_id
		previous_proof_flag = String(case.get("proof_flag", ""))
		profile = CampaignRulesScript.record_session_completion(profile, session)
		_rows.append({"campaign_id":campaign_id, "scenario_id":scenario_id, "battle_count":battle_count, "proof_flag":previous_proof_flag, "save_round_trip_exact":true})
	_expect(CampaignRulesScript._campaign_is_completed(profile, campaign_id), "%s did not complete after all three exact victories." % campaign_id)


func _validate_opening(session, baseline, case: Dictionary, expected: Dictionary, previous_scenario_id: String, previous_proof_flag: String, index: int, campaign_id: String) -> void:
	_expect(session.launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == campaign_id, "%s lost its campaign launch identity." % session.scenario_id)
	_expect(String(session.overworld.get("active_hero_id", "")) == String(case.get("hero_id", "")), "%s launched with the wrong commander." % session.scenario_id)
	if index == 0:
		return
	_expect(String(session.flags.get("campaign_previous_scenario_id", "")) == previous_scenario_id and bool(session.flags.get("carryover_%s" % previous_proof_flag, false)), "%s did not import the exact prior proof." % session.scenario_id)
	var actual_resources: Dictionary = session.overworld.get("resources", {})
	var baseline_resources: Dictionary = baseline.overworld.get("resources", {})
	for resource_id in ["gold", "wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]:
		var delta := int(actual_resources.get(resource_id, 0)) - int(baseline_resources.get(resource_id, 0))
		_expect(delta == int(expected.get(resource_id, 0)), "%s imported unexpected %s carryover: %d." % [session.scenario_id, resource_id, delta])
	var hero: Dictionary = session.overworld.get("hero", {})
	var baseline_hero: Dictionary = baseline.overworld.get("hero", {})
	_expect(int(hero.get("level", 0)) == int(baseline_hero.get("level", 0)), "%s inherited another commander's progression." % session.scenario_id)
	_expect(hero.get("spellbook", {}).get("known_spell_ids", []) == baseline_hero.get("spellbook", {}).get("known_spell_ids", []), "%s inherited another commander's spells." % session.scenario_id)
	_expect(JSON.stringify(hero.get("artifacts", {})) == JSON.stringify(baseline_hero.get("artifacts", {})), "%s inherited another commander's artifacts." % session.scenario_id)
	_expect(JSON.stringify(hero.get("army", {}).get("stacks", [])) == JSON.stringify(baseline_hero.get("army", {}).get("stacks", [])), "%s inherited another commander's units." % session.scenario_id)


func _validate_contract(session, case: Dictionary) -> void:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var size: Dictionary = scenario.get("map_size", {})
	_expect(Vector2i(int(size.get("width", 0)), int(size.get("height", 0))) == case.get("size"), "%s lost its authored board." % session.scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")), "%s lost its faction or hero contract." % session.scenario_id)
	_expect(scenario.get("selection", {}).get("availability", {}) == {"campaign":true, "skirmish":true}, "%s is not live in both campaign and skirmish." % session.scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == int(case.get("node_count", 0)) and (scenario.get("encounters", []) as Array).size() == int(case.get("battle_count", 0)) and (scenario.get("script_hooks", []) as Array).size() == int(case.get("hook_count", 0)) and (scenario.get("objectives", {}).get("victory", []) as Array).size() == int(case.get("objective_count", 0)), "%s lost its exact production board contract." % session.scenario_id)


func _validate_battles(session, case: Dictionary) -> int:
	var count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
			_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
			if not battle.is_empty():
				count += 1
	_expect(count == int(case.get("battle_count", 0)), "%s constructed %d battles instead of %d." % [session.scenario_id, count, int(case.get("battle_count", 0))])
	return count


func _validate_proof(session, case: Dictionary) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	resolved.append(String(case.get("guard_id", "")))
	session.overworld["resolved_encounters"] = resolved
	var result := ScenarioScriptRulesScript.process_hooks(session)
	var proof_flag := String(case.get("proof_flag", ""))
	var hook_id := String(case.get("hook_id", ""))
	_expect(bool(session.flags.get(proof_flag, false)), "%s did not produce its exact campaign proof." % session.scenario_id)
	_expect(hook_id in result.get("fired_ids", []), "%s did not fire its signature hook." % hook_id)
	var repeat := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (hook_id in repeat.get("fired_ids", [])), "%s fired more than once." % hook_id)


func _expected_carryover(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {"gold":mini(400, int(floor(maxi(0, int(resources.get("gold", 0))) * 0.15))), "wood":mini(2, int(floor(maxi(0, int(resources.get("wood", 0))) * 0.15))), "ore":mini(2, int(floor(maxi(0, int(resources.get("ore", 0))) * 0.15)))}


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])


func _capture_map(view: Control, session, case: Dictionary, campaign_id: String) -> void:
	_reveal_all(session)
	var focus := Vector2i.ZERO
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == String(case.get("guard_id", "")):
			focus = Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var filename := "%s__%s.png" % [campaign_id.trim_prefix("campaign_"), session.scenario_id]
	_expect(image != null and not image.is_empty() and image.save_png("%s/%s" % [OUTPUT_DIR, filename]) == OK, "Could not capture %s." % session.scenario_id)


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
	session.overworld["fog"] = {"visible_tiles":visible_tiles, "explored_tiles":explored_tiles, "visible_count":map_size.x*map_size.y, "explored_count":map_size.x*map_size.y, "total_tiles":map_size.x*map_size.y}


func _validate_art() -> void:
	var hashes := {}
	var sheet := Image.create(320, 384, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0,0,0,0))
	for index in range(ART_RECORDS.size()):
		var record: Dictionary = ART_RECORDS[index]
		var path := String(record.get("path", ""))
		var absolute := ProjectSettings.globalize_path(path)
		var image := Image.load_from_file(absolute)
		var digest := FileAccess.get_sha256(absolute)
		_expect(not image.is_empty() and image.get_size() == record.get("size") and image.detect_alpha() != Image.ALPHA_NONE and digest == String(record.get("hash", "")), "%s lost its exact alpha-safe campaign art." % path)
		hashes[digest] = true
		if not image.is_empty():
			var row := int(index / 4)
			var column := index % 4
			var position := Vector2i(0, row * 128) if column == 0 else Vector2i(128 + (column - 1) * 64, row * 128 + 32)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), position)
	_expect(hashes.size() == 12, "The final-nine campaign art is not twelve byte-distinct identities.")
	for arc_value in ARCS:
		var arc: Dictionary = arc_value
		var campaign := ContentService.get_campaign(String(arc.get("campaign_id", "")))
		_expect(not str(campaign.get("emblem_alt_text", "")).strip_edges().is_empty() and not String(campaign.get("emblem_path", "")).is_empty(), "%s lost accessible emblem ownership." % String(arc.get("campaign_id", "")))
		for chapter_value in campaign.get("scenarios", []):
			var chapter: Dictionary = chapter_value
			_expect(not str(chapter.get("seal_alt_text", "")).strip_edges().is_empty() and not String(chapter.get("seal_path", "")).is_empty(), "%s lost accessible seal ownership." % String(chapter.get("scenario_id", "")))
	_expect(sheet.save_png("%s/campaign_emblems_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the final-nine campaign art sheet.")


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
