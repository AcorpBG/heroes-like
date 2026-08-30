extends "res://tests/two_elite_neutral_dwellings_report.gd"

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")

const ACCORD_REPORT_ID := "HORN_GLASS_ACCORD_CAMPAIGN_REPORT"
const ACCORD_OUTPUT_DIR := "res://.artifacts/horn_glass_accord_campaign_report"
const ACCORD_CAMPAIGN_ID := "campaign_horn_glass_accord"
const ACCORD_CASES := [
	{
		"scenario_id":"beaconscribe-frostbeacon-circuit", "site_id":"site_cinderwake_fold", "placement_id":"beaconscribe_cinderwake_fold", "guard_id":"beaconscribe_cinderwake_fold_watch", "encounter_id":"encounter_cinderwake_fold_watch", "unit_id":"unit_neutral_cinderwake_aurochs", "ability_ids":["reach", "shielding"], "unclaimed":"mapobj_cinderwake_fold", "claimed":"resource_site_neutral_cinderwake_fold_controlled", "region":Rect2(48,0,48,48)
	},
	{
		"scenario_id":"vowless-saltpan-circuit", "site_id":"site_tideglass_roost", "placement_id":"vowless_tideglass_roost", "guard_id":"vowless_tideglass_roost_watch", "encounter_id":"encounter_tideglass_roost_watch", "unit_id":"unit_neutral_tideglass_skyrays", "ability_ids":["harry", "volley"], "unclaimed":"mapobj_tideglass_roost", "claimed":"resource_site_neutral_tideglass_roost_controlled", "region":Rect2(144,0,48,48)
	},
	{
		"scenario_id":"three-banner-field-commission", "site_id":"site_cinderwake_fold", "placement_id":"commission_cinderwake_fold", "guard_id":"commission_cinderwake_fold_watch", "encounter_id":"encounter_cinderwake_fold_watch", "unit_id":"unit_neutral_cinderwake_aurochs", "ability_ids":["reach", "shielding"], "unclaimed":"mapobj_cinderwake_fold", "claimed":"resource_site_neutral_cinderwake_fold_controlled", "region":Rect2(48,0,48,48)
	},
	{
		"scenario_id":"three-banner-field-commission", "site_id":"site_tideglass_roost", "placement_id":"commission_tideglass_roost", "guard_id":"commission_tideglass_roost_watch", "encounter_id":"encounter_tideglass_roost_watch", "unit_id":"unit_neutral_tideglass_skyrays", "ability_ids":["harry", "volley"], "unclaimed":"mapobj_tideglass_roost", "claimed":"resource_site_neutral_tideglass_roost_controlled", "region":Rect2(144,0,48,48)
	},
]
const CHAPTERS := [
	{
		"scenario_id":"beaconscribe-frostbeacon-circuit", "hero_id":"hero_embercourt_jorun_beaconscribe", "faction_id":"faction_embercourt", "site_cases":[ACCORD_CASES[0]], "claim_flag":"cinderwake_fold_claimed", "testimony_flag":"horn_glass_cinder_testimony", "hook_id":"beaconscribe_cinderwake_testimony", "battle_count":6
	},
	{
		"scenario_id":"vowless-saltpan-circuit", "hero_id":"hero_veilmourn_nacre_vowless", "faction_id":"faction_veilmourn", "site_cases":[ACCORD_CASES[1]], "claim_flag":"tideglass_roost_claimed", "testimony_flag":"horn_glass_tide_testimony", "hook_id":"vowless_tideglass_testimony", "battle_count":7
	},
	{
		"scenario_id":"three-banner-field-commission", "hero_id":"hero_neral", "faction_id":"faction_sunvault", "site_cases":[ACCORD_CASES[2], ACCORD_CASES[3]], "claim_flag":"horn_glass_accord_convened", "testimony_flag":"horn_glass_accord_convened", "hook_id":"commission_horn_glass_accord", "battle_count":5
	},
]
const ART_RECORDS := [
	{"path":"res://art/campaigns/runtime/emblems/horn_glass_accord.png", "size":Vector2i(128,128), "hash":"20b5186ee703641c6c30b27739a43341d222f734b57878e06bf2aa940828ee30"},
	{"path":"res://art/campaigns/runtime/chapter_seals/bank_cinderwake.png", "size":Vector2i(64,64), "hash":"33dbdd9ab168ad037df80f71fcf65e3072eb42a34dea8db77ec3a0c91feaeefe"},
	{"path":"res://art/campaigns/runtime/chapter_seals/read_tideglass_wake.png", "size":Vector2i(64,64), "hash":"cd5cb10a63192b82796d9f1eaadbb94788f9ff967d099ea7a2b80d1012f2f1fd"},
	{"path":"res://art/campaigns/runtime/chapter_seals/horn_glass_commission.png", "size":Vector2i(64,64), "hash":"ab3ccd75cc552071d236cd6256cbe6c144435e33945ae9c5ba4fc14befd6170a"},
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACCORD_OUTPUT_DIR))
	ContentService.clear_cache()
	var campaign := ContentService.get_campaign(ACCORD_CAMPAIGN_ID)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == 3, "Horn and Glass Accord is not a complete three-chapter campaign.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in ACCORD_CASES:
		print("%s DWELLING_START %s/%s" % [ACCORD_REPORT_ID, String(case_value.get("scenario_id", "")), String(case_value.get("site_id", ""))])
		await _validate_case(view, case_value)
		print("%s DWELLING_DONE %s/%s" % [ACCORD_REPORT_ID, String(case_value.get("scenario_id", "")), String(case_value.get("site_id", ""))])
	var progression_rows := await _validate_campaign_progression(view)
	_validate_campaign_art(campaign)
	var report := {
		"ok":_errors.is_empty(), "campaign_id":ACCORD_CAMPAIGN_ID, "scenario_count":CHAPTERS.size(), "dwelling_case_count":ACCORD_CASES.size(),
		"battle_payload_count":progression_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0),
		"cross_faction_resource_only_carryover":_errors.is_empty(), "art_identity_count":ART_RECORDS.size(),
		"save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true,
		"dwelling_rows":_rows, "progression_rows":progression_rows, "errors":_errors,
	}
	_write_json("%s/report.json" % ACCORD_OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [ACCORD_REPORT_ID, JSON.stringify({"ok":true,"scenario_count":3,"dwelling_case_count":4,"battle_payload_count":int(report.get("battle_payload_count",0)),"art_identity_count":4,"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_campaign_progression(view: Control) -> Array:
	var progression_rows := []
	var profile := CampaignRulesScript.normalize_profile({})
	var expected_carryover := {}
	var previous_scenario_id := ""
	var previous_claim_flag := ""
	for index in range(CHAPTERS.size()):
		var chapter: Dictionary = CHAPTERS[index]
		var scenario_id := String(chapter.get("scenario_id", ""))
		var action := CampaignRulesScript.build_chapter_action(profile, ACCORD_CAMPAIGN_ID, scenario_id)
		_expect(not bool(action.get("disabled", true)), "%s did not unlock from the exact preceding victory and elite claim." % scenario_id)
		var baseline = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		var session = CampaignRulesScript.build_session(profile, scenario_id, "normal", ACCORD_CAMPAIGN_ID)
		_expect(session != null and session.scenario_id == scenario_id, "%s did not build as a Horn and Glass campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_expect(session.launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == ACCORD_CAMPAIGN_ID, "%s lost its campaign launch identity." % scenario_id)
		var scenario := ContentService.get_scenario(scenario_id)
		_expect(session.hero_id == String(chapter.get("hero_id", "")) and String(session.overworld.get("active_hero_id", "")) == session.hero_id and String(scenario.get("player_faction_id", "")) == String(chapter.get("faction_id", "")), "%s launched with the wrong faction or commander." % scenario_id)
		if index > 0:
			_validate_resource_only_import(session, baseline, expected_carryover, previous_scenario_id, previous_claim_flag)
		var battle_count := _validate_all_battles(session, int(chapter.get("battle_count", 0)))
		for case_value in chapter.get("site_cases", []):
			_claim_campaign_dwelling(session, case_value)
		var hook_id := String(chapter.get("hook_id", ""))
		var fired_hook_ids: Array = session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", [])
		var repeat_result := ScenarioScriptRulesScript.process_hooks(session)
		_expect(hook_id in fired_hook_ids and not (hook_id in repeat_result.get("fired_ids", [])) and bool(session.flags.get(String(chapter.get("testimony_flag", "")), false)), "%s did not execute its exact one-time accord testimony hook: %s" % [scenario_id, JSON.stringify(repeat_result)])
		if index < 2:
			_expect(bool(session.flags.get(String(chapter.get("claim_flag", "")), false)), "%s lost the elite claim required by the next chapter." % scenario_id)
		else:
			_expect(bool(session.flags.get("cinderwake_fold_claimed", false)) and bool(session.flags.get("tideglass_roost_claimed", false)) and bool(session.flags.get("horn_glass_accord_convened", false)), "The finale did not convene both local elite claims.")
		_validate_campaign_save(session)
		await _capture_chapter(view, session, chapter)
		expected_carryover = _expected_resource_carryover(session.overworld.get("resources", {}))
		previous_scenario_id = scenario_id
		previous_claim_flag = String(chapter.get("claim_flag", ""))
		session.scenario_status = "victory"
		session.scenario_summary = "%s completed its Horn and Glass testimony." % scenario_id
		profile = CampaignRulesScript.record_session_completion(profile, session)
		progression_rows.append({"scenario_id":scenario_id,"battle_count":battle_count,"claim_flag":String(chapter.get("claim_flag", "")),"hook_id":String(chapter.get("hook_id", "")),"save_round_trip_exact":true})
	_expect(CampaignRulesScript._campaign_is_completed(profile, ACCORD_CAMPAIGN_ID), "Horn and Glass Accord did not complete after all three exact victories.")
	return progression_rows


func _validate_resource_only_import(session, baseline, expected: Dictionary, previous_scenario_id: String, previous_claim_flag: String) -> void:
	_expect(String(session.flags.get("campaign_previous_scenario_id", "")) == previous_scenario_id and bool(session.flags.get("carryover_%s" % previous_claim_flag, false)), "%s did not import exact prior claim testimony." % session.scenario_id)
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
	_expect(JSON.stringify(hero.get("army", {}).get("stacks", [])) == JSON.stringify(baseline_hero.get("army", {}).get("stacks", [])), "%s inherited another commander's recruited units." % session.scenario_id)


func _validate_all_battles(session, expected_count: int) -> int:
	var count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
		_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
		if not battle.is_empty():
			count += 1
	_expect(count == expected_count, "%s constructed %d battles instead of %d." % [session.scenario_id, count, expected_count])
	return count


func _claim_campaign_dwelling(session, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var guard_id := String(case.get("guard_id", ""))
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var guard := _encounter(session, guard_id)
	_expect(String(node.get("guard_front_id", "")) == guard_id and String(guard.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s lost its exact campaign guard link." % placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, false)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before its campaign guard." % placement_id)
	_resolve_guard(session, guard_id)
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), false)
	var flag := "cinderwake_fold_claimed" if String(case.get("site_id", "")) == "site_cinderwake_fold" else "tideglass_roost_claimed"
	_expect(bool(claim.get("ok", false)) and bool(session.flags.get(flag, false)), "%s did not grant its exact local campaign claim: %s" % [placement_id, JSON.stringify(claim)])


func _expected_resource_carryover(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {
		"gold":mini(700, int(floor(maxi(0, int(resources.get("gold", 0))) * 0.25))),
		"wood":mini(2, int(floor(maxi(0, int(resources.get("wood", 0))) * 0.25))),
		"ore":mini(2, int(floor(maxi(0, int(resources.get("ore", 0))) * 0.25))),
	}


func _validate_campaign_save(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])


func _capture_chapter(view: Control, session, chapter: Dictionary) -> void:
	_reveal_all(session)
	var cases: Array = chapter.get("site_cases", [])
	var focus := Vector2i.ZERO
	if not cases.is_empty():
		var node: Dictionary = _resource_node_result(session, String(cases[0].get("placement_id", ""))).get("node", {})
		focus = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [ACCORD_OUTPUT_DIR, session.scenario_id]
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


func _validate_campaign_art(campaign: Dictionary) -> void:
	var hashes := {}
	var strip := Image.create(320, 128, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0,0,0,0))
	for index in range(ART_RECORDS.size()):
		var record: Dictionary = ART_RECORDS[index]
		var path := String(record.get("path", ""))
		var absolute := ProjectSettings.globalize_path(path)
		var image := Image.load_from_file(absolute)
		var digest := FileAccess.get_sha256(absolute)
		_expect(not image.is_empty() and image.get_size() == record.get("size") and image.detect_alpha() != Image.ALPHA_NONE and digest == String(record.get("hash", "")), "%s lost its exact alpha-safe campaign art." % path)
		hashes[digest] = true
		if not image.is_empty():
			var position := Vector2i(0,0) if index == 0 else Vector2i(128 + (index - 1) * 64,32)
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), position)
	_expect(hashes.size() == 4, "Horn and Glass campaign art is not four byte-distinct identities.")
	_expect(String(campaign.get("emblem_path", "")) == String(ART_RECORDS[0].get("path", "")) and String(campaign.get("emblem_runtime_sha256", "")) == String(ART_RECORDS[0].get("hash", "")), "Campaign browser lost the Horn and Glass emblem contract.")
	_expect(strip.save_png("%s/campaign_emblem_and_seals.png" % ACCORD_OUTPUT_DIR) == OK, "Could not save the Horn and Glass campaign art strip.")


func _report_id() -> String:
	return ACCORD_REPORT_ID


func _output_dir() -> String:
	return ACCORD_OUTPUT_DIR


func _capture_environment_name() -> String:
	return "HORN_GLASS_ACCORD_CAPTURE_DIR"


func _cases() -> Array:
	return ACCORD_CASES
