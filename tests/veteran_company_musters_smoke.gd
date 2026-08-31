extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "VETERAN_COMPANY_MUSTERS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/veteran_company_musters_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/veteran_company_musters_wave1/veteran_company_musters_atlas.png"
const CASES := [
	{"scenario_id":"pikeward-ashcharter-veteran-muster","prefix":"ashcharter","faction_id":"faction_embercourt","hero_id":"hero_torren","army_id":"army_ashcharter_veteran_muster_company","site_id":"site_ash_charter_rollhouse","object_id":"object_ash_charter_rollhouse","placement_id":"ashcharter_veteran_muster","targets":{"unit_embercourt_lantern_sappers":4,"unit_embercourt_ash_oath_bailiffs":2,"unit_embercourt_charter_colossus":1},"unclaimed":"mapobj_ash_charter_rollhouse","controlled":"resource_site_veteran_ash_charter_rollhouse_controlled","unclaimed_region":Rect2(0,0,48,48),"controlled_region":Rect2(48,0,48,48)},
	{"scenario_id":"chainboom-gorefen-veteran-muster","prefix":"gorefenring","faction_id":"faction_mireclaw","hero_id":"hero_mireclaw_kessa_chainboom","army_id":"army_gorefenring_veteran_muster_company","site_id":"site_gorefen_chain_ring","object_id":"object_gorefen_chain_ring","placement_id":"gorefenring_veteran_muster","targets":{"unit_mireclaw_ferrychain_lashers":2,"unit_mireclaw_gorefen_rippers":1},"unclaimed":"mapobj_gorefen_chain_ring","controlled":"resource_site_veteran_gorefen_chain_ring_controlled","unclaimed_region":Rect2(96,0,48,48),"controlled_region":Rect2(144,0,48,48)},
	{"scenario_id":"glassmarshal-daybreak-veteran-muster","prefix":"daybreakprism","faction_id":"faction_sunvault","hero_id":"hero_sunvault_ilyr_glassmarshal","army_id":"army_daybreakprism_veteran_muster_company","site_id":"site_mirror_daybreak_drill_prism","object_id":"object_mirror_daybreak_drill_prism","placement_id":"daybreakprism_veteran_muster","targets":{"unit_sunvault_mirror_duelists":3,"unit_sunvault_daybreak_colossus":1},"unclaimed":"mapobj_mirror_daybreak_drill_prism","controlled":"resource_site_veteran_mirror_daybreak_drill_prism_controlled","unclaimed_region":Rect2(192,0,48,48),"controlled_region":Rect2(240,0,48,48)},
	{"scenario_id":"bramblehound-worldroot-veteran-muster","prefix":"fivebough","faction_id":"faction_thornwake","hero_id":"hero_thornwake_silsa_bramblehound","army_id":"army_fivebough_veteran_muster_company","site_id":"site_five_bough_veteran_grove","object_id":"object_five_bough_veteran_grove","placement_id":"fivebough_veteran_muster","targets":{"unit_thornwake_pollenhook_whistlers":6,"unit_thornwake_bramblekite_needlers":4,"unit_thornwake_seedshield_wardens":3,"unit_thornwake_graft_matriarchs":1,"unit_thornwake_worldroot_bastion":1},"unclaimed":"mapobj_five_bough_veteran_grove","controlled":"resource_site_veteran_five_bough_veteran_grove_controlled","unclaimed_region":Rect2(288,0,48,48),"controlled_region":Rect2(336,0,48,48)},
	{"scenario_id":"pitmarshal-foundry-veteran-muster","prefix":"threegauge","faction_id":"faction_brasshollow","hero_id":"hero_brasshollow_selka_pitmarshal","army_id":"army_threegauge_veteran_muster_company","site_id":"site_three_gauge_chapter_foundry","object_id":"object_three_gauge_chapter_foundry","placement_id":"threegauge_veteran_muster","targets":{"unit_brasshollow_quenchspool_slingers":4,"unit_brasshollow_gaugefire_arbalists":3,"unit_brasshollow_foundry_saint":1},"unclaimed":"mapobj_three_gauge_chapter_foundry","controlled":"resource_site_veteran_three_gauge_chapter_foundry_controlled","unclaimed_region":Rect2(384,0,48,48),"controlled_region":Rect2(432,0,48,48)},
	{"scenario_id":"keelwarden-fogkeel-veteran-muster","prefix":"fogkeel","faction_id":"faction_veilmourn","hero_id":"hero_veilmourn_jessa_keelwarden","army_id":"army_fogkeel_veteran_muster_company","site_id":"site_fog_keel_lastwatch_mooring","object_id":"object_fog_keel_lastwatch_mooring","placement_id":"fogkeel_veteran_muster","targets":{"unit_veilmourn_wakechain_boarders":3,"unit_veilmourn_mirrorkeel_reavers":1,"unit_veilmourn_fogbound_leviathan":1},"unclaimed":"mapobj_fog_keel_lastwatch_mooring","controlled":"resource_site_veteran_fog_keel_lastwatch_mooring_controlled","unclaimed_region":Rect2(480,0,48,48),"controlled_region":Rect2(528,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(576, 48), "The twelve-state veteran-muster atlas must remain exactly 576x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var unique_units := {}
	for row_value in _rows:
		for unit_id_value in row_value.get("target_unit_ids", []):
			unique_units[String(unit_id_value)] = true
	var report := {
		"ok":_errors.is_empty(),
		"case_count":CASES.size(),
		"battle_victory_count":_rows.reduce(func(total,row): return total + int(row.get("battle_victory_count",0)),0),
		"target_unit_count":unique_units.size(),
		"blocked_claim_count":_count_rows("blocked_claim"),
		"live_claim_count":_count_rows("live_claim"),
		"weekly_delivery_count":_count_rows("weekly_delivery"),
		"exact_two_state_art_count":_count_rows("exact_two_state_art"),
		"scenario_victory_count":_count_rows("scenario_victory"),
		"save_round_trip_count":_count_rows("save_round_trip_exact"),
		"save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true,
		"rows":_rows,
		"errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"battle_victory_count":18,"target_unit_count":18,"blocked_claim_count":6,"live_claim_count":6,"weekly_delivery_count":6,"exact_two_state_art_count":6,"scenario_victory_count":6,"save_round_trip_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var direct_lead: bool = String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("player_army_id", "")) == String(case.get("army_id", "")) and scenario.get("selection", {}).get("availability", {}) == {"campaign":false,"skirmish":true}
	_expect(direct_lead, "%s did not launch its exact skirmish-only hero, faction, and lean company." % scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width", 0)) == 15 and int(map_size.get("height", 0)) == 9 and scenario.get("towns", []).size() == 2 and scenario.get("resource_nodes", []).size() == 7 and scenario.get("encounters", []).size() == 3 and scenario.get("script_hooks", []).size() == 5, "%s lost its exact 15x9 veteran-operation composition." % scenario_id)

	var targets: Dictionary = case.get("targets", {})
	var absent_at_launch := true
	for unit_id_value in targets.keys():
		absent_at_launch = absent_at_launch and _army_count(session, String(unit_id_value)) == 0
	_expect(absent_at_launch, "%s started with a veteran company that should be won from the live map." % scenario_id)

	var node_result := _resource_node_result(session, String(case.get("placement_id", "")))
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var map_object := ContentService.get_map_object(String(case.get("object_id", "")))
	_expect(String(node.get("site_id", "")) == String(case.get("site_id", "")) and String(node.get("guard_front_id", "")) == "%s_muster_guard" % prefix, "%s lost its exact guarded muster placement." % scenario_id)
	var expected_weekly_contract := {}
	for unit_id_value in targets.keys():
		expected_weekly_contract[String(unit_id_value)] = 1
	_expect(_integer_dictionary_equal(site.get("claim_recruits", {}), targets) and _integer_dictionary_equal(site.get("weekly_recruits", {}), expected_weekly_contract) and String(site.get("faction_id", "")) == String(case.get("faction_id", "")), "%s lost its exact multi-company recruitment contract." % scenario_id)
	_expect(bool(map_object.get("approach", {}).get("guard_clearance_required", false)) and bool(map_object.get("interaction", {}).get("requires_guard_clear", false)), "%s no longer requires its authored guard to be cleared." % String(case.get("object_id", "")))
	var pathing := OverworldRules.overworld_object_placement_pathing_surface(session, String(case.get("placement_id", "")))
	_expect(String(pathing.get("object_id", "")) == String(case.get("object_id", "")) and int(pathing.get("body_tile_count", 0)) == 1 and int(pathing.get("interaction_tile_count", 0)) == 1, "%s lost its compact live pathing surface." % scenario_id)

	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, tile)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	var unclaimed_texture = view.call("_object_texture_for_asset", unclaimed_asset_id)
	var unclaimed_exact := unclaimed_asset_id == String(case.get("unclaimed", "")) and _exact_atlas_texture(unclaimed_texture, case.get("unclaimed_region"))
	_expect(unclaimed_exact, "%s did not render its exact unclaimed atlas state." % scenario_id)

	var authority_before_block := session.to_dict()
	var blocked_result := OverworldRules._collect_resource_node_result(session, node_result, true)
	var blocked_claim := not bool(blocked_result.get("ok", false)) and session.to_dict() == authority_before_block
	_expect(blocked_claim, "%s allowed or mutated a claim before the authored guard fell: %s" % [scenario_id, JSON.stringify(blocked_result)])

	var battle_victory_count := 0
	for placement_id in ["%s_west_company" % prefix, "%s_south_company" % prefix, "%s_muster_guard" % prefix]:
		if _resolve_production_battle(session, placement_id):
			battle_victory_count += 1
	_expect(battle_victory_count == 3, "%s won %d of its three production battles." % [scenario_id, battle_victory_count])
	if battle_victory_count != 3:
		return

	node_result = _resource_node_result(session, String(case.get("placement_id", "")))
	var counts_before := _army_counts(session, targets.keys())
	var claim_result := OverworldRules._collect_resource_node_result(session, node_result, true)
	var live_claim := bool(claim_result.get("ok", false)) and _army_delta_exact(counts_before, _army_counts(session, targets.keys()), targets)
	_expect(live_claim, "%s did not add every exact veteran company through live claim authority: %s" % [scenario_id, JSON.stringify(claim_result)])
	var army_objective_id := "%s_assemble_veterans" % prefix
	_expect(ScenarioRulesScript.is_objective_met(session, army_objective_id, "victory"), "%s claim did not satisfy its exact hero-army objective." % scenario_id)

	var claimed_node: Dictionary = _resource_node_result(session, String(case.get("placement_id", ""))).get("node", {})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var controlled_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var controlled_texture = view.call("_object_texture_for_asset", controlled_asset_id)
	var exact_two_state_art := unclaimed_exact and controlled_asset_id == String(case.get("controlled", "")) and _exact_atlas_texture(controlled_texture, case.get("controlled_region")) and controlled_asset_id != unclaimed_asset_id
	_expect(exact_two_state_art, "%s did not switch to its exact controlled atlas state." % scenario_id)

	var town_before := _town_recruit_counts(session, targets.keys())
	var muster_messages := OverworldRules.apply_controlled_resource_site_musters(session, "player")
	var expected_weekly := {}
	for unit_id_value in targets.keys():
		expected_weekly[String(unit_id_value)] = 1
	var weekly_delivery := not muster_messages.is_empty() and _army_delta_exact(town_before, _town_recruit_counts(session, targets.keys()), expected_weekly)
	_expect(weekly_delivery, "%s did not deliver all veteran grades to the nearest held town." % scenario_id)

	var authority_after_claim := session.to_dict()
	var repeat_result := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, String(case.get("placement_id", ""))), true)
	_expect(not bool(repeat_result.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated save authority." % scenario_id)

	var outcome := ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(outcome.get("status", "")) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory, "%s did not win after all three battles, control, and exact army assembly: %s" % [scenario_id, JSON.stringify(outcome)])
	var capture_path := await _capture_if_requested(scenario_id)
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"faction_id":String(case.get("faction_id", "")),"site_id":String(case.get("site_id", "")),"target_unit_ids":targets.keys(),"direct_lead":direct_lead,"blocked_claim":blocked_claim,"battle_victory_count":battle_victory_count,"live_claim":live_claim,"weekly_delivery":weekly_delivery,"exact_two_state_art":exact_two_state_art,"scenario_victory":scenario_victory,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_production_battle(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var placement := _encounter(session, placement_id)
	if placement.is_empty():
		return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state", "")) == "victory" and session.battle.is_empty() and OverworldRules.is_encounter_resolved(session, placement)


func _resource_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _exact_atlas_texture(texture: Variant, region_value: Variant) -> bool:
	return texture is AtlasTexture and texture.atlas != null and texture.atlas.resource_path == ATLAS_PATH and texture.region == region_value


func _army_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total


func _army_counts(session: SessionStateStoreScript.SessionData, unit_ids: Array) -> Dictionary:
	var result := {}
	for unit_id_value in unit_ids:
		result[String(unit_id_value)] = _army_count(session, String(unit_id_value))
	return result


func _town_recruit_counts(session: SessionStateStoreScript.SessionData, unit_ids: Array) -> Dictionary:
	var result := {}
	for unit_id_value in unit_ids:
		result[String(unit_id_value)] = 0
	for town in session.overworld.get("towns", []):
		if town is Dictionary:
			for unit_id_value in unit_ids:
				var unit_id := String(unit_id_value)
				result[unit_id] = int(result.get(unit_id, 0)) + int(town.get("available_recruits", {}).get(unit_id, 0))
	return result


func _army_delta_exact(before: Dictionary, after: Dictionary, expected: Dictionary) -> bool:
	for unit_id_value in expected.keys():
		var unit_id := String(unit_id_value)
		if int(after.get(unit_id, 0)) - int(before.get(unit_id, 0)) != int(expected.get(unit_id_value, 0)):
			return false
	return true


func _integer_dictionary_equal(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Dictionary) or not (right_value is Dictionary):
		return false
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	if left.size() != right.size():
		return false
	for key_value in right.keys():
		if int(left.get(key_value, -999999)) != int(right.get(key_value, 0)):
			return false
	return true


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {})
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("VETERAN_COMPANY_MUSTER_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var path := capture_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "%s capture failed." % stem)
	return path


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error(message)
