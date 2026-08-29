extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_CREATURE_BANK_FORTS_REPORT"
const OUTPUT_DIR := "res://.artifacts/three_creature_bank_forts_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/creature_bank_opened_atlas.png"
const CASES := [
	{"scenario_id":"gaugesavant-milestone-calibration","site_id":"site_sealed_muster_fort","site_placement_id":"gaugesavant_sealed_muster_fort","guard_placement_id":"gaugesavant_milestone_arsenal_watch","guard_encounter_id":"encounter_milestone_arsenal_watch","unclaimed_asset_id":"mapobj_sealed_muster_fort","claimed_asset_id":"resource_site_creature_bank_sealed_muster_fort_opened","region":Rect2(0,0,48,48),"resource_count":13,"encounter_count":4,"rewards":{"gold":700,"wood":2,"ore":3},"recruits":{"unit_neutral_milestone_bucklers":3,"unit_neutral_cartbow_tenders":2}},
	{"scenario_id":"lockmaster-cinder-kiln","site_id":"site_kiln_chain_redoubt","site_placement_id":"lockmaster_kiln_chain_redoubt","guard_placement_id":"lockmaster_basalt_gatehouse_watch","guard_encounter_id":"encounter_basalt_gatehouse_watch","unclaimed_asset_id":"mapobj_kiln_chain_redoubt","claimed_asset_id":"resource_site_creature_bank_kiln_chain_redoubt_opened","region":Rect2(48,0,48,48),"resource_count":11,"encounter_count":4,"rewards":{"gold":920,"ore":4},"recruits":{"unit_neutral_basalt_wardens":3,"unit_neutral_tunnelmark_bolters":2}},
	{"scenario_id":"pitmarshal-peat-chain-seizure","site_id":"site_brasswake_depot","site_placement_id":"pitmarshal_brasswake_depot","guard_placement_id":"pitmarshal_crystal_sump_watch","guard_encounter_id":"encounter_crystal_sump_watch","unclaimed_asset_id":"mapobj_brasswake_depot","claimed_asset_id":"resource_site_creature_bank_brasswake_depot_opened","region":Rect2(96,0,48,48),"resource_count":10,"encounter_count":4,"rewards":{"gold":960,"ore":5},"recruits":{"unit_neutral_sumpstone_guards":3,"unit_neutral_echodart_casts":2}},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("site_id", ""))])
		var completed_rows_before := _rows.size()
		await _validate_case(view, case_value)
		if _rows.size() != completed_rows_before + 1:
			_error("%s did not complete its combined smoke case." % String(case_value.get("site_id", "")))
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("site_id", ""))])
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var site_id := String(case.get("site_id", ""))
	var site_placement_id := String(case.get("site_placement_id", ""))
	var guard_placement_id := String(case.get("guard_placement_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == int(case.get("resource_count", -1)), "%s resource placement count changed." % scenario_id)
	_expect((scenario.get("encounters", []) as Array).size() == int(case.get("encounter_count", -1)), "%s encounter placement count changed." % scenario_id)
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, site_placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	var guard := _encounter(session, guard_placement_id)
	_expect(String(node.get("site_id", "")) == site_id and String(node.get("guard_front_id", "")) == guard_placement_id, "%s lost its exact site-to-guard link." % site_placement_id)
	_expect(String(guard.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s lost its authored guard identity." % guard_placement_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "resource_and_recruit_rewards_live", "%s is not a live creature-bank reward site." % site_id)
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(maxi(0, focus.x - 1), focus.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed_asset_id", "")), "%s lost its sealed landmark art." % site_id)
	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_placement_id, "%s did not expose its exact blocking guard." % site_placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % site_placement_id)
	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s did not construct its production guard battle." % guard_placement_id)
	_resolve_guard(session, guard_placement_id)
	_expect(OverworldRules.resource_site_blocking_guard(session, _resource_node_result(session, site_placement_id).get("node", {}), site).is_empty(), "%s remained blocked after guard resolution." % site_placement_id)

	var rewards: Dictionary = case.get("rewards", {})
	var recruits: Dictionary = case.get("recruits", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var recruits_before := _army_counts(session, recruits.keys())
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), true)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [site_placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s resource reward changed." % site_placement_id)
	_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s recruit reward changed." % site_placement_id)
	var claimed_node: Dictionary = _resource_node_result(session, site_placement_id).get("node", {})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed_asset_id", "")), "%s did not switch to its opened landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s did not resolve its exact opened atlas region." % site_id)
	var capture_path := await _capture_if_requested(site_id)
	var authority_after_claim := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated authority." % site_placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, site_placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), focus)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [site_placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its opened art state." % site_placement_id)
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"site_placement_id":site_placement_id,"guard_placement_id":guard_placement_id,"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"capture_path":capture_path,"blocked_before_guard_clear":true,"guard_battle_constructed":not battle.is_empty(),"resource_reward_verified":true,"recruit_reward_verified":true,"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


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


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("CREATURE_BANK_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await get_tree().process_frame
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path


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
