extends Control

const TARGET_VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1024.0, 600.0),
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in TARGET_VIEWPORT_SIZES:
		if not await _run_layout_case(viewport_size):
			return
	get_tree().quit(0)

func _run_layout_case(viewport_size: Vector2) -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var target_town := _first_enemy_town(session)
	if target_town.is_empty():
		push_error("Battle layout smoke: could not find an enemy town assault target.")
		get_tree().quit(1)
		return false

	session.battle = BattleRules.create_town_assault_payload(session, String(target_town.get("placement_id", "")))
	if session.battle.is_empty():
		push_error("Battle layout smoke: could not stage a town-assault battle.")
		get_tree().quit(1)
		return false
	SessionState.set_active_session(session)

	var frame := Control.new()
	frame.name = "BattleLayoutFrame"
	frame.size = viewport_size
	add_child(frame)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_rect := frame.get_global_rect()
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null:
		push_error("Battle layout smoke: battle board did not load.")
		get_tree().quit(1)
		return false

	var board_rect := board.get_global_rect()
	if board_rect.size.x < 520.0 or board_rect.size.y < 240.0:
		push_error("Battle layout smoke: tactical board collapsed below a usable surface at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if board_rect.position.x < viewport_rect.position.x - 1.0 or board_rect.position.y < viewport_rect.position.y - 1.0:
		push_error("Battle layout smoke: tactical board rendered outside the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false
	if board_rect.end.x > viewport_rect.end.x + 1.0 or board_rect.end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: tactical board overflowed the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	var banner: Control = shell.get_node_or_null("%Banner")
	if banner == null or banner.get_global_rect().position.y < viewport_rect.position.y - 1.0:
		push_error("Battle layout smoke: battle header is clipped above the viewport at %s: banner=%s viewport=%s." % [viewport_size, banner.get_global_rect() if banner != null else Rect2(), viewport_rect])
		get_tree().quit(1)
		return false

	var footer: Control = shell.get_node_or_null("%Footer")
	if footer == null or footer.get_global_rect().end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: battle command footer overflowed the viewport at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	var advance_button: Button = shell.get_node_or_null("%Advance")
	if advance_button == null or not viewport_rect.intersects(advance_button.get_global_rect()):
		push_error("Battle layout smoke: primary battle controls are not visible at %s." % [viewport_size])
		get_tree().quit(1)
		return false

	frame.queue_free()
	await get_tree().process_frame
	return true

func _first_enemy_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			return town
	return {}
