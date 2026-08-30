extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BRIARWHEEL_COVENANT_CAMPAIGN_REPORT"
const OUTPUT_DIR := "res://.artifacts/briarwheel_covenant_campaign_report"
const CAMPAIGN_ID := "campaign_briarwheel_covenant"
const HERO_ID := "hero_thornwake_ardren_briarmarshal"
const ARMY_ID := "army_ardren_briar_cordon"
const MARKER_ATLAS := "res://art/overworld/runtime/objects/resource_sites/frontier_marker_landmarks_atlas.png"
const CASES := [
	{"scenario_id":"briarwheel-reclamation","size":Vector2i(14,8),"placement_id":"reclamation_old_measure","site_id":"site_old_measure_marker","flag":"old_measure_marker_rehung","spell_id":"spell_survey_chain","xp":120,"asset_id":"resource_site_frontier_marker_old_measure","region":Rect2(48,0,48,48)},
	{"scenario_id":"rootway-graftmarch","size":Vector2i(16,10),"placement_id":"graftmarch_rootway_marker","site_id":"site_rootway_marker","flag":"rootway_marker_awakened","spell_id":"spell_rootway_tangle","xp":110,"asset_id":"resource_site_frontier_marker_rootway","region":Rect2(96,0,48,48)},
	{"scenario_id":"worldroot-crown-covenant","size":Vector2i(20,12),"placement_id":"covenant_fogline_marker","site_id":"site_fogline_marker","flag":"fogline_marker_charted","spell_id":"spell_fogline_drift","xp":110,"asset_id":"resource_site_frontier_marker_fogline","region":Rect2(0,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var campaign := ContentService.get_campaign(CAMPAIGN_ID)
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == 3, "Briarwheel Covenant is not a complete three-chapter live campaign.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	var sessions := []
	for case_value in CASES:
		var scenario_id := String(case_value.get("scenario_id", ""))
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
		_expect(session != null, "%s did not create a campaign session." % scenario_id)
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		_validate_scenario_contract(session, case_value)
		_validate_marker(view, session, case_value)
		_validate_battles(session)
		_validate_save_round_trip(session)
		await _capture_map(view, session, case_value)
		sessions.append(session)
	_validate_campaign_progression(sessions)
	_validate_art_strip()
	var report := {
		"ok": _errors.is_empty(),
		"campaign_id": CAMPAIGN_ID,
		"scenario_count": CASES.size(),
		"map_sizes": ["14x8", "16x10", "20x12"],
		"battle_payload_count": _rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0),
		"marker_case_count": _rows.size(),
		"all_markers_claim_once": _rows.size() == 3 and _rows.all(func(row): return bool(row.get("claim_once", false))),
		"all_marker_responses_live": _rows.size() == 3 and _rows.all(func(row): return bool(row.get("response_live", false))),
		"all_marker_art_exact": _rows.size() == 3 and _rows.all(func(row): return bool(row.get("art_exact", false))),
		"same_hero_campaign_progression": _errors.is_empty(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"scenario_count":3,"battle_payload_count":int(report.get("battle_payload_count",0)),"marker_case_count":3,"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_scenario_contract(session, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var expected_size: Vector2i = case.get("size", Vector2i.ZERO)
	var scenario := ContentService.get_scenario(scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(Vector2i(int(map_size.get("width", 0)), int(map_size.get("height", 0))) == expected_size, "%s lost its exact authored map size." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == HERO_ID and String(scenario.get("player_army_id", "")) == ARMY_ID, "%s lost Ardren's live command identity." % scenario_id)
	_expect(String(session.overworld.get("active_hero_id", "")) == HERO_ID and not (session.overworld.get("army", {}).get("stacks", []) as Array).is_empty(), "%s did not bootstrap Ardren's production army." % scenario_id)
	_expect((scenario.get("towns", []) as Array).size() >= 2 and (scenario.get("resource_nodes", []) as Array).size() >= 11 and (scenario.get("encounters", []) as Array).size() >= 4, "%s lost its playable town, economy, or battle breadth." % scenario_id)
	_expect((scenario.get("objectives", {}).get("victory", []) as Array).size() >= 4 and (scenario.get("objectives", {}).get("defeat", []) as Array).size() >= 4, "%s lost its authored objective boundaries." % scenario_id)


func _validate_marker(view: Control, session, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	_expect(String(node.get("site_id", "")) == String(case.get("site_id", "")), "%s is not placed on its authored campaign board." % placement_id)
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var art_exact: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == MARKER_ATLAS and texture.region == case.get("region")
	_expect(art_exact, "%s did not resolve its exact marker atlas region." % placement_id)
	var before_xp := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim := OverworldRules._collect_resource_node_result(session, node_result, false)
	var known_spells: Array = session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])
	var claim_once: bool = bool(claim.get("ok", false)) and bool(session.flags.get(String(case.get("flag", "")), false)) and String(case.get("spell_id", "")) in known_spells and int(session.overworld.get("hero", {}).get("experience", 0)) - before_xp == int(case.get("xp", 0))
	_expect(claim_once, "%s did not grant its exact flag, spell, and experience payload: %s" % [placement_id, JSON.stringify(claim)])
	var authority_after_claim: Dictionary = session.to_dict()
	var repeated := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), false)
	_expect(not bool(repeated.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeated its one-time campaign claim or mutated authority." % placement_id)
	var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	resources["gold"] = maxi(1000, int(resources.get("gold", 0)))
	resources["ore"] = maxi(4, int(resources.get("ore", 0)))
	session.overworld["resources"] = resources
	var movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	movement["current"] = maxi(10, int(movement.get("current", 0)))
	movement["max"] = maxi(10, int(movement.get("max", 0)))
	session.overworld["movement"] = movement
	var response := OverworldRules._issue_resource_site_response(session, placement_id, "field")
	var response_state := OverworldRules._resource_site_response_state(session, _node_result(session, placement_id).get("node", {}), ContentService.get_resource_site(String(case.get("site_id", ""))))
	var response_live: bool = bool(response.get("ok", false)) and bool(response_state.get("active", false))
	_expect(response_live, "%s did not execute its authored route response: %s" % [placement_id, JSON.stringify(response)])
	_rows.append({"scenario_id":String(case.get("scenario_id","")),"site_id":String(case.get("site_id","")),"placement_id":placement_id,"claim_once":claim_once,"repeat_blocked":true,"response_live":response_live,"art_exact":art_exact,"save_round_trip_exact":false,"battle_count":0})


func _validate_battles(session) -> void:
	var battle_count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
		_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
		if not battle.is_empty():
			battle_count += 1
	if not _rows.is_empty():
		_rows[-1]["battle_count"] = battle_count


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var exact: bool = restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(exact, "%s did not round-trip exactly through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])
	if not _rows.is_empty():
		_rows[-1]["save_round_trip_exact"] = exact


func _validate_campaign_progression(sessions: Array) -> void:
	if sessions.size() != 3:
		_error("Campaign progression could not run without all three sessions.")
		return
	var profile := CampaignRulesScript.normalize_profile({})
	var first = sessions[0]
	first.overworld["resources"] = {"gold":4000,"wood":12,"ore":12,"verdant_grafts":8}
	first.flags["briarwheel_reclaimed"] = true
	first.scenario_status = "victory"
	first.scenario_summary = "Briarwheel and the old measure were reclaimed."
	var after_first := CampaignRulesScript.record_session_completion(profile, first)
	var second_action := CampaignRulesScript.build_chapter_action(after_first, CAMPAIGN_ID, "rootway-graftmarch")
	_expect(not bool(second_action.get("disabled", true)), "The exact Briarwheel victory and measure flag did not unlock Rootway Graftmarch.")
	var second = CampaignRulesScript.build_session(after_first, "rootway-graftmarch", "normal", CAMPAIGN_ID)
	var second_spells: Array = second.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])
	_expect(String(second.overworld.get("active_hero_id", "")) == HERO_ID and "spell_survey_chain" in second_spells and bool(second.flags.get("carryover_old_measure_marker_rehung", false)), "Ardren's exact first-chapter progression did not import into Rootway Graftmarch.")
	_validate_marker_progression_claim(second, CASES[1])
	second.overworld["resources"] = {"gold":5000,"wood":15,"ore":15,"verdant_grafts":10}
	second.flags["rootway_graftmarch_open"] = true
	second.scenario_status = "victory"
	second.scenario_summary = "The Rootway carried the covenant east."
	var after_second := CampaignRulesScript.record_session_completion(after_first, second)
	var third_action := CampaignRulesScript.build_chapter_action(after_second, CAMPAIGN_ID, "worldroot-crown-covenant")
	_expect(not bool(third_action.get("disabled", true)), "The exact Rootway victory and awakened-marker flag did not unlock the finale.")
	var third = CampaignRulesScript.build_session(after_second, "worldroot-crown-covenant", "hard", CAMPAIGN_ID)
	var third_spells: Array = third.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])
	_expect(String(third.overworld.get("active_hero_id", "")) == HERO_ID and "spell_survey_chain" in third_spells and "spell_rootway_tangle" in third_spells and bool(third.flags.get("carryover_rootway_marker_awakened", false)), "Ardren's same-hero spell and route evidence did not reach the Worldroot Crown.")


func _validate_marker_progression_claim(session, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var claim := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), false)
	_expect(bool(claim.get("ok", false)) and bool(session.flags.get(String(case.get("flag", "")), false)), "Campaign-built %s did not execute its Rootway claim." % session.scenario_id)


