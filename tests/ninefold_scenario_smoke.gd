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
	if String(terrain_presentation.get("rendering_mode", "")) != "original_quiet_tile_bank" or bool(terrain_presentation.get("uses_sampled_texture", true)) or bool(terrain_presentation.get("generated_source_primary", true)) or not bool(terrain_presentation.get("uses_original_tile_bank", false)):
		_fail("Ninefold smoke: large-map starting terrain is not using the original quiet terrain tile bank: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("primary_base_model", "")) != "original_quiet_tile_bank" or String(terrain_presentation.get("terrain_noise_profile", "")) != "quiet_low_contrast_macro_readable":
		_fail("Ninefold smoke: large-map starting terrain does not expose the quiet macro-readable base model: %s." % town_presentation)
		return false
	if not bool(terrain_presentation.get("road_overlay", false)) or String(terrain_presentation.get("road_overlay_id", "")) != "road_dirt" or not bool(terrain_presentation.get("road_overlay_art", false)) or String(terrain_presentation.get("road_shape_model", "")) != "connection_piece_overlay":
		_fail("Ninefold smoke: large-map starting road is not represented as a structural art overlay: %s." % town_presentation)
		return false
	var town_readability: Dictionary = town_presentation.get("marker_readability", {})
	if not bool(town_readability.get("hero_emphasis", false)) or not bool(town_readability.get("selection_emphasis", false)):
		_fail("Ninefold smoke: active hero/current-selection emphasis is not readable on the large starting town tile: %s." % town_presentation)
		return false
	var town_art: Dictionary = town_presentation.get("art_presentation", {})
	var town_asset_ids: Array = town_art.get("sprite_asset_ids", [])
	if not bool(town_art.get("uses_asset_sprite", false)) or "frontier_town" not in town_asset_ids or bool(town_art.get("fallback_procedural_marker", true)):
		_fail("Ninefold smoke: large-map starting town is not using the default frontier town sprite: %s." % town_presentation)
		return false

	var resource_tile := Vector2i(23, 24)
	var resource_presentation: Dictionary = shell.call("validation_tile_presentation", resource_tile.x, resource_tile.y)
	if not _assert_marker_style(resource_presentation, "resource", false):
		return false
	var art_presentation: Dictionary = resource_presentation.get("art_presentation", {})
	if bool(art_presentation.get("uses_asset_sprite", true)) or not bool(art_presentation.get("fallback_procedural_marker", false)):
		_fail("Ninefold smoke: unmapped large-map resource site did not keep procedural marker fallback: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_silhouette_model", "")) != "family_specific_procedural_world_object":
		_fail("Ninefold smoke: unmapped large-map resource site did not report family-specific procedural world-object fallback: %s." % resource_presentation)
		return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	if expected_kind not in object_kinds:
		_fail("Ninefold smoke: expected %s marker kind was missing on the large map: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("ground_anchor", false)) or String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		_fail("Ninefold smoke: large-map %s marker lacks a terrain-grounded anchor: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object" or String(readability.get("occlusion_model", "")) != "foreground_ground_lip":
		_fail("Ninefold smoke: large-map %s marker no longer reports object-first footprint presence and foreground occlusion: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("terrain_quieting_bed", false)) or String(readability.get("placement_bed_model", "")) != "footprint_terrain_quieting_bed" or String(readability.get("placement_bed_shape", "")) != "organic_footprint_clearing":
		_fail("Ninefold smoke: large-map %s marker lacks the footprint-aware terrain quieting bed: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("placement_bed_ui_plate", true)) or not bool(readability.get("placement_bed_terrain_tinted", false)) or float(readability.get("placement_bed_alpha", 0.0)) < 0.28:
		_fail("Ninefold smoke: large-map %s placement bed regressed toward a generic UI plate or became too faint: %s." % [expected_kind, presentation])
		return false
	if not _assert_upper_mass_backdrop(readability, expected_kind):
		return false
	if not bool(readability.get("foreground_occlusion_lip", false)):
		_fail("Ninefold smoke: large-map %s marker lacks a foreground ground lip: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("depth_cue_model", "")) != "footprint_cast_shadow_with_base_occlusion":
		_fail("Ninefold smoke: large-map %s marker lacks the footprint cast-shadow/base-occlusion depth model: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("directional_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "directional_footprint_cast_shadow":
		_fail("Ninefold smoke: large-map %s marker lacks a directional terrain contact shadow: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("base_occlusion_pads", false)) or String(readability.get("base_occlusion_model", "")) != "foreground_base_occlusion_pads":
		_fail("Ninefold smoke: large-map %s marker lacks foreground base occlusion pads: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("contact_shadow_alpha", 0.0)) < 0.28 or float(readability.get("base_occlusion_alpha", 0.0)) < 0.30:
		_fail("Ninefold smoke: large-map %s marker contact-depth cues are too faint: %s." % [expected_kind, presentation])
		return false
	if int(readability.get("footprint_width_tiles", 0)) <= 0 or int(readability.get("footprint_height_tiles", 0)) <= 0:
		_fail("Ninefold smoke: large-map %s marker does not expose footprint dimensions: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < 0.60 or float(readability.get("footprint_anchor_height_fraction", 0.0)) < 0.20:
		_fail("Ninefold smoke: large-map %s footprint anchor is too small for object-first tactical framing: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("ui_badge_plate", true)):
		_fail("Ninefold smoke: large-map %s marker regressed to a UI badge plate: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		_fail("Ninefold smoke: large-map %s marker is too small for tactical framing: %s." % [expected_kind, presentation])
		return false
	if remembered:
		if not bool(readability.get("memory_echo", false)) or float(readability.get("remembered_marker_alpha", 0.0)) < 0.80:
			_fail("Ninefold smoke: remembered large-map %s marker is too faint: %s." % [expected_kind, presentation])
			return false
	else:
		if bool(readability.get("memory_echo", false)) or float(readability.get("anchor_alpha", 0.0)) < 0.30 or float(readability.get("outline_alpha", 0.0)) < 0.85 or float(readability.get("grid_alpha", 1.0)) > 0.42:
			_fail("Ninefold smoke: visible large-map %s marker grounding or map contrast regressed: %s." % [expected_kind, presentation])
			return false
	return true

func _assert_upper_mass_backdrop(readability: Dictionary, label: String) -> bool:
	if not bool(readability.get("upper_mass_backdrop", false)) or String(readability.get("upper_mass_backdrop_model", "")) != "family_scaled_rear_backdrop_wash":
		_fail("Ninefold smoke: large-map %s lacks the rear upper-mass backdrop cue: %s." % [label, readability])
		return false
	if String(readability.get("upper_mass_backdrop_shape", "")) != "family_scaled_rear_wash" or String(readability.get("upper_mass_backdrop_position", "")) != "behind_upper_body":
		_fail("Ninefold smoke: large-map %s rear backdrop is not reported as a family-scaled behind-body wash: %s." % [label, readability])
		return false
	if bool(readability.get("upper_mass_backdrop_ui_halo", true)) or bool(readability.get("upper_mass_backdrop_ui_badge", true)):
		_fail("Ninefold smoke: large-map %s rear backdrop regressed into a UI halo or badge: %s." % [label, readability])
		return false
	if float(readability.get("upper_mass_backdrop_alpha", 0.0)) < 0.20 or float(readability.get("upper_mass_backdrop_alpha", 1.0)) > 0.34:
		_fail("Ninefold smoke: large-map %s rear backdrop alpha is outside the subtle terrain-depth cue range: %s." % [label, readability])
		return false
	if float(readability.get("upper_mass_backdrop_height_fraction", 0.0)) < 0.32 or float(readability.get("upper_mass_backdrop_width_fraction", 0.0)) < 0.24:
		_fail("Ninefold smoke: large-map %s rear backdrop is too small to separate upper mass from terrain: %s." % [label, readability])
		return false
	if not bool(readability.get("vertical_mass_shadow", false)) or String(readability.get("vertical_mass_shadow_model", "")) != "subtle_vertical_mass_shadow" or float(readability.get("vertical_mass_shadow_alpha", 0.0)) < 0.14:
		_fail("Ninefold smoke: large-map %s lacks the subtle vertical mass shadow paired with the rear backdrop: %s." % [label, readability])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
