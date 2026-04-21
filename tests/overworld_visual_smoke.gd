extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var map_node = shell.get_node_or_null("%Map")
	if map_node == null:
		push_error("Overworld smoke: visual map node did not load.")
		get_tree().quit(1)
		return
	if not _assert_wireframe_contract(shell):
		return
	if not _assert_small_map_fit(shell):
		return
	if not _assert_marker_readability_contract(shell):
		return
	if not _assert_overworld_art_contract(shell):
		return
	if not await _assert_diagonal_movement_contract(shell, map_node):
		return

	var start = OverworldRules.hero_position(SessionState.ensure_active_session())
	var map_size = OverworldRules.derive_map_size(SessionState.ensure_active_session())
	var directions = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
	]

	var moved = false
	for direction in directions:
		var target: Vector2i = start + direction
		if target.x < 0 or target.y < 0 or target.x >= map_size.x or target.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(SessionState.ensure_active_session(), target.x, target.y):
			continue
		shell._on_map_tile_pressed(target)
		await get_tree().process_frame
		var end = OverworldRules.hero_position(SessionState.ensure_active_session())
		if end != start:
			moved = true
			break

	if not moved:
		push_error("Overworld smoke: unable to advance the hero through the visual map shell.")
		get_tree().quit(1)
		return

	_assert_remembered_owned_town_remote_entry(shell)
	return

func _assert_diagonal_movement_contract(shell: Node, map_node: Node) -> bool:
	var session = SessionState.ensure_active_session()
	var start: Vector2i = OverworldRules.hero_position(session)
	var route_goal: Vector2i = _two_step_diagonal_goal(session, start)
	if route_goal.x < 0:
		var route_origin: Vector2i = _two_step_diagonal_origin(session)
		if route_origin.x >= 0:
			_set_active_hero_position(session, route_origin)
			OverworldRules.refresh_fog_of_war(session)
			shell.call("validation_select_tile", route_origin.x, route_origin.y)
			start = route_origin
			route_goal = _two_step_diagonal_goal(session, start)
	if route_goal.x < 0:
		push_error("Overworld smoke: could not find a two-step diagonal route for pathing coverage.")
		get_tree().quit(1)
		return false

	var route_selection: Dictionary = shell.call("validation_select_tile", route_goal.x, route_goal.y)
	if String(route_selection.get("primary_action_id", "")) != "advance_route":
		push_error("Overworld smoke: diagonal route goal did not expose route advancement. snapshot=%s goal=%s." % [route_selection, route_goal])
		get_tree().quit(1)
		return false
	var shell_route: Array = shell.call("_selected_route")
	var view_route: Array = map_node.call("_build_path", start, route_goal)
	if shell_route.size() != 3 or view_route.size() != 3:
		push_error("Overworld smoke: diagonal pathing did not use the expected two one-point steps. shell_route=%s view_route=%s start=%s goal=%s." % [shell_route, view_route, start, route_goal])
		get_tree().quit(1)
		return false
	var route_delta: Vector2i = route_goal - start
	var expected_first_step: Vector2i = start + Vector2i(1 if route_delta.x > 0 else -1, 1 if route_delta.y > 0 else -1)
	if shell_route[1] != expected_first_step or view_route[1] != shell_route[1]:
		push_error("Overworld smoke: diagonal pathing did not choose the diagonal first step. shell_route=%s view_route=%s start=%s goal=%s." % [shell_route, view_route, start, route_goal])
		get_tree().quit(1)
		return false

	var movement_before_route := int(session.overworld.get("movement", {}).get("current", 0))
	var route_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var route_finish: Vector2i = OverworldRules.hero_position(session)
	var movement_after_route := int(session.overworld.get("movement", {}).get("current", 0))
	if not bool(route_result.get("ok", false)) or route_finish != shell_route[1] or movement_after_route != movement_before_route - 1:
		push_error("Overworld smoke: diagonal route advancement did not move one diagonal step for one point. result=%s route=%s finish=%s before=%d after=%d." % [route_result, shell_route, route_finish, movement_before_route, movement_after_route])
		get_tree().quit(1)
		return false

	_set_active_hero_position(session, start)
	OverworldRules.refresh_fog_of_war(session)
	shell.call("validation_select_tile", start.x, start.y)
	var click_target: Vector2i = _diagonal_open_tile(session, start)
	if click_target.x < 0:
		push_error("Overworld smoke: could not find an adjacent diagonal tile for click movement coverage.")
		get_tree().quit(1)
		return false
	var movement_before_click := int(session.overworld.get("movement", {}).get("current", 0))
	shell._on_map_tile_pressed(click_target)
	await get_tree().process_frame
	var click_finish: Vector2i = OverworldRules.hero_position(session)
	var movement_after_click := int(session.overworld.get("movement", {}).get("current", 0))
	if click_finish != click_target or movement_after_click != movement_before_click - 1:
		push_error("Overworld smoke: diagonal map click did not move to the adjacent diagonal tile for one point. target=%s finish=%s before=%d after=%d." % [click_target, click_finish, movement_before_click, movement_after_click])
		get_tree().quit(1)
		return false
	return true

func _assert_wireframe_contract(shell: Node) -> bool:
	var map_panel: Control = shell.get_node_or_null("%MapPanel")
	var map_frame: Control = shell.get_node_or_null("%MapFrame")
	var sidebar_shell: Control = shell.get_node_or_null("%SidebarShell")
	var command_spine: Control = shell.get_node_or_null("%CommandSpine")
	var command_band: Control = shell.get_node_or_null("%CommandBand")
	var top_strip: Control = shell.get_node_or_null("%TopStrip")
	var event_panel: Control = shell.get_node_or_null("%EventPanel")
	var commitment_panel: Control = shell.get_node_or_null("%CommitmentPanel")
	var briefing_panel: Control = shell.get_node_or_null("%BriefingPanel")
	var action_panel: Control = shell.get_node_or_null("%ActionPanel")
	var open_command: Button = shell.get_node_or_null("%OpenCommand")
	var open_frontier: Button = shell.get_node_or_null("%OpenFrontier")
	var hero_actions: Control = shell.get_node_or_null("%HeroActions")
	var context_actions: Control = shell.get_node_or_null("%ContextActions")
	var specialty_actions: Control = shell.get_node_or_null("%SpecialtyActions")
	var spell_actions: Control = shell.get_node_or_null("%SpellActions")
	var artifact_actions: Control = shell.get_node_or_null("%ArtifactActions")
	var resource_chip: Control = shell.get_node_or_null("%ResourceChip")
	var status_chip: Control = shell.get_node_or_null("%StatusChip")
	var cue_chip: Control = shell.get_node_or_null("%CueChip")
	var required_nodes = [
		map_panel,
		map_frame,
		sidebar_shell,
		command_spine,
		command_band,
		top_strip,
		event_panel,
		commitment_panel,
		briefing_panel,
		action_panel,
		open_command,
		open_frontier,
		hero_actions,
		context_actions,
		specialty_actions,
		spell_actions,
		artifact_actions,
		resource_chip,
		status_chip,
		cue_chip,
	]
	for node in required_nodes:
		if node == null:
			push_error("Overworld smoke: wireframe contract node is missing.")
			get_tree().quit(1)
			return false

	var map_rect := map_panel.get_global_rect()
	var sidebar_rect := sidebar_shell.get_global_rect()
	var footer_rect := command_band.get_global_rect()
	var shell_rect := (shell as Control).get_global_rect() if shell is Control else get_viewport().get_visible_rect()
	var main_area := map_rect.size.x * map_rect.size.y
	var body_area := main_area + (sidebar_rect.size.x * sidebar_rect.size.y)
	if body_area <= 0.0 or main_area / body_area < 0.74:
		push_error("Overworld smoke: adventure map is not dominant enough for the wireframe contract.")
		get_tree().quit(1)
		return false
	if map_rect.size.x <= sidebar_rect.size.x * 3.0:
		push_error("Overworld smoke: right command spine is stealing too much horizontal map surface.")
		get_tree().quit(1)
		return false
	if sidebar_rect.position.x < map_rect.position.x + map_rect.size.x - 1.0:
		push_error("Overworld smoke: command spine is not fixed to the right of the map.")
		get_tree().quit(1)
		return false
	if footer_rect.size.y > max(96.0, shell_rect.size.y * 0.12):
		push_error("Overworld smoke: footer ribbon regressed into an oversized bottom slab. footer=%.1f shell=%.1f" % [footer_rect.size.y, shell_rect.size.y])
		get_tree().quit(1)
		return false
	if footer_rect.position.y < map_rect.position.y + map_rect.size.y - 1.0:
		push_error("Overworld smoke: command footer is not below the map stage.")
		get_tree().quit(1)
		return false
	for panel in [top_strip, event_panel, commitment_panel, briefing_panel]:
		if not _is_descendant_of(panel, sidebar_shell):
			push_error("Overworld smoke: light status panels must live inside the carved right shell.")
			get_tree().quit(1)
			return false
	if not _assert_decluttered_right_shell(shell, sidebar_shell, command_spine, action_panel, [hero_actions, context_actions, specialty_actions, spell_actions, artifact_actions]):
		return false
	for chip in [resource_chip, status_chip, cue_chip]:
		if not _is_descendant_of(chip, command_band):
			push_error("Overworld smoke: resources, date, and map cue must live inside the footer ribbon.")
			get_tree().quit(1)
			return false
	return true

