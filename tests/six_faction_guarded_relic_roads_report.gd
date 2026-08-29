extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_GUARDED_RELIC_ROADS_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_guarded_relic_roads_report"
const TABLE_ID := "artifact_source_guarded_sites_faction_relics"
const CASES := [
	{"scenario_id":"rainledger-cinder-convergence","faction_id":"faction_embercourt","site_id":"site_lantern_crown_nave","site_placement_id":"rainledger_lantern_crown_nave","guard_placement_id":"rainledger_lantern_crown_guard","guard_encounter_id":"encounter_lantern_warren_watch","artifact_id":"artifact_lockfire_assize_seal","icon_path":"res://art/artifacts/runtime/lockfire_assize_seal.png","rewards":{"gold":820,"wood":2,"ore":2},"bonuses":{"battle_defense":2,"daily_income":{"embergrain":1}}},
	{"scenario_id":"fenwake-bogbell-convergence","faction_id":"faction_mireclaw","site_id":"site_hive_of_reeds","site_placement_id":"fenwake_hive_of_reeds","guard_placement_id":"fenwake_hive_of_reeds_guard","guard_encounter_id":"encounter_bogbell_croft_watch","artifact_id":"artifact_miremoon_hunt_drum","icon_path":"res://art/artifacts/runtime/miremoon_hunt_drum.png","rewards":{"gold":680,"wood":4},"bonuses":{"battle_attack":2,"battle_initiative":1,"daily_income":{"peatwax":1}}},
	{"scenario_id":"halometer-icehook-convergence","faction_id":"faction_sunvault","site_id":"site_glassbound_eyrie","site_placement_id":"halometer_glassbound_eyrie","guard_placement_id":"halometer_glassbound_eyrie_guard","guard_encounter_id":"encounter_cliffhawk_roost_watch","artifact_id":"artifact_noonglass_orrery","icon_path":"res://art/artifacts/runtime/noonglass_orrery.png","rewards":{"gold":860,"ore":3},"bonuses":{"battle_spell_resistance_pct":12,"battle_initiative":1,"daily_income":{"aetherglass":1}}},
	{"scenario_id":"graftsibyl-lantern-convergence","faction_id":"faction_thornwake","site_id":"site_rootwarden_stockade","site_placement_id":"graftsibyl_rootwarden_stockade","guard_placement_id":"graftsibyl_rootwarden_stockade_guard","guard_encounter_id":"encounter_bramble_hedge_watch","artifact_id":"artifact_worldroot_covenant_heartwood","icon_path":"res://art/artifacts/runtime/worldroot_covenant_heartwood.png","rewards":{"gold":900,"wood":5},"bonuses":{"battle_defense":2,"overworld_movement":1,"daily_income":{"verdant_grafts":1}}},
	{"scenario_id":"debtrune-default-convergence","faction_id":"faction_brasshollow","site_id":"site_rust_choir_foundry","site_placement_id":"debtrune_rust_choir_foundry","guard_placement_id":"debtrune_rust_choir_foundry_guard","guard_encounter_id":"encounter_cinder_kiln_watch","artifact_id":"artifact_seventh_clause_pressure_key","icon_path":"res://art/artifacts/runtime/seventh_clause_pressure_key.png","rewards":{"gold":980,"ore":5},"bonuses":{"battle_attack":1,"battle_defense":1,"daily_income":{"brass_scrip":1}}},
	{"scenario_id":"nightchart-meridian-convergence","faction_id":"faction_veilmourn","site_id":"site_salt_wight_convoy","site_placement_id":"nightchart_salt_wight_convoy","guard_placement_id":"nightchart_salt_wight_convoy_guard","guard_encounter_id":"encounter_saltpan_camp_watch","artifact_id":"artifact_last_bell_tideglass","icon_path":"res://art/artifacts/runtime/last_bell_tideglass.png","rewards":{"gold":760,"wood":3,"ore":2},"bonuses":{"scouting_radius":2,"battle_initiative":1,"daily_income":{"memory_salt":1}}},
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
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"reward_table_id": TABLE_ID,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var site_placement_id := String(case.get("site_placement_id", ""))
	var guard_placement_id := String(case.get("guard_placement_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s lost its faction owner." % scenario_id)
	_expect((scenario.get("resource_nodes", []) as Array).size() == 17 and (scenario.get("encounters", []) as Array).size() == 7, "%s lost its 17-site / 7-front contract." % scenario_id)
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _resource_node_result(session, site_placement_id)
	var node: Dictionary = node_result.get("node", {})
	var guard := _encounter(session, guard_placement_id)
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	_expect(not node.is_empty() and String(node.get("site_id", "")) == String(case.get("site_id", "")), "%s is missing its exact guarded site node." % scenario_id)
	_expect(String(node.get("guard_front_id", "")) == guard_placement_id, "%s site does not point to its exact guard." % scenario_id)
	_expect(not guard.is_empty() and String(guard.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s is missing its exact guard encounter." % scenario_id)
	_expect(String(site.get("guarded_reward_contract", {}).get("artifact_reward_table_id", "")) == TABLE_ID, "%s does not use the faction relic table." % String(case.get("site_id", "")))

	var icon = load(String(case.get("icon_path", "")))
	_expect(icon is Texture2D and icon.get_size() == Vector2(128, 128), "%s icon did not load as a 128x128 texture." % String(case.get("artifact_id", "")))
	var focus := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	_set_active_hero_position(session, Vector2i(maxi(0, focus.x - 1), focus.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), focus)
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var blocking_guard := OverworldRules.resource_site_blocking_guard(session, node, site)
	_expect(String(blocking_guard.get("placement_id", "")) == guard_placement_id, "%s did not expose the exact blocking guard." % site_placement_id)
	var blocked := OverworldRules._collect_resource_node_result(session, node_result, false)
	_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s could be claimed before guard clearance." % site_placement_id)

	var battle := BattleRulesScript.create_battle_payload(session, guard)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s did not construct its production guard battle." % guard_placement_id)
	_resolve_guard(session, guard_placement_id)
	_expect(OverworldRules.resource_site_blocking_guard(session, _resource_node_result(session, site_placement_id).get("node", {}), site).is_empty(), "%s remained blocked after its exact guard resolved." % site_placement_id)

	var resources_before := _resource_snapshot(session)
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), false)
	_expect(bool(claim.get("ok", false)), "%s claim failed after guard clearance: %s" % [site_placement_id, JSON.stringify(claim)])
	if not bool(claim.get("ok", false)):
		return
	var resources_after := _resource_snapshot(session)
	for resource_id_value in case.get("rewards", {}).keys():
		var resource_id := String(resource_id_value)
		var delta := int(resources_after.get(resource_id, 0)) - int(resources_before.get(resource_id, 0))
		_expect(delta == int(case.get("rewards", {}).get(resource_id, -1)), "%s reward delta changed for %s: %d." % [site_placement_id, resource_id, delta])
	var artifact_id := String(case.get("artifact_id", ""))
	var owned_after := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	_expect(owned_after.size() == owned_before.size() + 1 and artifact_id in owned_after, "%s did not grant exactly its faction relic." % site_placement_id)
	var claimed_node: Dictionary = _resource_node_result(session, site_placement_id).get("node", {})
	_expect(String(claimed_node.get("artifact_reward_id", "")) == artifact_id and String(claimed_node.get("artifact_reward_table_id", "")) == TABLE_ID and String(claimed_node.get("artifact_reward_claimed_by_faction_id", "")) == "player", "%s lost deterministic relic provenance." % site_placement_id)
	var totals := ArtifactRules.aggregate_bonuses(session.overworld.get("hero", {}))
	_validate_bonus_payload(totals, case.get("bonuses", {}), artifact_id)

	var repeat := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, site_placement_id), false)
	_expect(not bool(repeat.get("ok", true)) and ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {})).size() == owned_after.size(), "%s granted a repeated reward." % site_placement_id)
	var restored := _clone_session(session)
	var restored_node: Dictionary = _resource_node_result(restored, site_placement_id).get("node", {})
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict(), "%s did not round-trip exactly through save version %d." % [site_placement_id, SessionStateStoreScript.SAVE_VERSION])
	_expect(String(restored_node.get("artifact_reward_id", "")) == artifact_id and artifact_id in ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})), "%s restore lost relic ownership or provenance." % site_placement_id)
	_rows.append({"scenario_id":scenario_id,"site_id":String(case.get("site_id", "")),"site_placement_id":site_placement_id,"guard_encounter_id":String(case.get("guard_encounter_id", "")),"artifact_id":artifact_id,"icon_path":String(case.get("icon_path", "")),"capture_path":capture_path,"blocked_before_guard_clear":true,"guard_battle_constructed":not battle.is_empty(),"reward_granted_once":true,"save_round_trip_exact":restored.to_dict() == session.to_dict()})


func _validate_bonus_payload(actual: Dictionary, expected: Dictionary, artifact_id: String) -> void:
	for key_value in expected.keys():
		var key := String(key_value)
		if expected.get(key) is Dictionary:
			var actual_nested: Dictionary = actual.get(key, {}) if actual.get(key, {}) is Dictionary else {}
			for nested_key_value in (expected.get(key) as Dictionary).keys():
				var nested_key := String(nested_key_value)
				_expect(int(actual_nested.get(nested_key, 0)) == int(expected.get(key, {}).get(nested_key, -1)), "%s live %s.%s bonus changed." % [artifact_id, key, nested_key])
		else:
			_expect(int(actual.get(key, 0)) == int(expected.get(key, -1)), "%s live %s bonus changed." % [artifact_id, key])


func _resource_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _resolve_guard(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return resources.duplicate(true)


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("GUARDED_RELIC_ROADS_CAPTURE_DIR")
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
