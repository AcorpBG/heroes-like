extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "TEN_LAND_TRANSIT_NETWORK_REPORT"
const OUTPUT_DIR := "res://.artifacts/ten_land_transit_network_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/land_transit_active_atlas.png"
const CASES := [
	{"site_id":"site_repaired_ferry_stage","scenario_id":"ninefold-confluence","placement_id":"repaired_ferry_stage","from":Vector2i(48,20),"to":Vector2i(56,20),"two_way":true,"repair":true,"active":"resource_site_land_transit_repaired_ferry_stage_active","region":Rect2(0,0,48,48)},
	{"site_id":"site_rope_lift","scenario_id":"ninefold-confluence","placement_id":"rope_lift","from":Vector2i(9,51),"to":Vector2i(9,54),"two_way":true,"repair":true,"active":"resource_site_land_transit_rope_lift_active","region":Rect2(48,0,48,48)},
	{"site_id":"site_root_pass_arch","scenario_id":"seedseer-drowned-orchard","placement_id":"seedseer_dormant_b","from":Vector2i(4,2),"to":Vector2i(7,2),"two_way":true,"repair":false,"active":"resource_site_land_transit_root_pass_arch_active","region":Rect2(96,0,48,48)},
	{"site_id":"site_pressure_rail_switch","scenario_id":"quench-gorefen-audit","placement_id":"quench_dormant_b","from":Vector2i(1,5),"to":Vector2i(5,5),"two_way":true,"repair":false,"active":"resource_site_land_transit_pressure_rail_switch_active","region":Rect2(144,0,48,48)},
	{"site_id":"site_mirror_stair_turn","scenario_id":"choirward-foundry-eclipse","placement_id":"choirward_dormant_b","from":Vector2i(7,0),"to":Vector2i(7,3),"two_way":true,"repair":false,"active":"resource_site_land_transit_mirror_stair_turn_active","region":Rect2(192,0,48,48)},
	{"site_id":"site_basalt_undergate","scenario_id":"ninefold-confluence","placement_id":"ninefold_basalt_undergate","from":Vector2i(59,44),"to":Vector2i(59,48),"two_way":true,"repair":false,"active":"resource_site_land_transit_basalt_undergate_active","region":Rect2(240,0,48,48)},
	{"site_id":"site_ridge_wind_chute","scenario_id":"ninefold-confluence","placement_id":"ninefold_ridge_wind_chute","from":Vector2i(7,55),"to":Vector2i(7,58),"two_way":false,"repair":false,"active":"resource_site_land_transit_ridge_wind_chute_active","region":Rect2(288,0,48,48)},
	{"site_id":"site_slipgate_mirror","scenario_id":"ninefold-confluence","placement_id":"ninefold_slipgate_mirror","from":Vector2i(10,44),"to":Vector2i(12,44),"two_way":false,"repair":false,"active":"resource_site_land_transit_slipgate_mirror_active","region":Rect2(336,0,48,48)},
	{"site_id":"site_spillway_drop_marker","scenario_id":"fenhook-daybreak-hunt","placement_id":"fenhook_dormant_c","from":Vector2i(2,2),"to":Vector2i(5,2),"two_way":false,"repair":false,"active":"resource_site_land_transit_spillway_drop_marker_active","region":Rect2(384,0,48,48)},
	{"site_id":"site_tide_bore_marker","scenario_id":"fenhook-daybreak-hunt","placement_id":"fenhook_dormant_b","from":Vector2i(1,5),"to":Vector2i(4,5),"two_way":false,"repair":false,"active":"resource_site_land_transit_tide_bore_marker_active","region":Rect2(432,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []
var _unsafe_exit_fail_closed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_case(view, case_value)
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(480, 48), "Consolidated land-transit atlas was not the exact compact strip.")
	if not atlas.is_empty():
		atlas.save_png("%s/land_transit_active_strip.png" % OUTPUT_DIR)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"two_way_case_count": 6,
		"one_way_case_count": 4,
		"edge_absent_before_claim": _all_rows_true("edge_absent_before_claim"),
		"forward_move_cost_one": _all_rows_true("forward_move_cost_one"),
		"reverse_move_rejected_exact": _one_way_rows_true("reverse_exact"),
		"save_roundtrip_exact": _all_rows_true("save_roundtrip_exact"),
		"active_art_resolves": _all_rows_true("active_art_resolves"),
		"unsafe_exit_fail_closed": _unsafe_exit_fail_closed,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_visual_capture": "%s/land_transit_active_strip.png" % OUTPUT_DIR,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":10,"two_way_case_count":6,"one_way_case_count":4,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var session = ScenarioFactory.create_session(String(case.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s scenario session could not be created." % String(case.get("site_id", "")))
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var placement_id := String(case.get("placement_id", ""))
	var site_id := String(case.get("site_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var from_tile: Vector2i = case.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = case.get("to", Vector2i.ZERO)
	var edge_absent_before_claim := OverworldRules.active_linked_transit_edges(session).is_empty()
	_expect(not node.is_empty() and String(node.get("site_id", "")) == site_id, "%s shipped placement is missing." % site_id)
	_expect(edge_absent_before_claim, "%s exposed an edge before claim." % site_id)
	var ready_asset_id := String(view.call("_resource_asset_id", node))
	_expect(ready_asset_id == "mapobj_%s" % site_id.trim_prefix("site_"), "%s dormant asset mapping changed." % site_id)
	var claim_result := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(claim_result.get("ok", false)), "%s claim failed: %s" % [site_id, JSON.stringify(claim_result)])
	if bool(case.get("repair", false)):
		_expect(OverworldRules.active_linked_transit_edges(session).is_empty(), "%s repair-gated edge opened from claim alone." % site_id)
		_set_position(session, from_tile)
		_set_movement(session, 20)
		var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		resources["gold"] = maxi(1000, int(resources.get("gold", 0)))
		resources["wood"] = maxi(10, int(resources.get("wood", 0)))
		resources["ore"] = maxi(10, int(resources.get("ore", 0)))
		session.overworld["resources"] = resources
		var response_result := OverworldRules.perform_context_action(session, "site_response")
		_expect(bool(response_result.get("ok", false)), "%s repair response failed: %s" % [site_id, JSON.stringify(response_result)])
	var active_node: Dictionary = _node_result(session, placement_id).get("node", {})
	var active_asset_id := String(view.call("_resource_asset_id", active_node))
	var texture = view.call("_object_texture_for_asset", active_asset_id)
	var active_art_resolves: bool = active_asset_id == String(case.get("active", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(active_art_resolves, "%s did not resolve its exact activated atlas region." % site_id)
	var edges := OverworldRules.active_linked_transit_edges(session)
	var edge: Dictionary = _matching_edge(edges, placement_id)
	var edge_exact: bool = edge.get("from_tile", Vector2i(-1,-1)) == from_tile and edge.get("to_tile", Vector2i(-1,-1)) == to_tile and int(edge.get("movement_cost", 0)) == 1 and bool(edge.get("two_way", false)) == bool(case.get("two_way", false))
	_expect(edges.size() == 1 and edge_exact, "%s active edge was not exact: %s" % [site_id, JSON.stringify(edges)])
	_set_position(session, from_tile)
	_set_movement(session, 10)
	var movement_before := int(session.overworld.get("movement", {}).get("current", 0))
	var forward_result := OverworldRules.try_move_along_route(session, [from_tile, to_tile], 10)
	var forward_move_cost_one := bool(forward_result.get("ok", false)) and OverworldRules.hero_position(session) == to_tile and movement_before - int(session.overworld.get("movement", {}).get("current", 0)) == 1
	_expect(forward_move_cost_one, "%s forward traversal was not exactly one movement point: %s" % [site_id, JSON.stringify(forward_result)])
	_set_movement(session, 10)
	var reverse_exact := false
	if bool(case.get("two_way", false)):
		var reverse_result := OverworldRules.try_move_along_route(session, [to_tile, from_tile], 10)
		reverse_exact = bool(reverse_result.get("ok", false)) and OverworldRules.hero_position(session) == from_tile and int(session.overworld.get("movement", {}).get("current", 0)) == 9
		_expect(reverse_exact, "%s reverse traversal failed despite a two-way contract." % site_id)
	else:
		OverworldRules.normalize_overworld_state_for_runtime(session)
		var before_reverse: Dictionary = session.to_dict()
		var reverse_result := OverworldRules.try_move_along_route(session, [to_tile, from_tile], 10)
		reverse_exact = not bool(reverse_result.get("ok", true)) and session.to_dict() == before_reverse
		_expect(reverse_exact, "%s one-way reverse traversal did not reject without mutation." % site_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var restored_edge := _matching_edge(OverworldRules.active_linked_transit_edges(restored), placement_id)
	var restored_node: Dictionary = _node_result(restored, placement_id).get("node", {})
	var save_roundtrip_exact := not restored_edge.is_empty() and bool(restored_node.get("collected", false)) and restored.save_version == SessionState.SAVE_VERSION
	_expect(save_roundtrip_exact, "%s active authority did not survive save/load normalization." % site_id)
	if site_id == "site_basalt_undergate":
		var unsafe := SessionStateStoreScript.SessionData.new()
		unsafe.from_dict(session.to_dict())
		var encounters: Array = unsafe.overworld.get("encounters", []).duplicate(true)
		encounters.append({"placement_id":"land_transit_exit_blocker","encounter_id":"encounter_mire_raid","kind":"guard","x":to_tile.x,"y":to_tile.y,"resolved":false,"blocking_body":true})
		unsafe.overworld["encounters"] = encounters
		OverworldRules._refresh_blocked_tile_index(unsafe)
		_unsafe_exit_fail_closed = _matching_edge(OverworldRules.active_linked_transit_edges(unsafe), placement_id).is_empty()
		_expect(_unsafe_exit_fail_closed, "Unsafe occupied endpoint did not fail the Basalt Undergate closed.")
	_rows.append({"site_id":site_id,"placement_id":placement_id,"directionality":"two_way" if bool(case.get("two_way",false)) else "one_way","edge_absent_before_claim":edge_absent_before_claim,"forward_move_cost_one":forward_move_cost_one,"reverse_exact":reverse_exact,"save_roundtrip_exact":save_roundtrip_exact,"active_art_resolves":active_art_resolves})


func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _matching_edge(edges: Array, placement_id: String) -> Dictionary:
	for edge_value in edges:
		if edge_value is Dictionary and String(edge_value.get("placement_id", "")) == placement_id:
			return edge_value
	return {}


func _set_position(session, tile: Vector2i) -> void:
	OverworldRules._set_active_hero_position(session, tile)


func _set_movement(session, amount: int) -> void:
	var movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	movement["current"] = amount
	movement["max"] = maxi(amount, int(movement.get("max", 0)))
	session.overworld["movement"] = movement
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	HeroCommandRules.commit_active_hero(session)


func _all_rows_true(key: String) -> bool:
	return _rows.size() == CASES.size() and _rows.all(func(row): return bool(row.get(key, false)))


func _one_way_rows_true(key: String) -> bool:
	var rows := _rows.filter(func(row): return String(row.get("directionality", "")) == "one_way")
	return rows.size() == 4 and rows.all(func(row): return bool(row.get(key, false)))


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
