extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FIELD_MASTERY_CONVOCATIONS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/field_mastery_convocations_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/field_mastery_convocations_atlas.png"
const CASES := [
	{"scenario_id":"beaconscribe-first-light-convocation","prefix":"jorunmastery","site_id":"site_beaconscribe_first_light_lectern","asset_id":"resource_site_field_mastery_beaconscribe_lectern","region":Rect2(0,0,48,48),"command_key":"knowledge"},
	{"scenario_id":"rotlamp-shedskin-convocation","prefix":"eddamastery","site_id":"site_rotlamp_shedskin_censer","asset_id":"resource_site_field_mastery_rotlamp_censer","region":Rect2(48,0,48,48),"command_key":"defense"},
	{"scenario_id":"daynote-true-angle-convocation","prefix":"essamastery","site_id":"site_daynote_true_angle_dais","asset_id":"resource_site_field_mastery_daynote_dais","region":Rect2(96,0,48,48),"command_key":"power"},
	{"scenario_id":"loamchant-deep-root-convocation","prefix":"elianmastery","site_id":"site_loamchant_deep_root_seat","asset_id":"resource_site_field_mastery_loamchant_seat","region":Rect2(144,0,48,48),"command_key":"defense"},
	{"scenario_id":"gaugesavant-fifth-measure-convocation","prefix":"linamastery","site_id":"site_gaugesavant_fifth_measure_rig","asset_id":"resource_site_field_mastery_gaugesavant_rig","region":Rect2(192,0,48,48),"command_key":"attack"},
	{"scenario_id":"wakeoracle-last-echo-convocation","prefix":"morwenmastery","site_id":"site_wakeoracle_last_echo_choir","asset_id":"resource_site_field_mastery_wakeoracle_choir","region":Rect2(240,0,48,48),"command_key":"knowledge"},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Field Mastery atlas must remain exactly 288x48.")
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
		"level_three_control_count": _count_rows("level_three_control"),
		"pending_choice_control_count": _count_rows("pending_choice_control"),
		"production_claim_count": _count_rows("production_claim"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"specialty_choice_count": _rows.reduce(func(total, row): return total + int(row.get("specialty_choice_count", 0)), 0),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"specialty_choice_count":18,"scenario_victory_count":6,"single_consolidated_smoke":true})])
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
	var victory: Array = scenario.get("objectives", {}).get("victory", [])
	var objective: Dictionary = victory[0]
	var objective_id := String(objective.get("id", ""))
	var hero_id := String(objective.get("hero_id", ""))
	var hero: Dictionary = session.overworld.get("hero", {})
	_expect(int(hero.get("level", 0)) == 1 and hero.get("specialties", []).size() == 1 and hero.get("pending_specialty_choices", []).is_empty(), "%s must begin at level one with exactly one authored identity specialty and no pending choice." % scenario_id)

	var node_result := _resource_node_result(session, "%s_convocation" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact convocation atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var wrong_probe := _clone_session(session)
	_set_progression(wrong_probe, "wrong_field_commander", 4, ["armsmaster", "wayfinder", "spellwright", "drillmaster"], [])
	var wrong_hero_control: bool = not ScenarioRulesScript.is_objective_met(wrong_probe, objective_id, "victory")
	_expect(wrong_hero_control, "%s accepted mastery on the wrong commander." % scenario_id)

	var level_probe := _clone_session(session)
	_set_progression(level_probe, hero_id, 3, ["armsmaster", "wayfinder", "spellwright"], [])
	var level_three_control: bool = not ScenarioRulesScript.is_objective_met(level_probe, objective_id, "victory")
	_expect(level_three_control, "%s accepted a level-three commander." % scenario_id)

	var pending_probe := _clone_session(session)
	_set_progression(pending_probe, hero_id, 4, ["armsmaster", "wayfinder", "spellwright", "drillmaster"], [{"level":5,"options":["quartermaster"]}])
	var pending_choice_control: bool = not ScenarioRulesScript.is_objective_met(pending_probe, objective_id, "victory")
	_expect(pending_choice_control, "%s accepted an unresolved specialty choice." % scenario_id)

	var production_battle_count := 0
	for suffix in ["convocation_guard", "north_examination", "south_examination"]:
		if _resolve_guard(session, "%s_%s" % [prefix, suffix]):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s did not clear all three fronts through production battle authority." % scenario_id)

	var command_key := String(case.get("command_key", ""))
	var command_before := int(session.overworld.get("hero", {}).get("command", {}).get(command_key, 0))
	var experience_before_claim := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_convocation" % prefix), true)
	var claim_authority := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_convocation" % prefix), true)
	var command_after := int(session.overworld.get("hero", {}).get("command", {}).get(command_key, 0))
	var exact_command_lesson: bool = claim.get("shrine_effects", {}).get("hero_command_bonus", {}) == {command_key:1}
	var production_claim: bool = bool(claim.get("ok", false)) and bool(session.flags.get(String(ContentService.get_resource_site(String(case.get("site_id", ""))).get("claim_flags", {}).keys()[0]), false)) and int(session.overworld.get("hero", {}).get("experience", 0)) == experience_before_claim + 250 and exact_command_lesson and command_after >= command_before + 1 and not bool(repeat.get("ok", true)) and session.to_dict() == claim_authority
	_expect(production_claim, "%s did not grant its exact one-time +250 XP, flag, and command lesson." % scenario_id)
	var leveled_hero: Dictionary = session.overworld.get("hero", {})
	_expect(int(leveled_hero.get("level", 0)) >= 4 and leveled_hero.get("pending_specialty_choices", []).size() == 3, "%s did not earn level four and three queued choices from authored rewards." % scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"hero_progression_changed","hero_ids":[hero_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency: bool = String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose its exact hero progression dependency." % scenario_id)

	var specialty_choice_count := 0
	while not session.overworld.get("hero", {}).get("pending_specialty_choices", []).is_empty() and specialty_choice_count < 3:
		var actions: Array = OverworldRules.get_specialty_actions(session)
		if actions.is_empty():
			break
		var specialty_id := String(actions[0].get("id", "")).trim_prefix("choose_specialty:")
		var choice: Dictionary = OverworldRules.choose_specialty(session, specialty_id)
		if bool(choice.get("ok", false)):
			specialty_choice_count += 1
	_expect(specialty_choice_count == 3, "%s did not resolve three specialty decisions through production authority." % scenario_id)

	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and session.day < 16
	_expect(scenario_victory, "%s did not win after earning and resolving three field lessons: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve field mastery through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"wrong_hero_control":wrong_hero_control,"level_three_control":level_three_control,"pending_choice_control":pending_choice_control,"production_claim":production_claim,"production_battle_count":production_battle_count,"specialty_choice_count":specialty_choice_count,"scoped_dependency":scoped_dependency,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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


func _set_progression(session, hero_id: String, level: int, specialties: Array, pending: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = hero_id
	hero["level"] = level
	hero["specialties"] = specialties.duplicate(true)
	hero["pending_specialty_choices"] = pending.duplicate(true)
	session.overworld["active_hero_id"] = hero_id
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	if heroes.is_empty():
		heroes.append(hero.duplicate(true))
	else:
		heroes[0] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes


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
	var directory := OS.get_environment("FIELD_MASTERY_CONVOCATIONS_CAPTURE_DIR")
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
