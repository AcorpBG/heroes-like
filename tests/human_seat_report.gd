extends Node

# A human player on seat 1, played by fixed rules through the real screens,
# for tools/rules_parity.py --human (transition doc, Phase 7, D-a). The main
# menu starts a generated game, or loads the one save in user://saves; then
# each day the player:
#   - answers the overworld's dialogs: a level-up takes its first specialty,
#     a treasure its first reward, troops offered at a site the first stack;
#   - opens each of its towns from the town rail, builds the first building
#     it can that adds recruits (else the first it can), hires a hero while
#     it has fewer than MAX_HEROES, recruits what it can (nothing while it
#     has no hero, saving for one), learns the first
#     spell, moves every garrison stack it can to a visiting hero, then
#     leaves;
#   - moves each hero, in roster order, toward the target it can reach at
#     the least cost (route length plus KIND_COST, ties by tile; a tile a
#     hero reached is no target for REVISIT_DAYS): it hovers the tile, clicks
#     it to arm the route and clicks again to commit, through the map's own
#     input handlers (a guard is clicked on its own tile, measured to the
#     square the click routes to, and only when the hero's army is
#     GUARD_MARGIN times as strong, by OverworldRules._army_strength_value);
#   - fights every other battle through the battle screen, each order the
#     battle AI's suggestion (BattleShell.validation_auto_battle_order), and
#     quick-resolves the others; the result's Continue routes back;
#   - ends the turn through the confirmation.
# Every choice is a function of the game state, so one setup replays one
# game. It fails only when the game cannot be played on.
#
# HEROES_HUMAN_SEED, HEROES_HUMAN_SIZE, HEROES_HUMAN_PLAYERS,
# HEROES_HUMAN_WATER, HEROES_HUMAN_LEVELS: the generated game, chosen in the
#                       main menu's skirmish setup.
# HEROES_HUMAN_SAVE     1 loads the save in user://saves instead.
# HEROES_HUMAN_DAYS     days to play from the first (default 14).
# HEROES_HUMAN_OUT      the JSON record (default user://human_seat.json).
# HEROES_HUMAN_DIGEST   one line per action: "day<TAB>step<TAB>action<TAB>
#                       session<TAB>panels". session is the AI match runner's
#                       digest (header, overworld, battle and flags, 8 hex
#                       digits each), with the autosave's wall-clock stamp
#                       set to 0; panels is the Variant hash of the texts
#                       the screen shows: the text and tooltip of every
#                       visible Label, RichTextLabel, Button and LineEdit, in
#                       tree order.
# HEROES_HUMAN_DUMP     with HEROES_HUMAN_DUMP_STEP: after that step, the
#                       session state and the panel texts (with their node
#                       paths) as JSON, and the run stops.
# HEROES_AI_MATCH_DIGEST_BLANK as for the AI match runner (--portable).

