extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNBOUND_ROAD_LEDGER_CAMPAIGN_REPORT"
const OUTPUT_DIR := "res://.artifacts/unbound_road_ledger_campaign_report"
const CAMPAIGN_ID := "campaign_unbound_road_ledger"
const SITE_ID := "site_pactwright_waydesk"
const CASES := [
	{"scenario_id":"tollglass-relief-run", "hero_id":"hero_torren", "faction_id":"faction_embercourt", "placement_id":"tollglass_pactwright_waydesk", "guard_id":"tollglass_drowned_tally", "hook_id":"tollglass_waydesk_drowned_tally_witness", "testimony_flag":"unbound_drowned_tally_testimony"},
	{"scenario_id":"muckscript-reliquary-hunt", "hero_id":"hero_sable", "faction_id":"faction_mireclaw", "placement_id":"muckscript_pactwright_waydesk", "guard_id":"muckscript_prism_inquest", "hook_id":"muckscript_waydesk_peat_reliquary_witness", "testimony_flag":"unbound_peat_reliquary_testimony"},
	{"scenario_id":"mirrorstep-gauge-race", "hero_id":"hero_varis", "faction_id":"faction_sunvault", "placement_id":"mirrorstep_pactwright_waydesk", "guard_id":"mirrorstep_redline_calibrators", "hook_id":"mirrorstep_waydesk_redline_gauge_witness", "testimony_flag":"unbound_redline_gauge_testimony"},
	{"scenario_id":"briarmarshal-fen-cordon", "hero_id":"hero_thornwake_ardren_briarmarshal", "faction_id":"faction_thornwake", "placement_id":"briarmarshal_pactwright_waydesk", "guard_id":"briarmarshal_drum_cordon", "hook_id":"briarmarshal_waydesk_rooted_drum_witness", "testimony_flag":"unbound_rooted_drum_testimony"},
	{"scenario_id":"railhead-charter-seizure", "hero_id":"hero_brasshollow_kuld_varn", "faction_id":"faction_brasshollow", "placement_id":"railhead_pactwright_waydesk", "guard_id":"railhead_lockward_auditors", "hook_id":"railhead_waydesk_burning_charter_witness", "testimony_flag":"unbound_burning_charter_testimony"},
	{"scenario_id":"mistcorsair-graftwake-raid", "hero_id":"hero_veilmourn_cela_mistcorsair", "faction_id":"faction_veilmourn", "placement_id":"mistcorsair_pactwright_waydesk", "guard_id":"mistcorsair_graftwake_cordon", "hook_id":"mistcorsair_waydesk_salted_ghost_rope_witness", "testimony_flag":"unbound_salted_ghost_rope_testimony"},
]
const ART_RECORDS := [
	{"path":"res://art/campaigns/runtime/emblems/unbound_road_ledger.png", "size":Vector2i(128,128), "hash":"84927535b277bf0d54504316f712d707abe35dfc5f1d51cbfe245657ff0ce5e8"},
	{"path":"res://art/campaigns/runtime/chapter_seals/drowned_tally.png", "size":Vector2i(64,64), "hash":"89c637e56a6a641450f6e7bb14e35f523d243bcece519d419b813287792b9dfc"},
	{"path":"res://art/campaigns/runtime/chapter_seals/peat_reliquary.png", "size":Vector2i(64,64), "hash":"6d729c313b95259f86f3290b1a2aea2ae8909a44b59eecdd7cc150cb4c1500e6"},
	{"path":"res://art/campaigns/runtime/chapter_seals/redline_gauge.png", "size":Vector2i(64,64), "hash":"dd040b6aafe5267922a7d30ac08bd3de9d999fd57d9d2b3cb528f25e2aef52ae"},
	{"path":"res://art/campaigns/runtime/chapter_seals/rooted_drum.png", "size":Vector2i(64,64), "hash":"68b5b4df429e6ca33e42a75b4c0e24527dc97b8aab2a77e010e6316c21ad17c0"},
	{"path":"res://art/campaigns/runtime/chapter_seals/burning_charter.png", "size":Vector2i(64,64), "hash":"d7e4b0cf99a135b198a8ad92f96c802694a2f833b43d39d66c62fddd68a2e31e"},
	{"path":"res://art/campaigns/runtime/chapter_seals/salted_ghost_rope.png", "size":Vector2i(64,64), "hash":"5634770abcd5dacb2c49d7987062ecd923e73962912a5935197f8b3332b07929"},
]
const WAYDESK_ATLAS := {"path":"res://art/overworld/runtime/objects/resource_sites/pactwright_waydesk_state_atlas.png", "size":Vector2i(96,48), "hash":"b1b7c9c8c87ab65c6b3c1f1487bc48b04b7bdf7ac5a363917707cefb82c7786d"}

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("%s START" % REPORT_ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == CASES.size(), "The Unbound Road Ledger is not a complete six-chapter campaign.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	var profile := CampaignRulesScript.normalize_profile({})
	var expected_carryover := {}
	var previous_scenario_id := ""
	var previous_testimony_flag := ""
	for index in range(CASES.size()):
		var case: Dictionary = CASES[index]
		var scenario_id := String(case.get("scenario_id", ""))
		print("%s CHAPTER_START %s" % [REPORT_ID, scenario_id])
		var action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, scenario_id)
		_expect(not bool(action.get("disabled", true)), "%s did not unlock from the exact preceding victory and Waydesk witness." % scenario_id)
		if index + 1 < CASES.size():
			var locked_action := CampaignRulesScript.build_chapter_action(profile, CAMPAIGN_ID, String(CASES[index + 1].get("scenario_id", "")))
			_expect(bool(locked_action.get("disabled", false)), "The next ledger chapter unlocked before this local testimony was won.")
		var baseline = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		var session = CampaignRulesScript.build_session(profile, scenario_id, "normal", CAMPAIGN_ID)
		_expect(session != null and session.scenario_id == scenario_id, "%s did not build as a campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_validate_opening(session, baseline, case, expected_carryover, previous_scenario_id, previous_testimony_flag, index)
		_validate_contract(session, case)
		var battle_count := _validate_battles(session)
		_validate_waydesk(session, case)
		session.scenario_status = "victory"
		session.scenario_summary = "%s completed its exact Pactwright testimony." % scenario_id
		_validate_save_round_trip(session)
		await _capture_map(view, session, case)
		expected_carryover = _expected_carryover(session.overworld.get("resources", {}))
		previous_scenario_id = scenario_id
		previous_testimony_flag = String(case.get("testimony_flag", ""))
		profile = CampaignRulesScript.record_session_completion(profile, session)
		_rows.append({"scenario_id":scenario_id, "battle_count":battle_count, "waydesk_claimed":true, "testimony_flag":previous_testimony_flag, "save_round_trip_exact":true})
		print("%s CHAPTER_DONE %s" % [REPORT_ID, scenario_id])
	_validate_art(campaign)
	_expect(CampaignRulesScript._campaign_is_completed(profile, CAMPAIGN_ID), "The Unbound Road Ledger did not complete after all six exact victories.")
	var battle_total: int = int(_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0))
	var report := {"ok":_errors.is_empty(), "campaign_id":CAMPAIGN_ID, "scenario_count":_rows.size(), "battle_payload_count":battle_total, "waydesk_claim_count":_rows.filter(func(row): return bool(row.get("waydesk_claimed", false))).size(), "cross_faction_resource_only_carryover":_errors.is_empty(), "art_identity_count":ART_RECORDS.size(), "save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true, "scenario_count":6, "battle_payload_count":battle_total, "waydesk_claim_count":6, "art_identity_count":7, "save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_opening(session, baseline, case: Dictionary, expected: Dictionary, previous_scenario_id: String, previous_testimony_flag: String, index: int) -> void:
	_expect(session.launch_mode == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN and String(session.flags.get("campaign_id", "")) == CAMPAIGN_ID, "%s lost its campaign launch identity." % session.scenario_id)
	_expect(String(session.overworld.get("active_hero_id", "")) == String(case.get("hero_id", "")), "%s launched with the wrong commander." % session.scenario_id)
	if index == 0:
		return
	_expect(String(session.flags.get("campaign_previous_scenario_id", "")) == previous_scenario_id and bool(session.flags.get("carryover_pactwright_waydesk_witnessed", false)) and bool(session.flags.get("carryover_%s" % previous_testimony_flag, false)), "%s did not import both exact prior testimony flags." % session.scenario_id)
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


func _validate_contract(session, case: Dictionary) -> void:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var size: Dictionary = scenario.get("map_size", {})
	_expect(Vector2i(int(size.get("width", 0)), int(size.get("height", 0))) == Vector2i(11,6), "%s lost its compact authored board." % session.scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")), "%s lost its exact faction or hero." % session.scenario_id)
	_expect(bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) and bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)), "%s is not live in both campaign and skirmish." % session.scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == 11 and (scenario.get("encounters", []) as Array).size() == 3 and (scenario.get("script_hooks", []) as Array).size() == 6 and (scenario.get("objectives", {}).get("victory", []) as Array).size() == 5, "%s lost the 11-site / 3-battle / 6-hook / 5-objective contract." % session.scenario_id)


