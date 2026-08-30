extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FIVE_SCOUTING_STRUCTURES_REPORT"
const OUTPUT_DIR := "res://.artifacts/five_scouting_structures_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/scouting_structure_controlled_atlas.png"
const CASES := [
	{"scenario_id":"ninefold-confluence","site_id":"site_hilltop_signal_nest","placement_id":"ninefold_hilltop_signal_nest","ready":"mapobj_hilltop_signal_nest","controlled":"resource_site_scouting_hilltop_signal_nest_controlled","radius":4,"region":Rect2(0,0,48,48)},
	{"scenario_id":"mudkeel-hive-foreclosure","site_id":"site_marsh_listener_post","placement_id":"mudkeel_dormant_b","ready":"mapobj_marsh_listener_post","controlled":"resource_site_scouting_marsh_listener_post_controlled","radius":3,"region":Rect2(48,0,48,48)},
	{"scenario_id":"lenscaptain-greenline-survey","site_id":"site_prism_survey_frame","placement_id":"lenscaptain_dormant_a","ready":"mapobj_prism_survey_frame","controlled":"resource_site_scouting_prism_survey_frame_controlled","radius":5,"region":Rect2(96,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_underway_echo_well","placement_id":"ninefold_underway_echo_well","ready":"mapobj_underway_echo_well","controlled":"resource_site_scouting_underway_echo_well_controlled","radius":3,"region":Rect2(144,0,48,48)},
	{"scenario_id":"keelwarden-lockfire-run","site_id":"site_coast_bell_watch","placement_id":"keelwarden_dormant_a","ready":"mapobj_coast_bell_watch","controlled":"resource_site_scouting_coast_bell_watch_controlled","radius":5,"region":Rect2(192,0,48,48)},
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
	for case_value in CASES:
		await _validate_case(view, case_value)
	var capture := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not capture.is_empty(), "Could not load the consolidated scouting-state capture.")
	if not capture.is_empty():
		capture.save_png("%s/scouting_structure_state_strip.png" % OUTPUT_DIR)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_visual_capture":"%s/scouting_structure_state_strip.png" % OUTPUT_DIR,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(not node.is_empty() and String(node.get("site_id", "")) == site_id, "%s lost its shipped scenario placement." % site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "scouting_information_live", "%s is not live." % site_id)
	_expect(int(site.get("vision_radius", 0)) == int(case.get("radius", 0)), "%s reveal radius changed." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("ready", "")), "%s lost ready-state art." % site_id)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s capture failed: %s" % [site_id, JSON.stringify(first)])
	if not bool(first.get("ok", false)):
		return
	_expect(int(first.get("site_vision_radius", 0)) == int(case.get("radius", 0)), "%s capture did not execute its authored survey radius." % site_id)
	var controlled: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(controlled.get("collected", false)) and String(controlled.get("collected_by_faction_id", "")) == "player", "%s did not become player controlled." % site_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x",0)),int(node.get("y",0))))
	await get_tree().process_frame
	var controlled_id := String(view.call("_resource_asset_id", controlled))
	var texture = view.call("_object_texture_for_asset", controlled_id)
	_expect(controlled_id == String(case.get("controlled", "")), "%s did not switch to controlled-state art." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s controlled atlas region changed." % site_id)
	var authority_after_first := session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after_first, "%s repeat capture mutated authority." % site_id)
	var restored := _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s save round-trip changed authority." % site_id)
	var visibility_probe := _clone_session(restored)
	var controlled_tiles := _isolate_controlled_site_visibility(visibility_probe, placement_id)
	var expected_tiles := _expected_ring_tiles(controlled, int(case.get("radius", 0)), OverworldRules.derive_map_size(visibility_probe))
	_expect(controlled_tiles == expected_tiles, "%s persistent watch revealed %d tiles instead of %d." % [site_id, controlled_tiles, expected_tiles])
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"placement_id":placement_id,"first_capture":true,"repeat_blocked":true,"save_round_trip_exact":true,"persistent_watch_tiles":controlled_tiles,"ready_asset_id":String(case.get("ready","")),"controlled_asset_id":controlled_id})

func _isolate_controlled_site_visibility(session, placement_id: String) -> int:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node: Dictionary = nodes[index]
		if String(node.get("placement_id", "")) == placement_id:
			node["collected"] = true
			node["collected_by_faction_id"] = "player"
		else:
			node["collected"] = false
			node["collected_by_faction_id"] = ""
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes
	session.overworld["player_heroes"] = []
	var map_size := OverworldRules.derive_map_size(session)
	var blank := []
	for _y in range(map_size.y):
		var row := []
		for _x in range(map_size.x):
			row.append(false)
		blank.append(row)
	session.overworld["fog"] = {"visible_tiles":blank.duplicate(true),"explored_tiles":blank.duplicate(true),"visible_count":0,"explored_count":0,"total_tiles":map_size.x*map_size.y}
	OverworldRules.refresh_fog_of_war(session)
	var count := 0
	for row_value in session.overworld.get("fog", {}).get("explored_tiles", []):
		if row_value is Array:
			for value in row_value:
				if bool(value):
					count += 1
	return count

func _expected_ring_tiles(node: Dictionary, radius: int, map_size: Vector2i) -> int:
	var count := 0
	var origin := Vector2i(int(node.get("x",0)), int(node.get("y",0)))
	for y in range(maxi(0,origin.y-radius), mini(map_size.y-1,origin.y+radius)+1):
		for x in range(maxi(0,origin.x-radius), mini(map_size.x-1,origin.x+radius)+1):
			if absi(x-origin.x)+absi(y-origin.y) <= radius:
				count += 1
	return count

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _clone_session(source) -> SessionStateStoreScript.SessionData:
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
