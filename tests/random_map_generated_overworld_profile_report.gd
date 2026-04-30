extends Node

const REPORT_ID := "RANDOM_MAP_GENERATED_OVERWORLD_PROFILE_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "generated-overworld-profile-10184"

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_menu_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	shell.call("validation_set_generated_seed", EXPLICIT_SEED)
	shell.call("validation_select_generated_size_class", SIZE_CLASS_ID)
	shell.call("validation_select_generated_water_mode", "land")
	shell.call("validation_set_generated_underground", false)
	await get_tree().process_frame

	var launch: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(launch.get("started", false)):
		_fail("Generated Small launch did not start: %s" % JSON.stringify(launch))
		return
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_profile",
		{
			"scenario_id": String(launch.get("active_scenario_id", "")),
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
	for _i in range(90):
		if not bool(handoff_profile.get("active", false)):
			break
		await get_tree().process_frame
		handoff_profile = AppRouter.validation_latest_overworld_handoff_profile()
	if bool(handoff_profile.get("active", false)):
		_fail("Generated overworld handoff profile did not finish: %s" % JSON.stringify(handoff_profile))
		return
	if not overworld.has_method("validation_snapshot"):
		_fail("OverworldShell validation hooks are unavailable.")
		return

	var snapshot: Dictionary = overworld.validation_snapshot()
	if not _assert_generated_small_snapshot(snapshot):
		return
	var hero_pos: Dictionary = snapshot.get("hero_position", {}) if snapshot.get("hero_position", {}) is Dictionary else {}
	var hero_x := int(hero_pos.get("x", 0))
	var hero_y := int(hero_pos.get("y", 0))

	var baseline := await _profile_refresh(overworld, hero_x, hero_y, true)
	var optimized := await _profile_refresh(overworld, hero_x, hero_y, false)
	var baseline_hover := await _profile_hover(overworld, hero_x, hero_y, true)
	var optimized_hover := await _profile_hover(overworld, hero_x, hero_y, false)
	var end_turn := await _profile_end_turn(overworld)

	if not _assert_profile(baseline, optimized, baseline_hover, optimized_hover, end_turn):
		return

	var setup: Dictionary = launch.get("setup", {}) if launch.get("setup", {}) is Dictionary else {}
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": EXPLICIT_SEED,
		"effective_seed": String(setup.get("normalized_seed", "")),
		"seed_source": String(setup.get("seed_source", "")),
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"handoff_total_ms": int(handoff_profile.get("total_ms", -1)),
		"root_cause": "generated hover rebuilt command/frontier drawer handoff summaries; refresh also rebuilt generated road/object indexes despite unchanged map content",
		"baseline_forced_uncached_refresh": _compact_profile(baseline),
		"optimized_cached_refresh": _compact_profile(optimized),
		"baseline_hover_with_drawer_summary_rebuild": _compact_profile(baseline_hover),
		"optimized_hover_tooltip_only": _compact_profile(optimized_hover),
		"end_turn_save_profile": _compact_profile(end_turn),
		"map_viewport": snapshot.get("map_viewport", {}),
	})])
	get_tree().quit(0)

func _profile_refresh(overworld: Node, x: int, y: int, force_index_rebuild: bool) -> Dictionary:
	overworld.call("validation_set_force_map_index_rebuild", force_index_rebuild)
	overworld.call("validation_reset_profile")
	var started := Time.get_ticks_usec()
	var result: Dictionary = overworld.validation_select_tile(x, y)
	await get_tree().process_frame
	await get_tree().process_frame
	var elapsed_usec := Time.get_ticks_usec() - started
	var profile: Dictionary = overworld.validation_profile_snapshot()
	profile["wall_usec"] = elapsed_usec
	profile["result_ok"] = bool(result.get("ok", false))
	profile["force_index_rebuild"] = force_index_rebuild
	return profile

func _profile_hover(overworld: Node, x: int, y: int, force_drawer_sync: bool) -> Dictionary:
	overworld.call("validation_set_force_map_index_rebuild", false)
	overworld.call("validation_set_force_hover_drawer_sync", force_drawer_sync)
	overworld.call("validation_reset_profile", true)
	var hover_x := clampi(x + 1, 0, 35)
	var hover_y := y
	var started := Time.get_ticks_usec()
	var result: Dictionary = overworld.validation_hover_tile(hover_x, hover_y)
	await get_tree().process_frame
	var elapsed_usec := Time.get_ticks_usec() - started
	overworld.call("validation_set_force_hover_drawer_sync", false)
	var profile: Dictionary = overworld.validation_profile_snapshot()
	profile["wall_usec"] = elapsed_usec
	profile["result_ok"] = bool(result.get("ok", false))
	profile["hover_tile"] = {"x": hover_x, "y": hover_y}
	profile["force_drawer_sync"] = force_drawer_sync
	return profile

func _profile_end_turn(overworld: Node) -> Dictionary:
	overworld.call("validation_set_force_map_index_rebuild", false)
	overworld.call("validation_reset_profile")
	var started := Time.get_ticks_usec()
	var result: Dictionary = overworld.validation_end_turn()
	await get_tree().process_frame
	await get_tree().process_frame
	var elapsed_usec := Time.get_ticks_usec() - started
	var profile: Dictionary = overworld.validation_profile_snapshot()
	profile["wall_usec"] = elapsed_usec
	profile["result_ok"] = bool(result.get("ok", false))
	return profile

