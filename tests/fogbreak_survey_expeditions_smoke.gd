extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FOGBREAK_SURVEY_EXPEDITIONS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/fogbreak_survey_expeditions_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/fogbreak_survey_instruments_atlas.png"
const CASES := [
	{"scenario_id":"cinderquill-ashline-fogbreak-survey","prefix":"ashline","asset_id":"resource_site_fogbreak_embercourt_compass","region":Rect2(0,0,48,48)},
	{"scenario_id":"votivejaw-bogglass-fogbreak-survey","prefix":"bogglass","asset_id":"resource_site_fogbreak_mireclaw_mast","region":Rect2(48,0,48,48)},
	{"scenario_id":"sunvein-meridian-fogbreak-survey","prefix":"meridian","asset_id":"resource_site_fogbreak_sunvault_heliograph","region":Rect2(96,0,48,48)},
	{"scenario_id":"seedseer-rootstar-fogbreak-survey","prefix":"rootstar","asset_id":"resource_site_fogbreak_thornwake_orrery","region":Rect2(144,0,48,48)},
	{"scenario_id":"heatpriest-redgauge-fogbreak-survey","prefix":"redgauge","asset_id":"resource_site_fogbreak_brasshollow_theodolite","region":Rect2(192,0,48,48)},
	{"scenario_id":"vowless-drowned-horizon-fogbreak-survey","prefix":"drownedhorizon","asset_id":"resource_site_fogbreak_veilmourn_sextant","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Fogbreak instrument atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(), "case_count": CASES.size(),
		"exact_art_count": _count_rows("exact_art"),
		"initially_pending_count": _count_rows("initially_pending"),
		"malformed_fog_control_count": _count_rows("malformed_fog_control"),
		"partial_two_instrument_control_count": _count_rows("partial_two_instrument_control"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"production_claim_count": _rows.reduce(func(total, row): return total + int(row.get("production_claim_count", 0)), 0),
		"exploration_threshold_count": _count_rows("exploration_threshold"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true, "rows": _rows, "errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_claim_count":18,"scenario_victory_count":6,"single_consolidated_smoke":true})])
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
	_expect(initially_pending, "%s began with a completed exploration objective." % scenario_id)

	var malformed_probe := _clone_session(session)
	var malformed_fog: Dictionary = malformed_probe.overworld.get("fog", {}).duplicate(true)
	malformed_fog["total_tiles"] = 1
	malformed_fog["explored_count"] = 1
	malformed_probe.overworld["fog"] = malformed_fog
	var malformed_fog_control := not ScenarioRulesScript.is_objective_met(malformed_probe, objective_id, "victory")
	_expect(malformed_fog_control, "%s trusted a stale one-tile fog total." % scenario_id)

	var west_result := _resource_node_result(session, "%s_survey_west" % prefix)
	var west_node: Dictionary = west_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", west_node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact survey-instrument atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(west_node.get("x", 0)), int(west_node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"fog_exploration_changed","fog_exploration_changed":true})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose a scoped fog-exploration dependency." % scenario_id)

	var production_battle_count := 0
	var production_claim_count := 0
	for suffix in ["west", "south"]:
		if _resolve_guard(session, "%s_%s_guard" % [prefix, suffix]):
			production_battle_count += 1
		var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_survey_%s" % [prefix, suffix]), true)
		if bool(claim.get("ok", false)) and int(claim.get("site_reveal_tiles", 0)) > 0:
			production_claim_count += 1
	var explored_after_two := int(session.overworld.get("fog", {}).get("explored_count", 0))
	var partial_two_instrument_control := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(partial_two_instrument_control, "%s completed its chart after only two instruments (%d tiles)." % [scenario_id, explored_after_two])

	if _resolve_guard(session, "%s_east_guard" % prefix):
		production_battle_count += 1
	var east_claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_survey_east" % prefix), true)
	if bool(east_claim.get("ok", false)) and int(east_claim.get("site_reveal_tiles", 0)) > 0:
		production_claim_count += 1
	_expect(production_battle_count == 3 and production_claim_count == 3, "%s did not clear and claim all three production survey fronts." % scenario_id)
	var explored_after_three := int(session.overworld.get("fog", {}).get("explored_count", 0))
	var exploration_threshold := ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and explored_after_three >= 108
	_expect(exploration_threshold, "%s did not reach its exact 80%% chart after three instruments (%d tiles)." % [scenario_id, explored_after_three])
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and session.day < 15
	_expect(scenario_victory, "%s did not win after the complete production survey: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve its chart through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"initially_pending":initially_pending,"malformed_fog_control":malformed_fog_control,"partial_two_instrument_control":partial_two_instrument_control,"scoped_dependency":scoped_dependency,"production_battle_count":production_battle_count,"production_claim_count":production_claim_count,"explored_after_two":explored_after_two,"explored_after_three":explored_after_three,"exploration_threshold":exploration_threshold,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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
	var directory := OS.get_environment("FOGBREAK_SURVEY_CAPTURE_DIR")
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
