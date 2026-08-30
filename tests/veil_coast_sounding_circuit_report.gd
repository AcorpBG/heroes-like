extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "VEIL_COAST_SOUNDING_CIRCUIT_REPORT"
const OUTPUT_DIR := "res://.artifacts/veil_coast_sounding_circuit_report"
const SCENARIO_ID := "veil-coast-sounding-circuit"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/coast_route_operational_atlas.png"
const ROUTE := [
	Vector2i(1,7),Vector2i(1,6),Vector2i(1,5),Vector2i(1,4),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
	Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6),Vector2i(8,6),Vector2i(11,6),
	Vector2i(12,6),Vector2i(12,5),Vector2i(12,4),Vector2i(12,3),Vector2i(13,3),Vector2i(13,6),Vector2i(13,7),Vector2i(13,8),
	Vector2i(13,9),Vector2i(14,9),Vector2i(18,9),Vector2i(18,10),Vector2i(17,10),Vector2i(17,11),Vector2i(20,11),
	Vector2i(21,11),Vector2i(21,10),Vector2i(21,9),Vector2i(21,8),Vector2i(21,7),Vector2i(21,6),Vector2i(20,6),
	Vector2i(17,6),Vector2i(17,5),Vector2i(17,4),Vector2i(18,4),Vector2i(19,4),Vector2i(20,4),
	Vector2i(21,4),Vector2i(21,3),Vector2i(21,2),Vector2i(22,2),
]
const CASES := [
	{"site_id":"site_veil_skiffyard","placement_id":"sounding_veil_skiffyard","from":Vector2i(3,3),"to":Vector2i(7,3),"active":"resource_site_coast_route_veil_skiffyard_operational","region":Rect2(0,0,48,48),"guard":""},
	{"site_id":"site_harbor_pilot_post","placement_id":"sounding_harbor_pilot_post","from":Vector2i(8,6),"to":Vector2i(11,6),"active":"resource_site_coast_route_harbor_pilot_post_operational","region":Rect2(48,0,48,48),"guard":""},
	{"site_id":"site_bell_buoy_station","placement_id":"sounding_bell_buoy_station","from":Vector2i(13,3),"to":Vector2i(13,6),"active":"resource_site_coast_route_bell_buoy_station_operational","region":Rect2(96,0,48,48),"guard":""},
	{"site_id":"site_wreck_quay","placement_id":"sounding_wreck_quay","from":Vector2i(14,9),"to":Vector2i(18,9),"active":"resource_site_coast_route_wreck_quay_operational","region":Rect2(144,0,48,48),"guard":"sounding_wreck_quay_watch"},
	{"site_id":"site_tide_chain_mooring","placement_id":"sounding_tide_chain_mooring","from":Vector2i(17,11),"to":Vector2i(20,11),"active":"resource_site_coast_route_tide_chain_mooring_operational","region":Rect2(192,0,48,48),"guard":"sounding_tide_chain_watch"},
	{"site_id":"site_marsh_skiff_shelf","placement_id":"sounding_marsh_skiff_shelf","from":Vector2i(17,6),"to":Vector2i(20,6),"active":"resource_site_coast_route_marsh_skiff_shelf_operational","region":Rect2(240,0,48,48),"guard":""},
]