const NativeRulesScript = preload("res://scripts/core/NativeRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const REPORT_ID := "HUMAN_SEAT_REPORT"
const DEFAULT_OUT := "user://human_seat.json"
const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const BATTLE_REPORT_SCENE := "res://scenes/battle/BattleReportShell.tscn"
const OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const MAX_HEROES := 3
const MAX_MOVES_PER_HERO := 8
const REVISIT_DAYS := 7
const GUARD_MARGIN := 1.5
const MAX_BATTLE_ORDERS := 400
const SCENE_WAIT_FRAMES := 1200
# Added to the route length in tiles: pickups first, then sites, then towns
# to take, then neutral armies; a portal or gate last, once a day.
const KIND_COST := {"artifact": 0, "pickup": 0, "site": 3, "town": 5, "encounter": 8, "transit": 10}

var _failed := false
var _digest_file: FileAccess = null
var _dump_path := ""
var _dump_step := -1
var _blank_scopes := PackedStringArray()
var _blank_fields := {}
var _step := 0
var _battles := 0
var _timing := {}
var _action_counts := {}
var _setup := {}
var _stopped := false
var _target_kind := ""
var _target_level := 0
var _target_click := Vector2i(-1, -1)
var _visited := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not NativeRulesScript.available():
		_fail("The native rules library is not loaded: %s." % NativeRulesScript.REGISTER_HINT)
		return
	var days := int(OS.get_environment("HEROES_HUMAN_DAYS")) if OS.get_environment("HEROES_HUMAN_DAYS") != "" else 14
	var out_path := OS.get_environment("HEROES_HUMAN_OUT").strip_edges()
	if out_path == "":
		out_path = DEFAULT_OUT
	var digest_path := OS.get_environment("HEROES_HUMAN_DIGEST").strip_edges()
	if digest_path != "":
		_digest_file = FileAccess.open(digest_path, FileAccess.WRITE)
		if _digest_file == null:
			_fail("HEROES_HUMAN_DIGEST %s cannot be written." % digest_path)
			return
	_dump_path = OS.get_environment("HEROES_HUMAN_DUMP").strip_edges()
	if _dump_path != "" and OS.get_environment("HEROES_HUMAN_DUMP_STEP").strip_edges() != "":
		_dump_step = int(OS.get_environment("HEROES_HUMAN_DUMP_STEP"))
	for item in OS.get_environment("HEROES_AI_MATCH_DIGEST_BLANK").split(",", false):
		item = item.strip_edges()
		if item.begins_with("overworld.") or item.begins_with("flags."):
			_blank_scopes.append(item)
		else:
			_blank_fields[item] = true

	# The screens replace the current scene; this node stays beside them.
	var tree := get_tree()
	tree.root.remove_child.call_deferred(self)
	await tree.process_frame
	tree.root.add_child(self)
	AppRouter.go_to_main_menu()
	var menu = await _wait_for_scene([MAIN_MENU_SCENE])
	if menu == null:
		_fail("The main menu did not open.")
		return
	await _frames(8)
	if not await _start_game(menu):
		return
	var session = SessionState.ensure_active_session()
	var first_day := int(session.day)
	_setup["scenario_id"] = String(session.scenario_id)
	_setup["first_day"] = first_day
	_setup["hero_id"] = String(session.hero_id)
	_record("start")

	while not _stopped and not _failed:
		if not await _play_on():
			break
		session = SessionState.ensure_active_session()
		if session.scenario_status != "in_progress" or int(session.day) >= first_day + days:
			break
		await _play_day()
		if _stopped or _failed or not await _play_on():
			break
		session = SessionState.ensure_active_session()
		if session.scenario_status != "in_progress":
			break
		await _end_turn()
	if _failed:
		return
	_finish(out_path)

# ---------------------------------------------------------------- setup

func _start_game(menu) -> bool:
	if OS.get_environment("HEROES_HUMAN_SAVE").strip_edges() not in ["", "0"]:
		var resumed: Dictionary = menu.validation_resume_latest()
		_setup["save"] = String(resumed.get("selected_key", ""))
		if not bool(resumed.get("ok", false)):
			_fail("The save did not load: %s" % JSON.stringify(resumed).left(600))
			return false
		return true
	var size_class := OS.get_environment("HEROES_HUMAN_SIZE").strip_edges()
	var players := int(OS.get_environment("HEROES_HUMAN_PLAYERS")) if OS.get_environment("HEROES_HUMAN_PLAYERS") != "" else 2
	var water := OS.get_environment("HEROES_HUMAN_WATER").strip_edges()
	var levels := int(OS.get_environment("HEROES_HUMAN_LEVELS")) if OS.get_environment("HEROES_HUMAN_LEVELS") != "" else 1
	var map_seed := OS.get_environment("HEROES_HUMAN_SEED").strip_edges()
	_setup.merge({"seed": map_seed, "size": size_class, "players": players, "water": water, "levels": levels}, true)
	menu.validation_open_skirmish_stage()
	await _frames(4)
	var chosen: bool = (
		menu.validation_select_generated_size_class(size_class if size_class != "" else "homm3_small")
		and menu.validation_select_generated_player_count(players)
		and menu.validation_select_generated_water_mode(water if water != "" else "land")
		and menu.validation_set_generated_underground(levels == 2)
		and menu.validation_set_generated_seed(map_seed)
	)
	if not chosen:
		_fail("The skirmish setup refused %s." % JSON.stringify(_setup))
		return false
	var launch: Dictionary = await menu.validation_start_generated_skirmish_staged_route_to_overworld()
	if not bool(launch.get("started", false)):
		_fail("The generated game did not start: %s" % JSON.stringify(launch).left(600))
		return false
	return true

# ---------------------------------------------------------------- the day

## Plays whatever screen is up until the overworld waits for orders; false
## when the game is over or cannot go on.
func _play_on() -> bool:
	for _attempt in range(64):
		var scene = await _wait_for_scene([OVERWORLD_SCENE, TOWN_SCENE, BATTLE_SCENE, BATTLE_REPORT_SCENE, OUTCOME_SCENE])
		if scene == null:
			_fail("No playable screen came up (current %s)." % _current_scene_path())
			return false
		var path := String(scene.scene_file_path)
		if path == OUTCOME_SCENE:
			return false
		elif path in [BATTLE_SCENE, BATTLE_REPORT_SCENE]:
			await _play_battle(scene)
		elif path == TOWN_SCENE:
			await _play_town(scene)
		elif SessionState.ensure_active_session().scenario_status != "in_progress":
			await _frames(2)
		elif not await _answer_dialogs(scene):
			return not _failed
		if _failed or _stopped:
			return false
	_fail("The screens kept routing without reaching the overworld's orders.")
	return false

func _play_day() -> void:
	var session = SessionState.ensure_active_session()
	var day := int(session.day)
	var opened := {}
	for placement_id in _own_town_ids(session):
		if not await _play_on() or int(SessionState.ensure_active_session().day) != day:
			return
		var ow = get_tree().current_scene
		if opened.has(placement_id) or not _own_town_ids(SessionState.ensure_active_session()).has(placement_id):
			continue
		opened[placement_id] = true
		ow._on_town_roster_pressed(placement_id)
		if String(ow._town_at(ow._selected_tile.x, ow._selected_tile.y).get("placement_id", "")) != placement_id:
			continue
		_timed_call("town_open:%s" % placement_id, func(): ow._visit_selected_town())
	for hero_id in _hero_ids(SessionState.ensure_active_session()):
		var tried := {}
		for _move in range(MAX_MOVES_PER_HERO):
			if not await _play_on():
				return
			session = SessionState.ensure_active_session()
			if int(session.day) != day or not _hero_ids(session).has(hero_id):
				break
			var ow = get_tree().current_scene
			if String(session.overworld.get("active_hero_id", "")) != hero_id:
				_timed_call("hero:%s" % hero_id, func(): ow._on_hero_roster_pressed(hero_id))
				if String(SessionState.ensure_active_session().overworld.get("active_hero_id", "")) != hero_id:
					break
				continue
			if int(session.overworld.get("movement", {}).get("current", 0)) <= 0:
				break
			var target := _pick_target(ow, session, tried)
			if target.x < 0:
				break
			var before := _hero_signature(session)
			var click := _target_click
			_timed_call("hover:%d,%d" % [click.x, click.y], func(): ow._on_map_tile_hovered(click))
			_timed_call("arm:%d,%d" % [click.x, click.y], func(): ow._on_map_tile_pressed(click))
			if get_tree().current_scene == ow:
				_timed_call("move:%d,%d" % [click.x, click.y], func(): ow._on_map_tile_pressed(click))
			session = SessionState.ensure_active_session()
			if _target_kind == "transit" or _hero_signature(session) == before:
				tried[target] = true
			if OverworldRules.hero_position(session) == target or not session.battle.is_empty():
				_visited[Vector3i(target.x, target.y, _target_level)] = day

func _end_turn() -> void:
	var ow = get_tree().current_scene
	_timed_call("end_turn", func():
		ow.validation_request_end_turn()
		if bool(ow.validation_end_turn_confirmation_snapshot().get("pending", false)):
			ow.validation_confirm_end_turn()
	)

## The cheapest target the active hero can reach: route length in tiles plus
## the kind's cost, ties by row and column. A target the hero could not get
## closer to today is skipped.
func _pick_target(ow, session, tried: Dictionary) -> Vector2i:
	var hero_pos: Vector2i = OverworldRules.hero_position(session)
	var level := LevelRules.hero_level(session)
	var player_id := String(session.overworld.get("active_player_id", ""))
	var targets := {}
	var clicks := {}
	var army_strength := int(OverworldRules._army_strength_value(session.overworld.get("army", {}).get("stacks", [])))
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) != "player" and LevelRules.on_level(town, level):
			var entrance: Dictionary = LevelRules.town_entrance(town)
			_add_target(targets, Vector2i(int(entrance.get("x", -1)), int(entrance.get("y", -1))), "town")
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not LevelRules.on_level(node, level):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not OverworldRules.resource_node_is_present(node, site):
			continue
		if bool(node.get("collected", false)) and PlayerRules.resource_controller_id(node) == player_id:
			continue
		var tile: Vector2i = ow._resource_node_route_tile(node, Vector2i(int(node.get("x", -1)), int(node.get("y", -1))))
		var family := String(site.get("family", ""))
		var kind := "transit" if family == "transit_object" else "pickup" if family in ["", "one_shot_pickup"] and not bool(node.get("collected", false)) else "site"
		_add_target(targets, tile, kind)
	for artifact in session.overworld.get("artifact_nodes", []):
		if artifact is Dictionary and not bool(artifact.get("collected", false)) and LevelRules.on_level(artifact, level):
			_add_target(targets, Vector2i(int(artifact.get("x", -1)), int(artifact.get("y", -1))), "artifact")
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and LevelRules.on_level(encounter, level):
			var guard_army = encounter.get("enemy_army", {})
			var guard_strength := int(OverworldRules._army_strength_value(guard_army.get("stacks", []) if guard_army is Dictionary else []))
			if float(army_strength) < GUARD_MARGIN * float(guard_strength):
				continue
			var anchor := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
			if anchor.x < 0 or not OverworldRules.is_tile_explored(session, anchor.x, anchor.y, level):
				continue
			var entry: Vector2i = ow._selection_route_tile(anchor)
			if entry != anchor and not targets.has(entry):
				clicks[entry] = anchor
			_add_target(targets, entry, "encounter")
	var goals := []
	for tile in targets:
		if tile == hero_pos or tried.has(tile) or int(session.day) - int(_visited.get(Vector3i(tile.x, tile.y, level), -REVISIT_DAYS)) < REVISIT_DAYS:
			continue
		if OverworldRules.is_tile_explored(session, tile.x, tile.y, level):
			goals.append(tile)
	var lengths: Dictionary = ow._route_path_lengths(hero_pos, goals)
	var best := Vector2i(-1, -1)
	var best_cost := 1 << 30
	for tile in goals:
		if not lengths.has(tile):
			continue
		var cost := int(lengths[tile]) + int(KIND_COST[targets[tile]])
		if cost < best_cost or (cost == best_cost and (tile.y < best.y or (tile.y == best.y and tile.x < best.x))):
			best = tile
			best_cost = cost
	_target_kind = String(targets.get(best, ""))
	_target_level = level
	_target_click = clicks.get(best, best)
	return best

