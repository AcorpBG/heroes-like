extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "RELIEF_ROUTE_CONVOY_RUNS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/relief_route_convoy_runs_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/relief_route_convoy_relays_atlas.png"
const CASES := [
	{"scenario_id":"tollbrand-locklantern-relief-run","prefix":"locklantern","site_id":"site_embercourt_locklantern_convoy_relay","asset_id":"resource_site_relief_route_embercourt_relay","region":Rect2(0,0,48,48)},
	{"scenario_id":"mudkeel-antlerraft-relief-run","prefix":"antlerraft","site_id":"site_mireclaw_antlerraft_convoy_relay","asset_id":"resource_site_relief_route_mireclaw_relay","region":Rect2(48,0,48,48)},
	{"scenario_id":"choirward-prismwheel-relief-run","prefix":"prismwheel","site_id":"site_sunvault_prismwheel_convoy_relay","asset_id":"resource_site_relief_route_sunvault_relay","region":Rect2(96,0,48,48)},
	{"scenario_id":"mossvein-seedcart-relief-run","prefix":"seedcart","site_id":"site_thornwake_seedcart_convoy_relay","asset_id":"resource_site_relief_route_thornwake_relay","region":Rect2(144,0,48,48)},
	{"scenario_id":"varn-quenchrail-relief-run","prefix":"quenchrail","site_id":"site_brasshollow_quenchrail_convoy_relay","asset_id":"resource_site_relief_route_brasshollow_relay","region":Rect2(192,0,48,48)},
	{"scenario_id":"keelwarden-wakeglass-relief-run","prefix":"wakeglass","site_id":"site_veilmourn_wakeglass_convoy_relay","asset_id":"resource_site_relief_route_veilmourn_relay","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Relief-route relay atlas must remain exactly 288x48.")
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
		"wrong_site_control_count": _count_rows("wrong_site_control"),
		"wrong_target_control_count": _count_rows("wrong_target_control"),
		"production_claim_count": _count_rows("production_claim"),
		"production_dispatch_count": _count_rows("production_dispatch"),
		"interception_block_count": _count_rows("interception_block"),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"delivery_receipt_count": _count_rows("delivery_receipt"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true, "rows": _rows, "errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"delivery_receipt_count":6,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var relay_id := "%s_relay" % prefix
	var forward_id := "%s_forward" % prefix
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var objective: Dictionary = ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", [])[0]
	var initially_pending := not ScenarioRulesScript.is_objective_met(session, String(objective.get("id", "")), "victory")
	_expect(initially_pending, "%s began with a false delivery receipt." % scenario_id)

	var node_result := _resource_node_result(session, relay_id)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact relay atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var wrong_site_probe := _clone_session(session)
	_set_delivery_receipt(wrong_site_probe, "%s_rare" % prefix, forward_id)
	var wrong_site_control := not ScenarioRulesScript.is_objective_met(wrong_site_probe, String(objective.get("id", "")), "victory")
	_expect(wrong_site_control, "%s accepted a receipt from the wrong site." % scenario_id)
	var wrong_target_probe := _clone_session(session)
	_set_delivery_receipt(wrong_target_probe, relay_id, "%s_enemy" % prefix)
	var wrong_target_control := not ScenarioRulesScript.is_objective_met(wrong_target_probe, String(objective.get("id", "")), "victory")
	_expect(wrong_target_control, "%s accepted a receipt for the wrong destination." % scenario_id)

	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, node_result, true)
	var production_claim := bool(claim.get("ok", false)) and String(_resource_node_result(session, relay_id).get("node", {}).get("collected_by_faction_id", "")) == "player"
	_expect(production_claim, "%s did not claim its relay through production resource authority: %s" % [scenario_id, JSON.stringify(claim)])
	var dispatch: Dictionary = OverworldRules._issue_resource_site_response(session, relay_id, "field")
	var dispatched_node: Dictionary = _resource_node_result(session, relay_id).get("node", {})
	var arrival_day := int(dispatched_node.get("delivery_arrival_day", 0))
	var production_dispatch: bool = bool(dispatch.get("ok", false)) and String(dispatched_node.get("delivery_target_kind", "")) == "town" and String(dispatched_node.get("delivery_target_id", "")) == forward_id and not dispatched_node.get("delivery_manifest", {}).is_empty() and arrival_day > session.day
	_expect(production_dispatch, "%s did not dispatch an exact stocked forward-town convoy: %s" % [scenario_id, JSON.stringify(dispatch)])
	var interception: Dictionary = OverworldRules._resource_site_delivery_interception(session, dispatched_node, ContentService.get_resource_site(String(case.get("site_id", ""))))
	var interception_block := bool(interception.get("blocks_delivery", false)) and String(interception.get("encounter_key", "")) == "%s_interceptor" % prefix
	_expect(interception_block, "%s did not expose its arrived production interceptor." % scenario_id)

	session.day = arrival_day
	var production_battle_count := 0
	if _resolve_guard(session, "%s_interceptor" % prefix):
		production_battle_count += 1
	var completed_node: Dictionary = _resource_node_result(session, relay_id).get("node", {})
	var receipt_key := "town:%s" % forward_id
	var delivery_receipt: bool = int(completed_node.get("delivery_completion_counts", {}).get(receipt_key, 0)) == 1 and String(completed_node.get("last_delivery_target_id", "")) == forward_id and int(completed_node.get("last_delivery_day", 0)) == session.day and not completed_node.get("last_delivery_manifest", {}).is_empty()
	_expect(delivery_receipt, "%s did not retain its exact successful delivery receipt." % scenario_id)
	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"reserve_delivery_completed","resource_site_placement_ids":[relay_id],"town_placement_ids":[forward_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped relay-and-town delivery dependencies." % scenario_id)
	for suffix in ["north_screen", "south_screen"]:
		if _resolve_guard(session, "%s_%s" % [prefix, suffix]):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s did not clear all three fronts through production battle authority." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and session.day < 16
	_expect(scenario_victory, "%s did not win after its exact convoy and three production battles: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, String(objective.get("id", "")), "victory")
	_expect(save_exact, "%s did not preserve its delivery receipt through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"initially_pending":initially_pending,"wrong_site_control":wrong_site_control,"wrong_target_control":wrong_target_control,"production_claim":production_claim,"production_dispatch":production_dispatch,"interception_block":interception_block,"production_battle_count":production_battle_count,"delivery_receipt":delivery_receipt,"scoped_dependency":scoped_dependency,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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


func _set_delivery_receipt(session, placement_id: String, target_id: String) -> void:
	var result := _resource_node_result(session, placement_id)
	if result.is_empty():
		return
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = result.get("node", {}).duplicate(true)
	var completion_counts := {}
	completion_counts["town:%s" % target_id] = 1
	node["delivery_completion_counts"] = completion_counts
	nodes[int(result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes


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
	var directory := OS.get_environment("RELIEF_ROUTE_CONVOY_CAPTURE_DIR")
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
