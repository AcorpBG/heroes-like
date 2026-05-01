extends Node

const REPORT_ID := "OVERWORLD_INTERACTION_PROFILE_LOG_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _session_with_map(9, 3)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 6)

	var initial_overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	if bool(initial_overlay.get("enabled", true)) or bool(initial_overlay.get("visible", true)):
		_fail("F3 overlay should start disabled before enabling the persistent log.", initial_overlay)
		return

	var log_setup: Dictionary = shell.call("validation_set_overworld_profile_log_enabled", true, true)
	if not bool(log_setup.get("enabled", false)) or int(log_setup.get("record_count", -1)) != 0:
		_fail("Profile log did not enable and clear cleanly.", log_setup)
		return

	var target := Vector2i(5, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	await get_tree().process_frame
	await get_tree().process_frame
	if not bool(selection.get("ok", false)):
		_fail("Route selection failed while profile logging was enabled.", selection)
		return

	var records: Array = shell.call("validation_overworld_profile_log_last_records", 5)
	if records.size() != 1:
		_fail("Selecting a route should write exactly one JSONL record.", {"records": records, "count": shell.call("validation_overworld_profile_log_record_count")})
		return
	var select_record: Dictionary = records[0]
	if String(select_record.get("command_type", "")) != "select_route":
		_fail("Route-selection record used the wrong command type.", select_record)
		return
	if not _assert_record_shape(select_record, "select_route", true):
		return

	var overlay_after_log: Dictionary = shell.call("validation_debug_overlay_snapshot")
	if bool(overlay_after_log.get("enabled", true)) or bool(overlay_after_log.get("visible", true)):
		_fail("Persistent logging should not enable or show the F3 overlay.", overlay_after_log)
		return

	shell.call("validation_set_debug_overlay_enabled", true)
	var clicked: Dictionary = shell.call("validation_click_tile", target.x, target.y)
	await get_tree().process_frame
	await get_tree().process_frame
	if not bool(clicked.get("ok", false)):
		_fail("Confirming the existing selected route failed.", clicked)
		return
	if OverworldRules.hero_position(session) != target:
		_fail("Profile logging or F3 overlay changed movement behavior.", {"hero": _tile_payload(OverworldRules.hero_position(session)), "target": _tile_payload(target)})
		return
	var pathing_profile: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	if int(pathing_profile.get("route_interaction_lookup_count", 0)) != 0:
		_fail("Cached selected-route execution should not run route-wide interaction validation checks.", pathing_profile)
		return
	if int(pathing_profile.get("route_interaction_full_scan_count", 0)) != 0:
		_fail("Cached selected-route execution fell back to whole-map route-interaction scans.", pathing_profile)
		return
	if int(pathing_profile.get("route_interaction_spatial_lookup_count", 0)) != 0:
		_fail("Cached selected-route execution should not need spatial route-interaction lookups.", pathing_profile)
		return

	records = shell.call("validation_overworld_profile_log_last_records", 5)
	if records.size() != 2:
		_fail("Confirming an existing selection should append a second JSONL record.", {"records": records, "count": shell.call("validation_overworld_profile_log_record_count")})
		return
	var confirm_record: Dictionary = records[1]
	if String(confirm_record.get("command_type", "")) != "click_existing_selection":
		_fail("Existing-selection confirmation record used the wrong command type.", confirm_record)
		return
	if not _assert_record_shape(confirm_record, "click_existing_selection", false):
		return

	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	var last_command: Dictionary = overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}
	if not bool(overlay.get("enabled", false)) or not bool(overlay.get("visible", false)) or String(last_command.get("command_type", "")) != "click_existing_selection":
		_fail("F3 overlay did not keep reporting the latest command while persistent logging was enabled.", overlay)
		return

	var final_log: Dictionary = shell.call("validation_clear_overworld_profile_log")
	if int(final_log.get("record_count", -1)) != 0:
		_fail("Profile log did not clear after validation.", final_log)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"log_path": String(log_setup.get("path", "")),
		"absolute_path": String(log_setup.get("absolute_path", "")),
		"selection_total_ms": float(select_record.get("total_command_ms", 0.0)),
		"confirmation_total_ms": float(confirm_record.get("total_command_ms", 0.0)),
		"selection_route_bfs_calls": int(select_record.get("route_bfs", {}).get("calls", 0)),
		"confirmation_route_cache_hits": int(confirm_record.get("route_cache", {}).get("hits", 0)),
		"hero_after": _tile_payload(OverworldRules.hero_position(session)),
	})])
	get_tree().quit(0)