func _add_target(targets: Dictionary, tile: Vector2i, kind: String) -> void:
	if tile.x < 0 or tile.y < 0:
		return
	if not targets.has(tile) or int(KIND_COST[kind]) < int(KIND_COST[targets[tile]]):
		targets[tile] = kind

func _hero_signature(session) -> String:
	var position: Vector2i = OverworldRules.hero_position(session)
	return "%s|%d,%d|%d|%d" % [
		String(session.overworld.get("active_hero_id", "")), position.x, position.y,
		int(session.overworld.get("movement", {}).get("current", 0)), _step]

func _own_town_ids(session) -> Array:
	var ids := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			ids.append(String(town.get("placement_id", "")))
	ids.sort()
	return ids

func _hero_ids(session) -> Array:
	var ids := []
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			ids.append(String(hero.get("id", "")))
	return ids

## The overworld's dialogs, each answered by its fixed rule; true when one
## was answered.
func _answer_dialogs(ow) -> bool:
	var reason := String(ow._overworld_gameplay_movement_blocked_reason())
	match reason:
		"", "debug_active":
			return false
		"battle_approach", "end_turn_committing":
			await _frames(2)
			return true
		"site_recruit_dialog_open":
			var dialog: Dictionary = ow.validation_site_recruit_dialog()
			var slots: Array = dialog.get("slots", [])
			if slots.is_empty():
				_timed_call("site_recruit:leave", func(): ow.validation_site_recruit_leave())
			else:
				_timed_call("site_recruit:%d" % int(slots[0]), func(): ow.validation_site_recruit_choose(int(slots[0])))
			return true
		"hero_sheet_open":
			_timed_call("close:hero_sheet", func(): ow._hero_sheet.close_sheet())
			return true
		"hero_exchange_open":
			_timed_call("close:hero_exchange", func(): ow._hero_exchange.close_exchange())
			return true
		"end_turn_confirmation_open":
			_timed_call("confirm:end_turn", func(): ow.validation_confirm_end_turn())
			return true
	# A level-up, a treasure or another dialog: its first choice, else its
	# confirmation, else its cancel.
	var window := _open_dialog(ow)
	if window == null:
		_fail("The overworld is blocked (%s) by no dialog this player answers." % reason)
		return false
	var button := _first_choice(window)
	_timed_call("dialog:%s:%s" % [_stable_name(window), _stable_name(button) if button != null else "cancel"], func():
		if button != null:
			button.pressed.emit()
		else:
			window.get_cancel_button().pressed.emit()
	)
	return true

