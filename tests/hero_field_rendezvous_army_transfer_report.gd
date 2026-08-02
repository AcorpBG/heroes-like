extends Node

const REPORT_ID := "HERO_FIELD_RENDEZVOUS_ARMY_TRANSFER_REPORT"
const SAVE_SLOT := 8

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var direct_case := await _direct_transfer_save_case()
	if direct_case.is_empty():
		return
	var cached_case := await _cached_route_case()
	if cached_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"direct_transfer_save": direct_case,
		"cached_route": cached_case,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _direct_transfer_save_case() -> Dictionary:
	var fixture := _fixture(Vector2i(2, 1))
	var session = fixture.get("session")
	var active_id := String(fixture.get("active_id", ""))
	var reserve_id := String(fixture.get("reserve_id", ""))
	var unit_id := String(fixture.get("unit_id", ""))
	var remote: Dictionary = HeroCommandRules.transfer_field_stack(session, active_id, reserve_id, unit_id, "1")
	if bool(remote.get("ok", false)):
		return _fail("Remote field transfer was accepted.", remote)

	_set_hero_position(session, reserve_id, Vector2i(1, 1))
	HeroCommandRules.normalize_session(session)
	var movement_before := int(session.overworld.get("movement", {}).get("current", 0))
	var move_result: Dictionary = OverworldRules.try_move(session, 1, 0)
	if not bool(move_result.get("ok", false)) or String(move_result.get("route", "")) != "rendezvous":
		return _fail("Direct movement did not resolve a rendezvous.", move_result)
	if OverworldRules.hero_position(session) != Vector2i(1, 1) \
		or int(session.overworld.get("movement", {}).get("current", 0)) != movement_before - 1:
		return _fail("Rendezvous movement did not preserve exact position and movement cost.", move_result)
	# The synthetic corridor intentionally omits River Pass objectives; keep the UI fixture in active play.
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	var context: Dictionary = OverworldRules.get_active_context(session)
	if String(context.get("type", "")) != "rendezvous" \
		or "open_rendezvous" not in _action_ids(OverworldRules.get_context_actions(session)):
		return _fail("Co-located commanders did not expose rendezvous context.", context)

	var actions := OverworldRules.get_rendezvous_transfer_actions(session)
	var action_ids := _action_ids(actions)
	var half_id := "field_transfer:%s:%s:%s:half" % [active_id, reserve_id, unit_id]
	var reverse_all_id := "field_transfer:%s:%s:%s:all" % [reserve_id, active_id, unit_id]
	if half_id not in action_ids or reverse_all_id not in action_ids:
		return _fail("Bidirectional one/half/all transfer actions were incomplete.", action_ids)

	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	session = shell.get("_session")
	shell.call("validation_open_command_drawer")
	await get_tree().process_frame
	var shell_snapshot: Dictionary = shell.call("validation_snapshot")
	var rendezvous: Dictionary = shell_snapshot.get("rendezvous", {}) if shell_snapshot.get("rendezvous", {}) is Dictionary else {}
	if not bool(rendezvous.get("label_visible_in_tree", false)) \
		or not bool(rendezvous.get("controls_visible_in_tree", false)) \
		or not bool(rendezvous.get("order_focusable", false)) \
		or not bool(rendezvous.get("transfer_focusable", false)) \
		or int(rendezvous.get("order_count", 0)) < 4 \
		or half_id not in rendezvous.get("action_ids", []):
		shell.queue_free()
		return _fail("The compact Command-drawer rendezvous selector was not visible and focusable.", rendezvous)
	shell.queue_free()
	await get_tree().process_frame

	var half_result: Dictionary = OverworldRules.perform_rendezvous_transfer_action(session, half_id)
	if not bool(half_result.get("ok", false)) \
		or _stack_count(session, active_id, unit_id) != 3 \
		or _stack_count(session, reserve_id, unit_id) != 7:
		return _fail("Half transfer did not split and merge matching stacks exactly.", half_result)
	var reverse_result: Dictionary = OverworldRules.perform_rendezvous_transfer_action(session, reverse_all_id)
	if not bool(reverse_result.get("ok", false)) \
		or _stack_count(session, active_id, unit_id) != 10 \
		or _stack_count(session, reserve_id, unit_id) != 0:
		return _fail("Reverse all transfer did not merge the complete stack.", reverse_result)

	HeroCommandRules.normalize_session(session)
	OverworldRules.normalize_overworld_state(session)
	if _stack_count(session, active_id, unit_id) != 10 or _stack_count(session, reserve_id, unit_id) != 0:
		return _fail("Hero armies changed across runtime normalization.")
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		return _fail("Rendezvous armies did not save and restore.", save_result)
	OverworldRules.normalize_overworld_state(restored)
	if int(restored.save_version) != int(SessionStateStore.SAVE_VERSION) \
		or _stack_count(restored, active_id, unit_id) != 10 \
		or _stack_count(restored, reserve_id, unit_id) != 0 \
		or HeroCommandRules.field_rendezvous_heroes(restored).is_empty():
		return _fail("Rendezvous state changed across the version-9 save boundary.")
	return {
		"route": String(move_result.get("route", "")),
		"movement_spent": 1,
		"remote_transfer_rejected": true,
		"bidirectional_actions": true,
		"matching_stack_merge": true,
		"command_selector_focusable": true,
		"save_resume_preserved": true,
	}

