extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "RANDOM_MAP_PATHING_DEBUG_OVERLAY_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "pathing-debug-overlay-10184"
const TEMPLATE_ID := "border_gate_compact_v1"
const PROFILE_ID := "border_gate_compact_profile_v1"

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			EXPLICIT_SEED,
			TEMPLATE_ID,
			PROFILE_ID,
			3,
			"land",
			false,
			SIZE_CLASS_ID
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated setup failed: %s" % JSON.stringify(setup))
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated session did not start from setup: %s" % JSON.stringify(setup))
		return
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_pathing_debug_overlay",
		{
			"scenario_id": String(session.scenario_id),
			"size_class_id": SIZE_CLASS_ID,
			"seed": EXPLICIT_SEED,
		}
	)
	var prepare_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not bool(prepare_result.get("ok", false)):
		_fail("Generated overworld handoff did not prepare: %s" % JSON.stringify(prepare_result))
		return

	var overworld = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld)
	for _i in range(8):
		await get_tree().process_frame
	var handoff_profile: Dictionary = AppRouter.validation_latest_overworld_handoff_profile()
	for _i in range(120):
		if not bool(handoff_profile.get("active", false)):
			break
		await get_tree().process_frame
		handoff_profile = AppRouter.validation_latest_overworld_handoff_profile()
	if bool(handoff_profile.get("active", false)):
		_fail("Generated overworld handoff profile did not finish: %s" % JSON.stringify(handoff_profile))
		return
	if overworld == null or not overworld.has_method("validation_snapshot"):
		_fail("Generated route did not instantiate OverworldShell validation hooks.")
		return
	if not overworld.has_method("validation_set_debug_overlay_enabled") or not overworld.has_method("validation_debug_overlay_snapshot"):
		_fail("OverworldShell missed debug overlay validation hooks.")
		return

	var toggle_state: Dictionary = overworld.validation_set_debug_overlay_enabled(true)
	if not bool(toggle_state.get("enabled", false)) or not bool(toggle_state.get("visible", false)):
		_fail("Debug overlay did not become visible: %s" % JSON.stringify(toggle_state))
		return
	if String(toggle_state.get("toggle_key", "")) != "F3":
		_fail("Debug overlay toggle key was not documented as F3: %s" % JSON.stringify(toggle_state))
		return

	var initial_snapshot: Dictionary = overworld.validation_snapshot()
	if not _assert_generated_snapshot(initial_snapshot, "initial"):
		return
	var route_probe: Dictionary = await _select_reachable_route_target(overworld, initial_snapshot)
	if not bool(route_probe.get("ok", false)):
		_fail("No generated route target populated overlay timings: %s" % JSON.stringify(route_probe))
		return
	var selection_overlay: Dictionary = route_probe.get("overlay", {}) if route_probe.get("overlay", {}) is Dictionary else {}
	var selection_command: Dictionary = selection_overlay.get("last_command", {}) if selection_overlay.get("last_command", {}) is Dictionary else {}
	if not _assert_overlay_command(selection_overlay, "selection"):
		return

	var before_move: Dictionary = overworld.validation_snapshot()
	var before_pos: Dictionary = before_move.get("hero_position", {}) if before_move.get("hero_position", {}) is Dictionary else {}
	var primary_action := String(before_move.get("primary_action_id", ""))
	if primary_action not in ["advance_route", "march_selected"]:
		_fail("Selected route did not expose a movement primary action: %s" % JSON.stringify(_compact_snapshot(before_move)))
		return
	var move_result: Dictionary = overworld.validation_perform_primary_action()
	await get_tree().process_frame
	await get_tree().process_frame
	var after_move: Dictionary = overworld.validation_snapshot()
	var after_pos: Dictionary = after_move.get("hero_position", {}) if after_move.get("hero_position", {}) is Dictionary else {}
	if not bool(move_result.get("ok", false)):
		_fail("Primary route movement failed: %s" % JSON.stringify(move_result))
		return
	if int(before_pos.get("x", -1)) == int(after_pos.get("x", -1)) and int(before_pos.get("y", -1)) == int(after_pos.get("y", -1)):
		_fail("Primary route movement did not move the hero: before=%s after=%s result=%s" % [
			JSON.stringify(before_pos),
			JSON.stringify(after_pos),
			JSON.stringify(move_result),
		])
		return
	if String(after_move.get("scenario_status", "")) != "in_progress" or String(after_move.get("game_state", "")) != "overworld":
		_fail("Route movement changed scenario/game state unexpectedly: %s" % JSON.stringify(_compact_snapshot(after_move)))
		return
	var move_overlay: Dictionary = overworld.validation_debug_overlay_snapshot()
	if not _assert_overlay_command(move_overlay, "move"):
		return
	var move_command: Dictionary = move_overlay.get("last_command", {}) if move_overlay.get("last_command", {}) is Dictionary else {}
	if not _assert_latency_hotspot_reduction(move_command):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"toggle_key": "F3",
		"size_class_id": SIZE_CLASS_ID,
		"seed": EXPLICIT_SEED,
		"effective_seed": String(setup.get("normalized_seed", "")),
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"handoff_total_ms": int(handoff_profile.get("total_ms", -1)),
		"route_probe": route_probe.get("target", {}),
		"selection_overlay": _compact_overlay_command(selection_command),
		"move_overlay": _compact_overlay_command(move_command),
		"latency_optimization": _latency_optimization_summary(move_command),
		"move_result": {
			"ok": bool(move_result.get("ok", false)),
			"action_id": String(move_result.get("action_id", "")),
			"message": String(move_result.get("message", "")),
		},
		"before": _compact_snapshot(before_move),
		"after": _compact_snapshot(after_move),
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _select_reachable_route_target(overworld: Node, snapshot: Dictionary) -> Dictionary:
	var map_size: Dictionary = snapshot.get("map_size", {}) if snapshot.get("map_size", {}) is Dictionary else {}
	var hero: Dictionary = snapshot.get("hero_position", {}) if snapshot.get("hero_position", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var hero_tile := Vector2i(int(hero.get("x", 0)), int(hero.get("y", 0)))
	var attempts := []
	for radius in [1, 2, 3]:
		var offsets: Array[Vector2i] = [
			Vector2i(radius, 0),
			Vector2i(-radius, 0),
			Vector2i(0, radius),
			Vector2i(0, -radius),
			Vector2i(radius, radius),
			Vector2i(-radius, radius),
			Vector2i(radius, -radius),
			Vector2i(-radius, -radius),
		]
		for offset in offsets:
			var target: Vector2i = hero_tile + offset
			if target.x < 0 or target.y < 0 or target.x >= width or target.y >= height:
				continue
			var result: Dictionary = overworld.validation_select_tile(target.x, target.y)
			await get_tree().process_frame
			await get_tree().process_frame
			var overlay: Dictionary = overworld.validation_debug_overlay_snapshot()
			var route_decision: Dictionary = result.get("selected_route_decision", {}) if result.get("selected_route_decision", {}) is Dictionary else {}
			var command: Dictionary = overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}
			var status := String(route_decision.get("status", ""))
			var steps := int(route_decision.get("steps", 0))
			var target_record := {
				"x": target.x,
				"y": target.y,
				"status": status,
				"steps": steps,
				"action": String(result.get("primary_action_id", "")),
				"route_ms": float(command.get("pathfinding_ms", 0.0)),
				"set_map_state_ms": float(command.get("map_view_set_map_state_ms", 0.0)),
			}
			attempts.append(target_record)
			if status in ["reachable", "not_today"] and steps > 0 and _overlay_command_has_timings(command):
				return {
					"ok": true,
					"target": target_record,
					"overlay": overlay,
					"selected_route_decision": route_decision,
				}
	return {"ok": false, "attempts": attempts.slice(0, mini(attempts.size(), 16))}