func _open_dialog(ow) -> AcceptDialog:
	for child in ow.get_children():
		if child is AcceptDialog and child.visible:
			return child
	return null

## A button of the dialog's content first, then one of its own row (a
## treasure's rewards are there), then its confirmation.
func _first_choice(window: AcceptDialog) -> Button:
	var skip := [window.get_ok_button()]
	if window is ConfirmationDialog:
		skip.append(window.get_cancel_button())
	var buttons := window.find_children("*", "Button", true, false)
	buttons.append_array(window.get_ok_button().get_parent().get_children())
	for button in buttons:
		if button is Button and button.visible and not button.disabled and button not in skip:
			return button
	return window.get_ok_button() if window.get_ok_button().visible else null

# ---------------------------------------------------------------- towns and battles

func _play_town(town) -> void:
	await _frames(2)
	var placement_id := String(TownRules.get_active_town(SessionState.ensure_active_session()).get("placement_id", ""))
	var builds: Array = town.validation_action_catalog().get("build", [])
	var recruiting := builds.filter(func(action): return action is Dictionary and _adds_recruits(String(action.get("id", "")).trim_prefix("build:")))
	if not _town_action(town, recruiting):
		_town_action(town, builds)
	if _hero_ids(SessionState.ensure_active_session()).size() < MAX_HEROES:
		_town_action(town, town.validation_action_catalog().get("tavern", []))
	# With no hero left, the gold waits for the next one.
	for _round in range(12 if not _hero_ids(SessionState.ensure_active_session()).is_empty() else 0):
		if not _town_action(town, town.validation_action_catalog().get("recruit", [])):
			break
	_town_action(town, town.validation_action_catalog().get("study", []))
	for _round in range(7):
		if not _town_action(town, _garrison_to_hero(town.validation_action_catalog().get("transfer", []))):
			break
	_timed_call("town_leave:%s" % placement_id, func(): town.validation_leave_town())