func _assert_small_map_fit(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell validation snapshot is missing.")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	if viewport_metrics.is_empty():
		push_error("Overworld smoke: map viewport metrics are missing from validation snapshot.")
		get_tree().quit(1)
		return false
	if not bool(viewport_metrics.get("full_map_visible", false)):
		push_error("Overworld smoke: River Pass should still fit inside the overworld viewport. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	if not bool(viewport_metrics.get("fit_entire_map", false)):
		push_error("Overworld smoke: small-map fit mode is not active for River Pass. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	var map_size: Dictionary = viewport_metrics.get("map_size", {})
	if int(map_size.get("x", 0)) > 12 or int(map_size.get("y", 0)) > 12:
		push_error("Overworld smoke: small-map fit assertion was run against a non-small map. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	return true

func _assert_remembered_owned_town_remote_entry(shell: Node) -> bool:
	var tree := get_tree()
	if not shell.has_method("validation_select_tile") or not shell.has_method("validation_perform_primary_action"):
		push_error("Overworld smoke: shell is missing remote-town validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var town := _first_player_town(session)
	if town.is_empty():
		push_error("Overworld smoke: River Pass did not seed an owned town for remote-entry validation.")
		get_tree().quit(1)
		return false
	var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
	var remote_tile := _remote_memory_tile_for_town(session, town_tile)
	if remote_tile.x < 0:
		push_error("Overworld smoke: could not find a remote hero tile outside the owned town scout ring.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, remote_tile)
	OverworldRules.refresh_fog_of_war(session)
	if not OverworldRules.is_tile_explored(session, town_tile.x, town_tile.y):
		push_error("Overworld smoke: the previously scouted owned town was not preserved as explored memory.")
		get_tree().quit(1)
		return false
	if OverworldRules.is_tile_visible(session, town_tile.x, town_tile.y):
		push_error("Overworld smoke: remote-entry setup failed; owned town is still in the current scout net.")
		get_tree().quit(1)
		return false
	var selection: Dictionary = shell.call("validation_select_tile", town_tile.x, town_tile.y)
	if String(selection.get("primary_action_id", "")) != "visit_town":
		push_error("Overworld smoke: remembered owned town did not expose Visit Town as the primary order. snapshot=%s" % selection)
		get_tree().quit(1)
		return false
	if String(selection.get("context_summary", "")).find("Remembered Town") < 0:
		push_error("Overworld smoke: remembered owned town selection did not present a remembered-town context. snapshot=%s" % selection)
		get_tree().quit(1)
		return false
	var presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not bool(presentation.get("draws_remembered_object", false)):
		push_error("Overworld smoke: remembered owned town would not draw a remembered object marker. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if not _assert_explored_terrain_presentation(shell, town_tile, presentation):
		return false
	if not _assert_marker_style(presentation, "town", true):
		return false
	var remembered_timber_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 0)
	if bool(remembered_timber_presentation.get("visible", true)) or not _assert_art_sprite(remembered_timber_presentation, "lumber_wagon", true):
		push_error("Overworld smoke: remembered mapped pickup did not keep a ghosted sprite treatment. presentation=%s" % remembered_timber_presentation)
		get_tree().quit(1)
		return false
	var visit_result: Dictionary = shell.call("validation_perform_primary_action")
	if String(session.game_state) != "town" or not bool(visit_result.get("ok", false)):
		push_error("Overworld smoke: remembered owned town primary action did not route into town management. result=%s state=%s" % [visit_result, session.game_state])
		get_tree().quit(1)
		return false
	var active_town := TownRules.get_active_town(session)
	if String(active_town.get("placement_id", "")) != String(town.get("placement_id", "")):
		push_error("Overworld smoke: remote town route activated the wrong town. active=%s expected=%s" % [active_town, town])
		get_tree().quit(1)
		return false
	tree.quit(0)
	return true

func _assert_explored_terrain_presentation(shell: Node, remembered_tile: Vector2i, remembered_presentation: Dictionary) -> bool:
	var terrain_presentation: Dictionary = remembered_presentation.get("terrain_presentation", {})
	if not bool(remembered_presentation.get("explored", false)) or bool(remembered_presentation.get("visible", true)):
		push_error("Overworld smoke: terrain-memory assertion was not run against an explored tile outside the scout net. presentation=%s" % remembered_presentation)
		get_tree().quit(1)
		return false
	if not bool(terrain_presentation.get("terrain_fully_visible", false)):
		push_error("Overworld smoke: explored terrain outside the scout net is not staying fully visible at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if bool(terrain_presentation.get("uses_memory_terrain_dimming", true)) or float(terrain_presentation.get("memory_overlay_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: explored terrain outside the scout net is still using memory dimming at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if String(terrain_presentation.get("pattern_detail", "")) != "full":
		push_error("Overworld smoke: explored terrain outside the scout net lost full terrain detail at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if String(terrain_presentation.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(terrain_presentation.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(terrain_presentation.get("explored_intertile_seams", true)):
		push_error("Overworld smoke: explored terrain still reports a visible per-tile grid/seam treatment at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false

	var session = SessionState.ensure_active_session()
	var unexplored_tile := _first_unexplored_tile(session)
	if unexplored_tile.x < 0:
		push_error("Overworld smoke: could not find an unexplored tile to guard hidden fog presentation.")
		get_tree().quit(1)
		return false
	var unexplored_presentation: Dictionary = shell.call("validation_tile_presentation", unexplored_tile.x, unexplored_tile.y)
	var unexplored_terrain: Dictionary = unexplored_presentation.get("terrain_presentation", {})
	if bool(unexplored_presentation.get("explored", true)) or not bool(unexplored_terrain.get("unexplored_hidden", false)):
		push_error("Overworld smoke: unscouted terrain is not staying hidden at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	if bool(unexplored_terrain.get("terrain_fully_visible", true)):
		push_error("Overworld smoke: unscouted terrain became fully visible instead of remaining hidden at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	if not bool(unexplored_terrain.get("unexplored_wireframe", false)) or float(unexplored_terrain.get("unexplored_wireframe_alpha", 0.0)) < 0.30:
		push_error("Overworld smoke: unexplored terrain lost its necessary hidden-ground wireframe treatment at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_marker_readability_contract(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		push_error("Overworld smoke: shell is missing marker-presentation validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var marker_specs := [
		{"kind": "town", "tile": _first_visible_town_tile(session)},
		{"kind": "resource", "tile": _first_visible_resource_tile(session)},
		{"kind": "artifact", "tile": _first_visible_artifact_tile(session)},
		{"kind": "encounter", "tile": _first_visible_encounter_tile(session)},
	]
	for spec in marker_specs:
		var kind := String(spec.get("kind", ""))
		var tile: Vector2i = spec.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			push_error("Overworld smoke: could not find a visible %s marker candidate." % kind)
			get_tree().quit(1)
			return false
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		if not _assert_marker_style(presentation, kind, false):
			return false
		if kind == "town" and not _assert_town_non_entry_footprint(shell, presentation):
			return false

	var hero_tile := OverworldRules.hero_position(session)
	var hero_presentation: Dictionary = shell.call("validation_tile_presentation", hero_tile.x, hero_tile.y)
	var hero_readability: Dictionary = hero_presentation.get("marker_readability", {})
	if not bool(hero_presentation.get("has_visible_hero", false)) or not bool(hero_readability.get("hero_emphasis", false)):
		push_error("Overworld smoke: active hero marker is not emphasized. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if float(hero_readability.get("hero_symbol_extent_fraction", 0.0)) < 0.33:
		push_error("Overworld smoke: active hero symbol is too small to read against terrain. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if not bool(hero_readability.get("selection_emphasis", false)) or float(hero_readability.get("focus_ring_width_px", 0.0)) < 3.0:
		push_error("Overworld smoke: current selection focus is not readable on the map. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if not _assert_hero_presence_correction(hero_readability, hero_presentation):
		return false
	var hero_object_kinds: Array = hero_readability.get("object_kinds", [])
	if "town" in hero_object_kinds:
		if not _assert_town_grounding_correction(hero_readability, hero_presentation):
			return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	var is_town := expected_kind == "town"
	var uses_procedural_fallback := bool(readability.get("procedural_world_silhouette", false))
	var art: Dictionary = presentation.get("art_presentation", {})
	var uses_mapped_sprite := bool(art.get("uses_asset_sprite", false)) and not is_town
	if expected_kind not in object_kinds:
		push_error("Overworld smoke: expected %s marker kind was missing. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("ground_anchor", false)):
		push_error("Overworld smoke: %s marker lacks terrain-grounded placement metadata. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object":
		push_error("Overworld smoke: %s marker no longer reports object-first footprint presence. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else ("ground_contact_without_foreground_lip" if uses_procedural_fallback else ("sprite_contact_without_foreground_lip" if uses_mapped_sprite else ""))
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		push_error("Overworld smoke: %s marker no longer reports the expected foreground contact model. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif uses_procedural_fallback:
		if not _assert_procedural_fallback_grounding(readability, expected_kind, presentation):
			return false
	elif uses_mapped_sprite:
		if not _assert_mapped_sprite_grounding(readability, expected_kind, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		push_error("Overworld smoke: %s marker lacks the terrain-grounded anchor needed to read against the map. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	else:
		push_error("Overworld smoke: %s marker used an unsupported non-town/non-procedural/non-mapped grounding path. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if int(readability.get("footprint_width_tiles", 0)) <= 0 or int(readability.get("footprint_height_tiles", 0)) <= 0:
		push_error("Overworld smoke: %s marker does not expose authored/default footprint dimensions. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if expected_kind == "town":
		if int(readability.get("footprint_width_tiles", 0)) != 3 or int(readability.get("footprint_height_tiles", 0)) != 2:
			push_error("Overworld smoke: town marker must present as a 3x2 footprint. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		if not bool(town_presentation.get("has_town_footprint", false)) or String(town_presentation.get("presentation_model", "")) != "town_3x2_footprint_bottom_middle_entry":
			push_error("Overworld smoke: town presentation metadata does not expose the 3x2 model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if String(town_presentation.get("entry_role", "")) != "bottom_middle_visit_approach" or not bool(town_presentation.get("entry_is_visit_tile", false)):
			push_error("Overworld smoke: town presentation does not report the bottom-middle visit approach tile. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if not bool(town_presentation.get("is_entry_tile", false)) or String(town_presentation.get("tile_role", "")) != "bottom_middle_visit_approach":
			push_error("Overworld smoke: selected town tile is not reported as the entry approach. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
			push_error("Overworld smoke: town presentation must preserve blocked non-entry metadata without visible helper apron/gate/glyph cues. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
	var min_anchor_width := 0.36 if uses_mapped_sprite else (0.40 if uses_procedural_fallback else 0.60)
	var min_anchor_height := 0.06 if uses_mapped_sprite else (0.12 if uses_procedural_fallback else 0.20)
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < min_anchor_width or float(readability.get("footprint_anchor_height_fraction", 0.0)) < min_anchor_height:
		push_error("Overworld smoke: %s footprint anchor is too small to read as placed ground contact. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("ui_badge_plate", true)):
		push_error("Overworld smoke: %s marker regressed to a UI badge plate instead of a terrain footprint. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		push_error("Overworld smoke: %s marker symbol is too small for at-a-glance readability. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if remembered:
		if is_town:
			if bool(readability.get("memory_echo", false)) or String(readability.get("town_remembered_treatment", "")) != "ghosted_sprite_without_echo_plate":
				push_error("Overworld smoke: remembered town should use ghosted sprite treatment without the removed echo plate. presentation=%s" % presentation)
				get_tree().quit(1)
				return false
		elif not bool(readability.get("memory_echo", false)):
			push_error("Overworld smoke: remembered %s marker lacks a distinguishable memory treatment. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if float(readability.get("remembered_marker_alpha", 0.0)) < 0.80 or float(readability.get("outline_alpha", 0.0)) < 0.70:
			push_error("Overworld smoke: remembered %s marker is still too faint. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
	else:
		if bool(readability.get("memory_echo", false)):
			push_error("Overworld smoke: visible %s marker was styled like a remembered marker. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		var visible_grid_suppressed := String(readability.get("visible_terrain_grid_mode", "")) == "fog_boundary_only" and float(readability.get("grid_alpha", 1.0)) <= 0.08 and not bool(readability.get("explored_intertile_seams", true))
		var anchor_floor := 0.12 if uses_mapped_sprite else (0.16 if uses_procedural_fallback else 0.30)
		if not is_town and (float(readability.get("anchor_alpha", 0.0)) < anchor_floor or float(readability.get("outline_alpha", 0.0)) < 0.85 or not visible_grid_suppressed):
			push_error("Overworld smoke: visible %s marker grounding or map contrast regressed. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
	return true

func _assert_procedural_fallback_grounding(readability: Dictionary, expected_kind: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "family_terrain_contact_scuffs":
		push_error("Overworld smoke: procedural %s fallback still reports the old terrain-ellipse marker anchor. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("procedural_fallback_grounding", false)) or String(readability.get("procedural_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate":
		push_error("Overworld smoke: procedural %s fallback does not expose the family-specific contact-scuff grounding model. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("contrast_plate", true)) or bool(readability.get("shared_marker_plate", true)) or float(readability.get("plate_alpha", 1.0)) > 0.01 or float(readability.get("ring_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback still exposes the shared marker plate or ring. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback still reports the broad terrain quieting bed. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("procedural_contact_disturbance", false)) or String(readability.get("procedural_contact_disturbance_model", "")) != "thin_terrain_contact_disturbance":
		push_error("Overworld smoke: procedural %s fallback lacks the thin terrain contact disturbance. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("procedural_contact_disturbance_alpha", 0.0)) < 0.16 or float(readability.get("procedural_contact_disturbance_alpha", 1.0)) > 0.24:
		push_error("Overworld smoke: procedural %s fallback contact disturbance alpha is outside the grounded-object range. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: procedural %s fallback still reports upper-mass backdrop/shadow support. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or not bool(readability.get("procedural_contact_marks", false)):
		push_error("Overworld smoke: procedural %s fallback still reports the foreground lip instead of contact marks. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("depth_cue_model", "")) != "localized_contact_shadow_without_backdrop":
		push_error("Overworld smoke: procedural %s fallback does not report localized contact-shadow depth. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("directional_contact_shadow", true)) or not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_object_contact_shadow":
		push_error("Overworld smoke: procedural %s fallback still reports the shared directional cast shadow. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("contact_shadow_alpha", 0.0)) < 0.24 or bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback lacks localized contact shadow or still reports base occlusion pads. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_town_grounding_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "town_contact_cues_no_base_ellipse":
		push_error("Overworld smoke: town still reports a base ellipse anchor instead of quiet contact cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports a filled terrain underlay/quieting bed. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: town still reports upper-mass shadow/backdrop treatment. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("depth_cue_model", "")) != "town_contact_line_without_cast_shadow" or bool(readability.get("directional_contact_shadow", true)) or float(readability.get("contact_shadow_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports directional cast-shadow depth cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports foreground base occlusion pads. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		push_error("Overworld smoke: town grounding metadata does not describe the no-ellipse presentation. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("town_base_ellipse", true)) or bool(readability.get("town_underlay", true)) or bool(readability.get("town_cast_shadow", true)) or not bool(readability.get("town_contact_cue", false)):
		push_error("Overworld smoke: town grounding flags did not remove base ellipse/underlay/cast shadow while preserving contact cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	var town_presentation: Dictionary = presentation.get("town_presentation", {})
	if bool(town_presentation.get("base_ellipse", true)) or bool(town_presentation.get("filled_underlay", true)) or bool(town_presentation.get("cast_shadow", true)):
		push_error("Overworld smoke: town presentation payload still exposes the removed ellipse/underlay/shadow treatment. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(town_presentation.get("footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		push_error("Overworld smoke: town footprint cue metadata does not describe the cue-free 3x2 contract. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
		push_error("Overworld smoke: town presentation payload still exposes visible helper footprint/entry cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_hero_presence_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("hero_presence_model", "")) != "placed_world_hero_figure":
		push_error("Overworld smoke: active hero does not report the placed world-figure presence model. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_anchor_shape", "")) != "hero_foot_contact_shadow" or String(readability.get("hero_grounding_model", "")) != "hero_foot_contact_without_base_ellipse":
		push_error("Overworld smoke: active hero still lacks the hero-specific foot-contact grounding model. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_depth_cue_model", "")) != "hero_foot_contact_shadow_with_boot_occlusion":
		push_error("Overworld smoke: active hero does not report boot-level depth/occlusion contact. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("hero_badge_plate", true)) or bool(readability.get("hero_base_ellipse", true)) or bool(readability.get("hero_terrain_quieting_bed", true)) or bool(readability.get("hero_upper_mass_backdrop", true)) or bool(readability.get("hero_shared_marker_plate", true)):
		push_error("Overworld smoke: active hero regressed toward the staged badge/ellipse support. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if not bool(readability.get("hero_world_figure", false)) or not bool(readability.get("hero_foot_contact_shadow", false)) or not bool(readability.get("hero_boot_occlusion", false)):
		push_error("Overworld smoke: active hero lacks world-figure, foot-shadow, or boot-occlusion cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if float(readability.get("hero_contact_shadow_alpha", 0.0)) < 0.30 or float(readability.get("hero_boot_occlusion_alpha", 0.0)) < 0.34:
		push_error("Overworld smoke: active hero foot-contact depth cues are too faint. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if float(readability.get("hero_foot_anchor_width_fraction", 0.0)) < 0.50 or float(readability.get("hero_foot_anchor_height_fraction", 0.0)) < 0.12:
		push_error("Overworld smoke: active hero foot-contact anchor is too small to read as placed on terrain. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_selection_ring_source", "")) != "tile_focus":
		push_error("Overworld smoke: active hero selection readability is no longer tied to the tile focus ring. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_town_non_entry_footprint(shell: Node, entry_presentation: Dictionary) -> bool:
	var town_presentation: Dictionary = entry_presentation.get("town_presentation", {})
	var blocked_cells: Array = town_presentation.get("blocked_footprint_cells", [])
	if blocked_cells.is_empty():
		push_error("Overworld smoke: town 3x2 footprint did not expose any blocked non-entry cells. presentation=%s" % entry_presentation)
		get_tree().quit(1)
		return false
	for cell_value in blocked_cells:
		if not (cell_value is Dictionary):
			continue
		var cell: Dictionary = cell_value
		var cell_presentation: Dictionary = shell.call("validation_tile_presentation", int(cell.get("x", -1)), int(cell.get("y", -1)))
		var cell_town: Dictionary = cell_presentation.get("town_presentation", {})
		if not bool(cell_presentation.get("has_town_non_entry", false)):
			push_error("Overworld smoke: town footprint cell does not read as a non-entry town tile. cell=%s presentation=%s" % [cell, cell_presentation])
			get_tree().quit(1)
			return false
		if bool(cell_town.get("is_visit_tile", true)) or not bool(cell_town.get("presentation_blocked", false)) or String(cell_town.get("tile_role", "")) != "blocked_non_entry_footprint":
			push_error("Overworld smoke: town non-entry footprint cell is not presentation-blocked. cell=%s presentation=%s" % [cell, cell_presentation])
			get_tree().quit(1)
			return false
		return true
	push_error("Overworld smoke: town footprint blocked-cell payload contained no usable in-bounds cells. presentation=%s" % entry_presentation)
	get_tree().quit(1)
	return false

func _assert_mapped_sprite_grounding(readability: Dictionary, label: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "mapped_sprite_local_contact_scuffs" or not bool(readability.get("mapped_sprite_grounding", false)):
		push_error("Overworld smoke: mapped %s sprite does not report the local contact-scuff anchor. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs" or not bool(readability.get("mapped_sprite_contact_disturbance", false)):
		push_error("Overworld smoke: mapped %s sprite lacks localized contact scuffs. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("mapped_sprite_contact_disturbance_model", "")) != "thin_sprite_contact_disturbance" or float(readability.get("mapped_sprite_contact_disturbance_alpha", 0.0)) < 0.12:
		push_error("Overworld smoke: mapped %s sprite contact scuffs are missing or too faint. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: mapped %s sprite still reports a broad placement bed. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: mapped %s sprite still reports upper-mass backdrop or vertical shadow support. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or bool(readability.get("base_occlusion_pads", true)) or bool(readability.get("shared_marker_plate", true)):
		push_error("Overworld smoke: mapped %s sprite still reports foreground lip/base pads/shared marker plate. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_sprite_contact_shadow" or float(readability.get("contact_shadow_alpha", 0.0)) < 0.22:
		push_error("Overworld smoke: mapped %s sprite lacks localized contact-shadow readability. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_overworld_art_contract(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		push_error("Overworld smoke: shell is missing art-presentation validation hooks.")
		get_tree().quit(1)
		return false
	var grass_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 2)
	var grass_terrain: Dictionary = grass_presentation.get("terrain_presentation", {})
	if String(grass_terrain.get("rendering_mode", "")) != "homm3_local_reference_prototype":
		push_error("Overworld smoke: HoMM3 local prototype terrain atlas is not active on the overworld map. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("uses_sampled_texture", true)) or bool(grass_terrain.get("generated_source_primary", true)) or not bool(grass_terrain.get("uses_homm3_local_prototype", false)) or not bool(grass_terrain.get("texture_loaded", false)):
		push_error("Overworld smoke: overworld terrain is not reporting the HoMM3 local prototype tile bank. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("primary_base_model", "")) != "homm3_local_reference_prototype" or String(grass_terrain.get("terrain_noise_profile", "")) != "homm3_extracted_atlas_frame":
		push_error("Overworld smoke: overworld terrain does not expose the HoMM3 extracted-atlas base model. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_variant_selection", "")) != "table_driven_neighbor_mask_with_stable_interior_base" or String(grass_terrain.get("homm3_terrain_lookup_model", "")) != "table_driven_bridge_base_8_neighbor":
		push_error("Overworld smoke: grass terrain does not expose the table-driven HoMM3 stable-base lookup contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("homm3_interior_frame_selection", "")) != "single_stable_base_frame" or bool(grass_terrain.get("homm3_uses_interior_variant_cycle", true)):
		push_error("Overworld smoke: HoMM3 terrain interior frames still report patch-hash variant cycling. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("homm3_local_reference_only", false)) or String(grass_terrain.get("tile_art_source_basis", "")) != "homm3_extracted_local_reference_prototype":
		push_error("Overworld smoke: HoMM3 prototype terrain did not report its local-reference source basis. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_group", "")) != "grasslands" or String(grass_terrain.get("style_id", "")) == "":
		push_error("Overworld smoke: grass terrain does not expose grammar group/style metadata. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(grass_terrain.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(grass_terrain.get("explored_intertile_seams", true)):
		push_error("Overworld smoke: visible grass terrain still reports per-cell black grid seams. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("road_overlay", false)) or String(grass_terrain.get("road_overlay_id", "")) != "road_dirt" or not bool(grass_terrain.get("road_overlay_art", false)) or String(grass_terrain.get("road_shape_model", "")) != "homm3_4_neighbor_overlay_lookup":
		push_error("Overworld smoke: authored River Pass road overlay is not using HoMM3 4-neighbor road art. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(grass_terrain.get("road_same_type_adjacency", false)) or not bool(grass_terrain.get("road_orthogonal_mask_only", false)):
		push_error("Overworld smoke: River Pass road overlay is not being rebuilt from 4-neighbor same-type road adjacency. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("road_horizontal_edge_riding", true)) or bool(grass_terrain.get("road_diagonal_connections", true)) or String(grass_terrain.get("road_piece_selection_model", "")) != "homm3_4_neighbor_mask_lookup":
		push_error("Overworld smoke: River Pass road still reports old lane or diagonal-road topology. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(grass_terrain.get("road_joint_cap", false)):
		push_error("Overworld smoke: River Pass road intersection does not expose the connection-aware joint cap contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false

	var forest_edge_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var forest_edge_terrain: Dictionary = forest_edge_presentation.get("terrain_presentation", {})
	if (
		String(forest_edge_terrain.get("terrain_group", "")) != "forest"
		or not bool(forest_edge_terrain.get("neighbor_aware_transitions", false))
		or String(forest_edge_terrain.get("transition_calculation_model", "")) != "homm3_table_driven_bridge_base_lookup"
		or String(forest_edge_terrain.get("homm3_terrain_family", "")) != "grass"
		or String(forest_edge_terrain.get("homm3_logical_degrade_note", "")) == ""
		or String(forest_edge_terrain.get("transition_shape_model", "")) != "homm3_base_atlas_frame"
	):
		push_error("Overworld smoke: logical forest terrain did not report its explicit HoMM3 grass-atlas prototype degradation. presentation=%s" % forest_edge_presentation)
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	if not _assert_bridge_material_resolver_payloads(shell, session):
		return false
	if not _assert_single_sand_homm3_propagation(shell, session):
		return false
	var town_tile := _first_visible_town_tile(session)
	if town_tile.x < 0:
		push_error("Overworld smoke: could not find a visible town for default town sprite validation.")
		get_tree().quit(1)
		return false
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not _assert_art_sprite(town_presentation, "frontier_town", false):
		return false
	var encounter_tile := _first_visible_encounter_tile(session)
	if encounter_tile.x < 0:
		push_error("Overworld smoke: could not find a visible encounter for default encounter sprite validation.")
		get_tree().quit(1)
		return false
	var encounter_presentation: Dictionary = shell.call("validation_tile_presentation", encounter_tile.x, encounter_tile.y)
	if not _assert_art_sprite(encounter_presentation, "hostile_camp", false):
		return false
	var timber_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 0)
	if not _assert_art_sprite(timber_presentation, "lumber_wagon", false):
		return false
	var artifact_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 0)
	if not _assert_art_sprite(artifact_presentation, "adventurers_bundle", false):
		return false
	var fallback_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 3)
	var fallback_art: Dictionary = fallback_presentation.get("art_presentation", {})
	if bool(fallback_art.get("uses_asset_sprite", true)) or not bool(fallback_art.get("fallback_procedural_marker", false)):
		push_error("Overworld smoke: unmapped faction outpost did not preserve procedural marker fallback. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_silhouette_model", "")) != "family_specific_procedural_world_object":
		push_error("Overworld smoke: procedural fallback object did not report the family-specific world silhouette model. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate" or bool(fallback_art.get("fallback_shared_marker_plate", true)) or bool(fallback_art.get("fallback_upper_mass_backdrop", true)) or bool(fallback_art.get("fallback_foreground_lip", true)):
		push_error("Overworld smoke: procedural fallback object did not report the no-plate/no-backdrop/no-lip grounding correction. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_contact_shadow_model", "")) != "localized_object_contact_shadow":
		push_error("Overworld smoke: procedural fallback object did not report localized contact shadow grounding. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_bridge_material_resolver_payloads(shell: Node, session) -> bool:
	var original_map = session.overworld.get("map", []).duplicate(true)
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	if map_size.x < 9 or map_size.y < 5:
		push_error("Overworld smoke: bridge resolver fixture requires at least a 9x5 map, got %s." % map_size)
		get_tree().quit(1)
		return false
	var working_map := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			row.append("grass")
		working_map.append(row)
	var paint_plan := [
		{"tile": Vector2i(2, 1), "terrain": "badlands"},
		{"tile": Vector2i(4, 1), "terrain": "badlands"},
		{"tile": Vector2i(4, 0), "terrain": "badlands"},
		{"tile": Vector2i(4, 2), "terrain": "badlands"},
		{"tile": Vector2i(3, 1), "terrain": "badlands"},
		{"tile": Vector2i(5, 1), "terrain": "wastes"},
		{"tile": Vector2i(2, 3), "terrain": "swamp"},
		{"tile": Vector2i(7, 3), "terrain": "snow"},
		{"tile": Vector2i(7, 1), "terrain": "cavern"},
		{"tile": Vector2i(7, 0), "terrain": "cavern"},
		{"tile": Vector2i(7, 2), "terrain": "cavern"},
		{"tile": Vector2i(6, 1), "terrain": "cavern"},
		{"tile": Vector2i(8, 1), "terrain": "grass"},
	]
	for entry in paint_plan:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		working_map[tile.y][tile.x] = String(entry.get("terrain", "grass"))
	session.overworld["map"] = working_map
	var controlled_tiles := []
	for y in range(map_size.y):
		for x in range(map_size.x):
			controlled_tiles.append(Vector2i(x, y))
	_reveal_validation_tiles(session, controlled_tiles)
	shell.call("_refresh")
	var cases := [
		{
			"tile": Vector2i(1, 1),
			"source": "badlands",
			"kind": "direct_bridge_material",
			"rule": "full_receiver_direct_dirt_contact",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "fact",
			"model": "direct_bridge_material_contact_lookup",
		},
		{
			"tile": Vector2i(4, 1),
			"source": "wastes",
			"kind": "direct_bridge_material",
			"rule": "dirt_receiver_direct_sand_contact",
			"class": "sand_bridge",
			"family": "sand",
			"block": "dirt_to_sand_transition",
			"source_level": "fact",
			"model": "direct_dirt_sand_receiver_lookup",
		},
		{
			"tile": Vector2i(1, 3),
			"source": "swamp",
			"kind": "routed_bridge",
			"rule": "grass_swamp_via_dirt_bridge",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "inference",
			"model": "grass_swamp_via_dirt_bridge",
		},
		{
			"tile": Vector2i(6, 3),
			"source": "snow",
			"kind": "preferred_bridge_class",
			"rule": "full_receiver_prefers_dirt_bridge_class",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "editor_observation",
			"model": "receiver_preferred_bridge_class_lookup",
		},
		{
			"tile": Vector2i(7, 1),
			"source": "grass",
			"kind": "unresolved_fallback",
			"rule": "subterranean_preferred_bridge_class_provisional",
			"class": "subterranean_preferred_class_unresolved",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "provisional",
			"model": "provisional_subterranean_dirt_bridge_fallback",
			"provisional": true,
		},
	]
	for case in cases:
		var tile: Vector2i = case.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if not _assert_live_bridge_resolver_case(terrain, case):
			_restore_single_sand_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: bridge material resolver metadata did not match case %s. presentation=%s" % [case, presentation])
			get_tree().quit(1)
			return false
	_restore_single_sand_fixture(shell, session, original_map, original_fog)
	return true

func _assert_live_bridge_resolver_case(terrain: Dictionary, expected: Dictionary) -> bool:
	if String(terrain.get("homm3_selection_kind", "")) != "bridge_transition":
		return false
	if String(terrain.get("homm3_bridge_resolver_model", "")) != "data_driven_bridge_material_resolver.v1":
		return false
	if String(terrain.get("homm3_bridge_source_kind", "")) != String(expected.get("kind", "")):
		return false
	if String(terrain.get("homm3_bridge_rule_id", "")) != String(expected.get("rule", "")):
		return false
	if String(terrain.get("homm3_bridge_class", "")) != String(expected.get("class", "")):
		return false
	if String(terrain.get("homm3_bridge_family", "")) != String(expected.get("family", "")):
		return false
	if String(terrain.get("homm3_selected_frame_block", "")) != String(expected.get("block", "")):
		return false
	if String(terrain.get("homm3_bridge_target_frame_block", "")) != String(expected.get("block", "")):
		return false
	if String(terrain.get("homm3_bridge_source_level", "")) != String(expected.get("source_level", "")):
		return false
	if String(terrain.get("homm3_bridge_resolution_model", "")) != String(expected.get("model", "")):
		return false
	if bool(terrain.get("homm3_bridge_policy_provisional", false)) != bool(expected.get("provisional", false)):
		return false
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("source_terrain", "")) == String(expected.get("source", ""))
			and String(source.get("bridge_source_kind", "")) == String(expected.get("kind", ""))
			and String(source.get("bridge_rule_id", "")) == String(expected.get("rule", ""))
			and String(source.get("bridge_class", "")) == String(expected.get("class", ""))
			and String(source.get("resolved_bridge_family", "")) == String(expected.get("family", ""))
			and String(source.get("bridge_target_frame_block", "")) == String(expected.get("block", ""))
			and String(source.get("bridge_source_level", "")) == String(expected.get("source_level", ""))
		):
			return true
	return false

func _assert_single_sand_homm3_propagation(shell: Node, session) -> bool:
	var center := Vector2i(4, 2)
	var original_map = session.overworld.get("map", []).duplicate(true)
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	var controlled_tiles := []
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			controlled_tiles.append(tile)
	var working_map := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			row.append("grass")
		working_map.append(row)
	working_map[center.y][center.x] = "wastes"
	session.overworld["map"] = working_map
	_reveal_validation_tiles(session, controlled_tiles)
	shell.call("_refresh")

	var center_presentation: Dictionary = shell.call("validation_tile_presentation", center.x, center.y)
	var center_terrain: Dictionary = center_presentation.get("terrain_presentation", {})
	if (
			String(center_terrain.get("terrain", "")) != "wastes"
			or String(center_terrain.get("homm3_terrain_family", "")) != "sand"
			or String(center_terrain.get("homm3_selection_kind", "")) != "bridge_material_base_context"
			or String(center_terrain.get("homm3_atlas_role", "")) != "base_decor_bridge_material"
			or bool(center_terrain.get("homm3_allows_generic_land_edge_masks", true))
			or String(center_terrain.get("homm3_selected_frame_block", "")) != "base_context_provisional"
			or String(center_terrain.get("homm3_terrain_frame", "")) != "00_23"
			or String(center_terrain.get("homm3_bridge_family", "")) != "sand"
			or String(center_terrain.get("homm3_bridge_source_kind", "")) != "direct_bridge_material"
			or int(center_terrain.get("edge_transition_count", -1)) != 4
		or int(center_terrain.get("corner_transition_count", -1)) != 4
		or "grass" not in center_terrain.get("transition_source_terrain_ids", [])
	):
		_restore_single_sand_fixture(shell, session, original_map, original_fog)
		push_error("Overworld smoke: live renderer did not use the HoMM3 sand receiver transition lookup for the inserted sand center. presentation=%s" % center_presentation)
		get_tree().quit(1)
		return false

	var edge_cases := [
		{"tile": center + Vector2i(0, -1), "edge": "S", "frame": "00_32"},
		{"tile": center + Vector2i(1, 0), "edge": "W", "frame": "00_24"},
		{"tile": center + Vector2i(0, 1), "edge": "N", "frame": "00_28"},
		{"tile": center + Vector2i(-1, 0), "edge": "E", "frame": "00_35"},
	]
	for entry in edge_cases:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if (
			String(terrain.get("homm3_selection_kind", "")) != "bridge_transition"
			or String(terrain.get("transition_edge_mask", "")) != String(entry.get("edge", ""))
			or String(terrain.get("transition_corner_mask", "")) != ""
				or String(terrain.get("homm3_terrain_frame", "")) != String(entry.get("frame", ""))
				or String(terrain.get("homm3_bridge_family", "")) != "sand"
				or String(terrain.get("homm3_bridge_resolution_model", "")) != "direct_grass_sand_native_to_sand_lookup"
				or String(terrain.get("homm3_bridge_source_kind", "")) != "direct_bridge_material"
				or String(terrain.get("homm3_selected_frame_block", "")) != "native_to_sand_transition"
				or int(terrain.get("edge_transition_count", 0)) != 1
			or int(terrain.get("corner_transition_count", -1)) != 0
			or "wastes" not in terrain.get("transition_source_terrain_ids", [])
		):
			_restore_single_sand_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: live renderer did not select the expected grastl native-to-sand edge frame at %s. presentation=%s" % [tile, presentation])
			get_tree().quit(1)
			return false

	var corner_cases := [
		{"tile": center + Vector2i(-1, -1), "direction": "SE", "flip": "HV"},
		{"tile": center + Vector2i(1, -1), "direction": "SW", "flip": "V"},
		{"tile": center + Vector2i(-1, 1), "direction": "NE", "flip": "H"},
		{"tile": center + Vector2i(1, 1), "direction": "NW", "flip": ""},
	]
	for entry in corner_cases:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if (
			String(terrain.get("homm3_selection_kind", "")) != "propagated_transition"
			or String(terrain.get("transition_edge_mask", "")) != ""
			or String(terrain.get("homm3_transition_source_direction", "")) != String(entry.get("direction", ""))
			or String(terrain.get("homm3_terrain_frame", "")) != "00_20"
			or not bool(terrain.get("homm3_propagated_transition", false))
				or String(terrain.get("homm3_transition_propagation_model", "")) != "grastl_native_to_sand_4x5_stamp_with_axis_flips"
				or String(terrain.get("homm3_selected_frame_block", "")) != "native_to_sand_transition"
			or String(terrain.get("homm3_terrain_flip", "")) != String(entry.get("flip", ""))
			or int(terrain.get("edge_transition_count", -1)) != 0
			or int(terrain.get("corner_transition_count", -1)) != 1
			or int(terrain.get("propagated_transition_count", 0)) != 1
			or bool(terrain.get("transition_uses_second_ring", true))
			or "wastes" not in terrain.get("transition_source_terrain_ids", [])
		):
			_restore_single_sand_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: live renderer did not select the expected rotated grastl native-to-sand stamp frame at %s. presentation=%s" % [tile, presentation])
			get_tree().quit(1)
			return false

	var second_ring_cases := [
		{"tile": center + Vector2i(2, 2), "direction": "NW", "frame": "00_25", "flip": "", "distance": 2},
		{"tile": center + Vector2i(-2, -2), "direction": "SE", "frame": "00_25", "flip": "HV", "distance": 2},
	]
	for entry in second_ring_cases:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if (
			String(terrain.get("homm3_selection_kind", "")) != "propagated_transition"
			or String(terrain.get("homm3_terrain_frame", "")) != String(entry.get("frame", ""))
			or String(terrain.get("homm3_terrain_flip", "")) != String(entry.get("flip", ""))
			or int(terrain.get("homm3_transition_source_distance", 0)) != int(entry.get("distance", 0))
			or String(terrain.get("homm3_transition_source_direction", "")) != String(entry.get("direction", ""))
			or not bool(terrain.get("transition_uses_second_ring", false))
			or int(terrain.get("propagated_transition_count", 0)) != 1
			or "wastes" not in terrain.get("transition_source_terrain_ids", [])
		):
			_restore_single_sand_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: live renderer did not propagate the single sand through the grastl native-to-sand stamp at %s. presentation=%s" % [tile, presentation])
			get_tree().quit(1)
			return false

	var outside_tile := center + Vector2i(4, 0)
	var outside_presentation: Dictionary = shell.call("validation_tile_presentation", outside_tile.x, outside_tile.y)
	var outside_terrain: Dictionary = outside_presentation.get("terrain_presentation", {})
	if (
		String(outside_terrain.get("homm3_selection_kind", "")) != "interior"
		or bool(outside_terrain.get("homm3_propagated_transition", false))
		or String(outside_terrain.get("homm3_logical_terrain_id", "")) != "grass"
		or String(outside_terrain.get("homm3_renderer_family", "")) != "grass"
		or String(outside_terrain.get("homm3_atlas_role", "")) != "full_receiver_land"
		or String(outside_terrain.get("homm3_selected_frame_block", "")) != "native_interiors"
		or String(outside_terrain.get("homm3_selected_frame_block_source_level", "")) != "fact"
	):
		_restore_single_sand_fixture(shell, session, original_map, original_fog)
		push_error("Overworld smoke: live renderer propagated outside the explicit grastl native-to-sand stamp lookup at %s. presentation=%s" % [outside_tile, outside_presentation])
		get_tree().quit(1)
		return false

	_restore_single_sand_fixture(shell, session, original_map, original_fog)
	return true

func _restore_single_sand_fixture(shell: Node, session, original_map, original_fog) -> void:
	session.overworld["map"] = original_map.duplicate(true) if original_map is Array else []
	session.overworld["fog"] = original_fog.duplicate(true) if original_fog is Dictionary else {}
	shell.call("_refresh")

func _reveal_validation_tiles(session, tiles: Array) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles := []
	var explored_tiles := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		visible_tiles[tile.y][tile.x] = true
		explored_tiles[tile.y][tile.x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": tiles.size(),
		"explored_count": tiles.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _assert_art_sprite(presentation: Dictionary, expected_asset_id: String, remembered: bool) -> bool:
	var art: Dictionary = presentation.get("art_presentation", {})
	var asset_ids: Array = art.get("sprite_asset_ids", [])
	var is_town := expected_asset_id == "frontier_town"
	if not bool(art.get("uses_asset_sprite", false)) or expected_asset_id not in asset_ids:
		push_error("Overworld smoke: expected overworld sprite %s was not used. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("fallback_procedural_marker", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reported procedural fallback. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if is_town:
		if String(art.get("sprite_settlement_model", "")) != "town_sprite_settled_without_base_ellipse" or String(art.get("sprite_depth_cue_model", "")) != "town_contact_line_without_cast_shadow":
			push_error("Overworld smoke: town sprite does not report the quiet no-ellipse grounding model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if bool(art.get("sprite_placement_bed", true)) or bool(art.get("sprite_upper_mass_backdrop", true)) or bool(art.get("sprite_vertical_mass_shadow", true)):
			push_error("Overworld smoke: town sprite still reports placement bed or shadow/backdrop treatment. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if String(art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(art.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
			push_error("Overworld smoke: town art metadata does not expose the corrected footprint grounding model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if bool(art.get("town_base_ellipse", true)) or bool(art.get("town_underlay", true)) or bool(art.get("town_cast_shadow", true)) or bool(art.get("town_vertical_mass_shadow", true)):
			push_error("Overworld smoke: town art metadata still exposes removed ellipse/underlay/shadow treatment. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		return true
	if String(art.get("sprite_settlement_model", "")) != "mapped_sprite_contact_grounding_no_support_stack" or bool(art.get("settled_sprite_occlusion", true)):
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the no-support-stack contact grounding. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("sprite_depth_contact_cues", false)) or String(art.get("sprite_depth_cue_model", "")) != "localized_sprite_contact_shadow_without_backdrop":
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting localized contact depth cues. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("sprite_placement_bed", true)) or String(art.get("sprite_placement_bed_model", "")) != "":
		push_error("Overworld smoke: mapped overworld sprite %s still reports a placement bed. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("sprite_upper_mass_backdrop", true)) or String(art.get("sprite_upper_mass_backdrop_model", "")) != "" or bool(art.get("sprite_vertical_mass_shadow", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reports upper-mass backdrop or vertical shadow support. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("mapped_sprite_grounding", false)) or String(art.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs":
		push_error("Overworld smoke: mapped overworld sprite %s does not report localized contact-scuff grounding. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if String(art.get("mapped_sprite_contact_shadow_model", "")) != "localized_sprite_contact_shadow" or not bool(art.get("mapped_sprite_contact_scuffs", false)):
		push_error("Overworld smoke: mapped overworld sprite %s does not report localized contact shadow/scuffs. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("mapped_sprite_foreground_lip", true)) or bool(art.get("mapped_sprite_support_stack", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reports foreground-lip/support-stack treatment. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if remembered and String(art.get("remembered_sprite_treatment", "")) != "ghosted_sprite_with_ground_anchor":
		push_error("Overworld smoke: remembered sprite %s did not report ghosted memory treatment. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	return true

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _remote_memory_tile_for_town(session, town_tile: Vector2i) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	var scout_radius := HeroCommandRules.scouting_radius_for_hero(session.overworld.get("hero", {}))
	for y in range(map_size.y - 1, -1, -1):
		for x in range(map_size.x - 1, -1, -1):
			var tile := Vector2i(x, y)
			if abs(tile.x - town_tile.x) + abs(tile.y - town_tile.y) <= scout_radius:
				continue
			if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
				continue
			if not _town_at(session, tile).is_empty():
				continue
			return tile
	return Vector2i(-1, -1)

func _first_unexplored_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y - 1, -1, -1):
		for x in range(map_size.x - 1, -1, -1):
			if not OverworldRules.is_tile_explored(session, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _two_step_diagonal_goal(session, start: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var first_step: Vector2i = start + offset
		var goal: Vector2i = start + (offset * 2)
		if goal.x < 0 or goal.y < 0 or goal.x >= map_size.x or goal.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, first_step.x, first_step.y):
			continue
		if OverworldRules.tile_is_blocked(session, goal.x, goal.y):
			continue
		if _tile_has_fixture_object(session, first_step) or _tile_has_fixture_object(session, goal):
			continue
		if not OverworldRules.is_tile_explored(session, goal.x, goal.y):
			continue
		return goal
	return Vector2i(-1, -1)

func _two_step_diagonal_origin(session) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var origin: Vector2i = Vector2i(x, y)
			if OverworldRules.tile_is_blocked(session, origin.x, origin.y):
				continue
			if _tile_has_fixture_object(session, origin):
				continue
			for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var first_step: Vector2i = origin + offset
				var goal: Vector2i = origin + (offset * 2)
				if goal.x < 0 or goal.y < 0 or goal.x >= map_size.x or goal.y >= map_size.y:
					continue
				if OverworldRules.tile_is_blocked(session, first_step.x, first_step.y):
					continue
				if OverworldRules.tile_is_blocked(session, goal.x, goal.y):
					continue
				if _tile_has_fixture_object(session, first_step) or _tile_has_fixture_object(session, goal):
					continue
				return origin
	return Vector2i(-1, -1)

func _diagonal_open_tile(session, start: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var tile: Vector2i = start + offset
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		if _tile_has_fixture_object(session, tile):
			continue
		return tile
	return Vector2i(-1, -1)

func _tile_has_fixture_object(session, tile: Vector2i) -> bool:
	for collection_name in ["towns", "resource_sites", "artifacts", "encounters"]:
		for entry in session.overworld.get(collection_name, []):
			if entry is Dictionary and int(entry.get("x", -1)) == tile.x and int(entry.get("y", -1)) == tile.y:
				return true
	return false

func _town_at(session, tile: Vector2i) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and int(town_value.get("x", -1)) == tile.x and int(town_value.get("y", -1)) == tile.y:
			return town_value
	return {}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _first_visible_town_tile(session) -> Vector2i:
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var tile := Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1)))
		if OverworldRules.is_tile_visible(session, tile.x, tile.y):
			return tile
	return Vector2i(-1, -1)

func _first_visible_resource_tile(session) -> Vector2i:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		if not OverworldRules.is_tile_visible(session, tile.x, tile.y):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return tile
	return Vector2i(-1, -1)

func _first_visible_artifact_tile(session) -> Vector2i:
	for node_value in session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		if not bool(node.get("collected", false)) and OverworldRules.is_tile_visible(session, tile.x, tile.y):
			return tile
	return Vector2i(-1, -1)

func _first_visible_encounter_tile(session) -> Vector2i:
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
		if OverworldRules.is_tile_visible(session, tile.x, tile.y) and not OverworldRules.is_encounter_resolved(session, encounter):
			return tile
	return Vector2i(-1, -1)

func _assert_decluttered_right_shell(shell: Node, sidebar_shell: Control, command_spine: Control, action_panel: Control, action_containers: Array) -> bool:
	if command_spine == null or not (command_spine is VBoxContainer):
		push_error("Overworld smoke: contextual drawers must use a stacked command container, not a tab strip.")
		get_tree().quit(1)
		return false
	if _contains_tab_container(sidebar_shell):
		push_error("Overworld smoke: cramped right-rail TabContainer returned and can collapse labels into vertical text.")
		get_tree().quit(1)
		return false
	if command_spine.is_visible_in_tree():
		push_error("Overworld smoke: Command/Frontier/Tile drawers must not be permanently visible at startup.")
		get_tree().quit(1)
		return false
	if action_panel == null or not action_panel.is_visible_in_tree():
		push_error("Overworld smoke: Command and Frontier must remain accessible through compact drawer buttons.")
		get_tree().quit(1)
		return false
	if shell.get_node_or_null("%MarchPanel") != null or shell.get_node_or_null("%MapHint") != null:
		push_error("Overworld smoke: old permanent movement hint or march-control footer returned.")
		get_tree().quit(1)
		return false
	for direction_button in ["MoveNorth", "MoveSouth", "MoveWest", "MoveEast"]:
		if shell.get_node_or_null("%" + direction_button) != null:
			push_error("Overworld smoke: footer march direction button %s returned." % direction_button)
			get_tree().quit(1)
			return false
	var map_cue = shell.get_node_or_null("%MapCue")
	if map_cue is Label:
		var cue_text := String((map_cue as Label).text)
		if cue_text.find("WASD") >= 0 or cue_text.find("Click route") >= 0 or cue_text.find("Click adjacent") >= 0:
			push_error("Overworld smoke: footer cue regressed into permanent movement-hint text: %s" % cue_text)
			get_tree().quit(1)
			return false
	if not _assert_drawer_toggle(shell, "command"):
		return false
	if not _assert_drawer_toggle(shell, "frontier"):
		return false
	for container in action_containers:
		if container == null or not (container is VBoxContainer):
			push_error("Overworld smoke: drawer actions must be full-width vertical command rows.")
			get_tree().quit(1)
			return false
		if container.is_visible_in_tree() and container.get_global_rect().size.x < 220.0:
			push_error("Overworld smoke: action drawer width collapsed below readable command-button width.")
			get_tree().quit(1)
			return false
		for child in container.get_children():
			if child is Button and child.visible and child.get_global_rect().size.x < 200.0:
				push_error("Overworld smoke: drawer command button collapsed into an unreadable chip.")
				get_tree().quit(1)
				return false
	if _has_vertical_text_like_label(sidebar_shell):
		push_error("Overworld smoke: right rail contains a visible label/control shaped like vertical text.")
		get_tree().quit(1)
		return false
	if not _assert_compact_rail_text(shell):
		return false
	return true

func _assert_drawer_toggle(shell: Node, drawer: String) -> bool:
	var state: Dictionary = {}
	match drawer:
		"command":
			state = shell.validation_open_command_drawer()
			if not bool(state.get("command_drawer_visible", false)):
				push_error("Overworld smoke: Command button did not open the command drawer.")
				get_tree().quit(1)
				return false
			if bool(state.get("frontier_drawer_visible", false)):
				push_error("Overworld smoke: Command drawer opened on top of the Frontier drawer.")
				get_tree().quit(1)
				return false
		"frontier":
			state = shell.validation_open_frontier_drawer()
			if not bool(state.get("frontier_drawer_visible", false)):
				push_error("Overworld smoke: Frontier button did not open the frontier drawer.")
				get_tree().quit(1)
				return false
			if bool(state.get("command_drawer_visible", false)):
				push_error("Overworld smoke: Frontier drawer opened on top of the Command drawer.")
				get_tree().quit(1)
				return false
		_:
			push_error("Overworld smoke: unknown drawer assertion %s." % drawer)
			get_tree().quit(1)
			return false
	if bool(state.get("order_panel_visible", false)):
		push_error("Overworld smoke: hidden Order panel became permanent while opening %s." % drawer)
		get_tree().quit(1)
		return false
	shell._on_close_drawers_pressed()
	var closed_state: Dictionary = shell._validation_chrome_state()
	if bool(closed_state.get("command_spine_visible", false)):
		push_error("Overworld smoke: drawer spine stayed visible after closing %s." % drawer)
		get_tree().quit(1)
		return false
	return true

func _assert_compact_rail_text(shell: Node) -> bool:
	var label_budgets := {
		"Event": 1,
		"Commitment": 2,
		"Briefing": 2,
		"Hero": 2,
		"Army": 1,
		"Heroes": 1,
		"Context": 2,
		"Specialties": 1,
		"Spellbook": 1,
		"Artifacts": 1,
		"Visibility": 1,
		"Objectives": 1,
		"Threats": 1,
		"Forecast": 1,
	}
	for label_name in label_budgets.keys():
		var label_node = shell.get_node_or_null("%" + String(label_name))
		if not (label_node is Label):
			push_error("Overworld smoke: compact rail label %s is missing." % String(label_name))
			get_tree().quit(1)
			return false
		var label := label_node as Label
		if not label.is_visible_in_tree():
			continue
		var lines := _visible_text_lines(label.text)
		if lines.size() > int(label_budgets[label_name]):
			push_error("Overworld smoke: %s rail label has %d visible lines; budget is %d." % [String(label_name), lines.size(), int(label_budgets[label_name])])
			get_tree().quit(1)
			return false
		if label.text.find("+ ") >= 0 and label.text.find("more") >= 0:
			push_error("Overworld smoke: %s rail label exposes hidden-report '+ more' wording." % String(label_name))
			get_tree().quit(1)
			return false
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or not label.clip_text:
			push_error("Overworld smoke: %s rail label must trim overflow instead of wrapping into a text wall." % String(label_name))
			get_tree().quit(1)
			return false
		for line in lines:
			if String(line).length() > 48:
				push_error("Overworld smoke: %s rail label line is too long for the compact right rail: %s" % [String(label_name), String(line)])
				get_tree().quit(1)
				return false
	return true

func _visible_text_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw_line in text.split("\n", false):
		var line := raw_line.strip_edges()
		if line != "":
			lines.append(line)
	return lines

func _contains_tab_container(node: Node) -> bool:
	if node is TabContainer:
		return true
	for child in node.get_children():
		if _contains_tab_container(child):
			return true
	return false

func _has_vertical_text_like_label(node: Node) -> bool:
	if node is Label or node is Button:
		var control := node as Control
		if control.is_visible_in_tree():
			var text := ""
			if node is Label:
				text = String((node as Label).text)
			elif node is Button:
				text = String((node as Button).text)
			text = text.strip_edges()
			var rect := control.get_global_rect()
			if text.length() >= 5 and rect.size.x < 70.0 and rect.size.y > rect.size.x * 1.4:
				return true
	for child in node.get_children():
		if _has_vertical_text_like_label(child):
			return true
	return false

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false