func _assert_overlay_command(overlay: Dictionary, label: String) -> bool:
	if not bool(overlay.get("enabled", false)) or not bool(overlay.get("visible", false)):
		_fail("%s overlay was not enabled/visible: %s" % [label, JSON.stringify(overlay)])
		return false
	var text := String(overlay.get("text", ""))
	for token in ["Path Debug (F3)", "total", "BFS", "set_map_state", "refresh calls", "unaccounted", "top", "save"]:
		if text.find(token) < 0:
			_fail("%s overlay text missed token %s: %s" % [label, token, text])
			return false
	var command: Dictionary = overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}
	if not _overlay_command_has_timings(command):
		_fail("%s overlay command missed required timing fields: %s" % [label, JSON.stringify(command)])
		return false
	if not _assert_phase_reconciliation(command, label):
		return false
	if String(command.get("save_summary", "")) != "none observed" and not bool(command.get("save_observed", false)):
		_fail("%s overlay save summary contradicted save_observed: %s" % [label, JSON.stringify(command)])
		return false
	return true

func _overlay_command_has_timings(command: Dictionary) -> bool:
	return (
		not command.is_empty()
		and command.has("command_type")
		and command.has("raw_target_tile")
		and command.has("selected_tile")
		and command.has("total_command_ms")
		and command.has("pathfinding_ms")
		and command.has("route_bfs_ms")
		and command.has("blocked_tile_lookup_count")
		and command.has("refresh_ms")
		and command.has("map_view_set_map_state_ms")
		and command.has("object_index_ms")
		and command.has("road_index_ms")
		and command.has("draw_dynamic_ms")
		and command.has("phase_buckets_ms")
		and command.has("refresh_sections_ms")
		and command.has("refresh_call_count")
		and command.has("measured_sum_ms")
		and command.has("unaccounted_ms")
		and command.has("top_offenders")
		and command.has("deferred_frame_wait_ms")
		and command.has("debug_overlay_update_ms")
		and command.has("save_summary")
		and command.has("fps")
		and command.has("frame_ms")
		and float(command.get("total_command_ms", -1.0)) > 0.0
		and float(command.get("map_view_set_map_state_ms", -1.0)) >= 0.0
	)

