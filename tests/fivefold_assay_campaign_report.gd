extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FIVEFOLD_ASSAY_CAMPAIGN_REPORT"
const OUTPUT_DIR := "res://.artifacts/fivefold_assay_campaign_report"
const CAMPAIGN_ID := "campaign_fivefold_assay"
const CASES := [
	{"scenario_id":"pitmarshal-peat-chain-seizure", "hero_id":"hero_brasshollow_selka_pitmarshal", "guard_id":"pitmarshal_peat_chain_levy", "proof_flag":"pitmarshal_peat_chain_tally_pit_broken", "hook_id":"pitmarshal_boss_broken", "size":Vector2i(11,6), "node_count":10, "battle_count":4, "hook_count":5, "objective_count":4},
	{"scenario_id":"quench-gorefen-audit", "hero_id":"hero_brasshollow_vellum_quench", "guard_id":"quench_gorefen_audit", "proof_flag":"quench_gorefen_debt_totem_broken", "hook_id":"quench_boss_broken", "size":Vector2i(11,6), "node_count":10, "battle_count":3, "hook_count":5, "objective_count":4},
	{"scenario_id":"heatpriest-obsidian-scar", "hero_id":"hero_brasshollow_odrik_heatpriest", "guard_id":"heatpriest_obsidian_scar_watch", "proof_flag":"heatpriest_obsidian_scar_watch_cleared", "hook_id":"heatpriest_watch_cleared", "size":Vector2i(11,6), "node_count":11, "battle_count":3, "hook_count":5, "objective_count":4},
	{"scenario_id":"gaugesavant-milestone-calibration", "hero_id":"hero_brasshollow_lina_gaugesavant", "guard_id":"gaugesavant_milestone_arsenal_watch", "proof_flag":"gaugesavant_milestone_arsenal_watch_secured", "hook_id":"gaugesavant_watch_secured", "size":Vector2i(12,7), "node_count":13, "battle_count":4, "hook_count":6, "objective_count":5},
	{"scenario_id":"ashmeter-dustjack-circuit", "hero_id":"hero_brasshollow_pava_ashmeter", "guard_id":"ashmeter_dustjack_yard_watch", "proof_flag":"ashmeter_dustjack_yard_watch_secured", "hook_id":"ashmeter_watch_secured", "size":Vector2i(13,8), "node_count":14, "battle_count":5, "hook_count":7, "objective_count":6},
]
const ART_RECORDS := [
	{"path":"res://art/campaigns/runtime/emblems/fivefold_assay.png", "size":Vector2i(128,128), "hash":"a62f6353408d061191b744e5c00117ca9d5895ff5ee48eafa04f39499fdd3afc"},
	{"path":"res://art/campaigns/runtime/chapter_seals/peat_chain_tally.png", "size":Vector2i(64,64), "hash":"51c866aff7f449fcd300b0ca3e28db8377901b7b95eebb9b8afb0856ae92ece6"},
	{"path":"res://art/campaigns/runtime/chapter_seals/gorefen_quenchmark.png", "size":Vector2i(64,64), "hash":"13a07ce0691b76a0f5711f61561d52cb5fe2f88ff0b6787b4f55e4a4fa6ee635"},
	{"path":"res://art/campaigns/runtime/chapter_seals/obsidian_heatproof.png", "size":Vector2i(64,64), "hash":"955cc947bff9cc831bad1f259497f31f6be7c7e007c48daea749e57cc57266e7"},
	{"path":"res://art/campaigns/runtime/chapter_seals/milestone_caliper.png", "size":Vector2i(64,64), "hash":"43f0538ef69ba6c68b57cb4bdb668d957575b7c6371cd52ae5cd39a4fb07462d"},
	{"path":"res://art/campaigns/runtime/chapter_seals/dustjack_balance.png", "size":Vector2i(64,64), "hash":"3c520f39f603e6af347cdfe604b92aaf783ce10738d53fcfec042e1e56e8b9ae"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("%s START" % REPORT_ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == CASES.size(), "The Fivefold Assay is not a complete five-chapter campaign.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	var profile := CampaignRulesScript.normalize_profile({})
	var expected_carryover := {}
	var previous_scenario_id := ""
	var previous_proof_flag := ""
	for index in range(CASES.size()):
		var case: Dictionary = CASES[index]
		var scenario_id := String(case.get("scenario_id", ""))
		print("%s CHAPTER_START %s" % [REPORT_ID, scenario_id])
		var action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, scenario_id)
		_expect(not bool(action.get("disabled", true)), "%s did not unlock from the preceding victory and proof." % scenario_id)
		if index + 1 < CASES.size():
			var locked_action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, String(CASES[index + 1].get("scenario_id", "")))
			_expect(bool(locked_action.get("disabled", false)), "The next Fivefold chapter unlocked before this proof was won.")
		var baseline = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		var session = CampaignRulesScript.build_session(profile, scenario_id, "normal", CAMPAIGN_ID)
		_expect(session != null and session.scenario_id == scenario_id, "%s did not build as a campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_validate_opening(session, baseline, case, expected_carryover, previous_scenario_id, previous_proof_flag, index)
		_validate_contract(session, case)
		var battle_count := _validate_battles(session, case)
		_validate_proof(session, case)
		session.scenario_status = "victory"
		session.scenario_summary = "%s secured its exact Fivefold proof." % scenario_id
		_validate_save_round_trip(session)
		await _capture_map(view, session, case)
		expected_carryover = _expected_carryover(session.overworld.get("resources", {}))
		previous_scenario_id = scenario_id
		previous_proof_flag = String(case.get("proof_flag", ""))
		profile = CampaignRulesScript.record_session_completion(profile, session)
		_rows.append({"scenario_id":scenario_id, "battle_count":battle_count, "proof_flag":previous_proof_flag, "save_round_trip_exact":true})
		print("%s CHAPTER_DONE %s" % [REPORT_ID, scenario_id])
	_validate_art(campaign)
	_expect(CampaignRulesScript._campaign_is_completed(profile, CAMPAIGN_ID), "The Fivefold Assay did not complete after all five victories.")
	var battle_total: int = int(_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0))
	var report := {"ok":_errors.is_empty(), "campaign_id":CAMPAIGN_ID, "scenario_count":_rows.size(), "battle_payload_count":battle_total, "proof_count":_rows.size(), "resource_only_carryover":_errors.is_empty(), "art_identity_count":ART_RECORDS.size(), "save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true, "scenario_count":5, "battle_payload_count":battle_total, "proof_count":5, "art_identity_count":6, "save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_opening(session, baseline, case: Dictionary, expected: Dictionary, previous_scenario_id: String, previous_proof_flag: String, index: int) -> void:
	_expect(session.launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == CAMPAIGN_ID, "%s lost its campaign launch identity." % session.scenario_id)
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
	_expect(String(scenario.get("player_faction_id", "")) == "faction_brasshollow" and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")), "%s lost its Brasshollow hero contract." % session.scenario_id)
	_expect(bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) and bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)), "%s is not live in both modes." % session.scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == int(case.get("node_count", 0)) and (scenario.get("encounters", []) as Array).size() == int(case.get("battle_count", 0)) and (scenario.get("script_hooks", []) as Array).size() == int(case.get("hook_count", 0)) and (scenario.get("objectives", {}).get("victory", []) as Array).size() == int(case.get("objective_count", 0)), "%s lost its exact map contract." % session.scenario_id)


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
	_expect(bool(session.flags.get(proof_flag, false)), "%s did not turn its exact resolved encounter into campaign proof." % session.scenario_id)
	_expect(hook_id in result.get("fired_ids", []), "%s did not fire its signature proof hook." % hook_id)
	var repeat := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (hook_id in repeat.get("fired_ids", [])), "%s fired more than once." % hook_id)


func _expected_carryover(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {"gold":mini(400, int(floor(maxi(0, int(resources.get("gold", 0))) * 0.15))), "wood":mini(2, int(floor(maxi(0, int(resources.get("wood", 0))) * 0.15))), "ore":mini(2, int(floor(maxi(0, int(resources.get("ore", 0))) * 0.15)))}


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])


func _capture_map(view: Control, session, case: Dictionary) -> void:
	_reveal_all(session)
	var focus := Vector2i.ZERO
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == String(case.get("guard_id", "")):
			focus = Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png("%s/%s.png" % [OUTPUT_DIR, session.scenario_id]) == OK, "Could not capture %s." % session.scenario_id)


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


func _validate_art(campaign: Dictionary) -> void:
	var hashes := {}
	var strip := Image.create(448, 128, false, Image.FORMAT_RGBA8)
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
	_expect(hashes.size() == 6, "Fivefold campaign art is not six byte-distinct identities.")
	_expect(String(campaign.get("emblem_path", "")) == String(ART_RECORDS[0].get("path", "")), "The campaign browser lost the Fivefold emblem.")
	_expect(strip.save_png("%s/campaign_emblem_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the campaign art strip.")


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
