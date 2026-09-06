extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "LARGE_GENERATED_MAP_RUNTIME_PROFILE_REPORT"
const SEED := "large-runtime-profile-10225"
const SIZE_CLASS_ID := "homm3_large"
const FACTION_ID := "faction_veilmourn"
const HERO_ID := "hero_veilmourn_orso_nightchart"
const PROFILE_ENV := "HEROES_PROFILE_LOG"
# Player/team and native transit sidecars change the package fingerprint, not
# the source map identity. The retained 2,961 source objects/terrain are checked
# by tools/rmg_native_transit_validation.py --portal-case large_profile.
const EXPECTED_MATERIALIZED_SIGNATURE := "79238f15"
const EXPECTED_NATIVE_MAP_HASH := "fnv1a32:c2520619"
const COMMAND_LIMIT_MS := 5000.0
const END_TURN_LIMIT_MS := 15000.0
var _previous_profile_env := ""

func _profile_identity_error(session, materialized_signature: String) -> String:
	if materialized_signature != EXPECTED_MATERIALIZED_SIGNATURE:
		return "deterministic materialized signature changed: %s" % materialized_signature
	var provenance: Dictionary = session.flags.get("generated_random_map_provenance", {})
	var native_hash := String(provenance.get("map_ref", {}).get("map_hash", ""))
	if native_hash != EXPECTED_NATIVE_MAP_HASH:
		return "native map/player identity changed: %s" % native_hash
	return ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_previous_profile_env = OS.get_environment(PROFILE_ENV)
	OS.set_environment(PROFILE_ENV, "1")
	OS.set_environment("AURELION_RMG_PROFILE_PHASES", "1")
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	SaveService.validation_clear_general_profile_log()
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	if OS.get_environment("HEROES_PROFILE_RESTORE_END_TURN_ONLY") == "1":
		await _run_restored_end_turn_profile()
		return
	var timings := {}

	var started := Time.get_ticks_usec()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED,
		"translated_rmg_template_042_v1",
		"translated_rmg_profile_042_v1",
		4,
		"land",
		false,
		SIZE_CLASS_ID,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		FACTION_ID,
		HERO_ID
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	timings["build_setup_ms"] = _elapsed_ms(started)
	print("%s_STAGE setup %s" % [REPORT_ID, JSON.stringify({
		"ok": setup.get("ok", false),
		"ms": timings["build_setup_ms"],
		"performance_profile": setup.get("performance_profile", {}),
	})])
	if not bool(setup.get("ok", false)):
		return _fail("Generated Large setup failed: %s" % JSON.stringify(setup))
	if OS.get_environment("HEROES_PROFILE_GENERATION_ONLY") == "1":
		_cleanup()
		get_tree().quit(0)
		return

	started = Time.get_ticks_usec()
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	timings["start_session_ms"] = _elapsed_ms(started)
	if session == null:
		return _fail("Generated Large session could not start.")
	print("%s_STAGE session %s" % [REPORT_ID, JSON.stringify({"ms": timings["start_session_ms"]})])

	started = Time.get_ticks_usec()
	OverworldRules.normalize_overworld_state_for_runtime(session)
	timings["normalize_runtime_ms"] = _elapsed_ms(started)
	print("%s_STAGE normalize %s" % [REPORT_ID, JSON.stringify({"ms": timings["normalize_runtime_ms"]})])

	started = Time.get_ticks_usec()
	session = SessionState.set_active_session(session)
	timings["set_active_session_ms"] = _elapsed_ms(started)
	AppRouter.begin_overworld_handoff_profile("large_runtime_profile_10225", {
		"seed": SEED,
		"size_class_id": SIZE_CLASS_ID,
	})

	started = Time.get_ticks_usec()
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	timings["instantiate_shell_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	add_child(shell)
	timings["add_shell_ready_ms"] = _elapsed_ms(started)
	print("%s_STAGE shell_ready %s" % [REPORT_ID, JSON.stringify({"instantiate_ms": timings["instantiate_shell_ms"], "add_ready_ms": timings["add_shell_ready_ms"]})])

	started = Time.get_ticks_usec()
	for _frame in range(4):
		await get_tree().process_frame
	timings["first_four_frames_ms"] = _elapsed_ms(started)
	var handoff := AppRouter.validation_latest_overworld_handoff_profile()
	print("%s_STAGE first_frames %s" % [REPORT_ID, JSON.stringify({"ms": timings["first_four_frames_ms"], "handoff": handoff})])

	if not shell.has_method("validation_profile_snapshot"):
		return _fail("Overworld profiling hooks are unavailable.")
	shell.validation_set_overworld_profile_log_enabled(true, true)
	shell.validation_set_end_turn_resolution_routing_enabled(false)
	var hero_tile := OverworldRules.hero_position(session)
	var target_tile := _distant_target(session, hero_tile)
	var commands := {}
	commands["select_target_cold"] = await _profile_route_refresh(shell, target_tile)
	commands["select_target_warm"] = await _profile_route_refresh(shell, target_tile)
	commands["hover_target"] = await _profile_hover(shell, target_tile)
	commands["move_adjacent"] = await _profile_adjacent_move(shell, session)
	commands["town_entry_exit"] = await _profile_town_entry_exit(session)
	commands["explicit_save"] = _profile_explicit_save(session)
	commands["end_turn"] = await _profile_end_turn(shell, session)
	var save_round_trip := _validate_generated_save_round_trip(session)
	commands["named_file_save"] = _profile_named_file_save(session)

	var size := OverworldRules.derive_map_size(session)
	var provenance: Dictionary = session.flags.get("generated_random_map_provenance", {}) if session.flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var materialization: Dictionary = session.flags.get("generated_random_map_materialization", {}) if session.flags.get("generated_random_map_materialization", {}) is Dictionary else {}
	var materialized_signature := String(materialization.get("materialized_map_signature", setup.get("generated_identity", {}).get("materialized_map_signature", "")))
	var counts := {
		"towns": _array_size(session.overworld.get("towns", [])),
		"resource_nodes": _array_size(session.overworld.get("resource_nodes", [])),
		"artifact_nodes": _array_size(session.overworld.get("artifact_nodes", [])),
		"artifacts": _array_size(session.overworld.get("artifacts", [])),
		"encounters": _array_size(session.overworld.get("encounters", [])),
		"map_objects": _array_size(session.overworld.get("map_objects", [])),
		"decorative_objects": _array_size(session.overworld.get("decorative_objects", [])),
	}
	var report := {
		"ok": true,
		"seed": SEED,
		"size_class_id": SIZE_CLASS_ID,
		"faction_id": FACTION_ID,
		"hero_id": HERO_ID,
		"scenario_id": session.scenario_id,
		"map_size": {"width": size.x, "height": size.y},
		"normalized_seed": String(provenance.get("normalized_seed", setup.get("normalized_seed", ""))),
		"materialized_signature": materialized_signature,
		"counts": counts,
		"timings_ms": timings,
		"handoff": handoff,
		"commands": commands,
		"save_round_trip": save_round_trip,
		"general_profile_records": SaveService.validation_general_profile_log_last_records(30),
	}
	var command_summary := {}
	for command_id_value in commands.keys():
		var command_id := String(command_id_value)
		var command: Dictionary = commands[command_id] if commands[command_id] is Dictionary else {}
		command_summary[command_id] = {"ok": command.get("ok", false), "wall_ms": command.get("wall_ms", 0.0)}
		if command_id == "end_turn":
			command_summary[command_id]["general"] = command.get("general", {})
			command_summary[command_id]["request_ms"] = command.get("request_ms", 0.0)
			command_summary[command_id]["confirm_ms"] = command.get("confirm_ms", 0.0)
	print("%s_STAGE commands %s" % [REPORT_ID, JSON.stringify(command_summary)])
	var failures := []
	var identity_error := _profile_identity_error(session, materialized_signature)
	if identity_error != "":
		failures.append(identity_error)
	for command_id_value in commands.keys():
		var command_id := String(command_id_value)
		var command: Dictionary = commands[command_id] if commands[command_id] is Dictionary else {}
		if not bool(command.get("ok", false)):
			failures.append("%s did not complete: %s" % [command_id, JSON.stringify(command)])
		var command_limit := END_TURN_LIMIT_MS if command_id == "end_turn" else COMMAND_LIMIT_MS
		if float(command.get("wall_ms", command_limit + 1.0)) >= command_limit:
			failures.append("%s exceeded %.0f ms: %.3f" % [command_id, command_limit, float(command.get("wall_ms", 0.0))])
	if not bool(save_round_trip.get("ok", false)):
		failures.append("generated save round trip was not exact: %s" % JSON.stringify(save_round_trip))
	report["failures"] = failures
	report["ok"] = failures.is_empty()
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	shell.queue_free()
	_cleanup()
	get_tree().quit(0 if failures.is_empty() else 1)


func _run_restored_end_turn_profile() -> void:
	var restore_started := Time.get_ticks_usec()
	var session = SaveService.restore_autosave_session()
	if session == null:
		return _fail("Large autosave could not be restored for focused end-turn profiling.")
	session = SessionState.set_active_session(session)
	session.game_state = "overworld"
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	shell.validation_set_end_turn_resolution_routing_enabled(false)
	var command := await _profile_end_turn(shell, session)
	print("%s_STAGE restored_end_turn %s" % [REPORT_ID, JSON.stringify({
		"restore_and_ready_ms": _elapsed_ms(restore_started) - float(command.get("wall_ms", 0.0)),
		"ok": command.get("ok", false),
		"wall_ms": command.get("wall_ms", 0.0),
		"request_ms": command.get("request_ms", 0.0),
		"confirm_ms": command.get("confirm_ms", 0.0),
		"general": command.get("general", {}),
		"enemy_turn_profile": command.get("enemy_turn_profile", {}),
	})])
	shell.queue_free()
	_cleanup()
	get_tree().quit(0 if bool(command.get("ok", false)) else 1)


func _profile_route_refresh(shell: Node, tile: Vector2i) -> Dictionary:
	shell.validation_reset_profile()
	var started := Time.get_ticks_usec()
	shell.call("_set_selected_tile", tile)
	shell.call("_refresh_selected_route_preview", "large_runtime_profile_selection")
	var wall_ms := _elapsed_ms(started)
	await get_tree().process_frame
	return {
		"ok": true,
		"tile": {"x": tile.x, "y": tile.y},
		"wall_ms": wall_ms,
		"profile": shell.validation_profile_snapshot(),
		"command_log": shell.validation_overworld_profile_log_last_records(1),
	}


func _profile_hover(shell: Node, tile: Vector2i) -> Dictionary:
	shell.validation_reset_profile(true)
	var started := Time.get_ticks_usec()
	shell.call("_on_map_tile_hovered", tile)
	var wall_ms := _elapsed_ms(started)
	await get_tree().process_frame
	return {
		"ok": true,
		"tile": {"x": tile.x, "y": tile.y},
		"wall_ms": wall_ms,
		"profile": shell.validation_profile_snapshot(),
	}


func _profile_adjacent_move(shell: Node, session) -> Dictionary:
	var origin := OverworldRules.hero_position(session)
	for direction_value in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var direction: Vector2i = direction_value
		var target := origin + direction
		if OverworldRules.tile_is_blocked(session, target.x, target.y):
			continue
		shell.validation_reset_profile()
		var started := Time.get_ticks_usec()
		shell.call("_on_map_tile_pressed", target)
		var wall_ms := _elapsed_ms(started)
		await get_tree().process_frame
		return {
			"ok": OverworldRules.hero_position(session) == target,
			"from": {"x": origin.x, "y": origin.y},
			"to": {"x": target.x, "y": target.y},
			"wall_ms": wall_ms,
			"profile": shell.validation_profile_snapshot(),
		}
	return {"ok": false, "wall_ms": 0.0, "reason": "no_adjacent_passable_tile"}


func _profile_town_entry_exit(session) -> Dictionary:
	var placement_id := ""
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("owner", "neutral")) == "player":
			placement_id = String(town_value.get("placement_id", ""))
			break
	if placement_id == "":
		return {"ok": false, "wall_ms": 0.0, "reason": "owned_town_missing"}
	var started := Time.get_ticks_usec()
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit.get("ok", false)):
		return {"ok": false, "wall_ms": _elapsed_ms(started), "reason": "town_visit_failed", "visit": visit}
	var town_shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(town_shell)
	await get_tree().process_frame
	var cache_snapshot: Dictionary = town_shell.validation_town_entity_cache_snapshot()
	var cache_result: Dictionary = cache_snapshot.get("last_cache_result", {}) if cache_snapshot.get("last_cache_result", {}) is Dictionary else {}
	print("%s_STAGE town_cache %s" % [REPORT_ID, JSON.stringify({
		"hit": cache_result.get("hit", false),
		"build_ms": cache_result.get("build_ms", 0.0),
		"build_buckets_ms": cache_result.get("build_buckets_ms", {}),
	})])
	var handoff: Dictionary = town_shell.validation_prepare_town_return_handoff()
	town_shell.queue_free()
	await get_tree().process_frame
	OverworldRules.clear_active_town_visit(session)
	session.game_state = "overworld"
	return {
		"ok": not handoff.is_empty(),
		"wall_ms": _elapsed_ms(started),
		"placement_id": placement_id,
		"return_handoff": handoff,
		"cache": cache_result,
	}


