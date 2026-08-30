extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")

const REPORT_ID := "ELEVEN_ROADS_OBJECTIVES_REPORT"
const OUTPUT_DIR := "res://.artifacts/eleven_roads_objectives_report"
const SCENARIO_ID := "writbound-crossroads"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/roads_objectives_state_atlas.png"
const SIGN_CASES := [
	{"site_id":"site_mile_writ_sign","placement_id":"writbound_mile_writ","ready":"mapobj_mile_writ_sign","hint":"distance_and_toll_law"},
	{"site_id":"site_reed_knot_waypost","placement_id":"writbound_reed_knot","ready":"mapobj_reed_knot_waypost","hint":"safe_channel_marker"},
	{"site_id":"site_switchback_cairn","placement_id":"writbound_switchback_cairn","ready":"mapobj_switchback_cairn","hint":"ridge_switchback_marker"},
	{"site_id":"site_ash_road_marker","placement_id":"writbound_ash_marker","ready":"mapobj_ash_road_marker","hint":"heat_safe_lane"},
	{"site_id":"site_underway_chalk_index","placement_id":"writbound_chalk_index","ready":"mapobj_underway_chalk_index","hint":"underway_junction_marker"},
]
const ROUTE_CASES := [
	{"site_id":"site_toll_chain_court","placement_id":"writbound_toll_chain","ready":"mapobj_toll_chain_court","active":"resource_site_roads_objectives_toll_chain_opened","cost":{"gold":220},"flag":"toll_chain_court_opened","region":Rect2(0,0,48,48)},
	{"site_id":"site_root_lease_gate","placement_id":"writbound_root_lease","ready":"mapobj_root_lease_gate","active":"resource_site_roads_objectives_root_lease_opened","cost":{"gold":100,"wood":2},"flag":"root_lease_gate_opened","region":Rect2(48,0,48,48)},
	{"site_id":"site_pressure_rail_stop","placement_id":"writbound_pressure_rail","ready":"mapobj_pressure_rail_stop","active":"resource_site_roads_objectives_pressure_rail_opened","cost":{"gold":140,"ore":2},"flag":"pressure_rail_stop_opened","region":Rect2(96,0,48,48)},
]
const OBJECTIVE_CASES := [
	{"site_id":"site_campaign_muster_seal","placement_id":"writbound_campaign_muster","ready":"mapobj_campaign_muster_seal","active":"resource_site_roads_objectives_campaign_muster_activated","flag":"writbound_campaign_muster_raised","objective":"raise_campaign_muster","xp":160,"gold":0,"recruit":"unit_river_guard","recruit_count":4,"spell":"","vision":0,"region":Rect2(144,0,48,48)},
	{"site_id":"site_broken_accord_marker","placement_id":"writbound_broken_accord","ready":"mapobj_broken_accord_marker","active":"resource_site_roads_objectives_broken_accord_activated","flag":"writbound_broken_accord_recorded","objective":"record_broken_accord","xp":180,"gold":300,"recruit":"","recruit_count":0,"spell":"","vision":0,"region":Rect2(192,0,48,48)},
	{"site_id":"site_scenario_witness_stone","placement_id":"writbound_witness_stone","ready":"mapobj_scenario_witness_stone","active":"resource_site_roads_objectives_witness_stone_activated","flag":"writbound_route_witness_sworn","objective":"swear_route_witness","xp":140,"gold":0,"recruit":"","recruit_count":0,"spell":"spell_lens_glass_survey_24","vision":4,"region":Rect2(240,0,48,48)},
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
	_expect(not scenario.is_empty() and scenario.get("resource_nodes", []).size() == 11, "Writbound Crossroads must ship all eleven family placements.")
	for case_value in SIGN_CASES:
		_validate_sign(view, case_value)
	for case_value in ROUTE_CASES:
		_validate_route(view, case_value)
	for case_value in OBJECTIVE_CASES:
		_validate_objective(view, case_value)
	var capture := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not capture.is_empty() and capture.get_size() == Vector2i(288,48), "Could not load the consolidated roads/objectives state atlas.")
	if not capture.is_empty():
		capture.save_png("%s/roads_objectives_state_strip.png" % OUTPUT_DIR)
	var report := {"ok":_errors.is_empty(),"scenario_id":SCENARIO_ID,"case_count":SIGN_CASES.size()+ROUTE_CASES.size()+OBJECTIVE_CASES.size(),"sign_count":SIGN_CASES.size(),"route_lock_count":ROUTE_CASES.size(),"objective_event_count":OBJECTIVE_CASES.size(),"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_visual_capture":"%s/roads_objectives_state_strip.png" % OUTPUT_DIR,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":11,"signs":5,"route_locks":3,"objective_events":3,"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_sign(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "sign_waypoint_live", "%s is not a live sign." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost its stable sign art." % site_id)
	var authority_before: Dictionary = session.to_dict()
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s first read failed: %s" % [site_id, JSON.stringify(first)])
	_expect(session.to_dict() == authority_before, "%s reading mutated session authority." % site_id)
	var sign_payload: Dictionary = first.get("sign_waypoint", {})
	_expect(String(sign_payload.get("route_hint_category", "")) == String(case.get("hint", "")) and String(sign_payload.get("text", "")) == String(site.get("sign_text", "")) and String(sign_payload.get("text", "")).length() >= 64, "%s did not return its authored route guidance." % site_id)
	var second := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(bool(second.get("ok", false)) and session.to_dict() == authority_before, "%s repeat read was not freely non-mutating." % site_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"interaction":"read_sign","non_mutating_reads":2,"ready_asset_id":String(case.get("ready", ""))})

func _validate_route(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "route_lock_live", "%s is not a live route lock." % site_id)
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	var body_tiles := OverworldRules._map_object_world_body_tiles(map_object, node)
	var blocked_before := OverworldRules._build_blocked_tile_index(session)
	_expect(not body_tiles.is_empty() and _all_body_tiles_blocked(body_tiles, blocked_before), "%s did not begin as a blocking route body." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost its closed-state art." % site_id)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)) and bool(first.get("route_opened", false)), "%s did not open: %s" % [site_id, JSON.stringify(first)])
	for key in case.get("cost", {}).keys():
		_expect(int(resources_before.get(key,0))-int(session.overworld.get("resources",{}).get(key,0)) == int(case.get("cost",{}).get(key,0)), "%s %s cost changed." % [site_id,String(key)])
	_expect(bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not set its route flag." % site_id)
	var opened: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(opened.get("collected", false)) and not bool(opened.get("blocking_body", true)) and opened.get("package_block_tiles", []).is_empty() and String(opened.get("route_state_id", "")) == "opened", "%s did not persist an open body state." % site_id)
	_expect(_no_body_tiles_blocked(body_tiles, OverworldRules._build_blocked_tile_index(session)), "%s body remained blocked after opening." % site_id)
	_validate_active_art(view, opened, case, site_id)
	var authority_after: Dictionary = session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat opening mutated authority." % site_id)
	var restored: SessionStateStoreScript.SessionData = _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s save round-trip changed opened route authority." % site_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"interaction":"open_route","route_opened":true,"cost":case.get("cost",{}),"repeat_blocked":true,"save_round_trip_exact":true,"active_asset_id":String(case.get("active", ""))})

func _validate_objective(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "objective_event_live", "%s is not a live objective event." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost its dormant objective art." % site_id)
	var before := _hero_snapshot(session, case)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s activation failed: %s" % [site_id, JSON.stringify(first)])
	var after := _hero_snapshot(session, case)
	_expect(int(after.get("experience",0))-int(before.get("experience",0)) == int(case.get("xp",0)), "%s experience reward changed." % site_id)
	_expect(int(after.get("gold",0))-int(before.get("gold",0)) == int(case.get("gold",0)), "%s gold reward changed." % site_id)
	if String(case.get("recruit", "")) != "":
		_expect(int(after.get("recruits",0))-int(before.get("recruits",0)) == int(case.get("recruit_count",0)), "%s muster recruits changed." % site_id)
	if String(case.get("spell", "")) != "":
		_expect(String(case.get("spell", "")) not in before.get("known_spell_ids",[]) and String(case.get("spell", "")) in after.get("known_spell_ids",[]), "%s witness spell changed." % site_id)
	if int(case.get("vision",0)) > 0:
		_expect(int(first.get("site_vision_radius",0)) == int(case.get("vision",0)), "%s witness survey radius changed." % site_id)
	_expect(bool(session.flags.get(String(case.get("flag", "")), false)), "%s did not set its scenario flag." % site_id)
	_expect(ScenarioRulesScript.is_objective_met(session, String(case.get("objective", "")), "victory"), "%s did not satisfy its linked victory objective." % site_id)
	var activated: Dictionary = _node_result(session, placement_id).get("node", {})
	_validate_active_art(view, activated, case, site_id)
	var authority_after: Dictionary = session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat activation mutated authority." % site_id)
	var restored: SessionStateStoreScript.SessionData = _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s save round-trip changed objective authority." % site_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"interaction":"activate_objective","objective_id":String(case.get("objective", "")),"objective_met":true,"repeat_blocked":true,"save_round_trip_exact":true,"active_asset_id":String(case.get("active", ""))})

func _validate_active_art(view: Control, node: Dictionary, case: Dictionary, site_id: String) -> void:
	var active_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", active_id)
	_expect(active_id == String(case.get("active", "")), "%s did not switch to active-state art." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s active atlas region changed." % site_id)

func _new_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _hero_snapshot(session, case: Dictionary) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {})
	return {"experience":int(hero.get("experience",0)),"gold":int(session.overworld.get("resources",{}).get("gold",0)),"recruits":_unit_count(hero.get("army",{}),String(case.get("recruit",""))),"known_spell_ids":hero.get("spellbook",{}).get("known_spell_ids",[]).duplicate(true)}

func _all_body_tiles_blocked(body_tiles: Array, blocked: Dictionary) -> bool:
	for tile_value in body_tiles:
		var tile: Vector2i = tile_value
		if not blocked.has(OverworldRules._tile_key(tile)):
			return false
	return true

func _no_body_tiles_blocked(body_tiles: Array, blocked: Dictionary) -> bool:
	for tile_value in body_tiles:
		var tile: Vector2i = tile_value
		if blocked.has(OverworldRules._tile_key(tile)):
			return false
	return true

func _unit_count(army: Dictionary, unit_id: String) -> int:
	if unit_id == "":
		return 0
	var total := 0
	for stack in army.get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

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
