extends Node

const REPORT_ID := "OVERWORLD_FULL_ROUTE_MOVEMENT_REGRESSION"
const CAPTURE_ENV := "HEROES_OVERWORLD_ROUTE_LOCOMOTION_CAPTURE"
const CAPTURE_DIR_ENV := "HEROES_OVERWORLD_ROUTE_LOCOMOTION_CAPTURE_DIR"

var _evidence: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _assert_partial_full_route_execution():
		return
	if not await _assert_reduced_motion_route_endpoint_snap():
		return
	if not await _assert_selected_route_cache_reuse():
		return
	if not await _assert_reachable_interaction_resolves_only_at_destination():
		return
	if not await _assert_route_does_not_pass_through_interaction():
		return
	if OS.get_environment(CAPTURE_ENV) == "1" and not await _capture_route_locomotion_viewports():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"evidence": _evidence, "ok": true})])
	get_tree().quit(0)

func _assert_partial_full_route_execution() -> bool:
	var session = _session_with_map(11, 3)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	shell.call("validation_set_debug_overlay_enabled", true)
	var target := Vector2i(9, 1)
	var before_target_explored := OverworldRules.is_tile_explored(session, target.x, target.y)
	var before_final_explored := OverworldRules.is_tile_explored(session, 4, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var route_decision: Dictionary = selection.get("selected_route_decision", {})
	var route_preview: Dictionary = selection.get("selected_route_preview", {})
	var map_preview: Dictionary = selection.get("map_viewport", {}).get("route_preview", {})
	if String(route_decision.get("status", "")) != "not_today":
		return _fail("Partial route should be clear but beyond current movement.", selection)
	if int(route_preview.get("total_steps", 0)) != 9 or int(route_preview.get("reachable_steps", 0)) != 4 or int(route_preview.get("unreachable_steps", 0)) != 5:
		return _fail("Route preview did not partition reachable and out-of-movement segments.", selection)
	if int(map_preview.get("reachable_steps", 0)) != 4 or int(map_preview.get("unreachable_steps", 0)) != 5:
		return _fail("Map route preview did not expose the same out-of-movement partition.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	var movement_start: Dictionary = _hero_movement_presentation(shell)
	var start_cache: Dictionary = _render_cache(shell)
	var expected_route: Array = [
		{"x": 0, "y": 1},
		{"x": 1, "y": 1},
		{"x": 2, "y": 1},
		{"x": 3, "y": 1},
		{"x": 4, "y": 1},
	]
	if (
		not bool(movement_start.get("active", false))
		or String(movement_start.get("event_id", "")) != "overworld_hero_move"
		or String(movement_start.get("animation_state", "")) != "map_step"
		or String(movement_start.get("visual_policy", "")) != "authored_animation_state"
		or bool(movement_start.get("reduced_motion", true))
		or movement_start.get("route_tiles", []) != expected_route
		or int(movement_start.get("route_step_count", 0)) != 4
		or int(movement_start.get("duration_ms", 0)) != 440
		or float(movement_start.get("progress", -1.0)) != 0.0
	):
		return _fail("Full-route movement did not start one exact normal-mode locomotion replay.", movement_start)
	await get_tree().create_timer(0.16).timeout
	var movement_mid: Dictionary = _hero_movement_presentation(shell)
	var mid_cache: Dictionary = _render_cache(shell)
	var mid_progress: float = float(movement_mid.get("progress", 0.0))
	var mid_center: Dictionary = movement_mid.get("draw_center", {}) if movement_mid.get("draw_center", {}) is Dictionary else {}
	if (
		not bool(movement_mid.get("active", false))
		or mid_progress <= 0.0
		or mid_progress >= 1.0
		or int(movement_mid.get("segment_index", -1)) < 0
		or float(movement_mid.get("segment_progress", 0.0)) <= 0.0
		or float(mid_center.get("x", 0.0)) <= 0.0
		or float(mid_center.get("y", 0.0)) <= 0.0
		or int(mid_cache.get("session_static_generation", -1)) != int(start_cache.get("session_static_generation", -2))
		or int(mid_cache.get("state_generation", -1)) != int(start_cache.get("state_generation", -2))
		or int(mid_cache.get("dynamic_generation", -1)) <= int(start_cache.get("dynamic_generation", -1))
	):
		return _fail("Normal-mode locomotion did not advance between exact route centers on only the dynamic layer.", {"start": movement_start, "mid": movement_mid})
	await get_tree().create_timer(0.36).timeout
	var movement_end: Dictionary = _hero_movement_presentation(shell)
	if bool(movement_end.get("active", true)) or float(movement_end.get("progress", 0.0)) != 1.0 or movement_end.get("final_tile", {}) != {"x": 4, "y": 1}:
		return _fail("Normal-mode locomotion did not settle on the authoritative endpoint.", movement_end)
	var completed_serial: int = int(movement_end.get("serial", 0))
	shell.call("_refresh")
	await get_tree().process_frame
	var movement_refresh: Dictionary = _hero_movement_presentation(shell)
	if bool(movement_refresh.get("active", true)) or int(movement_refresh.get("serial", -1)) != completed_serial or float(movement_refresh.get("progress", 0.0)) != 1.0:
		return _fail("An unrelated refresh replayed the completed movement serial.", movement_refresh)
	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	var last_command: Dictionary = overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}
	var phase_buckets: Dictionary = last_command.get("phase_buckets_ms", {}) if last_command.get("phase_buckets_ms", {}) is Dictionary else {}
	var finish := OverworldRules.hero_position(session)
	var movement_after := int(session.overworld.get("movement", {}).get("current", -1))
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	var route_steps: Array = route_execution.get("route_steps", []) if route_execution.get("route_steps", []) is Array else []
	if not bool(result.get("ok", false)) or finish != Vector2i(4, 1):
		return _fail("Full-route confirmation did not move to the farthest reachable tile.", result)
	if String(last_command.get("command_type", "")) != "full_route_execute" or not phase_buckets.has("route_execution_lookup"):
		return _fail("F3 overlay did not record full-route execution buckets.", overlay)
	_evidence["partial_full_route"] = {
		"command_type": String(last_command.get("command_type", "")),
		"total_command_ms": float(last_command.get("total_command_ms", 0.0)),
		"route_execution_lookup_ms": float(phase_buckets.get("route_execution_lookup", 0.0)),
		"movement_rules_ms": float(phase_buckets.get("movement_rules", 0.0)),
		"preview_total_steps": int(route_preview.get("total_steps", 0)),
		"preview_reachable_steps": int(route_preview.get("reachable_steps", 0)),
		"preview_unreachable_steps": int(route_preview.get("unreachable_steps", 0)),
		"executed_steps": route_steps.size(),
		"final_tile": {"x": finish.x, "y": finish.y},
		"movement_presentation_serial": completed_serial,
		"movement_duration_ms": int(movement_start.get("duration_ms", 0)),
		"movement_mid_progress": mid_progress,
		"movement_mid_segment": int(movement_mid.get("segment_index", -1)),
		"movement_dynamic_only": true,
		"movement_refresh_replayed": false,
	}
	if route_steps.size() != 4 or movement_after != 0:
		return _fail("Full-route confirmation did not consume one point per traversed tile.", result)
	if before_final_explored or not OverworldRules.is_tile_explored(session, 4, 1):
		return _fail("Fog did not reveal along the traversed route.", result)
	if before_target_explored or OverworldRules.is_tile_explored(session, target.x, target.y):
		return _fail("Fog revealed the untraversed destination before the hero reached it.", result)
	shell.queue_free()
	return true

func _assert_reduced_motion_route_endpoint_snap() -> bool:
	var original_reduced_motion: bool = SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(true)
	var session = _session_with_map(7, 3, true)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Reduced-motion fixture route was not reachable.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	var movement: Dictionary = _hero_movement_presentation(shell)
	var serial: int = int(movement.get("serial", 0))
	var expected_route: Array = [
		{"x": 0, "y": 1},
		{"x": 1, "y": 1},
		{"x": 2, "y": 1},
		{"x": 3, "y": 1},
		{"x": 4, "y": 1},
	]
	var reduced_exact: bool = (
		bool(result.get("ok", false))
		and OverworldRules.hero_position(session) == Vector2i(4, 1)
		and serial > 0
		and not bool(movement.get("active", true))
		and bool(movement.get("reduced_motion", false))
		and String(movement.get("animation_state", "")) == "route_endpoint_snap"
		and String(movement.get("visual_policy", "")) == "reduced_motion_fallback"
		and String(movement.get("fallback_tag", "")) == "route_endpoint_snap"
		and movement.get("route_tiles", []) == expected_route
		and int(movement.get("route_step_count", 0)) == 4
		and int(movement.get("duration_ms", -1)) == 0
		and float(movement.get("progress", 0.0)) == 1.0
		and movement.get("final_tile", {}) == {"x": 4, "y": 1}
	)
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed: Dictionary = _hero_movement_presentation(shell)
	var refresh_exact: bool = not bool(refreshed.get("active", true)) and int(refreshed.get("serial", -1)) == serial and float(refreshed.get("progress", 0.0)) == 1.0
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	if not reduced_exact or not refresh_exact:
		return _fail("Reduced motion did not use the exact one-shot endpoint-snap fallback.", {"movement": movement, "refreshed": refreshed})
	var final_tile: Dictionary = movement.get("final_tile", {}) if movement.get("final_tile", {}) is Dictionary else {}
	_evidence["reduced_motion_route"] = {
		"serial": serial,
		"animation_state": String(movement.get("animation_state", "")),
		"fallback_tag": String(movement.get("fallback_tag", "")),
		"route_step_count": int(movement.get("route_step_count", 0)),
		"duration_ms": int(movement.get("duration_ms", -1)),
		"final_tile": final_tile.duplicate(true),
		"refresh_replayed": false,
	}
	shell.queue_free()
	return true

func _assert_selected_route_cache_reuse() -> bool:
	var session = _session_with_map(32, 3, true)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 31)
	shell.call("validation_set_debug_overlay_enabled", true)
	var target := Vector2i(30, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	await get_tree().process_frame
	await get_tree().process_frame
	var selection_command := _last_debug_command(shell)
	var selection_map_path: Dictionary = selection_command.get("map_view_path", {}) if selection_command.get("map_view_path", {}) is Dictionary else {}
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Cache regression route should be reachable.", selection)
	if int(selection_command.get("route_bfs_calls", -1)) != 1:
		return _fail("Route selection should compute shell BFS exactly once.", selection_command)
	if not bool(selection_command.get("map_view_route_cache_reused", false)) or not bool(selection_map_path.get("cache_reused", false)):
		return _fail("Map view did not reuse the shell selected-route cache.", selection_command)
	if int(selection_command.get("route_cache_misses", 0)) != 1 or int(selection_command.get("route_cache_hits", 0)) <= 0:
		return _fail("Selection did not expose selected-route cache miss followed by reuse hits.", selection_command)

	shell.call("validation_reset_profile", true)
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not (String(snapshot.get("primary_action_id", "")) in ["advance_route", "march_selected"]):
		return _fail("Cached selected route did not remain available to action surfaces.", snapshot)
	if int(snapshot_profile.get("route_bfs_calls", 0)) != 0:
		return _fail("Action/validation surfaces recomputed BFS instead of reusing cached route.", snapshot_profile)
	if int(snapshot_profile.get("selected_route_cache_hits", 0)) <= 0:
		return _fail("Action/validation surfaces did not hit the durable selected-route cache.", snapshot_profile)

	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	await get_tree().process_frame
	var move_command := _last_debug_command(shell)
	if not bool(result.get("ok", false)):
		return _fail("Cached route confirmation failed.", result)
	if int(move_command.get("route_bfs_calls", -1)) != 0:
		return _fail("Existing-selection confirmation recomputed BFS despite a valid cached route.", move_command)
	if int(move_command.get("route_cache_hits", 0)) <= 0 or not bool(move_command.get("map_view_route_cache_reused", false)):
		return _fail("Existing-selection confirmation did not reuse route cache through refresh/map view.", move_command)
	_evidence["selected_route_cache_reuse"] = {
		"selection_bfs_calls": int(selection_command.get("route_bfs_calls", -1)),
		"selection_route_cache_hits": int(selection_command.get("route_cache_hits", 0)),
		"selection_route_cache_misses": int(selection_command.get("route_cache_misses", 0)),
		"selection_map_view_reused": bool(selection_command.get("map_view_route_cache_reused", false)),
		"snapshot_bfs_calls": int(snapshot_profile.get("route_bfs_calls", 0)),
		"confirmation_bfs_calls": int(move_command.get("route_bfs_calls", -1)),
		"confirmation_route_cache_hits": int(move_command.get("route_cache_hits", 0)),
		"confirmation_map_view_reused": bool(move_command.get("map_view_route_cache_reused", false)),
	}
	shell.queue_free()
	return true

func _assert_reachable_interaction_resolves_only_at_destination() -> bool:
	var session = _session_with_map(7, 3)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "full_route_wagon",
			"site_id": "site_wood_wagon",
			"x": 4,
			"y": 1,
			"collected": false,
			"collected_by_faction_id": "",
		}
	]
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Reachable interaction target did not expose an executable route.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	var finish := OverworldRules.hero_position(session)
	var node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	if not bool(result.get("ok", false)) or finish != Vector2i(4, 1):
		return _fail("Reachable interaction route did not move to the destination.", result)
	if not bool(node.get("collected", false)):
		return _fail("Reachable interaction did not resolve at the destination.", result)
	shell.queue_free()
	return true

