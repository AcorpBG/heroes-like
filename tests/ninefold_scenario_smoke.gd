extends Node

const SCENARIO_ID := "ninefold-confluence"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if scenario.is_empty():
		_fail("Ninefold smoke: scenario was not loaded by ContentService.")
		return

	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"hard",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)

	var map_size := OverworldRules.derive_map_size(session)
	if map_size != Vector2i(64, 64):
		_fail("Ninefold smoke: derived map size was %s, expected 64x64." % map_size)
		return
	if session.overworld.get("resource_nodes", []).size() < 47:
		_fail("Ninefold smoke: breadth resource-node placements did not seed into session state.")
		return
	if session.overworld.get("towns", []).size() < 6:
		_fail("Ninefold smoke: six-faction town placements did not seed into session state.")
		return
	if session.overworld.get("enemy_states", []).size() < 5:
		_fail("Ninefold smoke: hostile faction pressure states did not seed into session state.")
		return

	var basalt_profile := OverworldRules.terrain_profile_at(session, 60, 36)
	if String(basalt_profile.get("id", "")) != "biome_subterranean_underways":
		_fail("Ninefold smoke: Basalt Gatehouse did not land in the underway biome band.")
		return

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_snapshot"):
		_fail("Ninefold smoke: OverworldShell did not expose validation_snapshot.")
		return
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_size: Dictionary = snapshot.get("map_size", {})
	if int(snapshot_size.get("x", 0)) != 64 or int(snapshot_size.get("y", 0)) != 64:
		_fail("Ninefold smoke: OverworldShell snapshot did not retain the 64x64 map size.")
		return
	if String(snapshot.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Ninefold smoke: OverworldShell snapshot is not bound to Ninefold Confluence.")
		return
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	if viewport_metrics.is_empty():
		_fail("Ninefold smoke: OverworldShell snapshot did not expose map viewport metrics.")
		return
	if bool(viewport_metrics.get("full_map_visible", true)):
		_fail("Ninefold smoke: 64x64 overworld map is still fully visible instead of using tactical framing.")
		return
	if bool(viewport_metrics.get("fit_entire_map", true)):
		_fail("Ninefold smoke: 64x64 overworld map was treated as a fit-entire-map case.")
		return
	var visible_columns := float(viewport_metrics.get("visible_tile_columns", 0.0))
	var visible_rows := float(viewport_metrics.get("visible_tile_rows", 0.0))
	var visible_area := float(viewport_metrics.get("visible_tile_area", 0.0))
	if visible_columns <= 0.0 or visible_rows <= 0.0 or visible_area <= 0.0:
		_fail("Ninefold smoke: tactical viewport metrics were empty: %s." % viewport_metrics)
		return
	if visible_columns >= 32.0 or visible_rows >= 32.0 or visible_area > 220.0:
		_fail("Ninefold smoke: tactical viewport still shows too much of the 64x64 map: %s." % viewport_metrics)
		return
	var focus_tile: Dictionary = viewport_metrics.get("camera_focus_tile", {})
	if int(focus_tile.get("x", -1)) != 23 or int(focus_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: tactical viewport is not centered on Mira's starting hero tile: %s." % viewport_metrics)
		return
	if not _assert_large_map_marker_readability(shell):
		return
	if not shell.has_method("validation_pan_map") or not shell.has_method("validation_focus_map_on_hero"):
		_fail("Ninefold smoke: OverworldShell did not expose large-map pan validation hooks.")
		return
	var pan_result: Dictionary = shell.call("validation_pan_map", 6, 0)
	if not bool(pan_result.get("ok", false)):
		_fail("Ninefold smoke: 64x64 overworld map did not pan when requested: %s." % pan_result)
		return
	var panned_metrics: Dictionary = pan_result.get("after", {})
	var panned_focus: Dictionary = panned_metrics.get("camera_focus_tile", {})
	if not bool(panned_metrics.get("manual_camera", false)) or int(panned_focus.get("x", 0)) <= int(focus_tile.get("x", 0)):
		_fail("Ninefold smoke: map pan did not move the manual camera east: %s." % pan_result)
		return
	var panned_bounds: Dictionary = panned_metrics.get("visible_bounds", {})
	var original_bounds: Dictionary = viewport_metrics.get("visible_bounds", {})
	if int(panned_bounds.get("x", 0)) <= int(original_bounds.get("x", 0)):
		_fail("Ninefold smoke: visible tile bounds did not scroll east after panning: %s." % pan_result)
		return
	var focus_result: Dictionary = shell.call("validation_focus_map_on_hero")
	var refocused_metrics: Dictionary = focus_result.get("after", {})
	if bool(refocused_metrics.get("manual_camera", true)):
		_fail("Ninefold smoke: Home/focus validation did not return camera control to the active hero: %s." % focus_result)
		return

	var progress_result: Dictionary = shell.call("validation_try_progress_action")
	if not bool(progress_result.get("ok", false)):
		_fail("Ninefold smoke: OverworldShell could not advance one safe step on the 64x64 scenario.")
		return

	get_tree().quit(0)

func _assert_large_map_marker_readability(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		_fail("Ninefold smoke: OverworldShell did not expose tile marker presentation validation.")
		return false
	var town_tile := Vector2i(23, 26)
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not _assert_marker_style(town_presentation, "town", false):
		return false
	var terrain_presentation: Dictionary = town_presentation.get("terrain_presentation", {})
	if not bool(terrain_presentation.get("texture_loaded", false)) or String(terrain_presentation.get("rendering_mode", "")) != "texture_sampled_tile":
		_fail("Ninefold smoke: large-map starting terrain is not using prepared overworld texture art: %s." % town_presentation)
		return false
	var town_readability: Dictionary = town_presentation.get("marker_readability", {})
	if not bool(town_readability.get("hero_emphasis", false)) or not bool(town_readability.get("selection_emphasis", false)):
		_fail("Ninefold smoke: active hero/current-selection emphasis is not readable on the large starting town tile: %s." % town_presentation)
		return false

	var resource_tile := Vector2i(23, 24)
	var resource_presentation: Dictionary = shell.call("validation_tile_presentation", resource_tile.x, resource_tile.y)
	if not _assert_marker_style(resource_presentation, "resource", false):
		return false
	var art_presentation: Dictionary = resource_presentation.get("art_presentation", {})
	if bool(art_presentation.get("uses_asset_sprite", true)) or not bool(art_presentation.get("fallback_procedural_marker", false)):
		_fail("Ninefold smoke: unmapped large-map resource site did not keep procedural marker fallback: %s." % resource_presentation)
		return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	if expected_kind not in object_kinds:
		_fail("Ninefold smoke: expected %s marker kind was missing on the large map: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("contrast_plate", false)):
		_fail("Ninefold smoke: large-map %s marker lacks a terrain contrast plate: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		_fail("Ninefold smoke: large-map %s marker is too small for tactical framing: %s." % [expected_kind, presentation])
		return false
	if remembered:
		if not bool(readability.get("memory_echo", false)) or float(readability.get("remembered_marker_alpha", 0.0)) < 0.80:
			_fail("Ninefold smoke: remembered large-map %s marker is too faint: %s." % [expected_kind, presentation])
			return false
	else:
		if bool(readability.get("memory_echo", false)) or float(readability.get("plate_alpha", 0.0)) < 0.50 or float(readability.get("outline_alpha", 0.0)) < 0.85:
			_fail("Ninefold smoke: visible large-map %s marker contrast is too weak: %s." % [expected_kind, presentation])
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
