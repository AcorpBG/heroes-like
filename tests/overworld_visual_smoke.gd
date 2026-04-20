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
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	if expected_kind not in object_kinds:
		push_error("Overworld smoke: expected %s marker kind was missing. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("contrast_plate", false)):
		push_error("Overworld smoke: %s marker lacks the contrast plate needed to stand off terrain. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		push_error("Overworld smoke: %s marker symbol is too small for at-a-glance readability. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if remembered:
		if not bool(readability.get("memory_echo", false)):
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
		if float(readability.get("plate_alpha", 0.0)) < 0.50 or float(readability.get("outline_alpha", 0.0)) < 0.85:
			push_error("Overworld smoke: visible %s marker contrast is too weak. presentation=%s" % [expected_kind, presentation])
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
	if String(grass_terrain.get("rendering_mode", "")) != "authored_autotile_layers":
		push_error("Overworld smoke: authored terrain grammar is not active on the overworld map. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("uses_sampled_texture", true)) or bool(grass_terrain.get("texture_loaded", true)):
		push_error("Overworld smoke: overworld terrain still reports sampled texture rendering. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_group", "")) != "grasslands" or String(grass_terrain.get("style_id", "")) == "":
		push_error("Overworld smoke: grass terrain does not expose grammar group/style metadata. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("road_overlay", false)) or String(grass_terrain.get("road_overlay_id", "")) != "road_dirt":
		push_error("Overworld smoke: authored River Pass road overlay is not structural on the main route. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false

	var forest_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var forest_terrain: Dictionary = forest_presentation.get("terrain_presentation", {})
	if String(forest_terrain.get("terrain_group", "")) != "forest" or int(forest_terrain.get("edge_transition_count", 0)) <= 0:
		push_error("Overworld smoke: forest edge transition metadata is missing on the authored terrain grammar path. presentation=%s" % forest_presentation)
		get_tree().quit(1)
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
	return true

func _assert_art_sprite(presentation: Dictionary, expected_asset_id: String, remembered: bool) -> bool:
	var art: Dictionary = presentation.get("art_presentation", {})
	var asset_ids: Array = art.get("sprite_asset_ids", [])
	if not bool(art.get("uses_asset_sprite", false)) or expected_asset_id not in asset_ids:
		push_error("Overworld smoke: expected overworld sprite %s was not used. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("fallback_procedural_marker", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reported procedural fallback. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if remembered and String(art.get("remembered_sprite_treatment", "")) != "ghosted_sprite_with_memory_plate":
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
