extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "EIGHT_GUARDED_ROUTE_GATES_REPORT"
const OUTPUT_DIR := "res://.artifacts/eight_guarded_route_gates_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/guarded_route_opened_atlas.png"
const SCENARIO_ID := "ninefold-confluence"
const CASES := [
	{"site_id":"site_bridge_bastion","site_placement_id":"ninefold_bridge_bastion","guard_placement_id":"ninefold_bridge_bastion_watch","guard_encounter_id":"encounter_roadward_lodge_watch","unclaimed_asset_id":"mapobj_bridge_bastion","claimed_asset_id":"resource_site_guarded_route_bridge_bastion_opened","region":Rect2(0,0,48,48),"rewards":{"gold":620,"wood":2,"ore":2},"special":"objective"},
	{"site_id":"site_chainboom_fort","site_placement_id":"ninefold_chainboom_fort","guard_placement_id":"ninefold_chainboom_fort_watch","guard_encounter_id":"encounter_harbor_pilot_house_watch","unclaimed_asset_id":"mapobj_chainboom_fort","claimed_asset_id":"resource_site_guarded_route_chainboom_fort_opened","region":Rect2(48,0,48,48),"rewards":{"gold":640,"wood":3},"special":"scouting","vision_radius":5},
	{"site_id":"site_railblock_camp","site_placement_id":"ninefold_railblock_camp","guard_placement_id":"ninefold_railblock_camp_watch","guard_encounter_id":"encounter_dustjack_yard_watch","unclaimed_asset_id":"mapobj_railblock_camp","claimed_asset_id":"resource_site_guarded_route_railblock_camp_opened","region":Rect2(96,0,48,48),"rewards":{"gold":580,"ore":3},"special":"recruits","recruits":{"unit_neutral_dustjack_blades":2,"unit_neutral_scrapbow_teams":1}},
	{"site_id":"site_rootgate_den","site_placement_id":"ninefold_rootgate_den","guard_placement_id":"ninefold_rootgate_den_watch","guard_encounter_id":"encounter_greenbranch_copse_watch","unclaimed_asset_id":"mapobj_rootgate_den","claimed_asset_id":"resource_site_guarded_route_rootgate_den_opened","region":Rect2(144,0,48,48),"rewards":{"gold":560,"wood":4},"special":"recruits","recruits":{"unit_neutral_greenbranch_cudgels":3,"unit_neutral_sapwhistle_callers":2}},
	{"site_id":"site_fog_quay_ambush","site_placement_id":"ninefold_fog_quay_ambush","guard_placement_id":"ninefold_fog_quay_ambush_watch","guard_encounter_id":"encounter_reedbarge_mooring_watch","unclaimed_asset_id":"mapobj_fog_quay_ambush","claimed_asset_id":"resource_site_guarded_route_fog_quay_ambush_opened","region":Rect2(192,0,48,48),"rewards":{"gold":600,"wood":3},"special":"artifact"},
	{"site_id":"site_mirror_toll_causeway","site_placement_id":"ninefold_mirror_toll_causeway","guard_placement_id":"ninefold_mirror_toll_causeway_watch","guard_encounter_id":"encounter_kite_signal_eyrie_watch","unclaimed_asset_id":"mapobj_mirror_toll_causeway","claimed_asset_id":"resource_site_guarded_route_mirror_toll_causeway_opened","region":Rect2(240,0,48,48),"rewards":{"gold":660,"ore":2},"special":"spell_and_scouting","spell_id":"spell_lens_glass_survey_24","vision_radius":4},
	{"site_id":"site_ashbarb_roadblock","site_placement_id":"ninefold_ashbarb_roadblock","guard_placement_id":"ninefold_ashbarb_roadblock_watch","guard_encounter_id":"encounter_charcoal_burners_watch","unclaimed_asset_id":"mapobj_ashbarb_roadblock","claimed_asset_id":"resource_site_guarded_route_ashbarb_roadblock_opened","region":Rect2(288,0,48,48),"rewards":{"gold":540,"wood":2,"ore":2},"special":"recruits","recruits":{"unit_neutral_charcoal_mauls":2,"unit_neutral_emberpack_lobbers":1}},
	{"site_id":"site_frostford_hold","site_placement_id":"ninefold_frostford_hold","guard_placement_id":"ninefold_frostford_hold_watch","guard_encounter_id":"encounter_frostwharf_house_watch","unclaimed_asset_id":"mapobj_frostford_hold","claimed_asset_id":"resource_site_guarded_route_frostford_hold_opened","region":Rect2(336,0,48,48),"rewards":{"gold":620,"wood":2,"ore":2},"special":"recruits","recruits":{"unit_neutral_frostwharf_cutters":3,"unit_neutral_lanternskate_throwers":2}},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect((scenario.get("resource_nodes", []) as Array).size() == 88, "Ninefold Confluence resource placement count changed.")
	_expect((scenario.get("encounters", []) as Array).size() == 23, "Ninefold Confluence encounter placement count changed.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("site_id", ""))])
		var rows_before := _rows.size()
		await _validate_case(view, case_value)
		if _rows.size() != rows_before + 1:
			_error("%s did not complete its combined smoke case." % String(case_value.get("site_id", "")))
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("site_id", ""))])
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"scenario_id":SCENARIO_ID,"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("site_placement_id", ""))
	var guard_id := String(case.get("guard_placement_id", ""))
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	var guard := _encounter(session, guard_id)
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	_expect(String(node.get("site_id", "")) == site_id and String(node.get("guard_front_id", "")) == guard_id, "%s lost its exact site-to-guard link." % placement_id)
	_expect(String(guard.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s lost its authored guard identity." % guard_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "resource_and_route_rewards_live" and bool(site.get("opens_route_on_claim", false)), "%s route reward is not live." % site_id)
	var body_tiles := OverworldRules._map_object_world_body_tiles(map_object, node)
	var blocked_before := OverworldRules._build_blocked_tile_index(session)
	_expect(not body_tiles.is_empty() and _all_body_tiles_blocked(body_tiles, blocked_before), "%s body did not block its route before capture." % placement_id)
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(maxi(0, focus.x - 1), focus.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed_asset_id", "")), "%s lost its closed landmark art." % site_id)
	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_id, "%s did not expose its exact blocking guard." % placement_id)
	var blocked_claim := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(not bool(blocked_claim.get("ok", true)) and String(blocked_claim.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % placement_id)
	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s did not construct its production guard battle." % guard_id)
	_resolve_guard(session, guard_id)
	var rewards: Dictionary = case.get("rewards", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var recruits: Dictionary = case.get("recruits", {})
	var recruits_before := _army_counts(session, recruits.keys())
	var artifacts_before := _artifact_ids(session)
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(bool(claim.get("ok", false)) and bool(claim.get("route_opened", false)), "%s guarded route claim failed: %s" % [placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s resource reward changed." % placement_id)
	var claimed_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	_expect(bool(claimed_node.get("collected", false)) and not bool(claimed_node.get("blocking_body", true)) and claimed_node.get("package_block_tiles", null) is Array and (claimed_node.get("package_block_tiles", []) as Array).is_empty(), "%s did not clear its runtime route body." % placement_id)
	_expect(String(claimed_node.get("route_state_id", "")) == "opened" and String(claimed_node.get("state_id", "")) == "opened", "%s did not persist the opened state ids." % placement_id)
	var blocked_after := OverworldRules._build_blocked_tile_index(session)
	_expect(_no_body_tiles_blocked(body_tiles, blocked_after), "%s body remained blocked after capture." % placement_id)
	_validate_special_reward(session, case, claim, claimed_node, recruits_before, artifacts_before)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed_asset_id", "")), "%s did not switch to its opened landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s did not resolve its exact opened atlas region." % site_id)
	var authority_after_claim := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated authority." % placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), focus)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its opened art state." % placement_id)
	_expect(_no_body_tiles_blocked(body_tiles, OverworldRules._build_blocked_tile_index(restored)), "%s restore re-blocked its opened route." % placement_id)
	_rows.append({"site_id":site_id,"site_placement_id":placement_id,"guard_placement_id":guard_id,"special":String(case.get("special", "")),"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"body_tile_count":body_tiles.size(),"blocked_before_guard_clear":true,"route_opened":true,"guard_battle_constructed":not battle.is_empty(),"resource_reward_verified":true,"special_reward_verified":true,"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


func _validate_special_reward(session: SessionStateStoreScript.SessionData, case: Dictionary, claim: Dictionary, claimed_node: Dictionary, recruits_before: Dictionary, artifacts_before: Array) -> void:
	var placement_id := String(case.get("site_placement_id", ""))
	match String(case.get("special", "")):
		"objective":
			_expect(bool(session.flags.get("ninefold_bridge_bastion_open", false)), "%s did not set its route objective flag." % placement_id)
		"scouting":
			_expect(int(claim.get("site_vision_radius", 0)) == int(case.get("vision_radius", 0)) and int(claim.get("site_reveal_tiles", -1)) >= 0, "%s scouting reward did not execute." % placement_id)
		"recruits":
			var recruits: Dictionary = case.get("recruits", {})
			_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s recruit reward changed." % placement_id)
		"artifact":
			var owned_after := _artifact_ids(session)
			_expect(owned_after.size() == artifacts_before.size() + 1 and String(claimed_node.get("artifact_reward_table_id", "")) == "artifact_source_guarded_sites_standard" and String(claimed_node.get("artifact_reward_id", "")) in owned_after, "%s artifact reward did not execute once with provenance." % placement_id)
		"spell_and_scouting":
			var spell_ids: Array = session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])
			_expect(String(case.get("spell_id", "")) in spell_ids, "%s did not teach its authored spell." % placement_id)
			_expect(int(claim.get("site_vision_radius", 0)) == int(case.get("vision_radius", 0)) and int(claim.get("site_reveal_tiles", -1)) >= 0, "%s scouting reward did not execute." % placement_id)


func _all_body_tiles_blocked(body_tiles: Array, index: Dictionary) -> bool:
	for tile in body_tiles:
		if tile is Vector2i and not index.has(OverworldRules._tile_key(tile)):
			return false
	return true


func _no_body_tiles_blocked(body_tiles: Array, index: Dictionary) -> bool:
	for tile in body_tiles:
		if tile is Vector2i and index.has(OverworldRules._tile_key(tile)):
			return false
	return true


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


func _resolve_guard(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	if placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved


func _resource_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		var key := String(key_value)
		result[key] = int(session.overworld.get("resources", {}).get(key, 0))
	return result


func _army_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		result[String(key_value)] = 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		if stack is Dictionary and result.has(String(stack.get("unit_id", ""))):
			var unit_id := String(stack.get("unit_id", ""))
			result[unit_id] = int(result.get(unit_id, 0)) + int(stack.get("count", 0))
	return result


func _artifact_ids(session: SessionStateStoreScript.SessionData) -> Array:
	var result: Array = []
	var artifacts: Dictionary = session.overworld.get("hero", {}).get("artifacts", {})
	for artifact_id in artifacts.get("inventory", []):
		if String(artifact_id) not in result:
			result.append(String(artifact_id))
	for artifact_id in artifacts.get("equipped", {}).values():
		if String(artifact_id) != "" and String(artifact_id) not in result:
			result.append(String(artifact_id))
	return result


func _resource_delta_exact(before: Dictionary, after: Dictionary, expected: Dictionary) -> bool:
	for key_value in expected.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected.get(key_value, 0)):
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
