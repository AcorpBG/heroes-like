extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_MAJOR_VAULT_UNSEALING_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_major_vault_unsealing_report"
const TABLE_ID := "artifact_source_guarded_sites_standard"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/major_vault_unsealed_atlas.png"
const CASES := [
	{"scenario_id":"sunvein-crystal-sump-circuit","site_id":"site_mirror_archive","site_placement_id":"sunvein_mirror_archive","guard_placement_id":"sunvein_crystal_sump_watch","guard_encounter_id":"encounter_crystal_sump_watch","unclaimed_asset_id":"mapobj_mirror_archive","claimed_asset_id":"resource_site_major_vault_mirror_archive_unsealed","region":Rect2(0,0,48,48),"resource_count":15,"encounter_count":5,"rewards":{"gold":820,"ore":3},"spell_id":"spell_lens_glass_survey_24","vision_radius":6},
	{"scenario_id":"heatpriest-obsidian-scar","site_id":"site_furnace_vault","site_placement_id":"heatpriest_furnace_vault","guard_placement_id":"heatpriest_obsidian_scar_watch","guard_encounter_id":"encounter_obsidian_scar_watch","unclaimed_asset_id":"mapobj_furnace_vault","claimed_asset_id":"resource_site_major_vault_furnace_vault_unsealed","region":Rect2(48,0,48,48),"resource_count":11,"encounter_count":3,"rewards":{"gold":900,"ore":4},"recruits":{"unit_neutral_scarshield_veterans":3,"unit_neutral_ashdart_stalkers":2}},
	{"scenario_id":"pollenglass-greenbranch-copse","site_id":"site_thorn_crown_hollow","site_placement_id":"pollenglass_thorn_crown_hollow","guard_placement_id":"pollenglass_greenbranch_copse_watch","guard_encounter_id":"encounter_greenbranch_copse_watch","unclaimed_asset_id":"mapobj_thorn_crown_hollow","claimed_asset_id":"resource_site_major_vault_thorn_crown_hollow_unsealed","region":Rect2(96,0,48,48),"resource_count":11,"encounter_count":3,"rewards":{"gold":760,"wood":4},"recruits":{"unit_neutral_greenbranch_cudgels":4,"unit_neutral_sapwhistle_callers":2}},
	{"scenario_id":"keelwarden-lockfire-run","site_id":"site_storm_bell_wreck","site_placement_id":"keelwarden_dormant_c","guard_placement_id":"keelwarden_storm_bell_wreck_guard","guard_encounter_id":"encounter_harbor_pilot_house_watch","unclaimed_asset_id":"mapobj_storm_bell_wreck","claimed_asset_id":"resource_site_major_vault_storm_bell_wreck_unsealed","region":Rect2(144,0,48,48),"resource_count":10,"encounter_count":4,"rewards":{"gold":840,"wood":4,"ore":1},"vision_radius":5},
	{"scenario_id":"glassmarshal-ossuary-battery","site_id":"site_prism_ossuary","site_placement_id":"glassmarshal_dormant_c","guard_placement_id":"glassmarshal_prism_ossuary_guard","guard_encounter_id":"encounter_kite_signal_eyrie_watch","unclaimed_asset_id":"mapobj_prism_ossuary","claimed_asset_id":"resource_site_major_vault_prism_ossuary_unsealed","region":Rect2(192,0,48,48),"resource_count":10,"encounter_count":4,"rewards":{"gold":780,"ore":3},"spell_id":"spell_lens_starlens_survey_12","vision_radius":5},
	{"scenario_id":"ninefold-confluence","site_id":"site_basalt_oath_tomb","site_placement_id":"ninefold_basalt_oath_tomb","guard_placement_id":"ninefold_basalt_gatehouse_watch","guard_encounter_id":"encounter_basalt_gatehouse_watch","unclaimed_asset_id":"mapobj_basalt_oath_tomb","claimed_asset_id":"resource_site_major_vault_basalt_oath_tomb_unsealed","region":Rect2(240,0,48,48),"resource_count":65,"encounter_count":8,"rewards":{"gold":940,"ore":5},"recruits":{"unit_neutral_basalt_wardens":3,"unit_neutral_tunnelmark_bolters":2}},
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
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"reward_table_id":TABLE_ID,"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
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
	_expect(String(site.get("guarded_reward_contract", {}).get("artifact_reward_table_id", "")) == TABLE_ID, "%s lost the standard guarded artifact table." % site_id)
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(maxi(0, focus.x - 1), focus.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed_asset_id", "")), "%s lost its closed landmark art." % site_id)
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
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var spell_id := String(case.get("spell_id", ""))
	var spell_known_before := spell_id in _known_spell_ids(session)
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), true)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [site_placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s resource reward changed." % site_placement_id)
	_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s recruit reward changed." % site_placement_id)
	if spell_id != "":
		_expect(not spell_known_before and spell_id in _known_spell_ids(session), "%s did not teach its authored overworld spell." % site_placement_id)
	if int(case.get("vision_radius", 0)) > 0:
		_expect(int(claim.get("site_vision_radius", 0)) == int(case.get("vision_radius", 0)) and int(claim.get("site_reveal_tiles", -1)) >= 0, "%s did not execute its authored scouting ring." % site_placement_id)
	var owned_after := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claimed_node: Dictionary = _resource_node_result(session, site_placement_id).get("node", {})
	_expect(owned_after.size() == owned_before.size() + 1, "%s did not grant exactly one artifact." % site_placement_id)
	_expect(String(claimed_node.get("artifact_reward_table_id", "")) == TABLE_ID and String(claimed_node.get("artifact_reward_id", "")) in owned_after, "%s lost deterministic artifact provenance." % site_placement_id)

	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var texture = view.call("_object_texture_for_asset", claimed_asset_id)
	_expect(claimed_asset_id == String(case.get("claimed_asset_id", "")), "%s did not switch to its unsealed landmark." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s did not resolve its exact atlas region." % site_id)
	var capture_path := await _capture_if_requested(site_id)
	var authority_after_claim := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim mutated authority." % site_placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, site_placement_id).get("node", {})
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), focus)
	await get_tree().process_frame
	_expect(restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION, "%s did not round-trip exactly through save version %d." % [site_placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(view.call("_resource_asset_id", restored_node)) == claimed_asset_id, "%s restore lost its unsealed art state." % site_placement_id)
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"site_placement_id":site_placement_id,"guard_placement_id":guard_placement_id,"unclaimed_asset_id":unclaimed_asset_id,"claimed_asset_id":claimed_asset_id,"artifact_id":String(claimed_node.get("artifact_reward_id", "")),"capture_path":capture_path,"blocked_before_guard_clear":true,"guard_battle_constructed":not battle.is_empty(),"special_reward_verified":spell_id != "" or not recruits.is_empty() or int(case.get("vision_radius", 0)) > 0,"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


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


func _known_spell_ids(session: SessionStateStoreScript.SessionData) -> Array:
	return session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])


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
	var capture_dir := OS.get_environment("MAJOR_VAULT_CAPTURE_DIR")
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