func _assert_profile(
	baseline: Dictionary,
	optimized: Dictionary,
	baseline_hover: Dictionary,
	optimized_hover: Dictionary,
	end_turn: Dictionary
) -> bool:
	if not bool(baseline.get("result_ok", false)) or not bool(optimized.get("result_ok", false)):
		_fail("Refresh profiling did not complete: before=%s after=%s" % [JSON.stringify(baseline), JSON.stringify(optimized)])
		return false
	var baseline_map: Dictionary = baseline.get("map_view", {}) if baseline.get("map_view", {}) is Dictionary else {}
	var optimized_map: Dictionary = optimized.get("map_view", {}) if optimized.get("map_view", {}) is Dictionary else {}
	if int(baseline_map.get("object_index_rebuilds", 0)) <= 0 or int(baseline_map.get("road_index_rebuilds", 0)) <= 0:
		_fail("Baseline profile did not force generated index rebuilds: %s" % JSON.stringify(_compact_profile(baseline)))
		return false
	if int(optimized_map.get("object_index_skips", 0)) <= 0 or int(optimized_map.get("road_index_skips", 0)) <= 0:
		_fail("Optimized profile did not reuse generated indexes: %s" % JSON.stringify(_compact_profile(optimized)))
		return false
	if int(optimized_map.get("draw_session_static_calls", 0)) > 1:
		_fail("Optimized refresh redrew static layer more than once: %s" % JSON.stringify(_compact_profile(optimized)))
		return false
	if not bool(baseline_hover.get("result_ok", false)) or not bool(optimized_hover.get("result_ok", false)):
		_fail("Hover profiling did not complete: before=%s after=%s" % [
			JSON.stringify(_compact_profile(baseline_hover)),
			JSON.stringify(_compact_profile(optimized_hover)),
		])
		return false
	if int(optimized_hover.get("hover_calls", 0)) <= 0:
		_fail("Optimized hover profiling did not record hover work: %s" % JSON.stringify(_compact_profile(optimized_hover)))
		return false
	if float(optimized_hover.get("hover_usec", 0)) >= float(baseline_hover.get("hover_usec", 0)):
		_fail("Optimized hover did not improve over forced drawer-summary baseline: before=%s after=%s" % [
			JSON.stringify(_compact_profile(baseline_hover)),
			JSON.stringify(_compact_profile(optimized_hover)),
		])
		return false
	if not bool(end_turn.get("result_ok", false)):
		_fail("End-turn profiling did not complete: %s" % JSON.stringify(_compact_profile(end_turn)))
		return false
	return true

func _compact_profile(profile: Dictionary) -> Dictionary:
	var map_profile: Dictionary = profile.get("map_view", {}) if profile.get("map_view", {}) is Dictionary else {}
	var save_profile: Dictionary = profile.get("last_save_profile", {}) if profile.get("last_save_profile", {}) is Dictionary else {}
	return {
		"wall_ms": _usec_to_ms(float(profile.get("wall_usec", 0))),
		"refresh_ms": _usec_to_ms(float(profile.get("refresh_usec", 0))),
		"refresh_calls": int(profile.get("refresh_calls", 0)),
		"hover_ms": _usec_to_ms(float(profile.get("hover_usec", 0))),
		"hover_calls": int(profile.get("hover_calls", 0)),
		"tooltip_ms": _usec_to_ms(float(profile.get("map_tooltip_usec", 0))),
		"set_map_state_ms": _usec_to_ms(float(map_profile.get("set_map_state_usec", 0))),
		"object_index_ms": _usec_to_ms(float(map_profile.get("object_index_usec", 0))),
		"object_index_rebuilds": int(map_profile.get("object_index_rebuilds", 0)),
		"object_index_skips": int(map_profile.get("object_index_skips", 0)),
		"hero_index_rebuilds": int(map_profile.get("hero_index_rebuilds", 0)),
		"hero_index_skips": int(map_profile.get("hero_index_skips", 0)),
		"road_index_ms": _usec_to_ms(float(map_profile.get("road_index_usec", 0))),
		"road_index_rebuilds": int(map_profile.get("road_index_rebuilds", 0)),
		"road_index_skips": int(map_profile.get("road_index_skips", 0)),
		"path_ms": _usec_to_ms(float(map_profile.get("path_recompute_usec", 0))),
		"terrain_tile_draws": int(map_profile.get("terrain_tile_draws", 0)),
		"road_tile_draws": int(map_profile.get("road_tile_draws", 0)),
		"hidden_tile_checks": int(map_profile.get("hidden_tile_checks", 0)),
		"object_presentation_checks": int(map_profile.get("object_presentation_checks", 0)),
		"save_total_ms": int(save_profile.get("total_ms", 0)),
		"save_written_bytes": int(save_profile.get("written_bytes", 0)),
		"save_steps": save_profile.get("steps", []),
	}

func _usec_to_ms(value: float) -> float:
	return snapped(value / 1000.0, 0.001)

func _assert_generated_small_snapshot(snapshot: Dictionary) -> bool:
	if not bool(snapshot.get("generated_random_map", false)):
		_fail("Snapshot is not generated: %s" % JSON.stringify(snapshot))
		return false
	var map_size: Dictionary = snapshot.get("map_size", {}) if snapshot.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 36 or int(map_size.get("height", 0)) != 36:
		_fail("Snapshot did not preserve Small 36x36 size: %s" % JSON.stringify(map_size))
		return false
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	if String(viewport.get("visual_render_path", "")) != "normal_overworld_art" or bool(viewport.get("primitive_generated_render_path", true)):
		_fail("Generated profile must use normal overworld art path: %s" % JSON.stringify(viewport))
		return false
	return true

func _assert_menu_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_open_skirmish_stage",
		"validation_set_generated_seed",
		"validation_select_generated_size_class",
		"validation_select_generated_water_mode",
		"validation_set_generated_underground",
		"validation_start_generated_skirmish_staged",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing generated route validation hook %s." % method_name)
			return false
	return true

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