func _profile_explicit_save(session) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Dictionary = SaveService.save_runtime_autosave_session(session, false)
	return {
		"ok": bool(result.get("ok", false)),
		"wall_ms": _elapsed_ms(started),
		"bytes": int(result.get("bytes", 0)),
		"profile": SaveService.validation_last_runtime_save_profile(),
	}


func _profile_named_file_save(session) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Dictionary = SaveService.save_runtime_file_session(session, "Large named profile")
	var elapsed := _elapsed_ms(started)
	var profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var restored := _validate_generated_save_round_trip(session, result.get("summary", {})) if bool(result.get("ok", false)) else {"ok": false}
	return {"ok": bool(result.get("ok", false)) and bool(restored.get("ok", false)), "wall_ms": elapsed, "restore": restored, "profile": profile}


func _validate_generated_save_round_trip(session, named_summary: Dictionary = {}) -> Dictionary:
	var expected := {
		"scenario_id": session.scenario_id,
		"hero_id": session.hero_id,
		"day": session.day,
		"map_size": OverworldRules.derive_map_size(session),
		"town_count": _array_size(session.overworld.get("towns", [])),
		"resource_count": _array_size(session.overworld.get("resource_nodes", [])),
		"encounter_count": _array_size(session.overworld.get("encounters", [])),
		"source_object_count": (session.overworld.get("package_source_objects_by_id", {}) as Dictionary).size() \
			if session.overworld.get("package_source_objects_by_id", {}) is Dictionary else 0,
	}
	ContentService.clear_generated_scenario_drafts()
	var started := Time.get_ticks_usec()
	var restored = SaveService.restore_autosave_session() if named_summary.is_empty() else SaveService.restore_session_from_summary(named_summary)
	var elapsed := _elapsed_ms(started)
	if restored == null:
		return {"ok": false, "wall_ms": elapsed, "reason": "restore_failed"}
	var restored_size := OverworldRules.derive_map_size(restored)
	var restored_source_objects = restored.overworld.get("package_source_objects_by_id", {})
	var flags_record_present: bool = restored.flags.has("native_random_map_runtime_scenario_record")
	var overworld_record_present: bool = restored.overworld.has("native_random_map_runtime_scenario_record")
	var exact: bool = (
		restored.scenario_id == expected["scenario_id"]
		and restored.hero_id == expected["hero_id"]
		and restored.day == expected["day"]
		and restored_size == expected["map_size"]
		and _array_size(restored.overworld.get("towns", [])) == expected["town_count"]
		and _array_size(restored.overworld.get("resource_nodes", [])) == expected["resource_count"]
		and _array_size(restored.overworld.get("encounters", [])) == expected["encounter_count"]
		and (restored_source_objects as Dictionary).size() == expected["source_object_count"]
		and restored_source_objects == session.overworld.get("package_source_objects_by_id", {})
		and flags_record_present
		and overworld_record_present
	)
	return {
		"ok": exact,
		"wall_ms": elapsed,
		"scenario_id": restored.scenario_id,
		"day": restored.day,
		"map_size": {"width": restored_size.x, "height": restored_size.y},
		"runtime_scenario_records_preserved": flags_record_present and overworld_record_present,
		"source_object_count": (restored_source_objects as Dictionary).size(),
	}


