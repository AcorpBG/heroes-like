extends Node

const REPORT_ID := "RANDOM_MAP_LIVE_OVERWORLD_RENDER_MOVE_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "live-render-move-10184"
const MIN_IDLE_FPS := 9.0
const MOVE_LATENCY_BUDGET_MS := 2500
const POST_MOVE_FRAME_BUDGET_MS := 140.0

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
	var setup: Dictionary = launch.get("setup", {}) if launch.get("setup", {}) is Dictionary else {}
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_live_render_move",
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
	var profile: Dictionary = AppRouter.validation_latest_overworld_handoff_profile()
	for _i in range(90):
		if not bool(profile.get("active", false)):
			break
		await get_tree().process_frame
		profile = AppRouter.validation_latest_overworld_handoff_profile()
	if bool(profile.get("active", false)):
		_fail("Generated overworld handoff profile did not finish: %s" % JSON.stringify(profile))
		return
	if overworld == null or not overworld.has_method("validation_snapshot"):
		_fail("Generated route did not instantiate OverworldShell validation hooks.")
		return

	var before_snapshot: Dictionary = overworld.validation_snapshot()
	if not _assert_generated_small_snapshot(before_snapshot, "before_move"):
		return
	var idle_before := await _sample_fps(18)
	var move_start := Time.get_ticks_usec()
	var move_result: Dictionary = overworld.validation_try_progress_action()
	var move_latency_ms := float(Time.get_ticks_usec() - move_start) / 1000.0
	await get_tree().process_frame
	var post_move_frame_ms := await _single_frame_ms()
	var after_snapshot: Dictionary = overworld.validation_snapshot()
	var idle_after := await _sample_fps(18)

	if not _assert_move_result(move_result, before_snapshot, after_snapshot, move_latency_ms, post_move_frame_ms, idle_before, idle_after):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": EXPLICIT_SEED,
		"effective_seed": String(setup.get("normalized_seed", "")),
		"seed_source": String(setup.get("seed_source", "")),
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"handoff_profile_total_ms": int(profile.get("total_ms", -1)),
		"idle_fps_before_move": idle_before,
		"idle_fps_after_move": idle_after,
		"move_latency_ms": move_latency_ms,
		"post_move_frame_ms": post_move_frame_ms,
		"move_result": move_result,
		"before": _compact_snapshot(before_snapshot),
		"after": _compact_snapshot(after_snapshot),
		"map_viewport": after_snapshot.get("map_viewport", {}),
	})])
	get_tree().quit(0)

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

func _assert_generated_small_snapshot(snapshot: Dictionary, label: String) -> bool:
	if not bool(snapshot.get("generated_random_map", false)):
		_fail("%s snapshot is not generated: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	var map_size: Dictionary = snapshot.get("map_size", {}) if snapshot.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 36 or int(map_size.get("height", 0)) != 36:
		_fail("%s snapshot did not preserve Small 36x36 size: %s" % [label, JSON.stringify(map_size)])
		return false
	if String(snapshot.get("scenario_status", "")) != "in_progress" or String(snapshot.get("game_state", "")) != "overworld":
		_fail("%s snapshot is not a live overworld: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	return true

func _assert_move_result(
	move_result: Dictionary,
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	move_latency_ms: float,
	post_move_frame_ms: float,
	idle_before: Dictionary,
	idle_after: Dictionary
) -> bool:
	if not _assert_generated_small_snapshot(after_snapshot, "after_move"):
		return false
	if not bool(move_result.get("ok", false)):
		_fail("Generated Small movement did not commit: %s" % JSON.stringify(move_result))
		return false
	var before_pos: Dictionary = before_snapshot.get("hero_position", {})
	var after_pos: Dictionary = after_snapshot.get("hero_position", {})
	if int(before_pos.get("x", -1)) == int(after_pos.get("x", -1)) and int(before_pos.get("y", -1)) == int(after_pos.get("y", -1)):
		_fail("Generated Small movement did not change hero position: before=%s after=%s result=%s" % [
			JSON.stringify(before_pos),
			JSON.stringify(after_pos),
			JSON.stringify(move_result),
		])
		return false
	if String(after_snapshot.get("scenario_status", "")) != "in_progress":
		_fail("Generated Small movement routed to outcome/status %s." % String(after_snapshot.get("scenario_status", "")))
		return false
	if move_latency_ms > MOVE_LATENCY_BUDGET_MS:
		_fail("Generated Small movement latency exceeded budget: %.2fms result=%s" % [move_latency_ms, JSON.stringify(move_result)])
		return false
	if post_move_frame_ms > POST_MOVE_FRAME_BUDGET_MS:
		_fail("Generated Small post-move frame exceeded budget: %.2fms" % post_move_frame_ms)
		return false
	if float(idle_before.get("fps_wall", 0.0)) < MIN_IDLE_FPS or float(idle_after.get("fps_wall", 0.0)) < MIN_IDLE_FPS:
		_fail("Generated Small live FPS below budget: before=%s after=%s" % [JSON.stringify(idle_before), JSON.stringify(idle_after)])
		return false
	return true

func _sample_fps(frames: int) -> Dictionary:
	var start := Time.get_ticks_usec()
	for _i in range(frames):
		await get_tree().process_frame
	var elapsed_us := maxi(1, Time.get_ticks_usec() - start)
	return {
		"frames": frames,
		"elapsed_ms": float(elapsed_us) / 1000.0,
		"fps_wall": float(frames) * 1000000.0 / float(elapsed_us),
		"engine_fps": Engine.get_frames_per_second(),
	}

func _single_frame_ms() -> float:
	var start := Time.get_ticks_usec()
	await get_tree().process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0

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
		"map_cue_text": String(snapshot.get("map_cue_text", "")),
	}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