func _validate_battles(session) -> int:
	var count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
		_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
		if not battle.is_empty():
			count += 1
	_expect(count == 3, "%s constructed %d battle payloads instead of 3." % [session.scenario_id, count])
	return count


func _validate_waydesk(session, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var guard_id := String(case.get("guard_id", ""))
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	_expect(String(node.get("site_id", "")) == SITE_ID and String(node.get("guard_front_id", "")) == guard_id and not _encounter(session, guard_id).is_empty(), "%s lost its exact Waydesk guard link." % placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, false)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be witnessed before its signature guard." % placement_id)
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	resolved.append(guard_id)
	session.overworld["resolved_encounters"] = resolved
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), false)
	var testimony_flag := String(case.get("testimony_flag", ""))
	var hook_id := String(case.get("hook_id", ""))
	var fired_hook_ids: Array = session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", [])
	var repeat_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(bool(claim.get("ok", false)) and bool(session.flags.get("pactwright_waydesk_witnessed", false)) and bool(session.flags.get(testimony_flag, false)), "%s did not grant its local Waydesk testimony: %s" % [placement_id, JSON.stringify(claim)])
	_expect(hook_id in fired_hook_ids and not (hook_id in repeat_result.get("fired_ids", [])), "%s did not execute exactly once." % hook_id)
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), false)
	_expect(not bool(repeat.get("ok", true)), "%s granted its witness twice." % placement_id)


