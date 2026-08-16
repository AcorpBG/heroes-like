extends Node

const SCENARIO_ID := "ninefold-confluence"
const TERRAIN_SEQUENCE := ["sand", "grass", "dirt", "grass"]
const PAINT_TILE := Vector2i(50, 50)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: Dictionary = shell.call("validation_load_legacy_authored_scenario_for_dev", SCENARIO_ID)
	if not bool(loaded.get("ok", false)):
		_fail("Could not load the authored Map Editor performance fixture.")
		return

	var session = shell.get("_session")
	var map_size := OverworldRules.derive_map_size(session)
	if map_size != Vector2i(64, 64):
		_fail("Map Editor performance fixture did not retain its authored 64x64 map.")
		return
	var terrain_grammar := ContentService.get_terrain_grammar()
	var nonmap_authority_before := _session_nonmap_authority(session)
	var eager_usec := []
	var live_mutation_usec := []
	var live_refresh_usec := []
	var final_eager_result := {}
	shell.set("_tool", "terrain")

	for terrain_id_value in TERRAIN_SEQUENCE:
		var terrain_id := String(terrain_id_value)
		if not bool(shell.call("_select_terrain_by_id", terrain_id)):
			_fail("Could not select the focused terrain brush.")
			return
		shell.set("_selected_tile", PAINT_TILE)
		var live_map: Array = session.overworld.get("map", [])
		var eager_map: Array = live_map.duplicate(true)
		var eager_started := Time.get_ticks_usec()
		var eager_result: Dictionary = TerrainPlacementRules.apply_paint(
			eager_map,
			map_size,
			terrain_id,
			[PAINT_TILE],
			terrain_grammar,
			true
		)
		eager_usec.append(Time.get_ticks_usec() - eager_started)
		if not bool(eager_result.get("ok", false)) or not bool(eager_result.get("changed", false)):
			_fail("Eager terrain placement control did not change the expected tile.")
			return

		var live_started := Time.get_ticks_usec()
		var live_ok: bool = bool(shell.call("_paint_terrain", PAINT_TILE, terrain_id))
		live_mutation_usec.append(Time.get_ticks_usec() - live_started)
		var live_result: Dictionary = shell.get("_last_terrain_placement_result")
		if not live_ok or not bool(live_result.get("ok", false)) or not bool(live_result.get("changed", false)):
			_fail("Live terrain placement did not change the expected tile.")
			return
		if not bool(live_result.get("final_normalization_deferred", false)) or not Dictionary(live_result.get("final_normalization", {})).is_empty():
			_fail("Live terrain placement eagerly materialized validation-only final normalization.")
			return
		var eager_without_normalization := eager_result.duplicate(true)
		eager_without_normalization["final_normalization"] = {}
		eager_without_normalization["final_normalization_deferred"] = true
		if live_result != eager_without_normalization:
			_fail("Live terrain result diverged from the eager control outside final-normalization materialization.")
			return
		if session.overworld.get("map", []) != eager_map:
			_fail("Live terrain map writes diverged from the eager HoMM3 owner-queue control.")
			return
		var refresh_started := Time.get_ticks_usec()
		shell.call("_refresh_state")
		live_refresh_usec.append(Time.get_ticks_usec() - refresh_started)
		final_eager_result = eager_result

	var live_total := _integer_sum(live_mutation_usec)
	var eager_total := _integer_sum(eager_usec)
	if eager_total <= 0 or live_total * 4 >= eager_total:
		_fail("Live terrain mutation did not remove at least 75 percent of the eager normalization lane: live=%s eager=%s." % [live_mutation_usec, eager_usec])
		return
	if _session_nonmap_authority(session) != nonmap_authority_before:
		_fail("Terrain paint changed non-map session authority.")
		return

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var validation_result: Dictionary = snapshot.get("terrain_placement", {})
	if bool(validation_result.get("final_normalization_deferred", true)):
		_fail("Validation snapshot did not materialize final normalization.")
		return
	if validation_result != final_eager_result:
		_fail("On-demand validation result did not exactly match the eager placement control.")
		return
	var final_normalization: Dictionary = validation_result.get("final_normalization", {})
	if (
		String(final_normalization.get("model", "")) != TerrainPlacementRules.FINAL_NORMALIZATION_MODEL
		or int(final_normalization.get("visited_count", 0)) != map_size.x * map_size.y
		or int(final_normalization.get("missing_bucket_count", -1)) != 0
		or String(final_normalization.get("owner_map_source", "")) != "settled_after_4bc5f0_queue_drain"
	):
		_fail("Materialized final-normalization authority was incomplete: %s." % final_normalization)
		return
	if not bool(snapshot.get("dirty", false)) or snapshot.get("selected_tile", {}) != {"x": PAINT_TILE.x, "y": PAINT_TILE.y}:
		_fail("Live terrain paint did not preserve dirty/selection UI authority.")
		return
	var tile_inspection: Dictionary = snapshot.get("tile_inspection", {})
	if String(tile_inspection.get("terrain_id", "")) != String(TERRAIN_SEQUENCE[-1]):
		_fail("Live preview inspection did not expose the final painted terrain.")
		return

	var performance_shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	performance_shell.set("validation_skip_initial_package_index", true)
	add_child(performance_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var performance_loaded: Dictionary = performance_shell.call("validation_load_legacy_authored_scenario_for_dev", SCENARIO_ID)
	if not bool(performance_loaded.get("ok", false)):
		_fail("Could not load the independent live-click performance fixture.")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	performance_shell.set("_tool", "terrain")
	var live_click_usec := []
	for terrain_id_value in TERRAIN_SEQUENCE:
		var terrain_id := String(terrain_id_value)
		if not bool(performance_shell.call("_select_terrain_by_id", terrain_id)):
			_fail("Could not select the live-click performance terrain brush.")
			return
		var click_started := Time.get_ticks_usec()
		performance_shell.call("_on_map_tile_pressed", PAINT_TILE)
		live_click_usec.append(Time.get_ticks_usec() - click_started)
		var click_result: Dictionary = performance_shell.get("_last_terrain_placement_result")
		if not bool(click_result.get("changed", false)) or not bool(click_result.get("final_normalization_deferred", false)):
			_fail("Public live-click path did not change terrain with deferred normalization.")
			return
	if _integer_sum(live_click_usec) * 2 >= eager_total:
		_fail("Full live-click path did not remove at least half of the eager normalization lane: live=%s eager=%s." % [live_click_usec, eager_usec])
		return
	var performance_map_view = performance_shell.get("_map_view")
	var action_metrics: Dictionary = performance_map_view.call("validation_view_metrics")
	var action_route_profile: Dictionary = action_metrics.get("render_cache", {}).get("profile", {}).get("last_path_recompute", {})
	if not Dictionary(action_metrics.get("route_preview", {})).is_empty() or String(action_route_profile.get("status", "")) != "disabled_for_editor_action_tool":
		_fail("Terrain tool retained an irrelevant gameplay route preview.")
		return
	performance_shell.set("_tool", "inspect")
	performance_shell.set("_selected_tile", Vector2i(24, 27))
	performance_shell.call("_refresh_state")
	var inspect_metrics: Dictionary = performance_map_view.call("validation_view_metrics")
	var inspect_route_profile: Dictionary = inspect_metrics.get("render_cache", {}).get("profile", {}).get("last_path_recompute", {})
	if Dictionary(inspect_metrics.get("route_preview", {})).is_empty() or String(inspect_route_profile.get("status", "")) == "disabled_for_editor_action_tool":
		_fail("Inspect tool did not retain the shared gameplay route preview.")
		return

	print("MAP_EDITOR_TERRAIN_PAINT_PERFORMANCE_REPORT %s" % JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"map_size": {"x": map_size.x, "y": map_size.y},
		"paint_count": TERRAIN_SEQUENCE.size(),
		"eager_usec": eager_usec,
		"live_mutation_usec": live_mutation_usec,
		"live_refresh_usec": live_refresh_usec,
		"live_click_usec": live_click_usec,
		"live_to_eager_ratio": float(live_total) / float(eager_total),
		"map_parity": true,
		"result_parity": true,
		"validation_materialized_exact": true,
		"action_route_projection_disabled": true,
		"inspect_route_preview_preserved": true,
		"nonmap_authority_exact": true,
	}))
	shell.queue_free()
	performance_shell.queue_free()
	get_tree().quit(0)

func _session_nonmap_authority(session) -> Dictionary:
	var payload: Dictionary = session.to_dict()
	var overworld: Dictionary = payload.get("overworld", {}).duplicate(true)
	overworld.erase("map")
	payload["overworld"] = overworld
	return payload

func _integer_sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
