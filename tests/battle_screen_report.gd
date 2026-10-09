extends Node
## The battle screen (docs/battle-rework.md, slice 5) on a generated small map.
## The field fills the window: the heroes stand beside their armies with their
## plates below, the turn ribbon runs along the top and the command bar along
## the bottom. No part of the HUD covers a hex, another HUD part or the edge of
## the window, from 1280x720 to 1920x1080 and at 4:3 and 21:9, and the
## player's UI scale (Settings) enlarges it.
##
## A whole battle is played by mouse alone: the hero is clicked for the
## spellbook, a spell and then a lit stack, Wait on the bar, then enemies and
## hexes on the field until the result, which is dismissed with Continue. The
## hero's army is grown for the mouse and keyboard battles so they last some
## rounds and end in victory; auto battle and Quick Resolve fight with the
## army the map gave, which loses.
## Another is played by keyboard alone: Esc, Tab, S, Enter, the arrows, W and
## D, and Enter on Continue. Quick Resolve leaves the bar after the first
## order, the hero's cast keeps the stack's turn, auto battle plays the
## player's turns and stops when the player gives an order, and Quick Resolve
## through the harness API ends with the result over the field.
##
## A rendering run given "-- --capture-dir=<dir>" saves a screenshot of each
## state for review instead of checking layouts at other sizes.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_SCREEN_REPORT"
const SEED := "battle-screen-20261010"
const LAYOUT_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1920, 1440), Vector2i(2560, 1080)]
const PLAY_SIZE := Vector2i(1920, 1080)
## Orders after which a battle that has not ended counts as stuck.
const MAX_ORDERS := 160
const RESULT_WAIT_MSEC := 20000
const PLAYBACK_WAIT_MSEC := 30000
## A hero to stand for the enemy in the two-hero capture.
const CAPTURE_ENEMY_HERO_ID := "hero_thornwake_ardren_briarmarshal"

var _checks := 0
var _failures: Array[String] = []
var _details := {}
var _capture_dir := ""
var _base_session = null
## The hero with the army the map gave: auto battle and Quick Resolve.
var _starting_session = null


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--capture-dir="):
			_capture_dir = String(arg).trim_prefix("--capture-dir=")
	if _capture_dir != "":
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		SettingsService.set_battle_playback_speed_id("fast")
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	_base_session = _session()
	if _base_session != null:
		if _capture_dir == "":
			for size in LAYOUT_SIZES:
				await _check_layout(size)
			# 150% UI scale in a 1920x1080 window: the canvas is 1280x720 and
			# the HUD keeps its 1920x1080 size on screen, so 1.5 times larger.
			await _check_layout(Vector2i(1280, 720), 1.5)
			for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
				await _check_two_heroes(size)
		else:
			await _check_two_heroes(PLAY_SIZE)
		await _play_by_mouse()
		if _capture_dir == "":
			await _play_by_keyboard()
			await _check_auto_battle()
			await _check_quick_resolve()
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- Setup ---------------------------------------------------------------------

## The weakest guard of two or more stacks on the map, fought by a hero who
## knows a battle spell.
func _session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var best := {}
	var best_health := INF
	for encounter in session.overworld.get("encounters", []):
		var battle := BattleRules.create_battle_payload(session, encounter)
		var enemies := _living(battle, "enemy")
		if enemies.size() < 2 or int(BattleRules.hero_presentation(battle, "player").get("battle_spell_count", 0)) <= 0:
			continue
		var health := 0.0
		for stack in enemies:
			health += float(stack.get("total_health", 0))
		if health < best_health:
			best_health = health
			best = battle
	_check(not best.is_empty(), "a guard of two or more stacks to fight on the generated map")
	if best.is_empty():
		return null
	session.battle = best
	session.game_state = "battle"
	_details["encounter"] = String(best.get("encounter_id", ""))
	_details["enemy_stacks"] = _living(best, "enemy").size()
	_starting_session = SessionState.set_active_session(session)
	# Three times the guard's health: a battle of some rounds that the hero wins.
	var player_health := 0.0
	for stack in _living(best, "player"):
		player_health += float(stack.get("total_health", 0))
	var factor := maxi(1, ceili(3.0 * best_health / maxf(1.0, player_health)))
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary:
			stack["count"] = int(stack.get("count", 0)) * factor
	var encounter_placement := {}
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and OverworldRules.encounter_key(encounter) == String(best.get("resolved_key", "")):
			encounter_placement = encounter
	session.battle = BattleRules.create_battle_payload(session, encounter_placement)
	_check(_living(session.battle, "player").size() == _living(best, "player").size(), "the grown army fights the same guard")
	_details["army_factor"] = factor
	return session