func _assert_route_does_not_pass_through_interaction() -> bool:
	var original_reduced_motion: bool = SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(false)
	var session = _session_with_map(6, 3, true)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "corridor_blocking_wagon",
			"site_id": "site_wood_wagon",
			"x": 2,
			"y": 1,
			"collected": false,
			"collected_by_faction_id": "",
		}
	]
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 6)
	var authority_before: Dictionary = session.to_dict()
	var selection: Dictionary = shell.call("validation_select_tile", 5, 1)
	var route_decision: Dictionary = selection.get("selected_route_decision", {})
	if String(route_decision.get("status", "")) != "blocked" or bool(route_decision.get("route_clear", true)):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Route through an intermediate interaction should not be offered.", selection)
	if not String(route_decision.get("blocked_reason", "")).contains("No clear route"):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Blocked route did not explain that no clean path exists.", selection)
	await get_tree().process_frame
	var blocked_cue: Dictionary = _route_blocked_presentation(shell)
	var blocked_serial := int(blocked_cue.get("serial", 0))
	var blocked_asset: Dictionary = blocked_cue.get("vfx_asset", {}) if blocked_cue.get("vfx_asset", {}) is Dictionary else {}
	var blocked_draw: Dictionary = blocked_cue.get("vfx_draw", {}) if blocked_cue.get("vfx_draw", {}) is Dictionary else {}
	var start_cache: Dictionary = _render_cache(shell)
	if (
		blocked_serial <= 0
		or not bool(blocked_cue.get("active", false))
		or String(blocked_cue.get("event_id", "")) != "overworld_route_blocked"
		or blocked_cue.get("tile", {}) != {"x": 5, "y": 1}
		or String(blocked_cue.get("blocked_reason", "")) != String(route_decision.get("blocked_reason", ""))
		or String(blocked_cue.get("animation_state", "")) != "route_blocked"
		or String(blocked_cue.get("visual_policy", "")) != "authored_animation_state"
		or blocked_cue.get("selected_vfx_cue_ids", []) != ["vfx_placeholder_blocked_route_marker"]
		or not bool(blocked_asset.get("uses_imported_asset", false))
		or String(blocked_asset.get("texture_path", "")) != "res://art/overworld/runtime/vfx/route_blocked.png"
		or String(blocked_draw.get("mode", "")) != "imported_texture"
		or String(blocked_draw.get("texture_path", "")) != "res://art/overworld/runtime/vfx/route_blocked.png"
		or not bool(blocked_cue.get("allows_large_motion", false))
		or int(blocked_cue.get("duration_ms", 0)) != 420
		or session.to_dict() != authority_before
	):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Blocked route did not publish one exact authored cue at its selected tile.", {"decision": route_decision, "cue": blocked_cue})
	await get_tree().create_timer(0.14).timeout
	var mid_cue: Dictionary = _route_blocked_presentation(shell)
	var mid_cache: Dictionary = _render_cache(shell)
	if (
		not bool(mid_cue.get("active", false))
		or float(mid_cue.get("progress", 0.0)) <= 0.0
		or int(mid_cache.get("session_static_generation", -1)) != int(start_cache.get("session_static_generation", -2))
		or int(mid_cache.get("state_generation", -1)) != int(start_cache.get("state_generation", -2))
		or int(mid_cache.get("dynamic_generation", -1)) <= int(start_cache.get("dynamic_generation", -1))
		or session.to_dict() != authority_before
	):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Blocked route cue did not advance on only the dynamic layer.", {"cue": mid_cue, "start_cache": start_cache, "mid_cache": mid_cache})
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed_cue: Dictionary = _route_blocked_presentation(shell)
	var repeated_selection: Dictionary = shell.call("validation_select_tile", 5, 1)
	var repeated_cue: Dictionary = _route_blocked_presentation(shell)
	if (
		int(refreshed_cue.get("serial", -1)) != blocked_serial
		or int(repeated_cue.get("serial", -1)) != blocked_serial
		or String(repeated_selection.get("selected_route_decision", {}).get("status", "")) != "blocked"
		or session.to_dict() != authority_before
	):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Refresh or identical blocked-route reselection replayed the cue.", {"refreshed": refreshed_cue, "repeated": repeated_cue})
	await get_tree().create_timer(0.30).timeout
	var reachable_selection: Dictionary = shell.call("validation_select_tile", 1, 1)
	var reachable_cue: Dictionary = _route_blocked_presentation(shell)
	if (
		String(reachable_selection.get("selected_route_decision", {}).get("status", "")) != "reachable"
		or int(reachable_cue.get("serial", -1)) != blocked_serial
		or bool(reachable_cue.get("active", true))
		or session.to_dict() != authority_before
	):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		return _fail("Reachable route selection published or retained blocked-route playback.", {"selection": reachable_selection, "cue": reachable_cue})
	_evidence["blocked_route_cue"] = {
		"serial": blocked_serial,
		"tile": blocked_cue.get("tile", {}).duplicate(true),
		"duration_ms": int(blocked_cue.get("duration_ms", 0)),
		"refresh_replayed": false,
		"identical_reselection_replayed": false,
		"dynamic_layer_only": true,
	}
	shell.queue_free()
	await get_tree().process_frame

	SettingsService.set_reduced_motion_enabled(true)
	var reduced_session = _session_with_map(6, 3, true)
	reduced_session.overworld["resource_nodes"] = [{
		"placement_id": "reduced_corridor_blocking_wagon",
		"site_id": "site_wood_wagon",
		"x": 2,
		"y": 1,
		"collected": false,
		"collected_by_faction_id": "",
	}]
	reduced_session.overworld["fog"] = {}
	var reduced_opened := await _open_shell(reduced_session)
	var reduced_shell: Node = reduced_opened.get("shell", null)
	reduced_session = reduced_opened.get("session", reduced_session)
	_prepare_shell_state(reduced_shell, reduced_session, Vector2i(0, 1), 6)
	var reduced_authority_before: Dictionary = reduced_session.to_dict()
	var reduced_selection: Dictionary = reduced_shell.call("validation_select_tile", 5, 1)
	await get_tree().process_frame
	var reduced_cue: Dictionary = _route_blocked_presentation(reduced_shell)
	var reduced_asset: Dictionary = reduced_cue.get("vfx_asset", {}) if reduced_cue.get("vfx_asset", {}) is Dictionary else {}
	var reduced_draw: Dictionary = reduced_cue.get("vfx_draw", {}) if reduced_cue.get("vfx_draw", {}) is Dictionary else {}
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	if (
		String(reduced_selection.get("selected_route_decision", {}).get("status", "")) != "blocked"
		or int(reduced_cue.get("serial", 0)) <= 0
		or not bool(reduced_cue.get("active", false))
		or String(reduced_cue.get("event_id", "")) != "overworld_route_blocked"
		or reduced_cue.get("tile", {}) != {"x": 5, "y": 1}
		or String(reduced_cue.get("animation_state", "")) != "blocked_route_icon"
		or String(reduced_cue.get("visual_policy", "")) != "reduced_motion_fallback"
		or String(reduced_cue.get("fallback_tag", "")) != "blocked_route_icon"
		or reduced_cue.get("selected_vfx_cue_ids", []) != ["blocked_route_icon"]
		or bool(reduced_asset.get("uses_imported_asset", true))
		or not bool(reduced_asset.get("uses_procedural_fallback", false))
		or String(reduced_draw.get("mode", "")) != "blocked_route_icon"
		or int(reduced_draw.get("circle_count", 0)) != 1
		or int(reduced_draw.get("cross_line_count", 0)) != 2
		or bool(reduced_cue.get("allows_large_motion", true))
		or int(reduced_cue.get("duration_ms", 0)) != 260
		or reduced_session.to_dict() != reduced_authority_before
	):
		return _fail("Reduced motion did not use the exact blocked-route icon fallback.", {"selection": reduced_selection, "cue": reduced_cue})
	_evidence["reduced_motion_blocked_route_cue"] = {
		"serial": int(reduced_cue.get("serial", 0)),
		"fallback_tag": String(reduced_cue.get("fallback_tag", "")),
		"duration_ms": int(reduced_cue.get("duration_ms", 0)),
	}
	reduced_shell.queue_free()
	await get_tree().process_frame
	return true