func _profile_end_turn(shell: Node, session) -> Dictionary:
	var day_before: int = session.day
	var started := Time.get_ticks_usec()
	var request: Dictionary = shell.call("_request_end_turn", false)
	var request_ms := _elapsed_ms(started)
	var result := request
	var confirm_ms := 0.0
	if bool(request.get("confirmation_required", false)):
		var confirm_started := Time.get_ticks_usec()
		result = shell.call("_on_end_turn_confirmation_confirmed")
		confirm_ms = _elapsed_ms(confirm_started)
	var wall_ms := _elapsed_ms(started)
	await get_tree().process_frame
	var general := {}
	for record_value in SaveService.validation_general_profile_log_last_records(12):
		if record_value is Dictionary and String(record_value.get("event", "")) == "end_turn":
			general = {
				"total_ms": record_value.get("total_ms", 0.0),
				"buckets_ms": record_value.get("buckets_ms", {}),
			}
	var rule_result: Dictionary = result.get("result", {}) if result.get("result", {}) is Dictionary else {}
	return {
		"ok": bool(result.get("ok", false)) and session.day > day_before,
		"wall_ms": wall_ms,
		"request_ms": request_ms,
		"confirm_ms": confirm_ms,
		"day_before": day_before,
		"day_after": session.day,
		"result": result,
		"general": general,
		"enemy_turn_profile": rule_result.get("enemy_turn_profile", {}),
		"profile": shell.validation_profile_snapshot(),
	}


func _distant_target(session, origin: Vector2i) -> Vector2i:
	var size := OverworldRules.derive_map_size(session)
	for offset_value in [Vector2i(6, 0), Vector2i(0, 6), Vector2i(-6, 0), Vector2i(0, -6)]:
		var offset: Vector2i = offset_value
		var tile: Vector2i = origin + offset
		if tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
			return tile
	return origin


func _array_size(value: Variant) -> int:
	return (value as Array).size() if value is Array else 0


func _elapsed_ms(started_usec: int) -> float:
	return snapped(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.001)


func _cleanup() -> void:
	if _previous_profile_env == "":
		OS.unset_environment(PROFILE_ENV)
	else:
		OS.set_environment(PROFILE_ENV, _previous_profile_env)
	SessionState.reset_session()
	ContentService.clear_generated_scenario_drafts()
	OS.unset_environment("AURELION_RMG_PROFILE_PHASES")
	OS.unset_environment("HEROES_STRATEGIC_AI_PROFILE")


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