func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)


## Opens the battle screen on a fresh copy of the battle in a frame of size.
func _open_shell(size: Vector2i, prepare: Callable = Callable(), base = null):
	var session = SessionState.set_active_session(base if base != null else _base_session)
	if prepare.is_valid():
		prepare.call(session)
	var frame := Control.new()
	frame.name = "BattleFrame"
	frame.size = Vector2(size) if _capture_dir == "" else get_viewport().get_visible_rect().size
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	return shell


func _close_shell(shell) -> void:
	var frame: Node = shell.get_parent()
	frame.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(shell) -> void:
	var deadline := Time.get_ticks_msec() + PLAYBACK_WAIT_MSEC
	while (shell._action_playback_in_progress or shell._battle_exit_handoff_in_progress) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


func _wait_for_result(shell) -> bool:
	var deadline := Time.get_ticks_msec() + RESULT_WAIT_MSEC
	while not shell._battle_over and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame
	return shell._battle_over


func _capture(label: String) -> void:
	if _capture_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_dir.path_join("%s.png" % label))


# --- Input ---------------------------------------------------------------------

func _click_at(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var viewport := get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(6.0, 0.0)
	viewport.push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = position
		event.global_position = position
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame


func _hover_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(6.0, 0.0)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _click_control(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _stack_position(board, battle_id: String) -> Vector2:
	var layout: Dictionary = board._current_hex_layout()
	return board.global_position + board._hex_center(board._stack_cell_for_battle_id(battle_id), layout)


func _hex_position(board, q: int, r: int) -> Vector2:
	return board.global_position + board._hex_center(Vector2i(q, r), board._current_hex_layout())


## The order a player gives: attack an enemy a click on it reaches, else walk
## to the reachable hex nearest an enemy, else defend.
func _next_order(battle: Dictionary) -> Dictionary:
	var enemies := _living(battle, "enemy")
	for stack in enemies:
		var battle_id := String(stack.get("battle_id", ""))
		if String(BattleRules.board_click_attack_intent_for_target(battle, battle_id).get("action", "")) != "":
			return {"kind": "stack", "battle_id": battle_id}
	var best := {}
	var best_distance := 999
	for destination in BattleRules.legal_destinations_for_active_stack(battle):
		if not (destination is Dictionary):
			continue
		for stack in enemies:
			var distance := BattleRules._hex_distance(destination, BattleRules._stack_hex(stack))
			if distance < best_distance:
				best_distance = distance
				best = destination
	if not best.is_empty():
		return {"kind": "hex", "q": int(best.get("q", -1)), "r": int(best.get("r", -1))}
	return {"kind": "defend"}


func _order_cell(board, order: Dictionary) -> Vector2i:
	if String(order.get("kind", "")) == "stack":
		return board._stack_cell_for_battle_id(String(order.get("battle_id", "")))
	return Vector2i(int(order.get("q", -1)), int(order.get("r", -1)))


# --- Layout --------------------------------------------------------------------

func _check_layout(size: Vector2i, ui_scale_factor: float = 1.0) -> void:
	var window := get_window()
	var factor_before := window.content_scale_factor
	window.content_scale_factor = ui_scale_factor
	var shell = await _open_shell(size)
	var board = shell._battle_board_view
	var label := "%dx%d" % [size.x, size.y] if is_equal_approx(ui_scale_factor, 1.0) else "%dx%d at %d%% UI scale" % [size.x, size.y, roundi(ui_scale_factor * 100.0)]
	var expected_scale := minf(float(size.x) / 1920.0, float(size.y) / 1080.0) * ui_scale_factor
	_check(absf(board.ui_scale() - expected_scale) < 0.01, "%s: the HUD scales by %.2f (%.2f)" % [label, expected_scale, board.ui_scale()])
	var hud: Dictionary = shell.validation_hud_snapshot()
	var rects: Dictionary = hud.get("rects", {})
	_check(hud.get("clipped", []).is_empty(), "%s: the HUD stays inside the window %s" % [label, hud.get("clipped", [])])
	_check(hud.get("overlaps", []).is_empty(), "%s: no two HUD parts overlap %s" % [label, hud.get("overlaps", [])])
	_check(rects.has("command_bar") and rects.has("player_plate") and rects.has("log_line"), "%s: the command bar, the log line and the player's plate show %s" % [label, rects.keys()])
	var k: float = board.ui_scale()
	if rects.has("command_bar"):
		var bar: Rect2 = rects["command_bar"]
		_check(absf(bar.get_center().x - float(size.x) * 0.5) <= 1.5, "%s: the command bar is centred (%s)" % [label, bar])
		_check(absf(bar.end.y - (float(size.y) - 12.0 * k)) <= 1.5, "%s: the command bar sits on the bottom edge (%s)" % [label, bar])
	# No HUD part covers a hex: the field stays clickable everywhere.
	var layout: Dictionary = board._current_hex_layout()
	var covered := _covered_hexes(board, rects)
	_check(covered.is_empty(), "%s: the HUD and the ribbon cover no hex %s" % [label, covered.slice(0, 8)])
	# The hero stands outside the grid with its plate below its feet.
	var figure: Dictionary = board.hero_figure_layout("player")
	var grid: Rect2 = layout.get("rect", Rect2())
	_check(bool(figure.get("has_figure", false)), "%s: the player's hero stands on the field" % label)
	var hit: Rect2 = figure.get("hit_rect", Rect2())
	_check(hit.end.x <= grid.position.x + 1.0 and hit.position.x >= 0.0, "%s: the player's hero stands left of the grid (%s, grid %s)" % [label, hit, grid])
	if rects.has("player_plate"):
		var plate: Rect2 = rects["player_plate"]
		var foot: Vector2 = figure.get("foot", Vector2.ZERO)
		_check(plate.position.y >= foot.y - 1.0 and plate.position.x <= foot.x and plate.end.x >= foot.x, "%s: the plate hangs below the hero's feet (%s, foot %s)" % [label, plate, foot])
		_check(not (rects.get("command_bar", Rect2()) as Rect2).intersects(plate), "%s: the plate clears the command bar" % label)
	var buttons: Dictionary = hud.get("buttons", {})
	for name in ["Options", "Surrender", "Retreat", "AutoBattle", "QuickResolve", "Spellbook", "Wait", "Defend"]:
		var button: Dictionary = buttons.get(name, {})
		_check(bool(button.get("visible", false)), "%s: %s is on the command bar" % [label, name])
		_check(String(button.get("tooltip", "")) != "", "%s: %s has a tooltip" % [label, name])
	_check(String((buttons.get("Spellbook", {}) as Dictionary).get("badge", "")) != "", "%s: the spellbook shows the hero's mana" % label)
	_check(String(hud.get("log_line_text", "")).strip_edges() != "", "%s: the log line says something" % label)
	var plates: Dictionary = hud.get("plates", {})
	var player_plate: Dictionary = plates.get("player", {})
	_check(String(player_plate.get("name", "")) != "" and String(player_plate.get("mana_text", "")).contains("/"), "%s: the plate names the hero and its mana %s" % [label, player_plate])
	_check(bool(player_plate.get("portrait_visible", false)) or bool(player_plate.get("crest_visible", false)), "%s: the plate carries the hero's portrait or crest" % label)
	_details["layout_%s" % label] = {"scale": k, "rects": _rect_strings(rects)}
	await _close_shell(shell)
	window.content_scale_factor = factor_before


## The hexes the command bar, a plate or the ribbon would cover.
func _covered_hexes(board, rects: Dictionary) -> Array[String]:
	var layout: Dictionary = board._current_hex_layout()
	var radius := float(layout.get("radius", 1.0))
	var hex_width := float(layout.get("hex_width", radius * sqrt(3.0)))
	var hex_height := 2.0 * radius * float(layout.get("vertical_scale", 1.0))
	var covered: Array[String] = []
	for q in range(BattleRules.BATTLE_HEX_COLUMNS):
		for r in range(BattleRules.BATTLE_HEX_ROWS):
			var center: Vector2 = board._hex_center(Vector2i(q, r), layout)
			var hex_box := Rect2(center - Vector2(hex_width, hex_height) * 0.42, Vector2(hex_width, hex_height) * 0.84)
			for key in ["command_bar", "player_plate", "enemy_plate"]:
				if rects.has(key) and (rects[key] as Rect2).intersects(hex_box):
					covered.append("%s:%d,%d" % [key, q, r])
			if board._ribbon_rect().intersects(hex_box):
				covered.append("ribbon:%d,%d" % [q, r])
	return covered


## An open popover fits the window and covers neither the bar nor a plate.
func _check_open_hud(shell, label: String) -> void:
	var hud: Dictionary = shell.validation_hud_snapshot()
	_check(hud.get("clipped", []).is_empty(), "%s stays inside the window %s %s" % [label, hud.get("clipped", []), _rect_strings(hud.get("rects", {}))])
	_check(hud.get("overlaps", []).is_empty(), "%s covers no other HUD part %s %s" % [label, hud.get("overlaps", []), _rect_strings(hud.get("rects", {}))])


func _rect_strings(rects: Dictionary) -> Dictionary:
	var out := {}
	for key in rects:
		var rect: Rect2 = rects[key]
		out[key] = [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]
	return out


## Both heroes on the field, the right-hand one mirrored to face it: each
## plate hangs under its hero's feet with the whole name and covers no hex.
func _check_two_heroes(size: Vector2i) -> void:
	var commander := ContentService.get_hero(CAPTURE_ENEMY_HERO_ID)
	var shell = await _open_shell(size, func(session):
		var enemy_hero: Dictionary = session.battle.get("enemy_hero", {}) if session.battle.get("enemy_hero", {}) is Dictionary else {}
		enemy_hero["id"] = CAPTURE_ENEMY_HERO_ID
		enemy_hero["name"] = String(commander.get("name", ""))
		enemy_hero["faction_id"] = String(commander.get("faction_id", ""))
		session.battle["enemy_hero"] = enemy_hero
	)
	var label := "two heroes %dx%d" % [size.x, size.y]
	var hud: Dictionary = shell.validation_hud_snapshot()
	var plates: Dictionary = hud.get("plates", {})
	for side: String in ["player", "enemy"]:
		var plate: Dictionary = plates.get(side, {})
		var figure: Dictionary = plate.get("figure", {})
		var rect: Rect2 = plate.get("rect", Rect2())
		var foot: Vector2 = figure.get("foot", Vector2.ZERO)
		var grid: Rect2 = figure.get("grid_rect", Rect2())
		var hit: Rect2 = figure.get("hit_rect", Rect2())
		_check(bool(figure.get("has_figure", false)) and bool(plate.get("visible", false)), "%s: the %s's hero stands on the field with its plate" % [label, side])
		_check(is_equal_approx(float(figure.get("facing", 0.0)), -1.0 if side == "enemy" else 1.0), "%s: the %s's hero faces the field (%s)" % [label, side, figure.get("facing", 0.0)])
		var beside := hit.end.x <= grid.position.x + 1.0 if side == "player" else hit.position.x >= grid.end.x - 1.0
		_check(beside, "%s: the %s's hero stands beside the grid (%s, grid %s)" % [label, side, hit, grid])
		_check(rect.position.y >= foot.y - 1.0 and rect.position.x <= foot.x and rect.end.x >= foot.x, "%s: the %s's plate hangs below its hero's feet (%s, foot %s)" % [label, side, rect, foot])
		_check(bool(plate.get("name_fits", false)), "%s: the %s's plate shows the whole name (%s)" % [label, side, plate.get("name", "")])
	_check(String((plates.get("enemy", {}) as Dictionary).get("name", "")) == String(commander.get("name", "")), "%s: the enemy's plate names its commander" % label)
	_check(hud.get("clipped", []).is_empty() and hud.get("overlaps", []).is_empty(), "%s: the HUD fits the window without overlaps %s %s" % [label, hud.get("clipped", []), hud.get("overlaps", [])])
	var covered := _covered_hexes(shell._battle_board_view, hud.get("rects", {}))
	_check(covered.is_empty(), "%s: the plates cover no hex %s" % [label, covered.slice(0, 8)])
	if _capture_dir != "":
		await _capture("two_heroes")
	await _close_shell(shell)


# --- A battle by mouse ---------------------------------------------------------

func _play_by_mouse() -> void:
	var shell = await _open_shell(PLAY_SIZE)
	var board = shell._battle_board_view
	var session = SessionState.ensure_active_session()
	_check(bool(shell._quick_resolve_button.visible), "mouse: Quick Resolve is offered before the first order")
	await _capture("start")
	# Hovering an enemy forecasts the attack beside the pointer.
	var enemy_id := String(_living(session.battle, "enemy")[0].get("battle_id", ""))
	await _hover_at(_stack_position(board, enemy_id))
	_check(board._hover_forecast_lines().size() > 0, "mouse: hovering an enemy shows a forecast beside the pointer")
	await _capture("hover_enemy")
	await _cast_by_mouse(shell, board, session)
	# Wait on the bar: the stack goes to the end of the round.
	var waiting_id := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	await _click_control(shell._wait_button)
	await _settle(shell)
	_check(BattleRules.stack_has_waited(session.battle, waiting_id) or String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) != waiting_id, "mouse: Wait on the bar hands the turn on (%s)" % waiting_id)
	_check(not bool(shell._quick_resolve_button.visible), "mouse: Quick Resolve leaves the bar after the first order")
	# The log opens from the log line and closes with a click outside it.
	await _click_control(shell._log_line)
	_check(bool(shell._log_popover.visible), "mouse: clicking the log line opens the battle log")
	_check_open_hud(shell, "mouse: the battle log")
	await _capture("battle_log")
	await _click_at(Vector2(PLAY_SIZE.x * 0.5, PLAY_SIZE.y * 0.42))
	_check(not bool(shell._log_popover.visible), "mouse: a click outside the log closes it")
	await _click_control(shell._options_button)
	_check(bool(shell._options_popover.visible), "mouse: Options opens above the bar")
	_check_open_hud(shell, "mouse: Options")
	await _capture("options")
	await _click_control(shell._options_button)
	_check(not bool(shell._options_popover.visible), "mouse: Options closes again")
	var orders := await _fight_by_mouse(shell, board, session)
	_details["mouse_orders"] = orders
	await _check_result(shell, "mouse")
	await _click_control(shell._view_field_button)
	_check(not bool(shell._result_overlay.visible) and bool(shell._show_result_button.visible), "mouse: View the field hides the result")
	await _capture("view_field")
	await _click_control(shell._show_result_button)
	_check(bool(shell._result_overlay.visible), "mouse: Show result brings it back")
	await _click_control(shell._continue_button)
	_check(bool(shell._last_continue_result.get("ok", false)), "mouse: Continue saves the result and goes on %s" % shell._last_continue_result)
	await _close_shell(shell)


## Clicks the hero, a spell and a lit stack; the stack keeps its turn.
func _cast_by_mouse(shell, board, session) -> void:
	var active_before := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	var mana_before := int(BattleRules.hero_presentation(session.battle, "player").get("mana_current", 0))
	var figure: Dictionary = board.hero_figure_layout("player")
	await _click_at(board.global_position + (figure.get("hit_rect", Rect2()) as Rect2).get_center())
	_check(bool(shell._spellbook_popover.visible), "mouse: clicking the hero opens the spellbook")
	_check_open_hud(shell, "mouse: the spellbook")
	await _capture("spellbook")
	var row: Button = null
	for child in shell._spell_list.get_children():
		if child is Button and not child.disabled:
			row = child
			break
	_check(row != null, "mouse: the spellbook offers a spell to cast now")
	if row == null:
		_details["spell_rows"] = shell.validation_hud_snapshot().get("spell_rows", [])
		shell._close_popovers()
		return
	var spell_id := String(row.get_meta("spell_id", ""))
	await _click_control(row)
	_check(shell._spell_targeting_id == spell_id and not bool(shell._spellbook_popover.visible), "mouse: choosing %s closes the book and lights its targets" % spell_id)
	var targets: Array = BattleRules.spell_target_ids(session, spell_id)
	_check(not targets.is_empty() and board._spell_target_mode, "mouse: the field lights the stacks %s can be cast on" % spell_id)
	await _hover_at(_stack_position(board, String(targets[0])))
	await _capture("spell_targeting")
	await _click_at(_stack_position(board, String(targets[0])))
	await _settle(shell)
	var hero := BattleRules.hero_presentation(session.battle, "player")
	_check(shell._spell_targeting_id == "", "mouse: the click on a lit stack casts the spell")
	_check(int(hero.get("mana_current", 0)) < mana_before and bool(hero.get("cast_this_round", false)), "mouse: the cast spends mana (%d -> %d)" % [mana_before, int(hero.get("mana_current", 0))])
	_check(String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) == active_before, "mouse: the stack keeps its turn after the hero's cast")
	_check(String(shell._banner.text).contains("casts") or shell._message_log.entries.size() > 0, "mouse: the cast is announced (%s)" % shell._banner.text)
	_details["mouse_spell"] = spell_id


