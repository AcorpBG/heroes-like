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
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else "foreground_ground_lip"
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		push_error("Overworld smoke: %s marker no longer reports the expected foreground contact model. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		push_error("Overworld smoke: %s marker lacks the terrain-grounded anchor needed to read against the map. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	else:
		if not bool(readability.get("terrain_quieting_bed", false)) or String(readability.get("placement_bed_model", "")) != "footprint_terrain_quieting_bed" or String(readability.get("placement_bed_shape", "")) != "organic_footprint_clearing":
			push_error("Overworld smoke: %s marker lacks the footprint-aware terrain quieting bed. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if bool(readability.get("placement_bed_ui_plate", true)) or not bool(readability.get("placement_bed_terrain_tinted", false)) or float(readability.get("placement_bed_alpha", 0.0)) < 0.28:
			push_error("Overworld smoke: %s placement bed regressed toward a generic UI plate or became too faint. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if not _assert_upper_mass_backdrop(readability, expected_kind):
			return false
		if not bool(readability.get("foreground_occlusion_lip", false)):
			push_error("Overworld smoke: %s marker lacks the foreground ground lip that seats it into terrain. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if String(readability.get("depth_cue_model", "")) != "footprint_cast_shadow_with_base_occlusion":
			push_error("Overworld smoke: %s marker lacks the footprint cast-shadow/base-occlusion depth model. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if not bool(readability.get("directional_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "directional_footprint_cast_shadow":
			push_error("Overworld smoke: %s marker lacks a directional contact shadow. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if not bool(readability.get("base_occlusion_pads", false)) or String(readability.get("base_occlusion_model", "")) != "foreground_base_occlusion_pads":
			push_error("Overworld smoke: %s marker lacks base occlusion pads at the terrain contact edge. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if float(readability.get("contact_shadow_alpha", 0.0)) < 0.28 or float(readability.get("base_occlusion_alpha", 0.0)) < 0.30:
			push_error("Overworld smoke: %s marker contact-depth cues are too faint to support object-first readability. presentation=%s" % [expected_kind, presentation])
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
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or not bool(town_presentation.get("entry_apron_cue", false)) or not bool(town_presentation.get("gate_cue", false)):
			push_error("Overworld smoke: town presentation lacks blocked non-entry tiles or the entry apron/gate cue. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < 0.60 or float(readability.get("footprint_anchor_height_fraction", 0.0)) < 0.20:
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
		if not is_town and (float(readability.get("anchor_alpha", 0.0)) < 0.30 or float(readability.get("outline_alpha", 0.0)) < 0.85 or float(readability.get("grid_alpha", 1.0)) > 0.42):
			push_error("Overworld smoke: visible %s marker grounding or map contrast regressed. presentation=%s" % [expected_kind, presentation])
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
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "sparse_wall_and_entry_cues_no_underlay":
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
	if String(town_presentation.get("footprint_cue_model", "")) != "sparse_wall_and_entry_cues_no_underlay":
		push_error("Overworld smoke: town footprint cue metadata does not describe sparse non-entry/approach cues. presentation=%s" % presentation)
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

func _assert_upper_mass_backdrop(readability: Dictionary, label: String) -> bool:
	if not bool(readability.get("upper_mass_backdrop", false)) or String(readability.get("upper_mass_backdrop_model", "")) != "family_scaled_rear_backdrop_wash":
		push_error("Overworld smoke: %s lacks the rear upper-mass backdrop cue needed to separate tall objects from terrain. readability=%s" % [label, readability])
		get_tree().quit(1)
		return false
	if String(readability.get("upper_mass_backdrop_shape", "")) != "family_scaled_rear_wash" or String(readability.get("upper_mass_backdrop_position", "")) != "behind_upper_body":
		push_error("Overworld smoke: %s rear backdrop is not reported as a family-scaled behind-body wash. readability=%s" % [label, readability])
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop_ui_halo", true)) or bool(readability.get("upper_mass_backdrop_ui_badge", true)):
		push_error("Overworld smoke: %s rear backdrop regressed into a UI halo or badge treatment. readability=%s" % [label, readability])
		get_tree().quit(1)
		return false
	if float(readability.get("upper_mass_backdrop_alpha", 0.0)) < 0.20 or float(readability.get("upper_mass_backdrop_alpha", 1.0)) > 0.34:
		push_error("Overworld smoke: %s rear backdrop alpha is outside the subtle terrain-depth cue range. readability=%s" % [label, readability])
		get_tree().quit(1)
		return false
	if float(readability.get("upper_mass_backdrop_height_fraction", 0.0)) < 0.32 or float(readability.get("upper_mass_backdrop_width_fraction", 0.0)) < 0.24:
		push_error("Overworld smoke: %s rear backdrop is too small to separate upper mass from busy terrain. readability=%s" % [label, readability])
		get_tree().quit(1)
		return false
	if not bool(readability.get("vertical_mass_shadow", false)) or String(readability.get("vertical_mass_shadow_model", "")) != "subtle_vertical_mass_shadow" or float(readability.get("vertical_mass_shadow_alpha", 0.0)) < 0.14:
		push_error("Overworld smoke: %s lacks the subtle vertical mass shadow paired with the rear backdrop. readability=%s" % [label, readability])
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
	if String(grass_terrain.get("rendering_mode", "")) != "original_quiet_tile_bank":
		push_error("Overworld smoke: original quiet terrain tile bank is not active on the overworld map. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("uses_sampled_texture", true)) or bool(grass_terrain.get("generated_source_primary", true)) or not bool(grass_terrain.get("uses_original_tile_bank", false)) or not bool(grass_terrain.get("texture_loaded", false)):
		push_error("Overworld smoke: overworld terrain is not reporting the original non-generated tile bank. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("primary_base_model", "")) != "original_quiet_tile_bank" or String(grass_terrain.get("terrain_noise_profile", "")) != "quiet_low_contrast_macro_readable":
		push_error("Overworld smoke: overworld terrain does not expose the quiet macro-readable base model. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_variant_selection", "")) != "patch_cohesive_low_frequency" or String(grass_terrain.get("grasslands_base_cohesion", "")) != "grass_plains_shared_palette":
		push_error("Overworld smoke: grass/plains terrain does not expose the cohesive low-frequency variant contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_group", "")) != "grasslands" or String(grass_terrain.get("style_id", "")) == "":
		push_error("Overworld smoke: grass terrain does not expose grammar group/style metadata. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("road_overlay", false)) or String(grass_terrain.get("road_overlay_id", "")) != "road_dirt" or not bool(grass_terrain.get("road_overlay_art", false)) or String(grass_terrain.get("road_shape_model", "")) != "connection_piece_overlay":
		push_error("Overworld smoke: authored River Pass road overlay is not using structural road art on the main route. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(grass_terrain.get("road_joint_cap", false)):
		push_error("Overworld smoke: River Pass road intersection does not expose the connection-aware joint cap contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false

	var forest_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var forest_terrain: Dictionary = forest_presentation.get("terrain_presentation", {})
	if String(forest_terrain.get("terrain_group", "")) != "forest" or int(forest_terrain.get("edge_transition_count", 0)) <= 0 or not bool(forest_terrain.get("edge_transition_art_loaded", false)) or String(forest_terrain.get("transition_shape_model", "")) != "jagged_directional_overlay":
		push_error("Overworld smoke: forest edge transition art is missing the jagged directional overlay path. presentation=%s" % forest_presentation)
		get_tree().quit(1)
		return false
	if String(forest_terrain.get("transition_edge_treatment", "")) != "soft_feathered_jagged_overlay":
		push_error("Overworld smoke: forest edge transition art is not reporting the softened feathered treatment. presentation=%s" % forest_presentation)
		get_tree().quit(1)
		return false

	var session = SessionState.ensure_active_session()
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
	return true

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
		if String(art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(art.get("town_footprint_cue_model", "")) != "sparse_wall_and_entry_cues_no_underlay":
			push_error("Overworld smoke: town art metadata does not expose the corrected footprint grounding model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if bool(art.get("town_base_ellipse", true)) or bool(art.get("town_underlay", true)) or bool(art.get("town_cast_shadow", true)) or bool(art.get("town_vertical_mass_shadow", true)):
			push_error("Overworld smoke: town art metadata still exposes removed ellipse/underlay/shadow treatment. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		return true
	if String(art.get("sprite_settlement_model", "")) != "footprint_scaled_sprite_with_ground_lip" or not bool(art.get("settled_sprite_occlusion", false)):
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the footprint-scaled settlement/occlusion treatment. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("sprite_depth_contact_cues", false)) or String(art.get("sprite_depth_cue_model", "")) != "footprint_cast_shadow_with_base_occlusion":
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the deeper footprint/contact depth cues. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("sprite_placement_bed", false)) or String(art.get("sprite_placement_bed_model", "")) != "footprint_terrain_quieting_bed":
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the footprint-aware terrain quieting bed. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("sprite_upper_mass_backdrop", false)) or String(art.get("sprite_upper_mass_backdrop_model", "")) != "family_scaled_rear_backdrop_wash" or not bool(art.get("sprite_vertical_mass_shadow", false)):
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the rear upper-mass backdrop treatment. presentation=%s" % [expected_asset_id, presentation])
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
