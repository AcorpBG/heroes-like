extends Node

const REPORT_ID := "OVERWORLD_ROPE_LIFT_LIVE_TRANSIT_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "rope_lift"
const NORTH_ENDPOINT := Vector2i(9, 51)
const SOUTH_ENDPOINT := Vector2i(9, 54)

var _original_session = null
var _original_window_size := Vector2i.ZERO


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_window_size = get_window().size
	var rules := _validate_rules_lifecycle()
	if rules.is_empty():
		return
	var live := await _validate_live_shell_widths(rules.get("active_payload", {}))
	if live.is_empty():
		return
	SessionState.set_active_session(_original_session)
	get_window().size = _original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"endpoints": [_tile_payload(NORTH_ENDPOINT), _tile_payload(SOUTH_ENDPOINT)],
		"rules": rules.get("summary", {}),
		"live": live,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _validate_rules_lifecycle() -> Dictionary:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		return _fail("Ninefold session could not be created.")
	var node_before := _resource_node(session)
	var site := ContentService.get_resource_site("site_rope_lift")
	var object := ContentService.get_map_object("object_rope_lift")
	var authored_checks := {
		"placement_exact": int(node_before.get("x", -1)) == 9 and int(node_before.get("y", -1)) == 52,
		"site_runtime_adopted": bool((site.get("runtime_boundary", {}) as Dictionary).get("pathing_runtime_adopted", false)) and bool((site.get("route_effect_boundary", {}) as Dictionary).get("runtime_behavior_adopted", false)),
		"object_runtime_adopted": bool((object.get("runtime_boundary", {}) as Dictionary).get("pathing_runtime_adopted", false)) and bool((object.get("route_effect_boundary", {}) as Dictionary).get("runtime_behavior_adopted", false)),
		"response_exact": String((site.get("response_profile", {}) as Dictionary).get("action_label", "")) == "Reeve Rope Lift" and int((site.get("response_profile", {}) as Dictionary).get("watch_days", 0)) == 4,
		"edge_absent_before_claim": OverworldRules.active_linked_transit_edges(session).is_empty(),
	}
	if not _checks_exact(authored_checks):
		return _fail("Authored Rope Lift boundary was not exact.", authored_checks)

	_set_position(session, Vector2i(9, 50))
	_set_movement(session, 10)
	var claim_result := OverworldRules.try_move_along_route(session, [Vector2i(9, 50), NORTH_ENDPOINT], 20)
	var claimed_node := _resource_node(session)
	var claim_checks := {
		"claim_ok": bool(claim_result.get("ok", false)),
		"claim_position": OverworldRules.hero_position(session) == NORTH_ENDPOINT,
		"claim_owner": String(claimed_node.get("collected_by_faction_id", "")) == "player",
		"claim_alone_closed": OverworldRules.active_linked_transit_edges(session).is_empty(),
	}
	if not _checks_exact(claim_checks):
		return _fail("Claiming the Rope Lift did not remain repair-gated.", {"checks": claim_checks, "result": claim_result})

	var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	resources["gold"] = maxi(500, int(resources.get("gold", 0)))
	resources["ore"] = maxi(5, int(resources.get("ore", 0)))
	session.overworld["resources"] = resources
	_set_movement(session, 10)
	var resources_before: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var movement_before := int((session.overworld.get("movement", {}) as Dictionary).get("current", 0))
	var response_result := OverworldRules.perform_context_action(session, "site_response")
	var active_edges := OverworldRules.active_linked_transit_edges(session)
	var resources_after: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var response_checks := {
		"response_ok": bool(response_result.get("ok", false)),
		"gold_exact": int(resources_before.get("gold", 0)) - int(resources_after.get("gold", 0)) == 130,
		"ore_exact": int(resources_before.get("ore", 0)) - int(resources_after.get("ore", 0)) == 1,
		"movement_exact": movement_before - int((session.overworld.get("movement", {}) as Dictionary).get("current", 0)) == 3,
		"edge_count_exact": active_edges.size() == 1,
		"edge_exact": _edge_exact(active_edges[0] if active_edges.size() == 1 else {}),
	}
	if not _checks_exact(response_checks):
		return _fail("Successful Reeve Rope Lift did not open the exact authored edge.", {"checks": response_checks, "movement_before": movement_before, "movement_after": (session.overworld.get("movement", {}) as Dictionary).get("current", -1), "result": response_result, "edges": active_edges})

	_set_movement(session, 10)
	var north_before := int((session.overworld.get("movement", {}) as Dictionary).get("current", 0))
	var north_to_south := OverworldRules.try_move_along_route(session, [NORTH_ENDPOINT, SOUTH_ENDPOINT], 10)
	var forward_checks := {
		"ok": bool(north_to_south.get("ok", false)),
		"position": OverworldRules.hero_position(session) == SOUTH_ENDPOINT,
		"movement_one": north_before - int((session.overworld.get("movement", {}) as Dictionary).get("current", 0)) == 1,
		"route_step_exact": north_to_south.get("route_steps", []) == [_tile_payload(SOUTH_ENDPOINT)],
		"preview_cost_one": int((north_to_south.get("route_execution", {}) as Dictionary).get("total_cost", 0)) == 1,
	}
	if not _checks_exact(forward_checks):
		return _fail("North-to-south Rope Lift movement was not exact.", {"checks": forward_checks, "result": north_to_south})

	_set_movement(session, 10)
	var south_before := int((session.overworld.get("movement", {}) as Dictionary).get("current", 0))
	var south_to_north := OverworldRules.try_move_along_route(session, [SOUTH_ENDPOINT, NORTH_ENDPOINT], 10)
	var reverse_checks := {
		"ok": bool(south_to_north.get("ok", false)),
		"position": OverworldRules.hero_position(session) == NORTH_ENDPOINT,
		"movement_one": south_before - int((session.overworld.get("movement", {}) as Dictionary).get("current", 0)) == 1,
	}
	if not _checks_exact(reverse_checks):
		return _fail("South-to-north Rope Lift movement was not exact.", {"checks": reverse_checks, "result": south_to_north})

	var active_payload: Dictionary = session.to_dict()
	var restored = SessionState.new_session_data()
	restored.from_dict(active_payload)
	var restored_edges := OverworldRules.active_linked_transit_edges(restored)
	if restored.save_version != SessionState.SAVE_VERSION or restored_edges.size() != 1 or not _edge_exact(restored_edges[0]):
		return _fail("Save normalization did not preserve exact active transit authority.", {"save_version": restored.save_version, "edges": restored_edges})

	var unsafe = SessionState.new_session_data()
	unsafe.from_dict(active_payload)
	var encounters: Array = (unsafe.overworld.get("encounters", []) as Array).duplicate(true)
	encounters.append({"placement_id": "rope_lift_exit_blocker", "encounter_id": "encounter_mire_raid", "kind": "guard", "x": SOUTH_ENDPOINT.x, "y": SOUTH_ENDPOINT.y, "resolved": false, "blocking_body": true})
	unsafe.overworld["encounters"] = encounters
	OverworldRules._refresh_blocked_tile_index(unsafe)
	if not OverworldRules.active_linked_transit_edges(unsafe).is_empty():
		return _fail("An unsafe occupied exit retained the Rope Lift edge.")

	var expired = SessionState.new_session_data()
	expired.from_dict(active_payload)
	var expired_node := _resource_node(expired)
	expired.day = int(expired_node.get("response_until_day", expired.day)) + 1
	OverworldRules.normalize_overworld_state_for_runtime(expired)
	var expired_before: Dictionary = expired.to_dict()
	var expired_move := OverworldRules.try_move_along_route(expired, [NORTH_ENDPOINT, SOUTH_ENDPOINT], 10)
	if not OverworldRules.active_linked_transit_edges(expired).is_empty() or bool(expired_move.get("ok", false)) or expired.to_dict() != expired_before:
		return _fail("Expired Rope Lift transit did not fail closed without mutation.", {"result": expired_move})

	var failed = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var failed_nodes: Array = (failed.overworld.get("resource_nodes", []) as Array).duplicate(true)
	var failed_index := _resource_node_index(failed)
	var failed_node: Dictionary = failed_nodes[failed_index]
	failed_node["collected"] = true
	failed_node["collected_by_faction_id"] = "player"
	failed_nodes[failed_index] = failed_node
	failed.overworld["resource_nodes"] = failed_nodes
	_set_position(failed, NORTH_ENDPOINT)
	_set_movement(failed, 20)
	var failed_resources: Dictionary = (failed.overworld.get("resources", {}) as Dictionary).duplicate(true)
	failed_resources["gold"] = 0
	failed_resources["ore"] = 0
	failed.overworld["resources"] = failed_resources
	OverworldRules.normalize_overworld_state_for_runtime(failed)
	var failed_before: Dictionary = failed.to_dict()
	var failed_result := OverworldRules.perform_context_action(failed, "site_response")
	if bool(failed_result.get("ok", false)) or not OverworldRules.active_linked_transit_edges(failed).is_empty() or failed.to_dict() != failed_before:
		return _fail("Unaffordable Rope Lift response did not fail closed without mutation.", {"result": failed_result})
	var exhausted = SessionState.new_session_data()
	exhausted.from_dict(failed_before)
	var exhausted_resources: Dictionary = (exhausted.overworld.get("resources", {}) as Dictionary).duplicate(true)
	exhausted_resources["gold"] = 500
	exhausted_resources["ore"] = 5
	exhausted.overworld["resources"] = exhausted_resources
	_set_movement(exhausted, 0)
	OverworldRules.normalize_overworld_state_for_runtime(exhausted)
	var exhausted_before: Dictionary = exhausted.to_dict()
	var exhausted_result := OverworldRules.perform_context_action(exhausted, "site_response")
	if bool(exhausted_result.get("ok", false)) or not OverworldRules.active_linked_transit_edges(exhausted).is_empty() or exhausted.to_dict() != exhausted_before:
		return _fail("Movement-exhausted Rope Lift response did not fail closed without mutation.", {"result": exhausted_result})

	return {
		"active_payload": active_payload,
		"summary": {
			"claim_alone_closed": true,
			"response_cost_exact": true,
			"two_way_cost_one": true,
			"save_roundtrip": true,
			"unsafe_exit_closed": true,
			"expired_closed": true,
			"failed_response_closed": true,
			"exhausted_response_closed": true,
		},
	}