## Clicks enemies and hexes until the battle ends.
func _fight_by_mouse(shell, board, session) -> int:
	var orders := 0
	var refused := 0
	while orders < MAX_ORDERS and not shell._battle_over:
		await _settle(shell)
		if shell._battle_over or session.battle.is_empty():
			break
		var active := BattleRules.get_active_stack(session.battle)
		if String(active.get("side", "")) != "player":
			await get_tree().process_frame
			refused += 1
			if refused > 20:
				break
			continue
		var before := hash(session.battle)
		var order := _next_order(session.battle)
		match String(order.get("kind", "")):
			"stack":
				await _click_at(_stack_position(board, String(order.get("battle_id", ""))))
			"hex":
				await _click_at(_hex_position(board, int(order.get("q", -1)), int(order.get("r", -1))))
			_:
				await _click_control(shell._defend_button)
		orders += 1
		if not session.battle.is_empty() and hash(session.battle) == before:
			refused += 1
			_details["refused_order"] = {"order": order, "hint": shell._command_hint}
			if refused > 6:
				break
	await _wait_for_result(shell)
	_check(shell._battle_over, "mouse: the battle ends within %d orders (%d given, %d refused)" % [MAX_ORDERS, orders, refused])
	return orders


func _check_result(shell, how: String) -> void:
	var ended: bool = await _wait_for_result(shell)
	_check(ended, "%s: the result shows over the field" % how)
	var result: Dictionary = shell.validation_result_snapshot()
	_check(bool(result.get("overlay_visible", false)) and not bool(result.get("command_bar_visible", true)), "%s: the result replaces the command bar %s" % [how, result])
	_check(String(result.get("title", "")) != "" and String(result.get("outcome", "")) != "", "%s: the result names the outcome (%s, %s)" % [how, result.get("title", ""), result.get("outcome", "")])
	_check(int(result.get("player_loss_icon_count", 0)) + int(result.get("enemy_loss_icon_count", 0)) > 0, "%s: the result shows the losses as unit icons" % how)
	var lead_lines := String(result.get("lead", "")).split("
")
	var ending := lead_lines[lead_lines.size() - 1].strip_edges() if lead_lines.size() > 1 else ""
	_check(ending == "" or not String(result.get("aftermath", "")).contains(ending), "%s: the details do not repeat how the battle ended (%s)" % [how, ending])
	_check(bool(shell.validation_result_pending()), "%s: the result waits for Continue" % how)
	var hud: Dictionary = shell.validation_hud_snapshot()
	_check(not (hud.get("clipped", []) as Array).has("result_panel"), "%s: the result panel fits the window (%s in %s)" % [how, (hud.get("rects", {}) as Dictionary).get("result_panel", Rect2()), hud.get("viewport_size", Vector2.ZERO)])
	_check(not bool(hud.get("board_input_enabled", true)), "%s: the field takes no orders after the battle" % how)
	_details["%s_outcome" % how] = String(result.get("outcome", ""))
	await _capture("result_%s" % how)


# --- A battle by keyboard ------------------------------------------------------

func _play_by_keyboard() -> void:
	var shell = await _open_shell(PLAY_SIZE)
	var board = shell._battle_board_view
	var session = SessionState.ensure_active_session()
	_check(board.has_focus(), "keys: the field has the keys at the start")
	_check(not board._keyboard_cursor_shown(), "keys: the keyboard cursor waits for a key")
	await _press_key(KEY_ESCAPE)
	_check(bool(shell._options_popover.visible), "keys: Esc opens Options")
	await _press_key(KEY_ESCAPE)
	_check(not bool(shell._options_popover.visible) and board.has_focus(), "keys: Esc closes Options and the field has the keys again")
	# Tab walks the field and the bar and comes back to the field.
	var stops: Array[String] = []
	for _step in range(12):
		await _press_key(KEY_TAB)
		var focus_owner := get_viewport().gui_get_focus_owner()
		stops.append(String(focus_owner.name) if focus_owner != null else "")
		if focus_owner == board:
			break
	_check(stops.has("Wait") and stops.has("Options") and stops.back() == "BattleBoard", "keys: Tab walks the command bar back to the field %s" % [stops])
	_check(board._keyboard_cursor_shown(), "keys: Tab into the field shows the keyboard cursor")
	# The spellbook: S, Enter on a spell, the arrows to a lit stack, Enter.
	var active_before := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	await _press_key(KEY_S)
	_check(bool(shell._spellbook_popover.visible), "keys: S opens the spellbook")
	var focus_owner := get_viewport().gui_get_focus_owner()
	var spell_id := String(focus_owner.get_meta("spell_id", "")) if focus_owner != null and focus_owner.has_meta("spell_id") else ""
	_check(spell_id != "", "keys: the first spell that can be cast has the keys")
	if spell_id != "":
		await _press_key(KEY_ENTER)
		_check(shell._spell_targeting_id == spell_id, "keys: Enter chooses %s" % spell_id)
		var targets: Array = BattleRules.spell_target_ids(session, spell_id)
		if not targets.is_empty():
			await _steer_to(board, board._stack_cell_for_battle_id(String(targets[0])))
			await _press_key(KEY_ENTER)
			await _settle(shell)
			_check(bool(BattleRules.hero_presentation(session.battle, "player").get("cast_this_round", false)), "keys: Enter on a lit stack casts %s" % spell_id)
			_check(String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) == active_before, "keys: the stack keeps its turn after the cast")
	else:
		await _press_key(KEY_ESCAPE)
	# W waits and D defends.
	var waiting_id := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	await _press_key(KEY_W)
	await _settle(shell)
	_check(BattleRules.stack_has_waited(session.battle, waiting_id) or String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) != waiting_id, "keys: W waits")
	var defending_id := String(BattleRules.get_active_stack(session.battle).get("battle_id", ""))
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) == "player":
		await _press_key(KEY_D)
		await _settle(shell)
		_check(session.battle.is_empty() or String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) != defending_id or int(session.battle.get("round", 1)) > 1, "keys: D defends")
	var orders := await _fight_by_keyboard(shell, board, session)
	_details["keyboard_orders"] = orders
	await _check_result(shell, "keys")
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() == shell._continue_button, "keys: Continue has the keys when the result shows")
	await _press_key(KEY_ENTER)
	_check(bool(shell._last_continue_result.get("ok", false)), "keys: Enter on Continue goes on %s" % shell._last_continue_result)
	await _close_shell(shell)


