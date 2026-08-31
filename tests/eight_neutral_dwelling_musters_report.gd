extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "EIGHT_NEUTRAL_DWELLING_MUSTERS_REPORT"
const OUTPUT_DIR := "res://.artifacts/eight_neutral_dwelling_musters_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/neutral_dwelling_claimed_atlas.png"
const CASES := [
	{"scenario_id":"tollreaver-roadward-lodge","site_id":"site_free_company_yard","placement_id":"tollreaver_watch_dwelling","guard_id":"tollreaver_roadward_lodge_watch","encounter_id":"encounter_roadward_lodge_watch","unclaimed":"mapobj_roadward_lodge","claimed":"resource_site_neutral_roadward_lodge_claimed","region":Rect2(0,0,48,48)},
	{"scenario_id":"cinderquill-fenhound-lexicon","site_id":"site_fenhound_kennels","placement_id":"cinderquill_watch_dwelling","guard_id":"cinderquill_fenhound_kennel_watch","encounter_id":"encounter_fenhound_kennel_watch","unclaimed":"kennel","claimed":"resource_site_neutral_fenhound_kennels_claimed","region":Rect2(48,0,48,48)},
	{"scenario_id":"facetlane-cliffhawk-roost","site_id":"site_cliffhawk_roost","placement_id":"facetlane_watch_dwelling","guard_id":"facetlane_cliffhawk_roost_watch","encounter_id":"encounter_cliffhawk_roost_watch","unclaimed":"mapobj_cliffhawk_roost","claimed":"resource_site_neutral_cliffhawk_roost_claimed","region":Rect2(96,0,48,48)},
	{"scenario_id":"reedscript-reedbarge-circuit","site_id":"site_reedbarge_mooring","placement_id":"reedscript_watch_dwelling","guard_id":"reedscript_reedbarge_mooring_watch","encounter_id":"encounter_reedbarge_mooring_watch","unclaimed":"mapobj_reedbarge_mooring","claimed":"resource_site_neutral_reedbarge_mooring_claimed","region":Rect2(144,0,48,48)},
	{"scenario_id":"rotlamp-glowcap-refrain","site_id":"site_glowcap_croft","placement_id":"rotlamp_watch_dwelling","guard_id":"rotlamp_glowcap_croft_watch","encounter_id":"encounter_glowcap_croft_watch","unclaimed":"mapobj_glowcap_croft","claimed":"resource_site_neutral_glowcap_croft_claimed","region":Rect2(192,0,48,48)},
	{"scenario_id":"ashmeter-dustjack-circuit","site_id":"site_dustjack_yard","placement_id":"ashmeter_watch_dwelling","guard_id":"ashmeter_dustjack_yard_watch","encounter_id":"encounter_dustjack_yard_watch","unclaimed":"mapobj_dustjack_yard","claimed":"resource_site_neutral_dustjack_yard_claimed","region":Rect2(240,0,48,48)},
	{"scenario_id":"lockmaster-cinder-kiln","site_id":"site_cinder_kiln","placement_id":"lockmaster_watch_dwelling","guard_id":"lockmaster_cinder_kiln_watch","encounter_id":"encounter_cinder_kiln_watch","unclaimed":"mapobj_cinder_kiln","claimed":"resource_site_neutral_cinder_kiln_claimed","region":Rect2(288,0,48,48)},
	{"scenario_id":"beaconscribe-frostbeacon-circuit","site_id":"site_frostbeacon_bothy","placement_id":"beaconscribe_watch_dwelling","guard_id":"beaconscribe_frostbeacon_bothy_watch","encounter_id":"encounter_frostbeacon_bothy_watch","unclaimed":"mapobj_frostbeacon_bothy","claimed":"resource_site_neutral_frostbeacon_bothy_claimed","region":Rect2(336,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir()))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in _cases():
		print("%s CASE_START %s" % [_report_id(), String(case_value.get("site_id", ""))])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [_report_id(), String(case_value.get("site_id", ""))])
	var report := {"ok":_errors.is_empty(),"case_count":_cases().size(),"atlas_path":_atlas_path(),"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_finalize_batch_report(report)
	report["ok"] = _errors.is_empty()
	report["errors"] = _errors
	_write_json("%s/report.json" % _output_dir(), report)
	if _errors.is_empty():
		print("%s %s" % [_report_id(), JSON.stringify({"ok":true,"case_count":_cases().size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var guard_id := String(case.get("guard_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	var guard := _encounter(session, guard_id)
	_expect(String(node.get("site_id", "")) == site_id and String(node.get("guard_front_id", "")) == guard_id, "%s lost its exact site-to-guard link." % placement_id)
	_expect(String(guard.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s lost its exact neutral watch." % guard_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "neutral_dwelling_live", "%s is not live." % site_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, tile)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed", "")), "%s lost its exact unclaimed landmark." % site_id)
	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_id, "%s did not expose its exact blocking guard." % placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % placement_id)
	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s did not construct its production guard battle." % guard_id)
	_resolve_guard(session, guard_id)
	# Flush any authored guard-clear hook before measuring the site's own claim delta.
	# This keeps scenario-event rewards distinct from the dwelling reward under test.
	ScenarioRules.evaluate_session(session)

	var rewards: Dictionary = site.get("claim_rewards", {})
	var claim_recruits: Dictionary = site.get("claim_recruits", {})
	var weekly_recruits: Dictionary = site.get("weekly_recruits", {})
	var resources_before := _resource_counts(session, rewards.keys())
	var army_before := _army_counts(session, claim_recruits.keys())
	var income_before := OverworldRules.controlled_resource_site_income(session, "player")
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s claim resources changed." % site_id)
	_expect(_resource_delta_exact(army_before, _army_counts(session, claim_recruits.keys()), claim_recruits), "%s claim recruits changed." % site_id)
	_expect(_resource_delta_exact(income_before, OverworldRules.controlled_resource_site_income(session, "player"), site.get("control_income", {})), "%s controlled income did not activate." % site_id)
	var claimed_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed", "")), "%s did not switch to its exact controlled-state landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == _atlas_path() and texture.region == case.get("region"), "%s did not resolve its exact atlas region." % site_id)

	var town_recruits_before := _town_recruit_counts(session, weekly_recruits.keys())
	var muster_messages := OverworldRules.apply_controlled_resource_site_musters(session, "player")
	_expect(not muster_messages.is_empty(), "%s did not emit its weekly muster." % site_id)
	_expect(_resource_delta_exact(town_recruits_before, _town_recruit_counts(session, weekly_recruits.keys()), weekly_recruits), "%s weekly recruits did not reach the nearest held town." % site_id)
	var authority_after_rewards := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_rewards, "%s repeat claim mutated authority." % site_id)

	_fund_response_order(session)
	_set_active_hero_position(session, tile)
	var response := OverworldRules.perform_context_action(session, "site_response")
	var response_node: Dictionary = _resource_node_result(session, placement_id).get("node", {})
	_expect(bool(response.get("ok", false)) and int(response_node.get("response_until_day", 0)) >= session.day, "%s public response order did not activate." % site_id)
	var capture_path := await _capture_if_requested(site_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), tile)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [site_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its controlled-state art." % site_id)
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"placement_id":placement_id,"guard_id":guard_id,"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"claim_rewards":rewards,"claim_recruits":claim_recruits,"weekly_recruits":weekly_recruits,"capture_path":capture_path,"guard_blocking":true,"guard_battle_constructed":not battle.is_empty(),"income_active":true,"response_active":bool(response.get("ok", false)),"save_round_trip_exact":restored.to_dict() == session.to_dict()})


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


func _town_recruit_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		result[String(key_value)] = 0
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		for key_value in keys:
			var unit_id := String(key_value)
			result[unit_id] = int(result.get(unit_id, 0)) + int(town.get("available_recruits", {}).get(unit_id, 0))
	return result


func _resource_delta_exact(before: Dictionary, after: Dictionary, expected_value: Variant) -> bool:
	if not (expected_value is Dictionary):
		return false
	for key_value in expected_value.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected_value.get(key_value, 0)):
			return false
	return true


func _fund_response_order(session: SessionStateStoreScript.SessionData) -> void:
	var resources: Dictionary = session.overworld.get("resources", {})
	for resource_id in ["gold", "wood", "ore"]:
		resources[resource_id] = maxi(9999, int(resources.get(resource_id, 0)))
	session.overworld["resources"] = resources
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["max"] = maxi(99, int(movement.get("max", 0)))
	movement["current"] = int(movement.get("max", 99))
	session.overworld["movement"] = movement


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
	var capture_dir := OS.get_environment(_capture_environment_name())
	if capture_dir == "":
		return ""
	await get_tree().process_frame
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "%s capture failed." % stem)
	return path


func _report_id() -> String:
	return REPORT_ID


func _output_dir() -> String:
	return OUTPUT_DIR


func _atlas_path() -> String:
	return ATLAS_PATH


func _capture_environment_name() -> String:
	return "NEUTRAL_DWELLING_CAPTURE_DIR"


func _cases() -> Array:
	return CASES


func _finalize_batch_report(_report: Dictionary) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error(message)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")
