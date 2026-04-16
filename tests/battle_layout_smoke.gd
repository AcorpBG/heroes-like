extends Control

const TARGET_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var target_town := _first_enemy_town(session)
	if target_town.is_empty():
		push_error("Battle layout smoke: could not find an enemy town assault target.")
		get_tree().quit(1)
		return

	session.battle = BattleRules.create_town_assault_payload(session, String(target_town.get("placement_id", "")))
	if session.battle.is_empty():
		push_error("Battle layout smoke: could not stage a town-assault battle.")
		get_tree().quit(1)
		return
	SessionState.set_active_session(session)

	var frame := Control.new()
	frame.name = "BattleLayoutFrame"
	frame.size = TARGET_VIEWPORT_SIZE
	add_child(frame)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_rect := Rect2(Vector2.ZERO, TARGET_VIEWPORT_SIZE)
	var board: Control = shell.get_node_or_null("%BattleBoard")
	if board == null:
		push_error("Battle layout smoke: battle board did not load.")
		get_tree().quit(1)
		return

	var board_rect := board.get_global_rect()
	if board_rect.size.x < 560.0 or board_rect.size.y < 260.0:
		push_error("Battle layout smoke: tactical board collapsed below a usable surface.")
		get_tree().quit(1)
		return
	if board_rect.position.x < -1.0 or board_rect.position.y < -1.0:
		push_error("Battle layout smoke: tactical board rendered outside the viewport.")
		get_tree().quit(1)
		return
	if board_rect.end.x > viewport_rect.end.x + 1.0 or board_rect.end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: tactical board overflowed the viewport.")
		get_tree().quit(1)
		return

	var banner: Control = shell.get_node_or_null("%Banner")
	if banner == null or banner.get_global_rect().position.y < -1.0:
		push_error("Battle layout smoke: battle header is clipped above the viewport.")
		get_tree().quit(1)
		return

	var footer: Control = shell.get_node_or_null("%Footer")
	if footer == null or footer.get_global_rect().end.y > viewport_rect.end.y + 1.0:
		push_error("Battle layout smoke: battle command footer overflowed the viewport.")
		get_tree().quit(1)
		return

	var advance_button: Button = shell.get_node_or_null("%Advance")
	if advance_button == null or not viewport_rect.intersects(advance_button.get_global_rect()):
		push_error("Battle layout smoke: primary battle controls are not visible.")
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _first_enemy_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			return town
	return {}