func _expected_carryover(resources_value: Variant) -> Dictionary:
	var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	return {"gold":mini(500, int(floor(maxi(0, int(resources.get("gold", 0))) * 0.2))), "wood":mini(2, int(floor(maxi(0, int(resources.get("wood", 0))) * 0.2))), "ore":mini(2, int(floor(maxi(0, int(resources.get("ore", 0))) * 0.2)))}


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])


func _capture_map(view: Control, session, case: Dictionary) -> void:
	_reveal_all(session)
	var node: Dictionary = _resource_node_result(session, String(case.get("placement_id", ""))).get("node", {})
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
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
	var strip := Image.create(512, 128, false, Image.FORMAT_RGBA8)
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
	_expect(hashes.size() == 7, "The Unbound Road Ledger art is not seven byte-distinct identities.")
	_expect(String(campaign.get("emblem_path", "")) == String(ART_RECORDS[0].get("path", "")), "The campaign browser lost the Unbound Road Ledger emblem.")
	_expect(strip.save_png("%s/campaign_emblem_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the campaign art strip.")
	var atlas_path := String(WAYDESK_ATLAS.get("path", ""))
	var atlas_absolute := ProjectSettings.globalize_path(atlas_path)
	var atlas := Image.load_from_file(atlas_absolute)
	_expect(not atlas.is_empty() and atlas.get_size() == WAYDESK_ATLAS.get("size") and atlas.detect_alpha() != Image.ALPHA_NONE and FileAccess.get_sha256(atlas_absolute) == String(WAYDESK_ATLAS.get("hash", "")), "The Pactwright Waydesk lost its exact two-state alpha-safe atlas.")


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index, "node":nodes[index]}
	return {"index":-1, "node":{}}


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
