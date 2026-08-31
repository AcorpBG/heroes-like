extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BORDER_OATH_STANDARD_SEIZURES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/border_oath_standard_seizures_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const STANDARD_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/border_oath_standards_atlas.png"
const CORDON_ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/border_oath_cordons/border_oath_cordons_atlas.png"
const CASES := [
	{"scenario_id":"tollbrand-cinderlock-border-oath-seizure","prefix":"threewrit","standard_asset":"resource_site_border_oath_embercourt_three_writ","standard_region":Rect2(0,0,48,48),"cordon_asset":"encounter_border_oath_mireclaw_moonhook","cordon_region":Rect2(0,0,48,48)},
	{"scenario_id":"rotlamp-nightglass-border-oath-seizure","prefix":"fenhook","standard_asset":"resource_site_border_oath_mireclaw_fenhook","standard_region":Rect2(48,0,48,48),"cordon_asset":"encounter_border_oath_sunvault_prismwrit","cordon_region":Rect2(48,0,48,48)},
	{"scenario_id":"lenscaptain-dawnmirror-border-oath-seizure","prefix":"trifold","standard_asset":"resource_site_border_oath_sunvault_trifold","standard_region":Rect2(96,0,48,48),"cordon_asset":"encounter_border_oath_thornwake_rootglass","cordon_region":Rect2(96,0,48,48)},
	{"scenario_id":"boltroot-briarwheel-border-oath-seizure","prefix":"threeseed","standard_asset":"resource_site_border_oath_thornwake_three_seed","standard_region":Rect2(144,0,48,48),"cordon_asset":"encounter_border_oath_brasshollow_blackbell","cordon_region":Rect2(144,0,48,48)},
	{"scenario_id":"pitmarshal-cindercoil-border-oath-seizure","prefix":"tripgauge","standard_asset":"resource_site_border_oath_brasshollow_tripgauge","standard_region":Rect2(192,0,48,48),"cordon_asset":"encounter_border_oath_veilmourn_wakechain","cordon_region":Rect2(192,0,48,48)},
	{"scenario_id":"oriflag-gloamwake-border-oath-seizure","prefix":"threewake","standard_asset":"resource_site_border_oath_veilmourn_three_wake","standard_region":Rect2(240,0,48,48),"cordon_asset":"encounter_border_oath_embercourt_rainbrand","cordon_region":Rect2(240,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var standard_atlas := load(STANDARD_ATLAS_PATH) as Texture2D
	var cordon_atlas := load(CORDON_ATLAS_PATH) as Texture2D
	_expect(standard_atlas != null and standard_atlas.get_size() == Vector2(288, 48), "Border Oath standard atlas must remain 288x48.")
	_expect(cordon_atlas != null and cordon_atlas.get_size() == Vector2(288, 48), "Border Oath cordon atlas must remain 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(),
		"exact_standard_art_count":_count_rows("exact_standard_art"), "exact_cordon_art_count":_count_rows("exact_cordon_art"),
		"initially_pending_count":_count_rows("initially_pending"), "wrong_site_control_count":_count_rows("wrong_site_control"),
		"two_of_three_pending_count":_count_rows("two_of_three_pending"), "enemy_recapture_pending_count":_count_rows("enemy_recapture_pending"),
		"scoped_dependency_count":_count_rows("scoped_dependency"), "unrelated_resource_skip_count":_count_rows("unrelated_resource_skip"),
		"production_battle_count":_rows.reduce(func(total,row): return total + int(row.get("production_battle_count",0)),0),
		"production_claim_count":_rows.reduce(func(total,row): return total + int(row.get("production_claim_count",0)),0),
		"control_objective_count":_count_rows("control_objective"), "scenario_victory_count":_count_rows("scenario_victory"),
		"save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_claim_count":18,"control_objective_count":6,"scenario_victory_count":6,"single_consolidated_smoke":true})])
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
	var objective: Dictionary = ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", [])[0]
	var objective_id := String(objective.get("id", ""))
	var initially_pending := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(initially_pending, "%s began with a completed three-standard objective." % scenario_id)

	var west_result := _resource_node_result(session, "%s_standard_west" % prefix)
	var west_node: Dictionary = west_result.get("node", {})
	var standard_asset := String(view.call("_resource_asset_id", west_node))
	var standard_texture = view.call("_object_texture_for_asset", standard_asset)
	var exact_standard_art: bool = standard_asset == String(case.get("standard_asset", "")) and standard_texture is AtlasTexture and standard_texture.atlas.resource_path == STANDARD_ATLAS_PATH and standard_texture.region == case.get("standard_region")
	_expect(exact_standard_art, "%s did not resolve its exact standard atlas region." % scenario_id)
	var west_encounter := _encounter(session, "%s_west_cordon" % prefix)
	var cordon_asset := String(view.call("_encounter_identity_asset_id", west_encounter))
	var cordon_texture = view.call("_object_texture_for_asset", cordon_asset)
	var exact_cordon_art: bool = cordon_asset == String(case.get("cordon_asset", "")) and cordon_texture is AtlasTexture and cordon_texture.atlas.resource_path == CORDON_ATLAS_PATH and cordon_texture.region == case.get("cordon_region")
	_expect(exact_cordon_art, "%s did not resolve its exact cordon atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(west_node.get("x",0)),int(west_node.get("y",0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var wrong_probe := _clone_session(session)
	var wrong_claim := OverworldRules._collect_resource_node_result(wrong_probe, _resource_node_result(wrong_probe, "%s_waystone" % prefix), true)
	var wrong_site_control := bool(wrong_claim.get("ok",false)) and not ScenarioRulesScript.is_objective_met(wrong_probe, objective_id, "victory")
	_expect(wrong_site_control, "%s accepted an unrelated claimed waystone." % scenario_id)
	var scoped := ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"resource_site_control_changed","resource_site_placement_ids":["%s_standard_west" % prefix]})
	var scoped_profile: Dictionary = scoped.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode","")) == "scoped" and int(scoped_profile.get("objectives_checked",0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped standard dependencies." % scenario_id)
	var unrelated := ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"resource_site_control_changed","resource_site_placement_ids":["%s_waystone" % prefix]})
	var unrelated_profile: Dictionary = unrelated.get("profile", {})
	var unrelated_resource_skip := String(unrelated_profile.get("dependency_mode","")) == "event_gated_skip" or int(unrelated_profile.get("objectives_checked",-1)) == 0
	_expect(unrelated_resource_skip, "%s re-evaluated the oath for an unrelated waystone." % scenario_id)

	var production_battle_count := 0
	var production_claim_count := 0
	for suffix in ["west", "south"]:
		if _resolve_cordon(session, "%s_%s_cordon" % [prefix,suffix]): production_battle_count += 1
		var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_standard_%s" % [prefix,suffix]), true)
		if bool(claim.get("ok",false)): production_claim_count += 1
	var two_of_three_pending := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(two_of_three_pending, "%s accepted only two of its three standards." % scenario_id)
	var recapture_probe := _clone_session(session)
	_set_site_owner(recapture_probe, "%s_standard_west" % prefix, "enemy")
	var enemy_recapture_pending := not ScenarioRulesScript.is_objective_met(recapture_probe, objective_id, "victory")
	_expect(enemy_recapture_pending, "%s ignored enemy recapture of a required standard." % scenario_id)
	if _resolve_cordon(session, "%s_east_cordon" % prefix): production_battle_count += 1
	var east_claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_standard_east" % prefix), true)
	if bool(east_claim.get("ok",false)): production_claim_count += 1
	_expect(production_battle_count == 3 and production_claim_count == 3, "%s did not clear and claim all three fronts." % scenario_id)
	var control_objective := ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(control_objective, "%s did not complete exact simultaneous standard control." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(victory_result.get("status","")) == "victory"
	_expect(scenario_victory, "%s did not win after all three cordons and standards: %s" % [scenario_id,JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve exact three-standard control through save version %d." % [scenario_id,SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_standard_art":exact_standard_art,"exact_cordon_art":exact_cordon_art,"initially_pending":initially_pending,"wrong_site_control":wrong_site_control,"two_of_three_pending":two_of_three_pending,"enemy_recapture_pending":enemy_recapture_pending,"scoped_dependency":scoped_dependency,"unrelated_resource_skip":unrelated_resource_skip,"production_battle_count":production_battle_count,"production_claim_count":production_claim_count,"control_objective":control_objective,"scenario_victory":scenario_victory,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_cordon(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty(): return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty(): return false
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks",[]).size()):
		var stack = session.battle.get("stacks",[])[index]
		if stack is Dictionary and String(stack.get("side","")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state","")) == "victory" and placement_id in session.overworld.get("resolved_encounters",[])


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id","")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _set_site_owner(session, placement_id: String, owner: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes",[])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id","")) == placement_id:
			nodes[index]["collected_by_faction_id"] = owner
			session.overworld["resource_nodes"] = nodes
			return


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters",[]):
		if value is Dictionary and String(value.get("placement_id","")) == placement_id: return value
	return {}


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("BORDER_OATH_CAPTURE_DIR")
	if directory == "": return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key,false))).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID,message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(payload,"  "))