func _cached_route_case() -> Dictionary:
	var fixture := _fixture(Vector2i(3, 1))
	var session = fixture.get("session")
	var reserve_id := String(fixture.get("reserve_id", ""))
	var reserve_name := String(HeroCommandRules.hero_by_id(session, reserve_id).get("name", reserve_id))
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	session = shell.get("_session")
	var selection: Dictionary = shell.call("validation_select_tile", 3, 1)
	var handoff_text := "%s %s %s" % [
		String(selection.get("route_target_handoff_visible_text", "")),
		String(selection.get("route_target_handoff_tooltip_text", "")),
		String(selection.get("primary_action_button_text", "")),
	]
	if not bool(selection.get("ok", false)) or not handoff_text.contains(reserve_name) or not handoff_text.contains("Rendezvous"):
		shell.queue_free()
		return _fail("Reserve hero was not exposed as a named route destination.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) \
		or OverworldRules.hero_position(session) != Vector2i(3, 1) \
		or HeroCommandRules.field_rendezvous_heroes(session).is_empty() \
		or String(session.flags.get("last_action", "")) != "hero_rendezvous" \
		or String(route_execution.get("route_validation_mode", "")) != "cached_prevalidated" \
		or String(route_execution.get("cached_execution_mode", "")) != "destination_interaction_fast_path" \
		or String(route_execution.get("interaction_dispatch_mode", "")) != "destination_descriptor":
		shell.queue_free()
		return _fail("Cached route did not dispatch the hero destination descriptor.", result)
	var post_snapshot: Dictionary = shell.call("validation_snapshot")
	var post_rendezvous: Dictionary = post_snapshot.get("rendezvous", {}) if post_snapshot.get("rendezvous", {}) is Dictionary else {}
	var chrome: Dictionary = post_snapshot.get("chrome", {}) if post_snapshot.get("chrome", {}) is Dictionary else {}
	if String(post_snapshot.get("active_context_type", "")) != "rendezvous" \
		or String(chrome.get("active_drawer", "")) != "command" \
		or not bool(post_rendezvous.get("controls_visible_in_tree", false)):
		shell.queue_free()
		return _fail("Cached rendezvous did not hand off to the live transfer controls.", post_snapshot)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"named_destination": true,
		"route_validation_mode": "cached_prevalidated",
		"cached_execution_mode": "destination_interaction_fast_path",
		"interaction_dispatch_mode": "destination_descriptor",
		"command_handoff": true,
	}

func _fixture(reserve_position: Vector2i) -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(3):
		var row := []
		for _x in range(5):
			row.append("grass" if y == 1 else "water")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": 5, "height": 3, "x": 5, "y": 3}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	var active := HeroCommandRules.active_hero(session)
	var active_id := String(active.get("id", ""))
	var active_stacks: Array = active.get("army", {}).get("stacks", []) if active.get("army", {}).get("stacks", []) is Array else []
	var unit_id := String(active_stacks[0].get("unit_id", "")) if not active_stacks.is_empty() and active_stacks[0] is Dictionary else ""
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	var reserve := HeroCommandRules.build_hero_from_template(
		ContentService.get_hero(reserve_id),
		{"x": reserve_position.x, "y": reserve_position.y},
		{"id": "%s_field_army" % reserve_id, "name": "Reserve Army", "stacks": [{"unit_id": unit_id, "count": 4}]},
		session
	)
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	heroes.append(reserve)
	session.overworld["player_heroes"] = heroes
	_set_hero_position(session, active_id, Vector2i(0, 1))
	_set_hero_army(session, active_id, unit_id, 6)
	_set_active_movement(session, active_id, 8)
	HeroCommandRules.normalize_session(session)
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session, "active_id": active_id, "reserve_id": reserve_id, "unit_id": unit_id}

func _set_hero_position(session, hero_id: String, tile: Vector2i) -> void:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index]
			hero["position"] = {"x": tile.x, "y": tile.y}
			heroes[index] = hero
			break
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		var active: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
		active["position"] = {"x": tile.x, "y": tile.y}
		session.overworld["hero"] = active
		session.overworld["hero_position"] = {"x": tile.x, "y": tile.y}

func _set_hero_army(session, hero_id: String, unit_id: String, count: int) -> void:
	var army := {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": [{"unit_id": unit_id, "count": count}]}
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index]
			hero["army"] = army.duplicate(true)
			heroes[index] = hero
			break
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		session.overworld["army"] = army.duplicate(true)
		var active: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
		active["army"] = army.duplicate(true)
		session.overworld["hero"] = active

func _set_active_movement(session, hero_id: String, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index]
			hero["movement"] = movement.duplicate(true)
			heroes[index] = hero
			break
	session.overworld["player_heroes"] = heroes
	session.overworld["movement"] = movement.duplicate(true)
	var active: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	active["movement"] = movement.duplicate(true)
	session.overworld["hero"] = active

func _stack_count(session, hero_id: String, unit_id: String) -> int:
	var hero := HeroCommandRules.hero_by_id(session, hero_id)
	for stack_value in hero.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			return int(stack_value.get("count", 0))
	return 0

func _action_ids(actions: Array) -> Array:
	var ids := []
	for action_value in actions:
		if action_value is Dictionary:
			ids.append(String(action_value.get("id", "")))
	return ids

func _fail(message: String, payload: Variant = {}) -> Dictionary:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return {}