func _assert_phase_reconciliation(command: Dictionary, label: String) -> bool:
	var phase_buckets: Dictionary = command.get("phase_buckets_ms", {}) if command.get("phase_buckets_ms", {}) is Dictionary else {}
	var refresh_sections: Dictionary = command.get("refresh_sections_ms", {}) if command.get("refresh_sections_ms", {}) is Dictionary else {}
	var top_offenders: Array = command.get("top_offenders", []) if command.get("top_offenders", []) is Array else []
	if phase_buckets.is_empty():
		_fail("%s overlay phase buckets were empty: %s" % [label, JSON.stringify(command)])
		return false
	if int(command.get("refresh_call_count", 0)) <= 0:
		_fail("%s overlay did not capture refresh call count: %s" % [label, JSON.stringify(command)])
		return false
	if not command.has("unaccounted_ms") or not command.has("measured_sum_ms"):
		_fail("%s overlay missed reconciliation fields: %s" % [label, JSON.stringify(command)])
		return false
	if top_offenders.is_empty():
		_fail("%s overlay did not expose top timing offenders: %s" % [label, JSON.stringify(command)])
		return false
	var total_ms := float(command.get("total_command_ms", 0.0))
	var measured_ms := float(command.get("measured_sum_ms", 0.0))
	var unaccounted_ms := float(command.get("unaccounted_ms", 0.0))
	if measured_ms <= 0.0 or measured_ms + maxf(unaccounted_ms, 0.0) < total_ms * 0.65:
		var top_record: Dictionary = top_offenders[0] if top_offenders[0] is Dictionary else {}
		var top_name := String(top_record.get("name", "unknown"))
		if top_name != "unaccounted":
			_fail("%s overlay measured too little of total without naming unaccounted as top unknown bucket: total=%.3f measured=%.3f unaccounted=%.3f top=%s command=%s" % [
				label,
				total_ms,
				measured_ms,
				unaccounted_ms,
				top_name,
				JSON.stringify(command),
			])
			return false
	if refresh_sections.is_empty():
		_fail("%s overlay missed detailed refresh sections: %s" % [label, JSON.stringify(command)])
		return false
	return true

func _assert_latency_hotspot_reduction(command: Dictionary) -> bool:
	var refresh_sections: Dictionary = command.get("refresh_sections_ms", {}) if command.get("refresh_sections_ms", {}) is Dictionary else {}
	var phase_buckets: Dictionary = command.get("phase_buckets_ms", {}) if command.get("phase_buckets_ms", {}) is Dictionary else {}
	var total_ms := float(command.get("total_command_ms", 0.0))
	var movement_ms := float(phase_buckets.get("movement_rules", 0.0))
	var read_scope_ms := float(refresh_sections.get("read_scope_map_state", 0.0))
	var actions_ms := float(refresh_sections.get("actions", 0.0))
	if read_scope_ms > 50.0:
		_fail("Optimized move still spent too long in normalized read scope: %.3fms command=%s" % [read_scope_ms, JSON.stringify(_compact_overlay_command(command))])
		return false
	if movement_ms > 2000.0:
		_fail("Optimized move still spent too long in movement rules: %.3fms command=%s" % [movement_ms, JSON.stringify(_compact_overlay_command(command))])
		return false
	if actions_ms > 1200.0:
		_fail("Optimized move still spent too long rebuilding actions: %.3fms command=%s" % [actions_ms, JSON.stringify(_compact_overlay_command(command))])
		return false
	if total_ms > 3500.0:
		_fail("Optimized move total exceeded focused generated Small latency ceiling: %.3fms command=%s" % [total_ms, JSON.stringify(_compact_overlay_command(command))])
		return false
	return true