func _capture_route_locomotion_viewports() -> bool:
	var capture_dir := OS.get_environment(CAPTURE_DIR_ENV).strip_edges()
	if capture_dir == "":
		capture_dir = "user://route_locomotion_captures"
	var absolute_capture_dir := ProjectSettings.globalize_path(capture_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_capture_dir)
	if mkdir_error != OK:
		return _fail("Could not create the route-locomotion capture directory.", {"path": absolute_capture_dir, "error": mkdir_error})
	var original_window_size := get_window().size
	var captures := {}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != viewport_size:
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture did not reach the requested viewport.", {"requested": str(viewport_size), "actual": str(get_window().size)})
		var session = _session_with_map(12, 5, true)
		session.overworld["fog"] = {}
		var opened := await _open_shell(session)
		var shell: Node = opened.get("shell", null)
		session = opened.get("session", session)
		_prepare_shell_state(shell, session, Vector2i(1, 1), 6)
		var selection: Dictionary = shell.call("validation_select_tile", 7, 1)
		if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture route was not reachable.", selection)
		var result: Dictionary = shell.call("validation_perform_primary_action")
		await get_tree().create_timer(0.24).timeout
		var movement := _hero_movement_presentation(shell)
		if not bool(result.get("ok", false)) or not bool(movement.get("active", false)) or float(movement.get("progress", 0.0)) <= 0.0 or float(movement.get("progress", 0.0)) >= 1.0:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture did not observe the live marker between route endpoints.", movement)
		await get_tree().process_frame
		var viewport_texture: Texture2D = get_viewport().get_texture()
		if viewport_texture == null:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture has no viewport texture.", movement)
		var image: Image = viewport_texture.get_image()
		if image == null or image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture returned the wrong image dimensions.", {"requested": str(viewport_size), "width": image.get_width() if image != null else -1, "height": image.get_height() if image != null else -1})
		var capture_path := absolute_capture_dir.path_join("overworld_route_locomotion_%dx%d.png" % [viewport_size.x, viewport_size.y])
		var save_error := image.save_png(capture_path)
		if save_error != OK:
			shell.queue_free()
			get_window().size = original_window_size
			return _fail("Windowed locomotion capture could not save the image.", {"path": capture_path, "error": save_error})
		captures["%dx%d" % [viewport_size.x, viewport_size.y]] = {
			"path": capture_path,
			"progress": float(movement.get("progress", 0.0)),
			"segment_index": int(movement.get("segment_index", -1)),
			"route_step_count": int(movement.get("route_step_count", 0)),
		}
		shell.queue_free()
		await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	_evidence["windowed_route_locomotion"] = captures
	return true

func _last_debug_command(shell: Node) -> Dictionary:
	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	return overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}

func _hero_movement_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("hero_movement_presentation", {}).duplicate(true) if viewport.get("hero_movement_presentation", {}) is Dictionary else {}

func _route_blocked_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("route_blocked_presentation", {}).duplicate(true) if viewport.get("route_blocked_presentation", {}) is Dictionary else {}

func _render_cache(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("render_cache", {}).duplicate(true) if viewport.get("render_cache", {}) is Dictionary else {}

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _session_with_map(width: int, height: int, corridor: bool = false):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(height):
		var row := []
		for _x in range(width):
			row.append("water" if corridor and y != 1 else "grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [
		{
			"placement_id": "riverwatch_hold",
			"town_id": "town_riverwatch",
			"x": 0,
			"y": 0,
			"owner": "player",
		}
	]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	OverworldRules.refresh_fog_of_war(session)
	return session

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["level"] = 1
	hero["experience"] = 0
	hero["specialties"] = []
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["base_movement"] = movement_points
			entry["level"] = 1
			entry["experience"] = 0
			entry["specialties"] = []
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _fail(message: String, payload: Dictionary = {}) -> bool:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