func _validate_live_shell_widths(active_payload: Dictionary) -> Dictionary:
	var rows := []
	for width in [1280, 1920]:
		get_window().size = Vector2i(width, 720 if width == 1280 else 1080)
		await get_tree().process_frame
		var session = SessionState.new_session_data()
		session.from_dict(active_payload)
		_set_position(session, NORTH_ENDPOINT)
		_set_movement(session, 10)
		session = SessionState.set_active_session(session)
		var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		await get_tree().process_frame
		await get_tree().process_frame
		var path: Array = shell.call("_build_path", NORTH_ENDPOINT, SOUTH_ENDPOINT)
		shell.call("_set_selected_tile", SOUTH_ENDPOINT)
		var route_state: Dictionary = shell.call("_ensure_selected_route_state", "rope_lift_focused")
		var preview: Dictionary = route_state.get("route_preview", {}) if route_state.get("route_preview", {}) is Dictionary else {}
		var snapshot: Dictionary = shell.call("validation_snapshot")
		var active_generation := int(route_state.get("generation", -1))
		var active_signature := String(route_state.get("signature", ""))
		var live_node := _resource_node(session)
		session.day = int(live_node.get("response_until_day", session.day)) + 1
		var expired_route_state: Dictionary = shell.call("_ensure_selected_route_state", "rope_lift_expired")
		var expired_route: Array = expired_route_state.get("route_tiles", []) if expired_route_state.get("route_tiles", []) is Array else []
		var checks := {
			"path_exact": path == [NORTH_ENDPOINT, SOUTH_ENDPOINT],
			"selected_route_exact": route_state.get("route_tiles", []) == [NORTH_ENDPOINT, SOUTH_ENDPOINT],
			"preview_cost_one": int(preview.get("total_cost", 0)) == 1 and bool(preview.get("destination_reachable", false)),
			"viewport_width": int(get_window().size.x) == width,
			"session_identity": is_same(SessionState.active_session, session),
			"snapshot_ready": not snapshot.is_empty(),
			"expiry_cache_invalidated": int(expired_route_state.get("generation", -1)) > active_generation and String(expired_route_state.get("signature", "")) != active_signature,
			"expired_direct_edge_absent": expired_route != [NORTH_ENDPOINT, SOUTH_ENDPOINT] and OverworldRules.active_linked_transit_edges(session).is_empty(),
		}
		if not _checks_exact(checks):
			shell.queue_free()
			await get_tree().process_frame
			return _fail("%d live Rope Lift route preview was not exact." % width, {"checks": checks, "path": path, "route_state": route_state})
		rows.append({"width": width, "path_tiles": path.size(), "total_cost": int(preview.get("total_cost", 0)), "expiry_cache_invalidated": true})
		shell.queue_free()
		await get_tree().process_frame
	return {"widths": [1280, 1920], "rows": rows, "live_selected_route": true}