func _latency_optimization_summary(command: Dictionary) -> Dictionary:
	var refresh_sections: Dictionary = command.get("refresh_sections_ms", {}) if command.get("refresh_sections_ms", {}) is Dictionary else {}
	var phase_buckets: Dictionary = command.get("phase_buckets_ms", {}) if command.get("phase_buckets_ms", {}) is Dictionary else {}
	return {
		"known_before_xl": {
			"total_command_ms": 13762.108,
			"movement_rules_ms": 7890.9,
			"refresh_ms": 5824.791,
			"read_scope_map_state_ms": 3262.4,
			"refresh_actions_ms": 2214.8,
		},
		"after_generated_small": {
			"total_command_ms": float(command.get("total_command_ms", 0.0)),
			"movement_rules_ms": float(phase_buckets.get("movement_rules", 0.0)),
			"refresh_ms": float(command.get("refresh_ms", 0.0)),
			"read_scope_map_state_ms": float(refresh_sections.get("read_scope_map_state", 0.0)),
			"refresh_actions_ms": float(refresh_sections.get("actions", 0.0)),
		},
		"root_causes": [
			"routine generated movement re-entered full overworld normalization through movement rules and refresh read scopes",
			"post-move collection re-normalized the just-mutated generated session before finalization",
			"route-decision refresh work performed broad route-interception fallback scans during ordinary selected-route action rebuilds",
		],
	}

func _assert_generated_snapshot(snapshot: Dictionary, label: String) -> bool:
	if not bool(snapshot.get("generated_random_map", false)):
		_fail("%s snapshot is not generated: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	var map_size: Dictionary = snapshot.get("map_size", {}) if snapshot.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 36 or int(map_size.get("height", 0)) != 36:
		_fail("%s snapshot did not preserve generated Small 36x36 size: %s" % [label, JSON.stringify(map_size)])
		return false
	if String(snapshot.get("scenario_status", "")) != "in_progress" or String(snapshot.get("game_state", "")) != "overworld":
		_fail("%s snapshot is not a live overworld: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	return true

func _compact_overlay_command(value: Variant) -> Dictionary:
	var command: Dictionary = value if value is Dictionary else {}
	return {
		"command_type": String(command.get("command_type", "")),
		"raw_target_tile": command.get("raw_target_tile", {}),
		"selected_tile": command.get("selected_tile", {}),
		"total_command_ms": float(command.get("total_command_ms", 0.0)),
		"pathfinding_ms": float(command.get("pathfinding_ms", 0.0)),
		"route_bfs_ms": float(command.get("route_bfs_ms", 0.0)),
		"route_bfs_calls": int(command.get("route_bfs_calls", 0)),
		"blocked_tile_lookup_count": int(command.get("blocked_tile_lookup_count", 0)),
		"blocked_index_rebuild_count_delta": int(command.get("blocked_index_rebuild_count_delta", 0)),
		"blocked_index_rebuild_ms": command.get("blocked_index_rebuild_ms", -1.0),
		"refresh_ms": float(command.get("refresh_ms", 0.0)),
		"refresh_call_count": int(command.get("refresh_call_count", 0)),
		"set_map_state_ms": float(command.get("map_view_set_map_state_ms", 0.0)),
		"object_index_ms": float(command.get("object_index_ms", 0.0)),
		"object_index_rebuilds": int(command.get("object_index_rebuilds", 0)),
		"object_index_skips": int(command.get("object_index_skips", 0)),
		"road_index_ms": float(command.get("road_index_ms", 0.0)),
		"road_index_rebuilds": int(command.get("road_index_rebuilds", 0)),
		"road_index_skips": int(command.get("road_index_skips", 0)),
		"draw_dynamic_ms": float(command.get("draw_dynamic_ms", 0.0)),
		"dynamic_layer_reason": String(command.get("dynamic_layer_reason", "")),
		"phase_buckets_ms": command.get("phase_buckets_ms", {}),
		"refresh_sections_ms": command.get("refresh_sections_ms", {}),
		"measured_sum_ms": float(command.get("measured_sum_ms", 0.0)),
		"unaccounted_ms": float(command.get("unaccounted_ms", 0.0)),
		"top_offenders": command.get("top_offenders", []),
		"deferred_frame_wait_ms": float(command.get("deferred_frame_wait_ms", 0.0)),
		"debug_overlay_update_ms": float(command.get("debug_overlay_update_ms", 0.0)),
		"save_summary": String(command.get("save_summary", "")),
		"fps": float(command.get("fps", 0.0)),
		"frame_ms": float(command.get("frame_ms", 0.0)),
	}

func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"scenario_status": String(snapshot.get("scenario_status", "")),
		"game_state": String(snapshot.get("game_state", "")),
		"day": int(snapshot.get("day", 0)),
		"movement_current": int(snapshot.get("movement_current", 0)),
		"movement_max": int(snapshot.get("movement_max", 0)),
		"map_size": snapshot.get("map_size", {}),
		"hero_position": snapshot.get("hero_position", {}),
		"selected_tile": snapshot.get("selected_tile", {}),
		"primary_action_id": String(snapshot.get("primary_action_id", "")),
	}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
