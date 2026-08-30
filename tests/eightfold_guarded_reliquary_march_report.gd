extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "EIGHTFOLD_GUARDED_RELIQUARY_MARCH_REPORT"
const OUTPUT_DIR := "res://.artifacts/eightfold_guarded_reliquary_march_report"
const SCENARIO_ID := "eightfold-reliquary-march"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/eightfold_guarded_reliquary_atlas.png"
const CASES := [
	{"site_id":"site_barrow_vault","placement_id":"eightfold_barrow","guard_id":"eightfold_barrow_guard","encounter_id":"encounter_bramble_hedge_watch","claimed":"resource_site_eightfold_barrow_vault_opened","region":Rect2(0,0,48,48),"rewards":{"gold":700,"ore":2},"flag":"barrow_vault_opened","special":"artifact"},
	{"site_id":"site_drowned_reliquary","placement_id":"eightfold_drowned","guard_id":"eightfold_drowned_guard","encounter_id":"encounter_tidepool_skiffyard_watch","claimed":"resource_site_eightfold_drowned_reliquary_recovered","region":Rect2(48,0,48,48),"rewards":{"gold":520,"wood":2,"ore":2},"flag":"drowned_reliquary_recovered","special":"artifact"},
	{"site_id":"site_lantern_crown_nave","placement_id":"eightfold_lantern","guard_id":"eightfold_lantern_guard","encounter_id":"encounter_lantern_warren_watch","claimed":"resource_site_eightfold_lantern_crown_nave_consecrated","region":Rect2(96,0,48,48),"rewards":{"gold":820,"wood":2,"ore":2},"flag":"lantern_crown_nave_consecrated","special":"spell_support","spell_id":"spell_survey_chain"},
	{"site_id":"site_hive_of_reeds","placement_id":"eightfold_hive","guard_id":"eightfold_hive_guard","encounter_id":"encounter_bogbell_croft_watch","claimed":"resource_site_eightfold_hive_of_reeds_reclaimed","region":Rect2(144,0,48,48),"rewards":{"gold":680,"wood":4},"flag":"hive_of_reeds_reclaimed","special":"recruits","recruits":{"unit_neutral_bogbell_mauls":3,"unit_neutral_peatflare_jarriers":1}},
	{"site_id":"site_glassbound_eyrie","placement_id":"eightfold_glass","guard_id":"eightfold_glass_guard","encounter_id":"encounter_cliffhawk_roost_watch","claimed":"resource_site_eightfold_glassbound_eyrie_secured","region":Rect2(192,0,48,48),"rewards":{"gold":860,"ore":3},"flag":"glassbound_eyrie_secured","special":"recruits_scouting","recruits":{"unit_neutral_cliffhawk_wardens":2,"unit_neutral_windglass_slingers":1},"vision_radius":6},
	{"site_id":"site_rust_choir_foundry","placement_id":"eightfold_rust","guard_id":"eightfold_rust_guard","encounter_id":"encounter_cinder_kiln_watch","claimed":"resource_site_eightfold_rust_choir_foundry_silenced","region":Rect2(240,0,48,48),"rewards":{"gold":980,"ore":5},"flag":"rust_choir_foundry_silenced","special":"recruits","recruits":{"unit_neutral_kilnward_mallets":3,"unit_neutral_cinderpot_hurlers":1}},
	{"site_id":"site_salt_wight_convoy","placement_id":"eightfold_salt","guard_id":"eightfold_salt_guard","encounter_id":"encounter_saltpan_camp_watch","claimed":"resource_site_eightfold_salt_wight_convoy_cleared","region":Rect2(288,0,48,48),"rewards":{"gold":760,"wood":3,"ore":2},"flag":"salt_wight_convoy_cleared","special":"route"},
	{"site_id":"site_rootwarden_stockade","placement_id":"eightfold_root","guard_id":"eightfold_root_guard","encounter_id":"encounter_bramble_hedge_watch","claimed":"resource_site_eightfold_rootwarden_stockade_reclaimed","region":Rect2(336,0,48,48),"rewards":{"gold":900,"wood":5},"flag":"rootwarden_stockade_reclaimed","special":"recruits","recruits":{"unit_neutral_hedgehook_watch":3,"unit_neutral_thornbow_scouts":2}},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect(int(scenario.get("map_size", {}).get("width", 0)) == 30 and int(scenario.get("map_size", {}).get("height", 0)) == 18, "Scenario lost its 30x18 map.")
	_expect((scenario.get("resource_nodes", []) as Array).size() == 17, "Scenario lost its 17 resource placements.")
	_expect((scenario.get("encounters", []) as Array).size() == 10, "Scenario lost its 10 encounter placements.")
	_expect((scenario.get("script_hooks", []) as Array).size() == 6, "Scenario lost its six reactive hooks.")
	_expect((scenario.get("objectives", {}).get("victory", []) as Array).size() == 10, "Scenario lost its ten-part victory contract.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var report := {"ok":_errors.is_empty(),"scenario_id":SCENARIO_ID,"case_count":CASES.size(),"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var guard_id := String(case.get("guard_id", ""))
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	var guard := _encounter(session, guard_id)
	_expect(String(node.get("site_id", "")) == site_id and String(node.get("guard_front_id", "")) == guard_id, "%s lost its exact site-to-guard link." % placement_id)
	_expect(String(guard.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s lost its authored guard identity." % guard_id)
	_expect(bool(site.get("runtime_boundary", {}).get("live_reward_grants", false)) and bool(site.get("runtime_boundary", {}).get("renderer_sprite_required", false)), "%s is not a live rendered reward site." % site_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, tile)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id != String(case.get("claimed", "")), "%s began in its claimed art state." % site_id)
	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_id, "%s did not expose its exact blocking guard." % placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % placement_id)
	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s did not construct its production guard battle." % guard_id)
	_resolve_guard(session, guard_id)
	var rewards: Dictionary = case.get("rewards", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var recruits: Dictionary = case.get("recruits", {})
	if not recruits.is_empty():
		_clear_active_army(session)
	var recruits_before := _army_counts(session, recruits.keys())
	var artifacts_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	var resources_after := _resource_counts(session, rewards.keys())
	_expect(_resource_delta_exact(resources_before, resources_after, rewards), "%s resource reward changed: before=%s after=%s expected=%s." % [placement_id, resources_before, resources_after, rewards])
	_expect(bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not set its claim flag." % placement_id)
	var claimed_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	var artifacts_after := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	_expect(artifacts_after.size() == artifacts_before.size() + 1 and String(claimed_node.get("artifact_reward_id", "")) in artifacts_after, "%s did not grant one table-backed artifact." % placement_id)
	_validate_special(session, case, claim, claimed_node, recruits_before)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed", "")), "%s did not switch to its exact claimed landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region") and texture.get_size() == Vector2(48,48), "%s did not resolve its exact 48x48 atlas region." % site_id)
	var authority_after_claim := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated authority." % placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), tile)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its claimed art state." % placement_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"guard_id":guard_id,"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"special":String(case.get("special", "")),"blocked_before_guard_clear":true,"guard_battle_constructed":not battle.is_empty(),"artifact_reward_granted":true,"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


func _validate_special(session: SessionStateStoreScript.SessionData, case: Dictionary, claim: Dictionary, claimed_node: Dictionary, recruits_before: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var recruits: Dictionary = case.get("recruits", {})
	if not recruits.is_empty():
		_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s recruit reward changed." % placement_id)
	match String(case.get("special", "")):
		"spell_support":
			_expect(String(case.get("spell_id", "")) in session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", []), "%s did not teach its authored spell." % placement_id)
			var logistics := OverworldRules.town_logistics_state(session, _town(session, "eightfold_player_town"))
			_expect(int(logistics.get("readiness_bonus", 0)) >= 3 and int(logistics.get("recovery_relief_bonus", 0)) >= 2 and int(logistics.get("growth_bonus_percent", 0)) >= 5, "%s did not provide its authored persistent town support: %s." % [placement_id, logistics])
		"recruits_scouting":
			_expect(int(claim.get("site_vision_radius", 0)) == int(case.get("vision_radius", 0)) and int(claim.get("site_reveal_tiles", -1)) >= 0, "%s scouting reveal did not execute." % placement_id)
		"route":
			_expect(bool(claim.get("route_opened", false)) and not bool(claimed_node.get("blocking_body", true)) and (claimed_node.get("package_block_tiles", []) as Array).is_empty(), "%s did not open and clear its route body." % placement_id)


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


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
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
		result[String(key_value)] = int(session.overworld.get("resources", {}).get(String(key_value), 0))
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


func _resource_delta_exact(before: Dictionary, after: Dictionary, expected: Dictionary) -> bool:
	for key_value in expected.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected.get(key_value, 0)):
			return false
	return true


func _clear_active_army(session: SessionStateStoreScript.SessionData) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["army"] = {"stacks":[]}
	session.overworld["hero"] = hero


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["position"] = position.duplicate(true)
			heroes[index] = roster_hero
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
