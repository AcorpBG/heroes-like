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