var _errors: Array[String] = []
var _rows: Array = []
var _unsafe_exit_fail_closed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect(not scenario.is_empty(), "Veil-Coast Sounding Circuit is missing from the live scenario catalog.")
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	_expect(int(map_size.get("width", 0)) == 24 and int(map_size.get("height", 0)) == 14, "Veil-Coast Sounding Circuit lost its exact 24x14 map.")
	_expect((scenario.get("resource_nodes", []) as Array).size() == 16 and (scenario.get("encounters", []) as Array).size() == 4, "Veil-Coast Sounding Circuit lost its 16-site / 4-front contract.")
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Veil-Coast Sounding Circuit could not create a live skirmish session.")
	if session == null:
		_finish(null)
		return
	OverworldRules.normalize_overworld_state(session)
	_expect(String(session.overworld.get("hero", {}).get("id", "")) == "hero_veilmourn_sael_mirrorbell", "Sael Mirrorbell is not the live scenario commander.")
	_expect(String(scenario.get("player_army_id", "")) == "army_sael_spellwright_cadre" and not (session.overworld.get("army", {}).get("stacks", []) as Array).is_empty(), "Sael's mirror-navigation cadre is not the live player company.")

	var pre_activation: SessionStateStoreScript.SessionData = _clone_session(session)
	_set_position(pre_activation, ROUTE[0])
	_set_movement(pre_activation, 100)
	var unopened_route := OverworldRules.try_move_along_route(pre_activation, ROUTE, 100)
	var route_blocked_before_activation := not bool(unopened_route.get("ok", true)) and OverworldRules.hero_position(pre_activation) != ROUTE[-1]
	_expect(route_blocked_before_activation, "The water-separated coast route was traversable before its six services activated.")

	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_case(view, session, case_value)

	for placement_id in ["sounding_midchannel_battery", "sounding_final_matrix"]:
		_resolve_guard(session, placement_id)
	_set_position(session, ROUTE[0])
	var route_result := {}
	var route_legs := []
	for _leg in range(8):
		var route_start_index := ROUTE.find(OverworldRules.hero_position(session))
		if route_start_index < 0 or OverworldRules.hero_position(session) == ROUTE[-1]:
			break
		_set_movement(session, 11)
		route_result = OverworldRules.try_move_along_route(session, ROUTE.slice(route_start_index), 11)
		route_legs.append(route_result.duplicate(true))
		if not bool(route_result.get("ok", false)):
			break
	var sequential_route_complete := bool(route_result.get("ok", false)) and OverworldRules.hero_position(session) == ROUTE[-1]
	_expect(sequential_route_complete, "The complete six-service sounding route did not reach Dawnmirror across daily movement legs: result=%s leg_count=%d blockers=%s" % [JSON.stringify(route_result), route_legs.size(), JSON.stringify(_route_blockers(session))])

	var restored: SessionStateStoreScript.SessionData = _clone_session(session)
	var save_round_trip_exact: bool = restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and OverworldRules.active_linked_transit_edges(restored).size() == 6
	_expect(save_round_trip_exact, "The six active shore services did not round-trip exactly through save version %d." % SessionStateStoreScript.SAVE_VERSION)

	var unsafe: SessionStateStoreScript.SessionData = _clone_session(session)
	var unsafe_target: Vector2i = CASES[0].get("to", Vector2i.ZERO)
	var encounters: Array = unsafe.overworld.get("encounters", []).duplicate(true)
	encounters.append({"placement_id":"sounding_unsafe_exit_blocker","encounter_id":"encounter_mire_raid","kind":"guard","x":unsafe_target.x,"y":unsafe_target.y,"resolved":false,"blocking_body":true})
	unsafe.overworld["encounters"] = encounters
	OverworldRules._refresh_blocked_tile_index(unsafe)
	_unsafe_exit_fail_closed = _matching_edge(OverworldRules.active_linked_transit_edges(unsafe), "sounding_veil_skiffyard").is_empty()
	_expect(_unsafe_exit_fail_closed, "An occupied coast-route endpoint did not fail closed.")

	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(12, 7))
	await get_tree().process_frame
	var map_capture_path := "%s/veil_coast_sounding_circuit.png" % OUTPUT_DIR
	var capture := get_viewport().get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(map_capture_path) != OK:
		_error("Could not save the Veil-Coast Sounding Circuit visual capture.")
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(288, 48), "Coast-route operational atlas is not the exact compact strip.")
	if not atlas.is_empty():
		atlas.save_png("%s/coast_route_operational_strip.png" % OUTPUT_DIR)

	var report := {
		"ok": _errors.is_empty(),
		"scenario_id": SCENARIO_ID,
		"case_count": CASES.size(),
		"route_blocked_before_activation": route_blocked_before_activation,
		"all_six_edges_active": OverworldRules.active_linked_transit_edges(session).size() == 6,
		"all_six_live_interactions": _all_rows_true("claim_once"),
		"all_six_forward_reverse": _all_rows_true("forward_reverse_exact"),
		"all_six_operational_art": _all_rows_true("operational_art_resolves"),
		"guard_battles_constructed": _guard_rows_true("guard_battle_constructed"),
		"sequential_route_complete": sequential_route_complete,
		"unsafe_exit_fail_closed": _unsafe_exit_fail_closed,
		"save_round_trip_exact": save_round_trip_exact,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"map_capture": map_capture_path,
		"atlas_capture": "%s/coast_route_operational_strip.png" % OUTPUT_DIR,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"scenario_id":SCENARIO_ID,"case_count":6,"all_six_edges_active":true,"sequential_route_complete":true,"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, session, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var site_id := String(case.get("site_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var from_tile: Vector2i = case.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = case.get("to", Vector2i.ZERO)
	var edge_absent_before_claim := _matching_edge(OverworldRules.active_linked_transit_edges(session), placement_id).is_empty()
	_expect(not node.is_empty() and String(node.get("site_id", "")) == site_id, "%s shipped placement is missing." % site_id)
	_expect(edge_absent_before_claim, "%s exposed a live edge before visit." % site_id)
	var ready_asset_id := String(view.call("_resource_asset_id", node))
	_expect(ready_asset_id == "mapobj_%s" % site_id.trim_prefix("site_"), "%s dormant landmark mapping changed." % site_id)

	var guard_id := String(case.get("guard", ""))
	var guard_battle_constructed := guard_id == ""
	if guard_id != "":
		var guard := _encounter(session, guard_id)
		var blocked := OverworldRules._collect_resource_node_result(session, node_result, false)
		_expect(not bool(blocked.get("ok", true)) and String(blocked.get("message", "")).begins_with("Clear "), "%s did not remain blocked by its exact guard." % site_id)
		var battle := BattleRulesScript.create_battle_payload(session, guard)
		guard_battle_constructed = not battle.is_empty() and String(battle.get("encounter_id", "")) == String(guard.get("encounter_id", ""))
		_expect(guard_battle_constructed, "%s did not construct its production guard battle." % site_id)
		_resolve_guard(session, guard_id)
		node_result = _node_result(session, placement_id)

	var claim := OverworldRules._collect_resource_node_result(session, node_result, false)
	var claim_once := bool(claim.get("ok", false))
	_expect(claim_once, "%s live visit failed: %s" % [site_id, JSON.stringify(claim)])
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), false)
	_expect(not bool(repeat.get("ok", true)), "%s accepted a repeated first-visit activation." % site_id)
	var active_node: Dictionary = _node_result(session, placement_id).get("node", {})
	var active_asset_id := String(view.call("_resource_asset_id", active_node))
	var texture = view.call("_object_texture_for_asset", active_asset_id)
	var operational_art_resolves: bool = active_asset_id == String(case.get("active", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(operational_art_resolves, "%s did not resolve its exact operational atlas region." % site_id)

	var edge := _matching_edge(OverworldRules.active_linked_transit_edges(session), placement_id)
	var edge_exact: bool = edge.get("from_tile", Vector2i(-1,-1)) == from_tile and edge.get("to_tile", Vector2i(-1,-1)) == to_tile and int(edge.get("movement_cost", 0)) == 1 and bool(edge.get("two_way", false))
	_expect(edge_exact, "%s active coast edge was not exact: %s" % [site_id, JSON.stringify(edge)])
	_set_position(session, from_tile)
	_set_movement(session, 10)
	var forward := OverworldRules.try_move_along_route(session, [from_tile, to_tile], 10)
	_set_movement(session, 10)
	var reverse := OverworldRules.try_move_along_route(session, [to_tile, from_tile], 10)
	var forward_reverse_exact := bool(forward.get("ok", false)) and bool(reverse.get("ok", false)) and OverworldRules.hero_position(session) == from_tile and int(session.overworld.get("movement", {}).get("current", 0)) == 9
	_expect(forward_reverse_exact, "%s did not traverse forward and reverse at exact one-point cost." % site_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"guarded":guard_id != "","edge_absent_before_claim":edge_absent_before_claim,"claim_once":claim_once,"guard_battle_constructed":guard_battle_constructed,"forward_reverse_exact":forward_reverse_exact,"operational_art_resolves":operational_art_resolves})


func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _matching_edge(edges: Array, placement_id: String) -> Dictionary:
	for edge_value in edges:
		if edge_value is Dictionary and String(edge_value.get("placement_id", "")) == placement_id:
			return edge_value
	return {}


func _route_blockers(session) -> Array:
	var blockers := []
	for index in range(1, ROUTE.size()):
		var previous: Vector2i = ROUTE[index - 1]
		var tile: Vector2i = ROUTE[index]
		var adjacent := maxi(abs(tile.x - previous.x), abs(tile.y - previous.y)) == 1
		if adjacent and (OverworldRules.tile_is_blocked(session, tile.x, tile.y) or OverworldRules.tile_has_route_interaction(session, tile.x, tile.y)):
			blockers.append({
				"index": index,
				"from": {"x": previous.x, "y": previous.y},
				"to": {"x": tile.x, "y": tile.y},
				"blocked": OverworldRules.tile_is_blocked(session, tile.x, tile.y),
				"interaction": OverworldRules.tile_has_route_interaction(session, tile.x, tile.y),
			})
	return blockers


func _resolve_guard(session, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved
	OverworldRules._refresh_blocked_tile_index(session)


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


func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _all_rows_true(key: String) -> bool:
	return _rows.size() == CASES.size() and _rows.all(func(row): return bool(row.get(key, false)))


func _guard_rows_true(key: String) -> bool:
	var guarded := _rows.filter(func(row): return bool(row.get("guarded", false)))
	return guarded.size() == 2 and guarded.all(func(row): return bool(row.get(key, false)))


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _finish(_session) -> void:
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