func _capture_map(view: Control, session, case: Dictionary) -> void:
	var node: Dictionary = _node_result(session, String(case.get("placement_id", ""))).get("node", {})
	_reveal_all(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, String(case.get("scenario_id", ""))]
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "Could not capture %s." % String(case.get("scenario_id", "")))


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


func _validate_art_strip() -> void:
	var strip := Image.create(320, 128, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	var paths := [
		"res://art/campaigns/runtime/emblems/briarwheel_covenant.png",
		"res://art/campaigns/runtime/chapter_seals/briarwheel_reclamation.png",
		"res://art/campaigns/runtime/chapter_seals/rootway_graftmarch.png",
		"res://art/campaigns/runtime/chapter_seals/worldroot_crown_covenant.png",
	]
	var positions := [Vector2i(0,0), Vector2i(128,32), Vector2i(192,32), Vector2i(256,32)]
	for index in range(paths.size()):
		var image := Image.load_from_file(ProjectSettings.globalize_path(paths[index]))
		_expect(not image.is_empty(), "Campaign art source %s could not load." % paths[index])
		if not image.is_empty():
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), positions[index])
	_expect(strip.save_png("%s/campaign_emblem_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the campaign art strip.")
	var marker_atlas := Image.load_from_file(ProjectSettings.globalize_path(MARKER_ATLAS))
	_expect(not marker_atlas.is_empty() and marker_atlas.get_size() == Vector2i(144,48), "Frontier marker atlas lost its exact compact dimensions.")
	if not marker_atlas.is_empty():
		marker_atlas.save_png("%s/frontier_marker_landmarks_atlas.png" % OUTPUT_DIR)


func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


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