func _assert_record_shape(record: Dictionary, expected_command: String, expect_bfs_call: bool) -> bool:
	for key in [
		"timestamp_utc",
		"monotonic_msec",
		"session",
		"command_type",
		"raw_target",
		"selected_target",
		"hero_before",
		"hero_after",
		"total_command_ms",
		"phase_buckets_ms",
		"refresh_sections_ms",
		"route_bfs",
		"route_cache",
		"incremental_refresh",
		"map_view_timings_ms",
		"movement_rules",
		"route_execution",
		"action_dispatch",
		"save",
		"fps",
		"frame_ms",
		"top_offenders",
		"unaccounted_ms",
	]:
		if not record.has(key):
			_fail("Profile record is missing required key %s." % key, record)
			return false
	if String(record.get("command_type", "")) != expected_command:
		_fail("Profile record command mismatch.", record)
		return false
	if not (record.get("phase_buckets_ms", {}) is Dictionary) or not (record.get("refresh_sections_ms", {}) is Dictionary):
		_fail("Profile record did not include phase and refresh buckets.", record)
		return false
	var route_bfs: Dictionary = record.get("route_bfs", {}) if record.get("route_bfs", {}) is Dictionary else {}
	for key in ["ms", "calls", "lookups", "status", "visited", "enqueued", "path_tiles"]:
		if not route_bfs.has(key):
			_fail("Route BFS profile is missing %s." % key, route_bfs)
			return false
	if expect_bfs_call and int(route_bfs.get("calls", 0)) <= 0:
		_fail("Route selection should include at least one shell BFS call.", record)
		return false
	var route_cache: Dictionary = record.get("route_cache", {}) if record.get("route_cache", {}) is Dictionary else {}
	for key in ["hits", "misses", "status", "details", "map_view_reused", "map_view_details"]:
		if not route_cache.has(key):
			_fail("Route cache profile is missing %s." % key, route_cache)
			return false
	var incremental_refresh: Dictionary = record.get("incremental_refresh", {}) if record.get("incremental_refresh", {}) is Dictionary else {}
	for key in [
		"request",
		"dirty_after",
		"phase_counts",
		"hero_actions_cache",
		"selected_context_actions_cache",
		"selected_route_decision_surface_cache",
		"selected_route_destination_action_cache",
		"route_destination_only_action",
	]:
		if not incremental_refresh.has(key):
			_fail("Incremental refresh profile is missing %s." % key, incremental_refresh)
			return false
	if expected_command == "select_route":
		var request: Dictionary = incremental_refresh.get("request", {}) if incremental_refresh.get("request", {}) is Dictionary else {}
		var phases: Array = request.get("phases", []) if request.get("phases", []) is Array else []
		for required_phase in ["map_view", "route_preview"]:
			if required_phase not in phases:
				_fail("Route-selection profile did not record incremental phase %s." % required_phase, record)
				return false
		for forbidden_phase in ["context_actions", "hero_actions"]:
			if forbidden_phase in phases:
				_fail("Route-selection profile should not request unrelated phase %s." % forbidden_phase, record)
				return false
		var destination_only: Dictionary = incremental_refresh.get("route_destination_only_action", {}) if incremental_refresh.get("route_destination_only_action", {}) is Dictionary else {}
		if not bool(destination_only.get("destination_only", false)) or not bool(destination_only.get("broad_context_actions_skipped", false)):
			_fail("Route-selection profile did not expose destination-only action skips.", record)
			return false
		var selected_context_cache: Dictionary = incremental_refresh.get("selected_context_actions_cache", {}) if incremental_refresh.get("selected_context_actions_cache", {}) is Dictionary else {}
		if not selected_context_cache.has("hits") or not selected_context_cache.has("misses"):
			_fail("Selected-context cache counters were not exposed in profile JSONL.", record)
			return false
	if expected_command == "click_existing_selection":
		var movement_rules: Dictionary = record.get("movement_rules", {}) if record.get("movement_rules", {}) is Dictionary else {}
		var movement_details: Dictionary = movement_rules.get("details", {}) if movement_rules.get("details", {}) is Dictionary else {}
		if not bool(movement_details.get("cached_route_execution", false)):
			_fail("Existing-selection confirmation did not expose cached route execution in profile JSONL.", record)
			return false
		if String(movement_details.get("route_validation_mode", "")) != "cached_prevalidated":
			_fail("Existing-selection confirmation did not record cached_prevalidated route validation mode.", record)
			return false
		if String(movement_details.get("fallback_reason", "")) != "":
			_fail("Existing-selection confirmation unexpectedly recorded a fallback reason.", record)
			return false
		if String(movement_details.get("cached_execution_mode", "")) != "open_fast_path":
			_fail("Existing-selection confirmation did not expose open fast-path mode.", record)
			return false
		if not bool(movement_details.get("post_action_recap_skipped", false)):
			_fail("Existing-selection confirmation did not expose skipped post-action recap.", record)
			return false
		if not bool(movement_details.get("scenario_eval_skipped", false)):
			_fail("Existing-selection confirmation did not expose skipped scenario evaluation.", record)
			return false
		if String(movement_details.get("interaction_dispatch_mode", "")) != "none":
			_fail("Existing-selection confirmation unexpectedly dispatched an interaction.", record)
			return false
	if not (record.get("map_view_timings_ms", {}) is Dictionary) or not (record.get("top_offenders", []) is Array):
		_fail("Profile record did not include map-view timings or top offenders.", record)
		return false
	return true

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

func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
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
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _fail(message: String, payload: Variant = {}) -> void:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
