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
	if not _assert_town_footprint_profile(shell, town_presentation):
		return false
	var terrain_presentation: Dictionary = town_presentation.get("terrain_presentation", {})
	if String(terrain_presentation.get("rendering_mode", "")) != "original_quiet_tile_bank" or bool(terrain_presentation.get("uses_sampled_texture", true)) or bool(terrain_presentation.get("generated_source_primary", true)) or not bool(terrain_presentation.get("uses_original_tile_bank", false)):
		_fail("Ninefold smoke: large-map starting terrain is not using the original quiet terrain tile bank: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("primary_base_model", "")) != "original_quiet_tile_bank" or String(terrain_presentation.get("terrain_noise_profile", "")) != "quiet_low_contrast_macro_readable":
		_fail("Ninefold smoke: large-map starting terrain does not expose the quiet macro-readable base model: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("terrain_variant_selection", "")) != "patch_cohesive_low_frequency" or String(terrain_presentation.get("grasslands_base_cohesion", "")) != "grass_plains_shared_palette":
		_fail("Ninefold smoke: large-map starting grasslands terrain does not expose the cohesive low-frequency variant contract: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(terrain_presentation.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(terrain_presentation.get("explored_intertile_seams", true)):
		_fail("Ninefold smoke: large-map visible terrain still reports per-cell black grid seams: %s." % town_presentation)
		return false
	if not bool(terrain_presentation.get("road_overlay", false)) or String(terrain_presentation.get("road_overlay_id", "")) != "road_dirt" or not bool(terrain_presentation.get("road_overlay_art", false)) or String(terrain_presentation.get("road_shape_model", "")) != "connection_piece_overlay":
		_fail("Ninefold smoke: large-map starting road is not represented as a structural art overlay: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(terrain_presentation.get("road_joint_cap", false)):
		_fail("Ninefold smoke: large-map starting road intersection does not expose the connection-aware joint cap contract: %s." % town_presentation)
		return false
	var town_readability: Dictionary = town_presentation.get("marker_readability", {})
	if not bool(town_readability.get("hero_emphasis", false)) or not bool(town_readability.get("selection_emphasis", false)):
		_fail("Ninefold smoke: active hero/current-selection emphasis is not readable on the large starting town tile: %s." % town_presentation)
		return false
	if not _assert_hero_presence_correction(town_readability, town_presentation):
		return false
	var town_art: Dictionary = town_presentation.get("art_presentation", {})
	var town_asset_ids: Array = town_art.get("sprite_asset_ids", [])
	if not bool(town_art.get("uses_asset_sprite", false)) or "frontier_town" not in town_asset_ids or bool(town_art.get("fallback_procedural_marker", true)):
		_fail("Ninefold smoke: large-map starting town is not using the default frontier town sprite: %s." % town_presentation)
		return false
	if String(town_art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or bool(town_art.get("town_base_ellipse", true)) or bool(town_art.get("town_cast_shadow", true)):
		_fail("Ninefold smoke: large-map starting town sprite did not use the corrected no-ellipse/no-cast-shadow grounding: %s." % town_presentation)
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
	var is_town := expected_kind == "town"
	if expected_kind not in object_kinds:
		_fail("Ninefold smoke: expected %s marker kind was missing on the large map: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("ground_anchor", false)):
		_fail("Ninefold smoke: large-map %s marker lacks terrain-grounded placement metadata: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object":
		_fail("Ninefold smoke: large-map %s marker no longer reports object-first footprint presence: %s." % [expected_kind, presentation])
		return false
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else "foreground_ground_lip"
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		_fail("Ninefold smoke: large-map %s marker no longer reports the expected foreground contact model: %s." % [expected_kind, presentation])
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		_fail("Ninefold smoke: large-map %s marker lacks a terrain-grounded anchor: %s." % [expected_kind, presentation])
		return false
	else:
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
	if expected_kind == "town":
		if int(readability.get("footprint_width_tiles", 0)) != 3 or int(readability.get("footprint_height_tiles", 0)) != 2:
			_fail("Ninefold smoke: large-map town marker must present as a 3x2 footprint: %s." % presentation)
			return false
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		if not bool(town_presentation.get("has_town_footprint", false)) or String(town_presentation.get("presentation_model", "")) != "town_3x2_footprint_bottom_middle_entry":
			_fail("Ninefold smoke: large-map town metadata does not expose the 3x2 presentation model: %s." % presentation)
			return false
		if String(town_presentation.get("entry_role", "")) != "bottom_middle_visit_approach" or not bool(town_presentation.get("entry_is_visit_tile", false)):
			_fail("Ninefold smoke: large-map town does not expose the bottom-middle visit approach tile: %s." % presentation)
			return false
		if not bool(town_presentation.get("is_entry_tile", false)) or String(town_presentation.get("tile_role", "")) != "bottom_middle_visit_approach":
			_fail("Ninefold smoke: large-map starting town tile is not reported as the entry approach: %s." % presentation)
			return false
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or not bool(town_presentation.get("entry_apron_cue", false)) or not bool(town_presentation.get("gate_cue", false)):
			_fail("Ninefold smoke: large-map town lacks blocked non-entry metadata or entry apron/gate cues: %s." % presentation)
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
		if is_town:
			if bool(readability.get("memory_echo", false)) or String(readability.get("town_remembered_treatment", "")) != "ghosted_sprite_without_echo_plate":
				_fail("Ninefold smoke: remembered large-map town should use ghosted sprite treatment without the removed echo plate: %s." % presentation)
				return false
		elif not bool(readability.get("memory_echo", false)) or float(readability.get("remembered_marker_alpha", 0.0)) < 0.80:
			_fail("Ninefold smoke: remembered large-map %s marker is too faint: %s." % [expected_kind, presentation])
			return false
	else:
		var visible_grid_suppressed := String(readability.get("visible_terrain_grid_mode", "")) == "fog_boundary_only" and float(readability.get("grid_alpha", 1.0)) <= 0.08 and not bool(readability.get("explored_intertile_seams", true))
		if bool(readability.get("memory_echo", false)) or (not is_town and (float(readability.get("anchor_alpha", 0.0)) < 0.30 or float(readability.get("outline_alpha", 0.0)) < 0.85 or not visible_grid_suppressed)):
			_fail("Ninefold smoke: visible large-map %s marker grounding or map contrast regressed: %s." % [expected_kind, presentation])
			return false
	return true

func _assert_town_grounding_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "town_contact_cues_no_base_ellipse":
		_fail("Ninefold smoke: large-map town still reports a base ellipse anchor: %s." % presentation)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports a filled terrain underlay/quieting bed: %s." % presentation)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: large-map town still reports upper-mass shadow/backdrop treatment: %s." % presentation)
		return false
	if String(readability.get("depth_cue_model", "")) != "town_contact_line_without_cast_shadow" or bool(readability.get("directional_contact_shadow", true)) or float(readability.get("contact_shadow_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports directional cast-shadow depth cues: %s." % presentation)
		return false
	if bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports foreground base occlusion pads: %s." % presentation)
		return false
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "sparse_wall_and_entry_cues_no_underlay":
		_fail("Ninefold smoke: large-map town grounding metadata does not describe the no-ellipse presentation: %s." % presentation)
		return false
	if bool(readability.get("town_base_ellipse", true)) or bool(readability.get("town_underlay", true)) or bool(readability.get("town_cast_shadow", true)) or not bool(readability.get("town_contact_cue", false)):
		_fail("Ninefold smoke: large-map town grounding flags did not remove base ellipse/underlay/cast shadow while preserving contact cues: %s." % presentation)
		return false
	var town_presentation: Dictionary = presentation.get("town_presentation", {})
	if bool(town_presentation.get("base_ellipse", true)) or bool(town_presentation.get("filled_underlay", true)) or bool(town_presentation.get("cast_shadow", true)):
		_fail("Ninefold smoke: large-map town presentation payload still exposes the removed ellipse/underlay/shadow treatment: %s." % presentation)
		return false
	if String(town_presentation.get("footprint_cue_model", "")) != "sparse_wall_and_entry_cues_no_underlay":
		_fail("Ninefold smoke: large-map town footprint cue metadata does not describe sparse non-entry/approach cues: %s." % presentation)
		return false
	return true

func _assert_hero_presence_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("hero_presence_model", "")) != "placed_world_hero_figure":
		_fail("Ninefold smoke: active hero does not report the placed world-figure presence model: %s." % presentation)
		return false
	if String(readability.get("hero_anchor_shape", "")) != "hero_foot_contact_shadow" or String(readability.get("hero_grounding_model", "")) != "hero_foot_contact_without_base_ellipse":
		_fail("Ninefold smoke: active hero still lacks the hero-specific foot-contact grounding model: %s." % presentation)
		return false
	if String(readability.get("hero_depth_cue_model", "")) != "hero_foot_contact_shadow_with_boot_occlusion":
		_fail("Ninefold smoke: active hero does not report boot-level depth/occlusion contact: %s." % presentation)
		return false
	if bool(readability.get("hero_badge_plate", true)) or bool(readability.get("hero_base_ellipse", true)) or bool(readability.get("hero_terrain_quieting_bed", true)) or bool(readability.get("hero_upper_mass_backdrop", true)) or bool(readability.get("hero_shared_marker_plate", true)):
		_fail("Ninefold smoke: active hero regressed toward the staged badge/ellipse support: %s." % presentation)
		return false
	if not bool(readability.get("hero_world_figure", false)) or not bool(readability.get("hero_foot_contact_shadow", false)) or not bool(readability.get("hero_boot_occlusion", false)):
		_fail("Ninefold smoke: active hero lacks world-figure, foot-shadow, or boot-occlusion cues: %s." % presentation)
		return false
	if float(readability.get("hero_contact_shadow_alpha", 0.0)) < 0.30 or float(readability.get("hero_boot_occlusion_alpha", 0.0)) < 0.34:
		_fail("Ninefold smoke: active hero foot-contact depth cues are too faint: %s." % presentation)
		return false
	if float(readability.get("hero_foot_anchor_width_fraction", 0.0)) < 0.50 or float(readability.get("hero_foot_anchor_height_fraction", 0.0)) < 0.12:
		_fail("Ninefold smoke: active hero foot-contact anchor is too small for the large-map tactical view: %s." % presentation)
		return false
	if String(readability.get("hero_selection_ring_source", "")) != "tile_focus":
		_fail("Ninefold smoke: active hero selection readability is no longer tied to the tile focus ring: %s." % presentation)
		return false
	return true

func _assert_town_footprint_profile(shell: Node, entry_presentation: Dictionary) -> bool:
	var profiles: Array = shell.call("validation_town_presentation_profiles")
	var matching_profile := {}
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		if String(profile.get("town_placement_id", "")) == "ninefold_embercourt_survey_camp":
			matching_profile = profile
			break
	if matching_profile.is_empty():
		_fail("Ninefold smoke: town presentation profiles did not include the starting survey camp: %s." % profiles)
		return false
	if int(matching_profile.get("footprint_width_tiles", 0)) != 3 or int(matching_profile.get("footprint_height_tiles", 0)) != 2:
		_fail("Ninefold smoke: starting town profile is not a 3x2 footprint: %s." % matching_profile)
		return false
	if int(matching_profile.get("blocked_footprint_cell_count", 0)) != 5 or int(matching_profile.get("off_map_footprint_cell_count", 0)) != 0:
		_fail("Ninefold smoke: in-bounds starting town should expose five blocked non-entry footprint cells: %s." % matching_profile)
		return false
	var entry_tile: Dictionary = matching_profile.get("entry_tile", {})
	if int(entry_tile.get("x", -1)) != 23 or int(entry_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: starting town entry tile moved away from the actual visit tile: %s." % matching_profile)
		return false
	var blocked_cells: Array = matching_profile.get("blocked_footprint_cells", [])
	if blocked_cells.is_empty():
		_fail("Ninefold smoke: starting town profile did not expose blocked non-entry cells: %s." % matching_profile)
		return false
	var first_blocked: Dictionary = blocked_cells[0]
	var blocked_presentation: Dictionary = shell.call("validation_tile_presentation", int(first_blocked.get("x", -1)), int(first_blocked.get("y", -1)))
	var blocked_town: Dictionary = blocked_presentation.get("town_presentation", {})
	if not bool(blocked_presentation.get("has_town_non_entry", false)) or bool(blocked_town.get("is_visit_tile", true)):
		_fail("Ninefold smoke: blocked town footprint tile did not read as non-entry: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	if not bool(blocked_town.get("presentation_blocked", false)) or String(blocked_town.get("tile_role", "")) != "blocked_non_entry_footprint":
		_fail("Ninefold smoke: blocked town footprint tile is not presentation-blocked: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	var entry_town: Dictionary = entry_presentation.get("town_presentation", {})
	if int(entry_town.get("blocked_footprint_cell_count", 0)) != 5:
		_fail("Ninefold smoke: entry tile did not expose the complete blocked-cell footprint: %s." % entry_presentation)
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
