extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SETBOUND_REGALIA_ASSEMBLIES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/setbound_regalia_assemblies_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/setbound_regalia_reliquaries_atlas.png"
const WRONG_SET_PIECES := ["artifact_trailsinger_boots", "artifact_waymark_compass", "artifact_milepost_lantern"]
const CASES := [
	{"scenario_id":"cinderquill-lockward-charter-assembly","prefix":"lockwardassembly","hero_id":"hero_embercourt_orra_cinderquill","set_id":"set_lockward_charter","pieces":["artifact_tollstone_ring","artifact_lockflame_writ_banner","artifact_lockward_beacon_key"],"site_id":"site_lockward_charter_reliquary","asset_id":"resource_site_regalia_lockward_charter_reliquary","region":Rect2(0,0,48,48)},
	{"scenario_id":"reedcaller-fenhound-pursuit-assembly","prefix":"fenhoundassembly","hero_id":"hero_mireclaw_rhask_reedcaller","set_id":"set_fenhound_pursuit","pieces":["artifact_reedshadow_waders","artifact_mirechain_hunt_totem","artifact_fenhound_scent_bell"],"site_id":"site_fenhound_pursuit_reliquary","asset_id":"resource_site_regalia_fenhound_pursuit_reliquary","region":Rect2(48,0,48,48)},
	{"scenario_id":"sunvein-meridian-relay-assembly","prefix":"meridianassembly","hero_id":"hero_sunvault_calis_sunvein","set_id":"set_meridian_relay","pieces":["artifact_prismward_mantle","artifact_zenith_prism_pennon","artifact_meridian_relay_lens"],"site_id":"site_meridian_relay_reliquary","asset_id":"resource_site_regalia_meridian_relay_reliquary","region":Rect2(96,0,48,48)},
	{"scenario_id":"mossvein-rootpath-covenant-assembly","prefix":"rootpathassembly","hero_id":"hero_thornwake_ralka_mossvein","set_id":"set_rootpath_covenant","pieces":["artifact_graftbark_cuirass","artifact_briarcrown_covenant_standard","artifact_rootpath_seed_compass"],"site_id":"site_rootpath_covenant_reliquary","asset_id":"resource_site_regalia_rootpath_covenant_reliquary","region":Rect2(144,0,48,48)},
	{"scenario_id":"blackgauge-redline-survey-assembly","prefix":"redlineassembly","hero_id":"hero_brasshollow_kestra_blackgauge","set_id":"set_redline_survey_warrant","pieces":["artifact_quenchplate_vambrace","artifact_redline_warrant_gonfalon","artifact_redline_survey_dial"],"site_id":"site_redline_survey_reliquary","asset_id":"resource_site_regalia_redline_survey_reliquary","region":Rect2(192,0,48,48)},
	{"scenario_id":"tidehook-drowned-wake-chart-assembly","prefix":"drownedwakeassembly","hero_id":"hero_veilmourn_olan_tidehook","set_id":"set_drowned_wake_chart","pieces":["artifact_fogwake_deckboots","artifact_wakebell_mourning_ensign","artifact_black_sail_compass"],"site_id":"site_drowned_wake_reliquary","asset_id":"resource_site_regalia_drowned_wake_reliquary","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Setbound Regalia atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"exact_art_count": _count_rows("exact_art"),
		"initially_pending_count": _count_rows("initially_pending"),
		"wrong_hero_control_count": _count_rows("wrong_hero_control"),
		"inventory_only_control_count": _count_rows("inventory_only_control"),
		"wrong_set_control_count": _count_rows("wrong_set_control"),
		"partial_set_control_count": _count_rows("partial_set_control"),
		"production_battle_count": _sum_rows("production_battle_count"),
		"artifact_pickup_claim_count": _sum_rows("artifact_pickup_claim_count"),
		"reliquary_claim_count": _count_rows("reliquary_claim"),
		"production_stow_count": _sum_rows("production_stow_count"),
		"production_equip_count": _sum_rows("production_equip_count"),
		"active_set_count": _count_rows("active_set"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"unrelated_event_skip_count": _count_rows("unrelated_event_skip"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_equip_count":18,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var hero_id := String(case.get("hero_id", ""))
	var set_id := String(case.get("set_id", ""))
	var pieces: Array = case.get("pieces", [])
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	var objective: Dictionary = scenario.get("objectives", {}).get("victory", [])[0]
	var objective_id := String(objective.get("id", ""))
	var initially_pending := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(initially_pending, "%s began with a completed artifact set." % scenario_id)

	var reliquary_result := _resource_node_result(session, "%s_reliquary" % prefix)
	var reliquary: Dictionary = reliquary_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", reliquary))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact regalia-reliquary atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(reliquary.get("x", 0)), int(reliquary.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var inventory_probe := _clone_session(session)
	_set_target_artifacts(inventory_probe, hero_id, [], pieces)
	var inventory_only_control := not ScenarioRulesScript.is_objective_met(inventory_probe, objective_id, "victory")
	_expect(inventory_only_control, "%s accepted a complete set held only in inventory." % scenario_id)

	var partial_probe := _clone_session(session)
	_set_target_artifacts(partial_probe, hero_id, pieces.slice(0, 2), [])
	var partial_set_control := not ScenarioRulesScript.is_objective_met(partial_probe, objective_id, "victory")
	_expect(partial_set_control, "%s accepted only two equipped set pieces." % scenario_id)

	var wrong_set_probe := _clone_session(session)
	_set_target_artifacts(wrong_set_probe, hero_id, WRONG_SET_PIECES, [])
	var wrong_set_control := not ScenarioRulesScript.is_objective_met(wrong_set_probe, objective_id, "victory")
	_expect(wrong_set_control, "%s accepted a complete but unrelated artifact set." % scenario_id)

	var wrong_hero_probe := _clone_session(session)
	_append_wrong_hero_with_set(wrong_hero_probe, pieces)
	var wrong_hero_control := not ScenarioRulesScript.is_objective_met(wrong_hero_probe, objective_id, "victory")
	_expect(wrong_hero_control, "%s accepted the complete set on a different controlled hero." % scenario_id)

	var production_battle_count := 0
	var artifact_pickup_claim_count := 0
	var production_stow_count := 0
	for route in [
		{"guard":"%s_first_piece_guard" % prefix,"node":"%s_first_piece" % prefix,"piece":pieces[0]},
		{"guard":"%s_second_piece_guard" % prefix,"node":"%s_second_piece" % prefix,"piece":pieces[1]},
	]:
		if _resolve_guard(session, String(route.get("guard", ""))):
			production_battle_count += 1
		var node_result := _artifact_node_result(session, String(route.get("node", "")))
		var claim: Dictionary = OverworldRules._collect_artifact_node_result(session, node_result, true)
		var authority := session.to_dict()
		var repeat: Dictionary = OverworldRules._collect_artifact_node_result(session, _artifact_node_result(session, String(route.get("node", ""))), true)
		if bool(claim.get("ok", false)) and not bool(repeat.get("ok", true)) and session.to_dict() == authority and ArtifactRulesScript.has_artifact(session.overworld.get("hero", {}), String(route.get("piece", ""))):
			artifact_pickup_claim_count += 1
		if _stow_piece(session, String(route.get("piece", ""))):
			production_stow_count += 1

	if _resolve_guard(session, "%s_reliquary_guard" % prefix):
		production_battle_count += 1
	var reliquary_claim_result: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_reliquary" % prefix), true)
	var reliquary_authority := session.to_dict()
	var reliquary_repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_reliquary" % prefix), true)
	var claimed_node: Dictionary = _resource_node_result(session, "%s_reliquary" % prefix).get("node", {})
	var mutation_facts: Dictionary = reliquary_claim_result.get("interaction_result", {}).get("mutation_facts", {})
	var reliquary_claim: bool = bool(reliquary_claim_result.get("ok", false)) and not bool(reliquary_repeat.get("ok", true)) and session.to_dict() == reliquary_authority and String(claimed_node.get("artifact_reward_id", "")) == String(pieces[2]) and String(pieces[2]) in mutation_facts.get("artifact_ids", [])
	_expect(reliquary_claim, "%s did not grant its exact one-time faction set piece." % scenario_id)
	if _stow_piece(session, String(pieces[2])):
		production_stow_count += 1
	_expect(production_battle_count == 3 and artifact_pickup_claim_count == 2 and production_stow_count == 3, "%s did not recover and stow all three pieces through production authority." % scenario_id)
	var live_inventory_only := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(live_inventory_only, "%s completed before the recovered pieces were equipped." % scenario_id)

	var unrelated_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"artifact_changed","artifact_ids":["artifact_unrelated"],"hero_ids":["hero_unrelated"]})
	var unrelated_profile: Dictionary = unrelated_result.get("profile", {})
	var unrelated_event_skip := String(unrelated_profile.get("dependency_mode", "")) == "event_gated_skip" and int(unrelated_profile.get("objectives_checked", -1)) == 0
	_expect(unrelated_event_skip, "%s reevaluated its set objective for unrelated hero/artifact changes." % scenario_id)

	var production_equip_count := 0
	for index in range(2):
		var equip_result: Dictionary = OverworldRules.equip_artifact(session, String(pieces[index]))
		if bool(equip_result.get("ok", false)):
			production_equip_count += 1
	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"artifact_changed","artifact_ids":pieces.duplicate(),"hero_ids":[hero_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped controlled-hero and set-piece dependencies." % scenario_id)
	var live_partial := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(live_partial, "%s completed with only two production-equipped set pieces." % scenario_id)
	var final_equip: Dictionary = OverworldRules.equip_artifact(session, String(pieces[2]))
	if bool(final_equip.get("ok", false)):
		production_equip_count += 1
	_expect(production_equip_count == 3, "%s did not equip all three pieces through production artifact actions." % scenario_id)

	var set_state := _set_state(session.overworld.get("hero", {}), set_id)
	var active_set: bool = bool(set_state.get("complete", false)) and int(set_state.get("equipped_piece_count", 0)) == 3 and set_state.get("active_thresholds", []).size() == 2
	_expect(active_set, "%s did not activate both live thresholds of its complete artifact set." % scenario_id)
	var objective_label: String = ScenarioRulesScript._objective_label(session, objective)
	_expect("3/3 regalia pieces equipped; set active" in objective_label, "%s did not expose compact complete-set objective progress." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", session.scenario_status)) == "victory" and ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and session.day < 18
	_expect(scenario_victory, "%s did not win after three battles and three production equip actions: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory") and bool(_set_state(restored.overworld.get("hero", {}), set_id).get("complete", false))
	_expect(save_exact, "%s did not preserve the completed equipped set through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"initially_pending":initially_pending,"wrong_hero_control":wrong_hero_control,"inventory_only_control":inventory_only_control and live_inventory_only,"wrong_set_control":wrong_set_control,"partial_set_control":partial_set_control and live_partial,"production_battle_count":production_battle_count,"artifact_pickup_claim_count":artifact_pickup_claim_count,"reliquary_claim":reliquary_claim,"production_stow_count":production_stow_count,"production_equip_count":production_equip_count,"active_set":active_set,"scoped_dependency":scoped_dependency,"unrelated_event_skip":unrelated_event_skip,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_guard(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
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
	return String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _set_target_artifacts(session, hero_id: String, equipped_ids: Array, inventory_ids: Array) -> void:
	var hero := HeroCommandRulesScript.hero_by_id(session, hero_id).duplicate(true)
	hero["artifacts"] = {"equipped":{},"inventory":inventory_ids.duplicate()}
	hero = ArtifactRulesScript.ensure_hero_artifacts(hero)
	for artifact_id in equipped_ids:
		if not ArtifactRulesScript.has_artifact(hero, String(artifact_id)):
			var inventory: Array = hero.get("artifacts", {}).get("inventory", [])
			inventory.append(String(artifact_id))
			hero["artifacts"]["inventory"] = inventory
		var equip_result: Dictionary = ArtifactRulesScript.equip_artifact(hero, String(artifact_id))
		hero = equip_result.get("hero", hero)
	_replace_hero(session, hero_id, hero)


func _append_wrong_hero_with_set(session, pieces: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = "hero_wrong_regalia_probe"
	hero["artifacts"] = {"equipped":{},"inventory":pieces.duplicate()}
	hero = ArtifactRulesScript.ensure_hero_artifacts(hero)
	for artifact_id in pieces:
		var equip_result: Dictionary = ArtifactRulesScript.equip_artifact(hero, String(artifact_id))
		hero = equip_result.get("hero", hero)
	var heroes: Array = session.overworld.get("player_heroes", [])
	heroes.append(hero)
	session.overworld["player_heroes"] = heroes


func _replace_hero(session, hero_id: String, hero: Dictionary) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		session.overworld["hero"] = hero.duplicate(true)
		session.overworld["army"] = hero.get("army", {}).duplicate(true)
	HeroCommandRulesScript.normalize_session(session)


func _stow_piece(session, artifact_id: String) -> bool:
	var location := ArtifactRulesScript.locate_artifact(session.overworld.get("hero", {}), artifact_id)
	if String(location.get("location", "")) == "inventory":
		return true
	if String(location.get("location", "")) != "equipped":
		return false
	var result: Dictionary = OverworldRules.unequip_artifact(session, String(location.get("slot", "")))
	return bool(result.get("ok", false)) and String(ArtifactRulesScript.locate_artifact(session.overworld.get("hero", {}), artifact_id).get("location", "")) == "inventory"


func _set_state(hero: Dictionary, set_id: String) -> Dictionary:
	for value in ArtifactRulesScript.artifact_set_runtime_state(hero):
		if value is Dictionary and String(value.get("set_id", "")) == set_id:
			return value
	return {}


func _artifact_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("SETBOUND_REGALIA_ASSEMBLIES_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _sum_rows(key: String) -> int:
	return _rows.reduce(func(total, row): return total + int(row.get(key, 0)), 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")