## Moves the keyboard cursor to cell with the arrows.
func _steer_to(board, cell: Vector2i) -> void:
	if not board._keyboard_cursor_shown():
		await _press_key(KEY_UP)
	for _step in range(BattleRules.BATTLE_HEX_COLUMNS + BattleRules.BATTLE_HEX_ROWS + 2):
		var cursor: Vector2i = board._controller_cursor_cell
		if cursor == cell:
			return
		if cursor.x != cell.x:
			await _press_key(KEY_RIGHT if cell.x > cursor.x else KEY_LEFT)
		else:
			await _press_key(KEY_DOWN if cell.y > cursor.y else KEY_UP)


func _fight_by_keyboard(shell, board, session) -> int:
	var orders := 0
	var refused := 0
	while orders < MAX_ORDERS and not shell._battle_over:
		await _settle(shell)
		if shell._battle_over or session.battle.is_empty():
			break
		if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
			await get_tree().process_frame
			refused += 1
			if refused > 20:
				break
			continue
		var before := hash(session.battle)
		var order := _next_order(session.battle)
		if String(order.get("kind", "")) == "defend":
			await _press_key(KEY_D)
		else:
			await _steer_to(board, _order_cell(board, order))
			await _press_key(KEY_ENTER)
		orders += 1
		if not session.battle.is_empty() and hash(session.battle) == before:
			refused += 1
			_details["refused_key_order"] = {"order": order, "cursor": board._controller_cursor_cell, "hint": shell._command_hint}
			if refused > 6:
				break
	await _wait_for_result(shell)
	_check(shell._battle_over, "keys: the battle ends within %d orders (%d given, %d refused)" % [MAX_ORDERS, orders, refused])
	return orders