## The transfers of a whole garrison stack to a hero: "all", or "1" for a
## stack of one.
func _garrison_to_hero(actions: Array) -> Array:
	var ids := {}
	for action in actions:
		if action is Dictionary and String(action.get("id", "")).begins_with("transfer:garrison:"):
			ids[String(action.id)] = true
	return actions.filter(func(action):
		var id := String(action.get("id", "")) if action is Dictionary else ""
		return ids.has(id) and (id.ends_with(":all") or (id.ends_with(":1") and not ids.has(id.trim_suffix(":1") + ":all"))))

## As LiveValidationHarness: a building that unlocks a unit or adds growth.
func _adds_recruits(building_id: String) -> bool:
	var building := ContentService.get_building(building_id)
	var growth_bonus = building.get("growth_bonus", {})
	return String(building.get("unlock_unit_id", "")) != "" or (growth_bonus is Dictionary and not growth_bonus.is_empty())

func _town_action(town, actions: Array) -> bool:
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			var action_id := String(action.get("id", ""))
			var result := {}
			_timed_call("town:%s" % action_id, func(): result.merge(town.validation_perform_town_action(action_id)))
			return bool(result.get("ok", false))
	return false

func _play_battle(scene) -> void:
	if String(scene.scene_file_path) == BATTLE_SCENE and not scene.validation_result_pending():
		_battles += 1
		if _battles % 2 == 0:
			_timed_call("battle:quick_resolve", func():
				scene.validation_request_quick_resolve_confirmation()
				scene.validation_confirm_quick_resolve_confirmation()
			)
		else:
			for _order in range(MAX_BATTLE_ORDERS):
				if get_tree().current_scene != scene or SessionState.ensure_active_session().battle.is_empty() or scene.validation_result_pending():
					break
				var battle: Dictionary = SessionState.ensure_active_session().battle
				var active := BattleRules.get_active_stack(battle)
				if String(active.get("side", "")) == "player":
					var order := {}
					_timed_call("battle:order", func(): order.merge(scene.validation_auto_battle_order()))
					if not bool(order.get("ok", false)):
						_fail("The battle refused its AI's order: %s" % JSON.stringify(order).left(400))
						return
				else:
					_timed_call("battle:wait", func(): scene.validation_try_progress_action())
				if _stopped:
					return
				await _frames(1)
		await _frames(2)
	var current = get_tree().current_scene
	if current == null:
		return
	var path := String(current.scene_file_path)
	if path == BATTLE_REPORT_SCENE or (path == BATTLE_SCENE and current.validation_result_pending()):
		_timed_call("battle:continue", func(): current.get_node("%Continue").pressed.emit())

