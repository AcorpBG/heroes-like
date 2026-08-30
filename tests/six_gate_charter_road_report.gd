extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")

const REPORT_ID := "SIX_GATE_CHARTER_ROAD_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_gate_charter_road_report"
const SCENARIO_ID := "six-gate-charter-road"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/route_control_opened_atlas.png"
const GATE_CASES := [
	{"site_id":"site_charter_bar_gate","placement_id":"six_gate_charter_bar","ready":"mapobj_charter_bar_gate","active":"resource_site_route_control_charter_bar_gate_opened","cost":{"gold":180},"flag":"charter_bar_gate_opened","objective":"open_charter_bar_gate","region":Rect2(0,0,48,48)},
	{"site_id":"site_thorn_seal_gate","placement_id":"six_gate_thorn_seal","ready":"mapobj_thorn_seal_gate","active":"resource_site_route_control_thorn_seal_gate_opened","cost":{"gold":90,"wood":3},"flag":"thorn_seal_gate_opened","objective":"open_thorn_seal_gate","region":Rect2(48,0,48,48)},
	{"site_id":"site_brass_toll_arch","placement_id":"six_gate_brass_toll","ready":"mapobj_brass_toll_arch","active":"resource_site_route_control_brass_toll_arch_opened","cost":{"gold":260},"flag":"brass_toll_arch_opened","objective":"open_brass_toll_arch","region":Rect2(96,0,48,48)},
	{"site_id":"site_reef_chain_boom","placement_id":"six_gate_reef_chain","ready":"mapobj_reef_chain_boom","active":"resource_site_route_control_reef_chain_boom_opened","cost":{"gold":120,"wood":2},"flag":"reef_chain_boom_opened","objective":"open_reef_chain_boom","region":Rect2(144,0,48,48)},
	{"site_id":"site_frost_toll_bar","placement_id":"six_gate_frost_bar","ready":"mapobj_frost_toll_bar","active":"resource_site_route_control_frost_toll_bar_opened","cost":{"gold":150,"ore":2},"flag":"frost_toll_bar_opened","objective":"open_frost_toll_bar","region":Rect2(192,0,48,48)},
	{"site_id":"site_ash_sluice_lock","placement_id":"six_gate_ash_sluice","ready":"mapobj_ash_sluice_lock","active":"resource_site_route_control_ash_sluice_lock_opened","cost":{"gold":130,"ore":3},"flag":"ash_sluice_lock_opened","objective":"open_ash_sluice_lock","region":Rect2(240,0,48,48)},
]
const WAYPOINT_CASES := [
	{"site_id":"site_mileward_route_post","placement_id":"six_gate_mileward_post","ready":"mapobj_mileward_route_post","hint":"charter_gate_sequence"},
	{"site_id":"site_road_oath_stone","placement_id":"six_gate_road_oath","ready":"mapobj_road_oath_stone","hint":"winter_reef_return"},
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
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect(not scenario.is_empty(), "Six-Gate Charter Road is not shipped.")
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width",0)) == 20 and int(map_size.get("height",0)) == 12, "Scenario size changed.")
	_expect(scenario.get("resource_nodes", []).size() == 14 and scenario.get("towns", []).size() == 2 and scenario.get("encounters", []).size() == 4, "Scenario breadth changed.")
	_expect(scenario.get("objectives", {}).get("victory", []).size() == 8, "Scenario route objective count changed.")
	_validate_resource_runway(scenario)
	for case_value in WAYPOINT_CASES:
		_validate_waypoint(view, case_value)
	for case_value in GATE_CASES:
		_validate_gate(view, case_value)
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(288,48), "Could not load the six-gate opened-state atlas.")
	if not atlas.is_empty():
		atlas.save_png("%s/route_control_opened_strip.png" % OUTPUT_DIR)
	var report := {
		"ok":_errors.is_empty(),"scenario_id":SCENARIO_ID,"case_count":8,
		"gate_count":GATE_CASES.size(),"waypoint_count":WAYPOINT_CASES.size(),
		"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors,
		"single_visual_capture":"%s/route_control_opened_strip.png" % OUTPUT_DIR,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":8,"gates":6,"waypoints":2,"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_resource_runway(scenario: Dictionary) -> void:
	var total := {"gold":0,"wood":0,"ore":0}
	for case_value in GATE_CASES:
		for key in case_value.get("cost", {}).keys():
			total[key] = int(total.get(key,0)) + int(case_value.get("cost",{}).get(key,0))
	var starting: Dictionary = scenario.get("starting_resources", {})
	for key in total.keys():
		_expect(int(starting.get(key,0)) >= int(total.get(key,0)), "Starting %s cannot fund all six authored gates." % key)

func _validate_waypoint(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var node: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "sign_waypoint_live", "%s is not a live waypoint." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost its waypoint art." % site_id)
	var authority_before: Dictionary = session.to_dict()
	var first := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(bool(first.get("ok", false)), "%s first read failed." % site_id)
	_expect(session.to_dict() == authority_before, "%s first read mutated session authority." % site_id)
	var payload: Dictionary = first.get("sign_waypoint", {})
	_expect(String(payload.get("route_hint_category", "")) == String(case.get("hint", "")), "%s hint category changed." % site_id)
	_expect(String(payload.get("text", "")) == String(site.get("sign_text", "")) and String(payload.get("text", "")).length() >= 100, "%s did not return its authored guidance." % site_id)
	var second := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(bool(second.get("ok", false)) and session.to_dict() == authority_before, "%s repeat read was not freely non-mutating." % site_id)
	_rows.append({"site_id":site_id,"interaction":"read_waypoint","non_mutating_reads":2,"ready_asset_id":String(case.get("ready", ""))})

func _validate_gate(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	var body_tiles := OverworldRules._map_object_world_body_tiles(map_object, node)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "route_lock_live", "%s is not a live route lock." % site_id)
	_expect(not body_tiles.is_empty() and _all_body_tiles_blocked(body_tiles, OverworldRules._build_blocked_tile_index(session)), "%s did not begin fully blocking." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost its closed-state art." % site_id)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)) and bool(first.get("route_opened", false)), "%s did not open: %s" % [site_id,JSON.stringify(first)])
	for key in ["gold","wood","ore"]:
		var expected_delta := int(case.get("cost",{}).get(key,0))
		_expect(int(resources_before.get(key,0))-int(session.overworld.get("resources",{}).get(key,0)) == expected_delta, "%s %s charge changed." % [site_id,key])
	_expect(bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not set its route flag." % site_id)
	_expect(ScenarioRulesScript.is_objective_met(session, String(case.get("objective", "")), "victory"), "%s did not satisfy its route objective." % site_id)
	var opened: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(opened.get("collected", false)) and not bool(opened.get("blocking_body", true)) and opened.get("package_block_tiles", []).is_empty() and String(opened.get("route_state_id", "")) == "opened", "%s did not persist its open body state." % site_id)
	_expect(_no_body_tiles_blocked(body_tiles, OverworldRules._build_blocked_tile_index(session)), "%s body remained blocked after opening." % site_id)
	var active_id := String(view.call("_resource_asset_id", opened))
	var texture = view.call("_object_texture_for_asset", active_id)
	_expect(active_id == String(case.get("active", "")), "%s did not switch to opened art." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s opened atlas region changed." % site_id)
	var authority_after: Dictionary = session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat opening mutated authority." % site_id)
	var restored = _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s save round-trip changed opened authority." % site_id)
	_rows.append({"site_id":site_id,"interaction":"open_route","cost":case.get("cost",{}),"body_tile_count":body_tiles.size(),"repeat_blocked":true,"save_round_trip_exact":true,"active_asset_id":active_id})

func _new_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _all_body_tiles_blocked(body_tiles: Array, blocked: Dictionary) -> bool:
	for tile_value in body_tiles:
		if not blocked.has(OverworldRules._tile_key(tile_value)):
			return false
	return true

func _no_body_tiles_blocked(body_tiles: Array, blocked: Dictionary) -> bool:
	for tile_value in body_tiles:
		if blocked.has(OverworldRules._tile_key(tile_value)):
			return false
	return true

func _clone_session(source):
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

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
