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

	get_tree().quit(0)

func _assert_wireframe_contract(shell: Node) -> bool:
	var map_panel: Control = shell.get_node_or_null("%MapPanel")
	var map_frame: Control = shell.get_node_or_null("%MapFrame")
	var sidebar_shell: Control = shell.get_node_or_null("%SidebarShell")
	var command_band: Control = shell.get_node_or_null("%CommandBand")
	var top_strip: Control = shell.get_node_or_null("%TopStrip")
	var event_panel: Control = shell.get_node_or_null("%EventPanel")
	var commitment_panel: Control = shell.get_node_or_null("%CommitmentPanel")
	var briefing_panel: Control = shell.get_node_or_null("%BriefingPanel")
	var resource_chip: Control = shell.get_node_or_null("%ResourceChip")
	var status_chip: Control = shell.get_node_or_null("%StatusChip")
	var cue_chip: Control = shell.get_node_or_null("%CueChip")
	var required_nodes = [
		map_panel,
		map_frame,
		sidebar_shell,
		command_band,
		top_strip,
		event_panel,
		commitment_panel,
		briefing_panel,
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
			push_error("Overworld smoke: contextual panels must live inside the carved right command spine.")
			get_tree().quit(1)
			return false
	for chip in [resource_chip, status_chip, cue_chip]:
		if not _is_descendant_of(chip, command_band):
			push_error("Overworld smoke: resources, date, and map cue must live inside the footer ribbon.")
			get_tree().quit(1)
			return false
	return true

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false