# --- Auto battle and Quick Resolve ----------------------------------------------

func _check_auto_battle() -> void:
	var shell = await _open_shell(PLAY_SIZE, Callable(), _starting_session)
	var board = shell._battle_board_view
	var session = SessionState.ensure_active_session()
	board.grab_focus()
	await _press_key(KEY_A)
	_check(bool(shell._auto_button.button_pressed), "auto: A turns auto battle on")
	var deadline := Time.get_ticks_msec() + 4000
	while int(shell._validation_auto_battle_order_count) < 2 and not shell._battle_over and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(int(shell._validation_auto_battle_order_count) >= 1, "auto: auto battle gives the player's orders (%d)" % int(shell._validation_auto_battle_order_count))
	if not shell._battle_over:
		await _settle(shell)
		var order := _next_order(session.battle)
		if String(order.get("kind", "")) == "stack":
			await _click_at(_stack_position(board, String(order.get("battle_id", ""))))
		elif String(order.get("kind", "")) == "hex":
			await _click_at(_hex_position(board, int(order.get("q", -1)), int(order.get("r", -1))))
		_check(not bool(shell._auto_button.button_pressed), "auto: an order from the player stops auto battle")
		await _press_key(KEY_A)
	deadline = Time.get_ticks_msec() + 60000
	while not shell._battle_over and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(shell._battle_over, "auto: auto battle plays the battle to its result (%d orders)" % int(shell._validation_auto_battle_order_count))
	_details["auto_orders"] = int(shell._validation_auto_battle_order_count)
	if shell._battle_over:
		_check(bool(shell.validation_press_continue().get("ok", false)), "auto: the result can be continued")
	await _close_shell(shell)


## The harness's path: Quick Resolve before the first order, through its
## confirmation, to the result over the field.
func _check_quick_resolve() -> void:
	var shell = await _open_shell(PLAY_SIZE, Callable(), _starting_session)
	var request: Dictionary = shell.validation_request_quick_resolve_confirmation()
	_check(bool(request.get("ok", false)) and bool(request.get("pending", false)), "quick: Quick Resolve asks to confirm %s" % request)
	var confirm: Dictionary = shell.validation_confirm_quick_resolve_confirmation()
	_check(bool(confirm.get("performed", false)), "quick: the confirmed Quick Resolve plays the battle out %s" % confirm.get("reason", ""))
	await _check_result(shell, "quick")
	var snapshot: Dictionary = shell.validation_snapshot()
	_check(bool(snapshot.get("battle_over", false)) and bool((snapshot.get("result", {}) as Dictionary).get("pending", false)), "quick: the snapshot reports the result waiting")
	shell.get_node("%Continue").pressed.emit()
	_check(bool(shell._last_continue_result.get("ok", false)), "quick: %Continue goes on as the battle report did")
	await _close_shell(shell)