# ---------------------------------------------------------------- records

func _timed_call(action: String, body: Callable) -> void:
	if _stopped or _failed:
		return
	var started := Time.get_ticks_usec()
	body.call()
	var ms := float(Time.get_ticks_usec() - started) / 1000.0
	var kind := action.get_slice(":", 0)
	var entry: Dictionary = _timing.get(kind, {"n": 0, "ms": 0.0, "max_ms": 0.0})
	entry.n += 1
	entry.ms += ms
	entry.max_ms = maxf(float(entry.max_ms), ms)
	_timing[kind] = entry
	_action_counts[kind] = int(_action_counts.get(kind, 0)) + 1
	_record(action)

## One digest row after each action, once its deferred calls have run.
func _record(action: String) -> void:
	_step += 1
	if _digest_file == null and _dump_step != _step:
		return
	var session = SessionState.ensure_active_session()
	var parts := _state_parts(session)
	var panels := _panel_texts()
	if _digest_file != null:
		var line := "%d\t%d\t%s\t" % [int(session.day), _step, action]
		for part in parts:
			line += "%08x" % hash(part)
		line += "\t%08x" % hash(panels.values())
		_digest_file.store_line(line)
		_digest_file.flush()
	if _dump_step == _step:
		var state: Dictionary = parts[0].duplicate()
		state["overworld"] = parts[1]
		state["battle"] = parts[2]
		state["flags"] = parts[3]
		var dump := FileAccess.open(_dump_path, FileAccess.WRITE)
		if dump != null:
			dump.store_string(JSON.stringify({"step": _step, "action": action, "scene": _current_scene_path(), "state": state, "panels": panels}, "", false, true))
			dump.close()
		_stopped = true

## The texts the current screen shows, by node path, in tree order. A node
## named by Godot (@Button@2047, from a counter that differs between runs) is
## named by its class and its place among its parent's children of that class.
func _panel_texts() -> Dictionary:
	var out := {}
	var scene := get_tree().current_scene
	if scene != null:
		_collect_texts(scene, "", out)
	return out

func _collect_texts(node: Node, path: String, out: Dictionary) -> void:
	if (node is CanvasItem and not node.visible) or (node is Window and not node.visible):
		return
	var text := ""
	if node is Label or node is Button or node is LineEdit:
		text = node.text
	elif node is RichTextLabel:
		text = node.get_parsed_text()
	if node is Control and node.tooltip_text != "":
		text += "␟" + node.tooltip_text
	if text != "":
		out[path] = text
	var counts := {}
	for child in node.get_children():
		var name := String(child.name)
		if name.begins_with("@"):
			var index := int(counts.get(child.get_class(), 0))
			counts[child.get_class()] = index + 1
			name = "@%s#%d" % [child.get_class(), index]
		_collect_texts(child, name if path == "" else path + "/" + name, out)

