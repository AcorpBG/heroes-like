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

	var map_node = shell.get_node_or_null("Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MapFrame/MapInset/Map")
	if map_node == null:
		push_error("Overworld smoke: visual map node did not load.")
		get_tree().quit(1)
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
