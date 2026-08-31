extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "GARRISON_WARRANT_MUSTERS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/garrison_warrant_musters_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/garrison_warrant_musters_atlas.png"
const CASES := [
	{"scenario_id":"beaconscribe-cinderlock-three-seal-garrison-warrant","prefix":"cinderlockwarrant","site_id":"site_cinderlock_three_seal_garrison_warrant","asset_id":"resource_site_garrison_warrant_cinderlock_seals","region":Rect2(0,0,48,48)},
	{"scenario_id":"reedscript-murkward-three-hook-garrison-warrant","prefix":"murkwardwarrant","site_id":"site_murkward_three_hook_garrison_warrant","asset_id":"resource_site_garrison_warrant_murkward_hooks","region":Rect2(48,0,48,48)},
	{"scenario_id":"sevenfold-meridian-three-prism-garrison-warrant","prefix":"meridianwarrant","site_id":"site_meridian_three_prism_garrison_warrant","asset_id":"resource_site_garrison_warrant_meridian_prisms","region":Rect2(96,0,48,48)},
	{"scenario_id":"loamchant-graftroot-three-seed-garrison-warrant","prefix":"graftrootwarrant","site_id":"site_graftroot_three_seed_garrison_warrant","asset_id":"resource_site_garrison_warrant_graftroot_seeds","region":Rect2(144,0,48,48)},
	{"scenario_id":"quench-orevein-three-gauge-garrison-warrant","prefix":"oreveinwarrant","site_id":"site_orevein_three_gauge_garrison_warrant","asset_id":"resource_site_garrison_warrant_orevein_gauges","region":Rect2(192,0,48,48)},
	{"scenario_id":"obituaryink-bellwake-three-bell-garrison-warrant","prefix":"bellwakewarrant","site_id":"site_bellwake_three_bell_garrison_warrant","asset_id":"resource_site_garrison_warrant_bellwake_bells","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Garrison Warrant atlas must remain exactly 288x48.")
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
		"wrong_town_control_count": _count_rows("wrong_town_control"),
		"enemy_owned_town_control_count": _count_rows("enemy_owned_town_control"),
		"hero_carried_control_count": _count_rows("hero_carried_control"),
		"partial_garrison_control_count": _count_rows("partial_garrison_control"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"production_claim_count": _count_rows("production_claim"),
		"production_transfer_count": _rows.reduce(func(total, row): return total + int(row.get("production_transfer_count", 0)), 0),
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
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_transfer_count":18,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var home_id := "%s_home" % prefix
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	var objective: Dictionary = scenario.get("objectives", {}).get("victory", [])[0]
	var objective_id := String(objective.get("id", ""))
	var requirements: Array = objective.get("requirements", [])
	var requirement_stacks := _requirement_stacks(requirements)
	var unit_ids := requirements.map(func(requirement): return String(requirement.get("unit_id", "")))
	_expect(not ScenarioRulesScript.is_objective_met(session, objective_id, "victory"), "%s began with a completed garrison." % scenario_id)

	var node_result := _resource_node_result(session, "%s_warrant" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact garrison-warrant atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var hero_probe := _clone_session(session)
	_set_hero_stacks(hero_probe, hero_id, requirement_stacks)
	var hero_carried_control := not ScenarioRulesScript.is_objective_met(hero_probe, objective_id, "victory")
	_expect(hero_carried_control, "%s accepted warranted companies carried by the hero instead of stationed in town." % scenario_id)

	var wrong_probe := _clone_session(session)
	var wrong_town := _town(wrong_probe, home_id).duplicate(true)
	wrong_town["placement_id"] = "%s_wrong_home" % prefix
	wrong_town["garrison"] = requirement_stacks.duplicate(true)
	var towns: Array = wrong_probe.overworld.get("towns", [])
	towns.append(wrong_town)
	wrong_probe.overworld["towns"] = towns
	var wrong_town_control := not ScenarioRulesScript.is_objective_met(wrong_probe, objective_id, "victory")
	_expect(wrong_town_control, "%s accepted a completed garrison at the wrong town." % scenario_id)

	var enemy_probe := _clone_session(session)
	_set_town_state(enemy_probe, home_id, "enemy", requirement_stacks)
	var enemy_owned_town_control := not ScenarioRulesScript.is_objective_met(enemy_probe, objective_id, "victory")
	_expect(enemy_owned_town_control, "%s accepted a complete enemy-owned garrison." % scenario_id)

	var partial_probe := _clone_session(session)
	var partial_stacks := requirement_stacks.duplicate(true)
	partial_stacks[-1]["count"] = int(partial_stacks[-1].get("count", 0)) - 1
	_set_town_state(partial_probe, home_id, "player", partial_stacks)
	var partial_garrison_control := not ScenarioRulesScript.is_objective_met(partial_probe, objective_id, "victory")
	_expect(partial_garrison_control, "%s accepted a below-threshold garrison company." % scenario_id)

	var production_battle_count := 0
	for suffix in ["warrant_guard", "north_road_guard", "south_road_guard"]:
		if _resolve_guard(session, "%s_%s" % [prefix, suffix]):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s did not clear all three fronts through production battle authority." % scenario_id)
	ScenarioScriptRulesScript.process_hooks(session)

	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_warrant" % prefix), true)
	var claim_authority := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_warrant" % prefix), true)
	var production_claim := bool(claim.get("ok", false)) and not bool(repeat.get("ok", true)) and session.to_dict() == claim_authority and unit_ids.all(func(unit_id): return _active_unit_count(session, String(unit_id)) > 0)
	_expect(production_claim, "%s did not grant all three exact one-time warrant companies." % scenario_id)
	_expect(not ScenarioRulesScript.is_objective_met(session, objective_id, "victory"), "%s completed while the warranted companies were still carried by the hero." % scenario_id)
	var unrelated_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"town_army_changed","town_placement_ids":["unrelated_town"],"unit_ids":["unit_unrelated"]})
	var unrelated_profile: Dictionary = unrelated_result.get("profile", {})
	var unrelated_event_skip := String(unrelated_profile.get("dependency_mode", "")) == "event_gated_skip" and int(unrelated_profile.get("objectives_checked", -1)) == 0
	_expect(unrelated_event_skip, "%s reevaluated its garrison objective for unrelated town/unit changes." % scenario_id)

	var home := _town(session, home_id)
	_move_active_hero_to_town(session, home)
	var production_transfer_count := 0
	for unit_id in unit_ids:
		var transfer := HeroCommandRulesScript.transfer_town_stack(session, home, hero_id, "garrison", String(unit_id), "all")
		if bool(transfer.get("ok", false)):
			production_transfer_count += 1
	_expect(production_transfer_count == 3, "%s did not transfer all three warranted companies through town-stack authority." % scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"town_army_changed","town_placement_ids":[home_id],"unit_ids":unit_ids})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped town-and-unit garrison dependencies." % scenario_id)

	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and session.day < 18
	_expect(scenario_victory, "%s did not win after three battles, warrant claim, and exact garrison transfer: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve its completed garrison through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"wrong_town_control":wrong_town_control,"enemy_owned_town_control":enemy_owned_town_control,"hero_carried_control":hero_carried_control,"partial_garrison_control":partial_garrison_control,"production_battle_count":production_battle_count,"production_claim":production_claim,"production_transfer_count":production_transfer_count,"scoped_dependency":scoped_dependency,"unrelated_event_skip":unrelated_event_skip,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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


func _requirement_stacks(requirements: Array) -> Array:
	var stacks := []
	for index in range(requirements.size()):
		var requirement: Dictionary = requirements[index]
		stacks.append({"unit_id":String(requirement.get("unit_id", "")),"count":int(requirement.get("minimum_count", 0)),"slot_index":index})
	return stacks


func _set_hero_stacks(session, hero_id: String, stacks: Array) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			var army: Dictionary = hero.get("army", {}).duplicate(true)
			army["stacks"] = stacks.duplicate(true)
			hero["army"] = army
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRulesScript.hero_by_id(session, hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
	HeroCommandRulesScript.normalize_session(session)


func _set_town_state(session, placement_id: String, owner: String, garrison: Array) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index].duplicate(true)
			town["owner"] = owner
			town["garrison"] = garrison.duplicate(true)
			towns[index] = town
			break
	session.overworld["towns"] = towns


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var position := {"x":int(town.get("x", 0)),"y":int(town.get("y", 0))}
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRulesScript.hero_by_id(session, hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["hero_position"] = position.duplicate(true)
	HeroCommandRulesScript.normalize_session(session)


func _active_unit_count(session, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total


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


func _town(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("GARRISON_WARRANT_MUSTERS_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")