## A node's name, or for one Godot named, its class and place among its
## parent's children of that class (as _collect_texts names it).
func _stable_name(node: Node) -> String:
	var name := String(node.name)
	if not name.begins_with("@") or node.get_parent() == null:
		return name
	var index := 0
	for sibling in node.get_parent().get_children():
		if sibling == node:
			break
		if sibling.get_class() == node.get_class() and String(sibling.name).begins_with("@"):
			index += 1
	return "@%s#%d" % [node.get_class(), index]

## As the AI match runner's, and the autosave's wall-clock stamp set to 0.
func _state_parts(session) -> Array:
	var overworld: Dictionary = session.overworld
	var flags: Dictionary = session.flags
	if flags.has(AppRouter.AUTOSAVE_PENDING_UNIX_FLAG):
		flags = flags.duplicate()
		flags[AppRouter.AUTOSAVE_PENDING_UNIX_FLAG] = 0
	if not _blank_scopes.is_empty():
		overworld = overworld.duplicate()
		flags = flags.duplicate()
		for scope in _blank_scopes:
			var part: Dictionary = overworld if scope.begins_with("overworld.") else flags
			var key := scope.get_slice(".", 1)
			if part.get(key) is Dictionary:
				part[key] = _blanked(part[key])
	var header := {
		"day": session.day,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"game_state": session.game_state,
		"scenario_status": session.scenario_status,
		"scenario_summary": session.scenario_summary,
	}
	return [header, overworld, session.battle, flags]

func _blanked(value: Dictionary) -> Dictionary:
	var out := {}
	for key in value:
		var child = value[key]
		if _blank_fields.has(String(key)):
			out[key] = ""
		elif child is Dictionary:
			out[key] = _blanked(child)
		else:
			out[key] = child
	return out

func _finish(out_path: String) -> void:
	var session = SessionState.ensure_active_session()
	var record := {
		"report_id": REPORT_ID,
		"setup": _setup,
		"final_day": int(session.day),
		"scenario_status": String(session.scenario_status),
		"final_scene": _current_scene_path(),
		"actions": _step,
		"action_counts": _action_counts,
		"battles": _battles,
		"timing": _timing,
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	var port_failures := _native_port_failures()
	if port_failures != "":
		_fail(port_failures)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true, "setup": _setup, "final_day": int(session.day), "scenario_status": String(session.scenario_status),
		"actions": _step, "battles": _battles, "dumped": _stopped, "out": ProjectSettings.globalize_path(out_path),
	})])
	get_tree().quit(0)

## As the AI match runner's: failed native calls, shadow mismatches and
## unknown names each printed a SCRIPT ERROR, which a release export hides.
func _native_port_failures() -> String:
	var stats: Dictionary = NativeRulesScript.api().port_stats()
	var failed := PackedStringArray()
	for name in stats:
		var entry = stats[name]
		if entry is Dictionary and int(entry.get("errors", 0)) + int(entry.get("mismatches", 0)) > 0:
			failed.append("%s (%d errors, %d mismatches)" % [name, int(entry.get("errors", 0)), int(entry.get("mismatches", 0))])
	if int(stats.get("unknown_calls", 0)) > 0:
		failed.append("%d calls of names it does not have" % int(stats.unknown_calls))
	if failed.is_empty():
		return ""
	return "The native rules port failed: %s." % ", ".join(failed)

# ---------------------------------------------------------------- scenes

func _wait_for_scene(paths: Array):
	for _frame in range(SCENE_WAIT_FRAMES):
		var current := get_tree().current_scene
		if current != null and current.is_node_ready() and String(current.scene_file_path) in paths:
			await _frames(2)
			if get_tree().current_scene == current:
				return current
		await get_tree().process_frame
	return null

func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame

func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return String(current.scene_file_path) if current != null else ""

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "step": _step})])
	get_tree().quit(1)
