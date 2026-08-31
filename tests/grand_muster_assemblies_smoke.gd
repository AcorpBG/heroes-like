extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "GRAND_MUSTER_ASSEMBLIES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/grand_muster_assemblies_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/grand_muster_assemblies_atlas.png"
const CASES := [
	{"scenario_id":"rainwrit-five-writ-grand-muster","prefix":"rainwritmuster","site_id":"site_rainwrit_five_writ_muster_standard","asset_id":"resource_site_grand_muster_rainwrit_standard","region":Rect2(0,0,48,48)},
	{"scenario_id":"hollowreed-moonhide-grand-muster","prefix":"hollowreedmuster","site_id":"site_hollowreed_moonhide_drum_standard","asset_id":"resource_site_grand_muster_hollowreed_standard","region":Rect2(48,0,48,48)},
	{"scenario_id":"meridian-five-facet-grand-muster","prefix":"meridianmuster","site_id":"site_meridian_five_facet_muster_prism","asset_id":"resource_site_grand_muster_meridian_prism","region":Rect2(96,0,48,48)},
	{"scenario_id":"crownroot-five-seed-grand-muster","prefix":"crownrootmuster","site_id":"site_crownroot_five_seed_muster_bough","asset_id":"resource_site_grand_muster_crownroot_bough","region":Rect2(144,0,48,48)},
	{"scenario_id":"blackbell-five-clause-grand-muster","prefix":"blackbellmuster","site_id":"site_blackbell_five_clause_muster_gantry","asset_id":"resource_site_grand_muster_blackbell_gantry","region":Rect2(192,0,48,48)},
	{"scenario_id":"pale-sounding-five-wake-grand-muster","prefix":"palesoundingmuster","site_id":"site_pale_sounding_five_wake_muster_mast","asset_id":"resource_site_grand_muster_pale_sounding_mast","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Grand Muster atlas must remain exactly 288x48.")
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
		"wrong_hero_control_count": _count_rows("wrong_hero_control"),
		"below_threshold_control_count": _count_rows("below_threshold_control"),
		"production_recruit_count": _count_rows("production_recruit"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"rally_claim_count": _count_rows("rally_claim"),
		"split_merge_exact_count": _count_rows("split_merge_exact"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	var objective: Dictionary = scenario.get("objectives", {}).get("victory", [])[0]
	var objective_id := String(objective.get("id", ""))
	var hero_id := String(objective.get("hero_id", ""))
	var requirements: Array = objective.get("requirements", [])
	var unit_ids := requirements.map(func(requirement): return String(requirement.get("unit_id", "")))
	var initial_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	_expect(String(initial_result.get("status", "")) == "in_progress" and not ScenarioRulesScript.is_objective_met(session, objective_id, "victory"), "%s began with a completed muster." % scenario_id)

	var node_result := _resource_node_result(session, "%s_standard" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact muster atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var full_stacks := _requirement_stacks(requirements)
	var wrong_probe := _clone_session(session)
	var wrong_hero := HeroCommandRulesScript.active_hero(wrong_probe).duplicate(true)
	wrong_hero["id"] = "wrong_controlled_commander"
	wrong_hero["army"] = {"id":"wrong_commander_muster","stacks":full_stacks.duplicate(true)}
	wrong_probe.overworld["active_hero_id"] = "wrong_controlled_commander"
	wrong_probe.overworld["player_heroes"] = [wrong_hero]
	wrong_probe.overworld["hero"] = wrong_hero.duplicate(true)
	wrong_probe.overworld["army"] = wrong_hero.get("army", {}).duplicate(true)
	var wrong_hero_control := not ScenarioRulesScript.is_objective_met(wrong_probe, objective_id, "victory")
	_expect(wrong_hero_control, "%s accepted the completed roster on the wrong commander." % scenario_id)

	var below_probe := _clone_session(session)
	var below_stacks := full_stacks.duplicate(true)
	below_stacks[-1]["count"] = int(below_stacks[-1].get("count", 0)) - 1
	_set_hero_stacks(below_probe, hero_id, below_stacks)
	var below_threshold_control := not ScenarioRulesScript.is_objective_met(below_probe, objective_id, "victory")
	_expect(below_threshold_control, "%s accepted a below-threshold fifth company." % scenario_id)

	session.day = 2
	var requisition: Dictionary = ScenarioScriptRulesScript.process_hooks(session)
	var home := _town(session, "%s_home" % prefix)
	_move_active_hero_to_town(session, home)
	var recruit_unit_id := String(requirements[0].get("unit_id", ""))
	var recruit_result: Dictionary = TownRules.recruit_active_town(session, recruit_unit_id, 1)
	var production_recruit: bool = bool(recruit_result.get("ok", false)) and "%s_day_two_requisition" % prefix in requisition.get("fired_ids", [])
	_expect(production_recruit, "%s could not recruit from the Day-2 production requisition: %s" % [scenario_id, JSON.stringify(recruit_result)])
	OverworldRules.clear_active_town_visit(session)
	session.game_state = "overworld"

	var production_battle_count := 0
	for suffix in ["standard_guard", "north_road_guard", "south_road_guard"]:
		if _resolve_guard(session, "%s_%s" % [prefix, suffix]):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s did not clear all three fronts through production battle authority." % scenario_id)
	ScenarioScriptRulesScript.process_hooks(session)

	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_standard" % prefix), true)
	var claim_authority := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_standard" % prefix), true)
	var rally_claim := bool(claim.get("ok", false)) and int(_active_unit_count(session, String(requirements[-1].get("unit_id", "")))) >= 2 and not bool(repeat.get("ok", true)) and session.to_dict() == claim_authority
	_expect(rally_claim, "%s did not grant its exact one-time fifth-company rally claim." % scenario_id)

	_set_hero_stacks(session, hero_id, full_stacks)
	var before_split: Dictionary = ScenarioRulesScript._hero_army_requirement_progress(session, objective)
	var split: Dictionary = HeroCommandRulesScript.manage_army_slots(session, {}, hero_id, 0, hero_id, 5, "half")
	var after_split: Dictionary = ScenarioRulesScript._hero_army_requirement_progress(session, objective)
	var merge: Dictionary = HeroCommandRulesScript.manage_army_slots(session, {}, hero_id, 5, hero_id, 0, "all")
	var after_merge: Dictionary = ScenarioRulesScript._hero_army_requirement_progress(session, objective)
	var split_merge_exact := bool(split.get("ok", false)) and String(split.get("operation", "")) == "split" and bool(merge.get("ok", false)) and String(merge.get("operation", "")) == "merge" and before_split == after_split and before_split == after_merge and bool(after_merge.get("complete", false))
	_expect(split_merge_exact, "%s changed muster authority while splitting or merging a company." % scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"army_changed","hero_ids":[hero_id],"unit_ids":unit_ids})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose exact commander/unit objective dependencies: %s" % [scenario_id, JSON.stringify(scoped_profile)])

	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and session.day < 18
	_expect(scenario_victory, "%s did not win after assembling five companies and clearing three fronts: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve its completed muster through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"wrong_hero_control":wrong_hero_control,"below_threshold_control":below_threshold_control,"production_recruit":production_recruit,"production_battle_count":production_battle_count,"rally_claim":rally_claim,"split_merge_exact":split_merge_exact,"scoped_dependency":scoped_dependency,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			var army: Dictionary = hero.get("army", {}).duplicate(true) if hero.get("army", {}) is Dictionary else {}
			army["stacks"] = stacks.duplicate(true)
			hero["army"] = army
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRulesScript.hero_by_id(session, hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
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


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x":int(town.get("x", 0)),"y":int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
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
	var visit := OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit.get("ok", false)), "Could not establish production Town visit for Grand Muster recruitment.")


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("GRAND_MUSTER_ASSEMBLIES_CAPTURE_DIR")
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
		file.store_string(JSON.stringify(payload, "  "))
