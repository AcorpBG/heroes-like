extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_LIVE_OVERWORLD_RENDER_MOVE_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "live-render-move-10184"
const MIN_IDLE_FPS := 9.0
const MOVE_LATENCY_BUDGET_MS := 2500
const POST_MOVE_FRAME_BUDGET_MS := 140.0

var _active_size_class_id := SIZE_CLASS_ID
var _active_seed := EXPLICIT_SEED
var _expected_map_size := Vector2i(36, 36)

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")

func _run() -> void:
	_active_size_class_id = OS.get_environment("RANDOM_MAP_LIVE_SIZE_CLASS").strip_edges()
	if _active_size_class_id == "":
		_active_size_class_id = SIZE_CLASS_ID
	_active_seed = OS.get_environment("RANDOM_MAP_LIVE_SEED").strip_edges()
	if _active_seed == "":
		_active_seed = EXPLICIT_SEED
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_menu_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	shell.call("validation_set_generated_seed", _active_seed)
	shell.call("validation_select_generated_size_class", _active_size_class_id)
	shell.call("validation_select_generated_water_mode", "land")
	shell.call("validation_set_generated_underground", false)
	await get_tree().process_frame

	var launch: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(launch.get("started", false)):
		_fail("Generated map launch did not start: %s" % JSON.stringify(launch))
		return
	var setup: Dictionary = launch.get("setup", {}) if launch.get("setup", {}) is Dictionary else {}
	_expected_map_size = OverworldRules.derive_map_size(SessionState.active_session)
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_live_render_move",
		{
			"scenario_id": String(launch.get("active_scenario_id", "")),
			"size_class_id": _active_size_class_id,
			"seed": _active_seed,
		}
	)
	var prepare_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not bool(prepare_result.get("ok", false)):
		_fail("Generated overworld handoff did not prepare: %s" % JSON.stringify(prepare_result))
		return
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1":
		_reveal_all_for_visual_capture(SessionState.active_session)

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
	var map_visual_before := _map_visual_summary(overworld)
	if not _assert_generated_visual_summary(map_visual_before, "before_move"):
		return
	var terrain_transition_before := _terrain_transition_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_terrain_transition_summary(terrain_transition_before, "before_move"):
		return
	var generated_presentation_authority_before := _generated_presentation_authority(SessionState.active_session)
	if not await _capture_if_requested("before_move"):
		return
	var idle_before := await _sample_fps(18)
	var move_start := Time.get_ticks_usec()
	var move_result: Dictionary = overworld.validation_try_progress_action()
	var move_latency_ms := float(Time.get_ticks_usec() - move_start) / 1000.0
	await get_tree().process_frame
	var post_move_frame_ms := await _single_frame_ms()
	var after_snapshot: Dictionary = overworld.validation_snapshot()
	var map_visual_after := _map_visual_summary(overworld)
	if not _assert_generated_visual_summary(map_visual_after, "after_move"):
		return
	var terrain_transition_after := _terrain_transition_summary(overworld)
	if OS.get_environment("RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL") == "1" and not _assert_terrain_transition_summary(terrain_transition_after, "after_move"):
		return
	if terrain_transition_after != terrain_transition_before:
		_fail("Generated terrain transition draw authority changed across movement/redraw.")
		return
	if map_visual_after.get("body_entries", []) != map_visual_before.get("body_entries", []):
		_fail("Generated blocker composition changed across movement/redraw.")
		return
	if _generated_presentation_authority(SessionState.active_session) != generated_presentation_authority_before:
		_fail("Generated object/body/map authority changed during presentation and movement validation.")
		return
	if not await _capture_if_requested("after_move"):
		return
	var idle_after := await _sample_fps(18)

	if not _assert_move_result(move_result, before_snapshot, after_snapshot, move_latency_ms, post_move_frame_ms, idle_before, idle_after):
		return
	var save_reload_source_authority := _generated_save_reload_authority(SessionState.active_session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(SessionState.active_session, 3)
	if not bool(save_result.get("ok", false)):
		_fail("Generated presentation authority did not save through the public manual path: %s" % JSON.stringify(save_result))
		return
	var restored_session = SaveService.restore_manual_session(3)
	if restored_session == null:
		_fail("Generated presentation authority did not restore through the public manual path.")
		return
	var save_reload_restored_authority := _generated_save_reload_authority(restored_session)
	if not _save_authority_values_equal(save_reload_restored_authority, save_reload_source_authority):
		_fail("Generated object/body/package authority changed across save and restore.")
		return
	var rebuilt_map_view = load("res://scenes/overworld/OverworldMapView.gd").new()
	add_child(rebuilt_map_view)
	rebuilt_map_view.set_map_state(
		restored_session,
		restored_session.overworld.get("map", []),
		OverworldRules.derive_map_size(restored_session),
		OverworldRules.hero_position(restored_session)
	)
	await get_tree().process_frame
	var rebuilt_visual_summary: Dictionary = rebuilt_map_view.validation_generated_object_visual_summary()
	if not _assert_generated_visual_summary(rebuilt_visual_summary, "save_restore_rebuild"):
		return
	if rebuilt_visual_summary.get("body_entries", []) != map_visual_before.get("body_entries", []):
		_fail("Generated blocker composition changed after a real save/restore session rebuild.")
		return
	rebuilt_map_view.queue_free()

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"seed": _active_seed,
		"size_class_id": _active_size_class_id,
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
		"generated_visual_before": _compact_generated_visual_summary(map_visual_before),
		"generated_visual_after": _compact_generated_visual_summary(map_visual_after),
		"terrain_transition": terrain_transition_after,
		"save_reload_authority_exact": true,
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
	if int(map_size.get("width", 0)) != _expected_map_size.x or int(map_size.get("height", 0)) != _expected_map_size.y:
		_fail("%s snapshot did not preserve generated %dx%d size: %s" % [label, _expected_map_size.x, _expected_map_size.y, JSON.stringify(map_size)])
		return false
	if String(snapshot.get("scenario_status", "")) != "in_progress" or String(snapshot.get("game_state", "")) != "overworld":
		_fail("%s snapshot is not a live overworld: %s" % [label, JSON.stringify(_compact_snapshot(snapshot))])
		return false
	return true

func _map_visual_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_generated_object_visual_summary"):
		return {}
	return map_view.call("validation_generated_object_visual_summary")

func _terrain_transition_summary(overworld: Node) -> Dictionary:
	var map_view := overworld.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_tile_presentation"):
		return {}
	var relationship_tile_count := 0
	var generic_overlay_tile_count := 0
	var self_contained_tile_count := 0
	var inactive_homm3_overlay_tile_count := 0
	var policy_ids: Dictionary = {}
	var session = SessionState.active_session
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_explored(session, x, y):
				continue
			var presentation: Dictionary = map_view.call("validation_tile_presentation", Vector2i(x, y))
			var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
			if int(terrain.get("generic_transition_overlay_relationship_count", 0)) <= 0:
				continue
			relationship_tile_count += 1
			var policy := String(terrain.get("transition_draw_policy", ""))
			if policy != "":
				policy_ids[policy] = true
			if bool(terrain.get("homm3_transition_self_contained", false)):
				self_contained_tile_count += 1
			elif bool(terrain.get("generic_transition_overlay_active", false)):
				generic_overlay_tile_count += 1
				if not bool(terrain.get("uses_homm3_local_prototype", false)):
					inactive_homm3_overlay_tile_count += 1
	return {
		"relationship_tile_count": relationship_tile_count,
		"generic_overlay_tile_count": generic_overlay_tile_count,
		"self_contained_tile_count": self_contained_tile_count,
		"inactive_homm3_overlay_tile_count": inactive_homm3_overlay_tile_count,
		"draw_policy_ids": policy_ids.keys(),
	}

func _assert_terrain_transition_summary(summary: Dictionary, label: String) -> bool:
	var relationship_count := int(summary.get("relationship_tile_count", 0))
	if (
		relationship_count <= 0
		or int(summary.get("generic_overlay_tile_count", 0)) != relationship_count
		or int(summary.get("inactive_homm3_overlay_tile_count", 0)) != relationship_count
		or int(summary.get("self_contained_tile_count", -1)) != 0
		or summary.get("draw_policy_ids", []) != ["active_homm3_self_contained_else_generic_overlay"]
	):
		_fail("%s generated terrain transitions did not use the disabled-HoMM3 generic overlay path: %s" % [label, JSON.stringify(summary)])
		return false
	return true

func _assert_generated_visual_summary(summary: Dictionary, label: String) -> bool:
	if summary.is_empty():
		_fail("%s generated visual summary is unavailable." % label)
		return false
	if String(summary.get("presentation_model", "")) != "exact_body_cell_biome_palette_clustered_original_sprite":
		_fail("%s generated body presentation model is not exact: %s" % [label, JSON.stringify(summary)])
		return false
	var is_default_fixture := _active_size_class_id == SIZE_CLASS_ID and _active_seed == EXPLICIT_SEED
	if is_default_fixture and int(summary.get("generated_record_count", 0)) != 175:
		_fail("%s generated decorative record count changed: %s" % [label, summary.get("generated_record_count", -1)])
		return false
	if is_default_fixture and (int(summary.get("expected_body_tile_count", 0)) != 464 or int(summary.get("indexed_body_tile_count", 0)) != 464):
		_fail("%s exact generated body coverage changed: expected=%s indexed=%s" % [label, summary.get("expected_body_tile_count", -1), summary.get("indexed_body_tile_count", -1)])
		return false
	if int(summary.get("generated_record_count", 0)) <= 0 or int(summary.get("expected_body_tile_count", 0)) <= 0:
		_fail("%s generated fixture has no decorative body authority: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not bool(summary.get("body_tile_keys_exact", false)) or not bool(summary.get("all_body_assets_loaded", false)) or not bool(summary.get("all_body_assets_terrain_matched", false)):
		_fail("%s generated body presentation is incomplete: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not is_equal_approx(float(summary.get("body_sprite_extent_tiles", 0.0)), 0.46):
		_fail("%s generated body sprite extent changed: %s" % [label, summary.get("body_sprite_extent_tiles", -1.0)])
		return false
	if int(summary.get("composition_key_count", 0)) != int(summary.get("indexed_body_tile_count", -1)):
		_fail("%s generated body composition keys are incomplete: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not bool(summary.get("all_transformed_bounds_within_tile", false)):
		_fail("%s generated body composition escaped its owning tiles: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if int(summary.get("distinct_body_asset_count", 0)) < 8 or int(summary.get("repeated_def_multi_asset_count", 0)) <= 0:
		_fail("%s generated body palette did not break repeated-definition stamping: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if (
		float(summary.get("scale_factor_min", 1.0)) >= 0.95
		or float(summary.get("scale_factor_max", 1.0)) <= 1.01
		or float(summary.get("offset_x_min", 0.0)) >= -0.02
		or float(summary.get("offset_x_max", 0.0)) <= 0.02
	):
		_fail("%s generated body composition does not exercise its bounded visual range: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if String(summary.get("composition_signature", "")).length() != 64:
		_fail("%s generated body composition signature is missing: %s" % [label, JSON.stringify(_compact_generated_visual_summary(summary))])
		return false
	if not is_equal_approx(float(summary.get("multi_tile_interactive_cap_tiles", 0.0)), 0.54):
		_fail("%s multi-tile visual cap changed: %s" % [label, summary.get("multi_tile_interactive_cap_tiles", -1.0)])
		return false
	var corrected_multi_tile_count := 0
	var one_tile_control_count := 0
	for entry_value in summary.get("resource_entries", []):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var metrics: Dictionary = entry.get("visual_metrics", {}) if entry.get("visual_metrics", {}) is Dictionary else {}
		var footprint: Dictionary = metrics.get("footprint", {}) if metrics.get("footprint", {}) is Dictionary else {}
		var multi_tile := int(footprint.get("width", 1)) > 1 or int(footprint.get("height", 1)) > 1
		if multi_tile:
			if not bool(metrics.get("uses_multi_tile_visual_cap", false)):
				_fail("%s multi-tile resource did not use the visual cap: %s" % [label, JSON.stringify(entry)])
				return false
			if float(metrics.get("sprite_extent_tiles", 99.0)) > 1.0001:
				_fail("%s multi-tile resource exceeded the visual cap: %s" % [label, JSON.stringify(entry)])
				return false
			if float(metrics.get("uncapped_sprite_extent_px", 0.0)) > float(metrics.get("sprite_extent_px", 0.0)) + 0.01:
				corrected_multi_tile_count += 1
		else:
			if bool(metrics.get("uses_multi_tile_visual_cap", true)) or not is_equal_approx(float(metrics.get("uncapped_sprite_extent_px", 0.0)), float(metrics.get("sprite_extent_px", -1.0))):
				_fail("%s one-tile resource presentation changed: %s" % [label, JSON.stringify(entry)])
				return false
			one_tile_control_count += 1
	if corrected_multi_tile_count <= 0 or one_tile_control_count <= 0:
		_fail("%s visual scale fixture lacks corrected multi-tile or unchanged one-tile controls: corrected=%d one_tile=%d" % [label, corrected_multi_tile_count, one_tile_control_count])
		return false
	return true

func _generated_presentation_authority(session) -> Dictionary:
	if session == null:
		return {}
	return {
		"map": session.overworld.get("map", []).duplicate(true),
		"map_objects": session.overworld.get("map_objects", []).duplicate(true),
		"resource_nodes": session.overworld.get("resource_nodes", []).duplicate(true),
		"towns": session.overworld.get("towns", []).duplicate(true),
		"encounters": session.overworld.get("encounters", []).duplicate(true),
	}

func _generated_save_reload_authority(session) -> Dictionary:
	if session == null:
		return {}
	var payload: Dictionary = SessionStateStoreScript.normalize_payload(session.to_dict())
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	return {
		"scenario_id": String(payload.get("scenario_id", "")),
		"launch_mode": String(payload.get("launch_mode", "")),
		"generated_random_map_provenance": flags.get("generated_random_map_provenance", {}).duplicate(true),
		"generated_random_map_replay_metadata": flags.get("generated_random_map_replay_metadata", {}).duplicate(true),
		"map": overworld.get("map", []).duplicate(true),
		"map_objects": overworld.get("map_objects", []).duplicate(true),
		"resource_nodes": overworld.get("resource_nodes", []).duplicate(true),
		"towns": overworld.get("towns", []).duplicate(true),
		"encounters": overworld.get("encounters", []).duplicate(true),
	}

func _save_authority_values_equal(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(float(left), float(right))
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _save_authority_values_equal(left.get(key), right.get(key)):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _save_authority_values_equal(left[index], right[index]):
				return false
		return true
	return left == right

func _compact_generated_visual_summary(summary: Dictionary) -> Dictionary:
	return {
		"presentation_model": String(summary.get("presentation_model", "")),
		"generated_record_count": int(summary.get("generated_record_count", 0)),
		"expected_body_tile_count": int(summary.get("expected_body_tile_count", 0)),
		"indexed_body_tile_count": int(summary.get("indexed_body_tile_count", 0)),
		"body_tile_keys_exact": bool(summary.get("body_tile_keys_exact", false)),
		"all_body_assets_loaded": bool(summary.get("all_body_assets_loaded", false)),
		"all_body_assets_terrain_matched": bool(summary.get("all_body_assets_terrain_matched", false)),
		"collision_tile_count": int(summary.get("collision_tile_count", 0)),
		"body_sprite_extent_tiles": float(summary.get("body_sprite_extent_tiles", 0.0)),
		"distinct_body_asset_count": int(summary.get("distinct_body_asset_count", 0)),
		"repeated_def_multi_asset_count": int(summary.get("repeated_def_multi_asset_count", 0)),
		"composition_key_count": int(summary.get("composition_key_count", 0)),
		"all_transformed_bounds_within_tile": bool(summary.get("all_transformed_bounds_within_tile", false)),
		"scale_factor_min": float(summary.get("scale_factor_min", 0.0)),
		"scale_factor_max": float(summary.get("scale_factor_max", 0.0)),
		"offset_x_min": float(summary.get("offset_x_min", 0.0)),
		"offset_x_max": float(summary.get("offset_x_max", 0.0)),
		"offset_y_min": float(summary.get("offset_y_min", 0.0)),
		"offset_y_max": float(summary.get("offset_y_max", 0.0)),
		"composition_signature": String(summary.get("composition_signature", "")),
		"multi_tile_interactive_cap_tiles": float(summary.get("multi_tile_interactive_cap_tiles", 0.0)),
		"capped_resource_count": int(summary.get("capped_resource_count", 0)),
		"max_capped_resource_extent_tiles": float(summary.get("max_capped_resource_extent_tiles", 0.0)),
	}

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

func _capture_if_requested(label: String) -> bool:
	var output_dir := OS.get_environment("RANDOM_MAP_LIVE_VISUAL_CAPTURE_DIR").strip_edges()
	if output_dir == "":
		return true
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		_fail("Could not create generated-map visual capture directory %s." % absolute_dir)
		return false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Generated-map visual capture %s returned no viewport image." % label)
		return false
	var result := image.save_png(absolute_dir.path_join("generated_%s.png" % label))
	if result != OK:
		_fail("Could not save generated-map visual capture %s: %s." % [label, result])
		return false
	return true

func _reveal_all_for_visual_capture(session) -> void:
	if session == null:
		return
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
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
		"map_cue_text": String(snapshot.get("map_cue_text", "")),
	}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
