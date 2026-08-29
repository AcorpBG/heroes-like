extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SEVEN_MINOR_GUARDED_CACHES_REPORT"
const OUTPUT_DIR := "res://.artifacts/seven_minor_guarded_caches_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/minor_guarded_cache_opened_atlas.png"
const CASES := [
	{"scenario_id":"tollreaver-roadward-lodge","site_id":"site_toll_ruin","site_placement_id":"tollreaver_toll_ruin","guard_placement_id":"tollreaver_roadward_lodge_watch","guard_encounter_id":"encounter_roadward_lodge_watch","unclaimed_asset_id":"mapobj_toll_ruin","claimed_asset_id":"resource_site_minor_cache_toll_ruin_opened","region":Rect2(0,0,48,48),"resource_count":11,"encounter_count":3,"rewards":{"gold":420,"wood":2},"special":"scouting"},
	{"scenario_id":"mirrorbell-harbor-echo","site_id":"site_wreck_locker","site_placement_id":"mirrorbell_wreck_locker","guard_placement_id":"mirrorbell_harbor_pilot_house_watch","guard_encounter_id":"encounter_harbor_pilot_house_watch","unclaimed_asset_id":"mapobj_wreck_locker","claimed_asset_id":"resource_site_minor_cache_wreck_locker_opened","region":Rect2(48,0,48,48),"resource_count":13,"encounter_count":4,"rewards":{"gold":380,"wood":3},"special":"artifact"},
	{"scenario_id":"pollenglass-greenbranch-copse","site_id":"site_amber_reliquary","site_placement_id":"pollenglass_amber_reliquary","guard_placement_id":"pollenglass_greenbranch_copse_watch","guard_encounter_id":"encounter_greenbranch_copse_watch","unclaimed_asset_id":"mapobj_amber_reliquary","claimed_asset_id":"resource_site_minor_cache_amber_reliquary_opened","region":Rect2(96,0,48,48),"resource_count":12,"encounter_count":3,"rewards":{"gold":460,"ore":1},"special":"spell"},
	{"scenario_id":"lockmaster-cinder-kiln","site_id":"site_slag_purse_vault","site_placement_id":"lockmaster_slag_purse_vault","guard_placement_id":"lockmaster_cinder_kiln_watch","guard_encounter_id":"encounter_cinder_kiln_watch","unclaimed_asset_id":"mapobj_slag_purse_vault","claimed_asset_id":"resource_site_minor_cache_slag_purse_vault_opened","region":Rect2(144,0,48,48),"resource_count":12,"encounter_count":4,"rewards":{"gold":520,"ore":2},"special":"town_support"},
	{"scenario_id":"greenbarrow-cinder-writ","site_id":"site_old_orchard_crypt","site_placement_id":"greenbarrow_dormant_b","guard_placement_id":"greenbarrow_orchard_levy_watch","guard_encounter_id":"encounter_orchard_levy_watch","unclaimed_asset_id":"mapobj_old_orchard_crypt","claimed_asset_id":"resource_site_minor_cache_old_orchard_crypt_opened","region":Rect2(192,0,48,48),"resource_count":10,"encounter_count":4,"rewards":{"gold":480,"wood":2},"special":"artifact"},
	{"scenario_id":"mossvein-switchback-circuit","site_id":"site_moss_oath_cache","site_placement_id":"mossvein_moss_oath_cache","guard_placement_id":"mossvein_switchback_hostel_watch","guard_encounter_id":"encounter_switchback_hostel_watch","unclaimed_asset_id":"mapobj_moss_oath_cache","claimed_asset_id":"resource_site_minor_cache_moss_oath_cache_opened","region":Rect2(240,0,48,48),"resource_count":15,"encounter_count":5,"rewards":{"gold":360,"ore":1},"special":"objective"},
	{"scenario_id":"beaconscribe-frostbeacon-circuit","site_id":"site_frost_tithe_cellar","site_placement_id":"beaconscribe_frost_tithe_cellar","guard_placement_id":"beaconscribe_frostbeacon_bothy_watch","guard_encounter_id":"encounter_frostbeacon_bothy_watch","unclaimed_asset_id":"mapobj_frost_tithe_cellar","claimed_asset_id":"resource_site_minor_cache_frost_tithe_cellar_opened","region":Rect2(288,0,48,48),"resource_count":15,"encounter_count":5,"rewards":{"gold":440,"wood":2},"special":"recruits","recruits":{"unit_neutral_frostbeacon_pikes":2,"unit_neutral_snowglass_markers":1}},
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
		var rows_before := _rows.size()
		await _validate_case(view, case_value)
		if _rows.size() != rows_before + 1:
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
	var placement_id := String(case.get("site_placement_id", ""))
	var guard_id := String(case.get("guard_placement_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == int(case.get("resource_count", -1)), "%s resource placement count changed." % scenario_id)
	_expect((scenario.get("encounters", []) as Array).size() == int(case.get("encounter_count", -1)), "%s encounter placement count changed." % scenario_id)
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	var guard := _encounter(session, guard_id)
	_expect(String(node.get("site_id", "")) == site_id and String(node.get("guard_front_id", "")) == guard_id, "%s lost its exact site-to-guard link." % placement_id)
	_expect(String(guard.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s lost its authored guard identity." % guard_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")).ends_with("_live"), "%s is not live." % site_id)
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(maxi(0, focus.x - 1), focus.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed_asset_id", "")), "%s lost its closed landmark art." % site_id)
	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_id, "%s did not expose its exact blocking guard." % placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % placement_id)
	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s did not construct its production guard battle." % guard_id)
	_resolve_guard(session, guard_id)
	var rewards: Dictionary = case.get("rewards", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var recruits: Dictionary = case.get("recruits", {})
	var recruits_before := _army_counts(session, recruits.keys())
	var artifacts_before := _artifact_ids(session)
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s resource reward changed." % placement_id)
	var claimed_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	var special := String(case.get("special", ""))
	match special:
		"scouting":
			_expect(int(claim.get("site_vision_radius", 0)) == 4 and int(claim.get("site_reveal_tiles", 0)) > 0, "%s scouting reveal did not execute." % placement_id)
		"artifact":
			var owned_after := _artifact_ids(session)
			_expect(_artifact_ids(session).size() == artifacts_before.size() + 1 and String(claimed_node.get("artifact_reward_table_id", "")) == "artifact_source_guarded_sites_standard" and String(claimed_node.get("artifact_reward_id", "")) in owned_after, "%s artifact reward did not execute once with provenance." % placement_id)
		"spell":
			_expect("spell_survey_chain" in session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", []), "%s did not teach Survey Chain." % placement_id)
		"town_support":
			var towns: Array = session.overworld.get("towns", [])
			for index in range(towns.size()):
				if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == "lockmaster_enemy_town":
					towns[index]["owner"] = "player"
			session.overworld["towns"] = towns
			var supported_town := _town(session, "lockmaster_enemy_town")
			var logistics := OverworldRules.town_logistics_state(session, supported_town)
			_expect(int(logistics.get("readiness_bonus", 0)) >= 2 and int(logistics.get("recovery_relief_bonus", 0)) >= 1, "%s did not provide persistent town support." % placement_id)
		"objective":
			_expect(bool(session.flags.get("moss_oath_cache_recovered", false)) and bool(session.flags.get("mossvein_moss_oath_recorded", false)), "%s did not trigger its scenario-reactive oath flags." % placement_id)
			_expect(int(session.overworld.get("resources", {}).get("verdant_grafts", 0)) >= 3, "%s did not grant the scenario-reactive verdant graft." % placement_id)
		"recruits":
			_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s recruit reward changed." % placement_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed_asset_id", "")), "%s did not switch to its claimed landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s did not resolve its exact claimed atlas region." % site_id)
	var capture_path := await _capture_if_requested(site_id)
	var authority_after_claim := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated authority." % placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), focus)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its claimed art state." % placement_id)
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"site_placement_id":placement_id,"guard_placement_id":guard_id,"special":special,"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"capture_path":capture_path,"blocked_before_guard_clear":true,"guard_battle_constructed":not battle.is_empty(),"resource_reward_verified":true,"special_reward_verified":true,"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


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


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("MINOR_GUARDED_CACHE_CAPTURE_DIR")
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
