extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FRONTIER_TREASURY_COMMISSIONS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/frontier_treasury_commissions_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/frontier_treasury_offices_atlas.png"
const CASES := [
	{"scenario_id":"powderwrit-rainwrit-treasury-commission","prefix":"rainledger","rare":"embergrain","wrong_rare":"peatwax","asset_id":"resource_site_frontier_treasury_embercourt_brazier","region":Rect2(0,0,48,48)},
	{"scenario_id":"orrik-reedbarrow-treasury-commission","prefix":"reedtally","rare":"peatwax","wrong_rare":"aetherglass","asset_id":"resource_site_frontier_treasury_mireclaw_drum","region":Rect2(48,0,48,48)},
	{"scenario_id":"neral-meridian-treasury-commission","prefix":"prismledger","rare":"aetherglass","wrong_rare":"verdant_grafts","asset_id":"resource_site_frontier_treasury_sunvault_prism","region":Rect2(96,0,48,48)},
	{"scenario_id":"bramblehound-crownroot-treasury-commission","prefix":"seedtithe","rare":"verdant_grafts","wrong_rare":"brass_scrip","asset_id":"resource_site_frontier_treasury_thornwake_arbor","region":Rect2(144,0,48,48)},
	{"scenario_id":"ashmeter-blackbell-treasury-commission","prefix":"counterwheel","rare":"brass_scrip","wrong_rare":"memory_salt","asset_id":"resource_site_frontier_treasury_brasshollow_wheel","region":Rect2(192,0,48,48)},
	{"scenario_id":"mistcorsair-pale-sounding-treasury-commission","prefix":"wakeledger","rare":"memory_salt","wrong_rare":"embergrain","asset_id":"resource_site_frontier_treasury_veilmourn_ledger","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Frontier treasury atlas must remain exactly 288x48.")
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
		"gold_only_control_count": _count_rows("gold_only_control"),
		"rare_only_control_count": _count_rows("rare_only_control"),
		"wrong_rare_control_count": _count_rows("wrong_rare_control"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"unrelated_resource_skip_count": _count_rows("unrelated_resource_skip"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"production_claim_count": _rows.reduce(func(total, row): return total + int(row.get("production_claim_count", 0)), 0),
		"after_claim_pending_count": _count_rows("after_claim_pending"),
		"controlled_income_crossing_count": _count_rows("controlled_income_crossing"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true, "rows": _rows, "errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_claim_count":18,"controlled_income_crossing_count":6,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var rare_id := String(case.get("rare", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var objective: Dictionary = ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", [])[0]
	var objective_id := String(objective.get("id", ""))
	var initially_pending := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(initially_pending, "%s began with a completed stockpile objective." % scenario_id)

	var gold_probe := _clone_session(session)
	gold_probe.overworld["resources"]["gold"] = 10000
	gold_probe.overworld["resources"][rare_id] = 11
	var gold_only_control := not ScenarioRulesScript.is_objective_met(gold_probe, objective_id, "victory")
	_expect(gold_only_control, "%s accepted gold without its exact rare stockpile." % scenario_id)
	var rare_probe := _clone_session(session)
	rare_probe.overworld["resources"]["gold"] = 9999
	rare_probe.overworld["resources"][rare_id] = 12
	var rare_only_control := not ScenarioRulesScript.is_objective_met(rare_probe, objective_id, "victory")
	_expect(rare_only_control, "%s accepted its rare stockpile without enough gold." % scenario_id)
	var wrong_probe := _clone_session(session)
	wrong_probe.overworld["resources"]["gold"] = 10000
	wrong_probe.overworld["resources"][rare_id] = 0
	wrong_probe.overworld["resources"][String(case.get("wrong_rare", ""))] = 99
	var wrong_rare_control := not ScenarioRulesScript.is_objective_met(wrong_probe, objective_id, "victory")
	_expect(wrong_rare_control, "%s accepted a different faction rare resource." % scenario_id)

	var west_result := _resource_node_result(session, "%s_treasury_west" % prefix)
	var west_node: Dictionary = west_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", west_node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact treasury-office atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(west_node.get("x", 0)), int(west_node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"stockpile_changed","resources":[rare_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose a scoped stockpile dependency." % scenario_id)
	var unrelated_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"stockpile_changed","resources":["wood"]})
	var unrelated_profile: Dictionary = unrelated_result.get("profile", {})
	var unrelated_resource_skip := String(unrelated_profile.get("dependency_mode", "")) == "event_gated_skip" or int(unrelated_profile.get("objectives_checked", -1)) == 0
	_expect(unrelated_resource_skip, "%s re-evaluated its stockpile objective for unrelated wood." % scenario_id)

	var production_battle_count := 0
	var production_claim_count := 0
	for suffix in ["west", "south", "east"]:
		if _resolve_guard(session, "%s_%s_guard" % [prefix, suffix]):
			production_battle_count += 1
		var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_treasury_%s" % [prefix, suffix]), true)
		if bool(claim.get("ok", false)):
			production_claim_count += 1
	_expect(production_battle_count == 3 and production_claim_count == 3, "%s did not clear and claim all three production treasury fronts." % scenario_id)
	var after_claim_pending := not ScenarioRulesScript.is_objective_met(session, objective_id, "victory")
	_expect(after_claim_pending, "%s completed its stockpile from one-time claims instead of controlled income." % scenario_id)
	var projected_income: Dictionary = OverworldRules.controlled_resource_site_income(session, "player")
	_expect(int(projected_income.get("gold", 0)) >= 1050 and int(projected_income.get(rare_id, 0)) >= 3, "%s did not expose all three offices through production income authority." % scenario_id)

	var start_gold := int(session.overworld.get("resources", {}).get("gold", 0))
	var start_rare := int(session.overworld.get("resources", {}).get(rare_id, 0))
	var income_turn_count := 0
	while not ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and session.day < 10:
		var turn_result: Dictionary = OverworldRules.end_turn(session)
		income_turn_count += 1
		_expect(String(turn_result.get("resource_income_summary", "")) != "", "%s end turn did not report production income." % scenario_id)
	var final_resources: Dictionary = session.overworld.get("resources", {})
	var controlled_income_crossing := ScenarioRulesScript.is_objective_met(session, objective_id, "victory") and int(final_resources.get("gold", 0)) >= 10000 and int(final_resources.get(rare_id, 0)) >= 12 and int(final_resources.get("gold", 0)) > start_gold and int(final_resources.get(rare_id, 0)) > start_rare and income_turn_count > 0
	_expect(controlled_income_crossing, "%s did not cross both exact stockpile thresholds through end-turn income." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and session.day < 12
	_expect(scenario_victory, "%s did not win after its controlled-income commission: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, objective_id, "victory")
	_expect(save_exact, "%s did not preserve its exact stockpile through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"initially_pending":initially_pending,"gold_only_control":gold_only_control,"rare_only_control":rare_only_control,"wrong_rare_control":wrong_rare_control,"scoped_dependency":scoped_dependency,"unrelated_resource_skip":unrelated_resource_skip,"production_battle_count":production_battle_count,"production_claim_count":production_claim_count,"after_claim_pending":after_claim_pending,"projected_site_income":projected_income,"income_turn_count":income_turn_count,"controlled_income_crossing":controlled_income_crossing,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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
	var directory := OS.get_environment("FRONTIER_TREASURY_CAPTURE_DIR")
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