func _resource_node_index(session) -> int:
	var nodes = session.overworld.get("resource_nodes", [])
	if not (nodes is Array):
		return -1
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == PLACEMENT_ID:
			return index
	return -1


func _resource_node(session) -> Dictionary:
	var index := _resource_node_index(session)
	var nodes = session.overworld.get("resource_nodes", [])
	return (nodes[index] as Dictionary).duplicate(true) if nodes is Array and index >= 0 and index < nodes.size() and nodes[index] is Dictionary else {}


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


func _edge_exact(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var edge: Dictionary = value
	return String(edge.get("placement_id", "")) == PLACEMENT_ID \
		and String(edge.get("site_id", "")) == "site_rope_lift" \
		and String(edge.get("object_id", "")) == "object_rope_lift" \
		and String(edge.get("effect_id", "")) == "rope_lift_vertical_shortcut" \
		and String(edge.get("endpoint_group_id", "")) == "ninefold_ridge_rope_lift" \
		and edge.get("from_tile", Vector2i.ZERO) == NORTH_ENDPOINT \
		and edge.get("to_tile", Vector2i.ZERO) == SOUTH_ENDPOINT \
		and int(edge.get("movement_cost", 0)) == 1 \
		and bool(edge.get("two_way", false))


func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}


func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _fail(message: String, details: Dictionary = {}) -> Dictionary:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(details)])
	SessionState.set_active_session(_original_session)
	get_window().size = _original_window_size
	get_tree().quit(1)
	return {}
