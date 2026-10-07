extends Node

## Live report for overworld movement feedback (owner playtest, 2026-10-07).
## Drives the real OverworldShell handlers over a small fixture map:
## - the hero portrait bar shows the movement actually left after pointer
##   routes, an arrow-key step, a hero switch and End Turn, without rebuilding
##   the roster on route-only refreshes;
## - an attack order walks the route with the normal walk animation, spends
##   movement and opens the battle only once the hero has arrived, both for a
##   plain enemy and for a random-map guard with an engagement ring;
## - an attack order beyond today's movement walks as far as it can and stops
##   without a battle; the next day the same order finishes the walk and fights.
## Pass --shots=<dir> (windowed runs only) to capture the portrait bar.

const REPORT_ID := "OVERWORLD_MOVEMENT_FEEDBACK_REPORT"
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const ENCOUNTER_ID := "encounter_ghoul_grove"
const MAX_WAIT_MSEC := 6000

var _failures := []
var _checks := 0
var _evidence := {}
var _shots_dir := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shots="):
			_shots_dir = String(arg).trim_prefix("--shots=")
	var reduced_motion_before := SettingsService.reduced_motion_enabled()
	if reduced_motion_before:
		SettingsService.set_reduced_motion_enabled(false)
	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	await _check_portrait_bar()
	await _check_attack_in_range()
	await _check_guard_attack()
	await _check_attack_out_of_range()
	AppRouter.validation_set_battle_entry_routing_suppressed(false)
	if reduced_motion_before:
		SettingsService.set_reduced_motion_enabled(true)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "evidence": _evidence}
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
	return condition

# --- portrait bar ----------------------------------------------------------------

func _check_portrait_bar() -> void:
	var opened := await _open_shell(_fixture_session(Vector2i(2, 3), 12, 12, []))
	var shell: Node = opened.shell
	var session = opened.session
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var reserve_id := _reserve_id(session)
	var evidence := {}
	_check(_meter(shell, active_id) == _movement(session), "portrait bar opens with the active hero's movement")
	var reserve_before := _meter(shell, reserve_id)
	var roster_nodes := _roster_instance_ids(shell)

	# Pointer route: select, then confirm on the same tile.
	var movement_before := _movement(session)
	var target := Vector2i(6, 3)
	shell.call("validation_reset_profile", true)
	shell.call("_on_map_tile_pressed", target)
	_check(_movement(session) == movement_before and OverworldRules.hero_position(session) != target, "selecting a route spends nothing")
	shell.call("_on_map_tile_pressed", target)
	var spent := _movement(session)
	_check(OverworldRules.hero_position(session) == target and spent == movement_before - 4, "pointer route moves the hero and spends four points")
	_check(int(_roster_button(shell, active_id).get_meta("movement_current", -1)) == spent, "route-only refresh hands the spent movement to the portrait bar")
	var walk := await _sample_walk(shell, active_id)
	evidence["pointer_walk"] = walk
	_check(bool(walk.get("walk_seen", false)), "the pointer route plays the walk animation")
	_check(bool(walk.get("non_increasing", false)) and float(walk.get("first", -1.0)) > float(spent), "the movement bar drains with the walk instead of jumping ahead of it")
	_check(is_equal_approx(_meter(shell, active_id), float(spent)), "after the walk the portrait bar shows the real movement left")
	_check(is_equal_approx(_meter(shell, reserve_id), reserve_before), "another hero's bar is untouched")
	_check(_roster_instance_ids(shell) == roster_nodes, "route-only refresh keeps the roster buttons (no rebuild)")
	var profile: Dictionary = shell.call("validation_profile_snapshot")
	_check(int(profile.get("refresh_phase_hero_actions_calls", 0)) == 0 and int(profile.get("refresh_phase_status_surfaces_calls", 0)) == 0, "the move stays on the route-only refresh path")
	evidence["pointer_profile"] = {
		"hero_roster_readiness_updates": int(profile.get("hero_roster_readiness_updates", 0)),
		"hero_roster_readiness_reuses": int(profile.get("hero_roster_readiness_reuses", 0)),
		"hero_actions_phase_calls": int(profile.get("refresh_phase_hero_actions_calls", 0)),
	}
	await _capture("portrait_after_pointer_route")

	# Arrow-key step (the keyboard movement handler).
	movement_before = _movement(session)
	shell.call("_move_east")
	_check(_movement(session) == movement_before - 1, "arrow-key step spends one point")
	await _sample_walk(shell, active_id)
	_check(is_equal_approx(_meter(shell, active_id), float(_movement(session))), "portrait bar follows an arrow-key step")

	# Hero switch: the roster commits the departing hero and shows both heroes.
	var lyra_left := _movement(session)
	shell.call("_on_hero_roster_pressed", reserve_id)
	_check(String(session.overworld.get("active_hero_id", "")) == reserve_id, "roster click switches the active hero")
	_check(is_equal_approx(_meter(shell, active_id), float(lyra_left)), "after a switch the first hero keeps its spent movement")
	_check(is_equal_approx(_meter(shell, reserve_id), float(_movement(session))), "after a switch the new active hero shows its own movement")
	shell.call("_on_hero_roster_pressed", active_id)

	# End Turn refills movement and the bar shows it.
	var day_before: int = session.day
	var end_turn: Dictionary = shell.call("validation_end_turn")
	_check(session.day == day_before + 1 and session.scenario_status == "in_progress", "end turn starts the next day")
	await _wait_turn_playback(shell)
	var refilled := _movement(session)
	_check(refilled > lyra_left and is_equal_approx(_meter(shell, active_id), float(refilled)), "after End Turn the portrait bar shows the refilled movement")
	evidence["end_turn"] = {"ok": bool(end_turn.get("ok", false)), "movement_after": refilled}
	_evidence["portrait_bar"] = evidence
	shell.queue_free()
	await _settle(2)

# --- attack in range ---------------------------------------------------------------

func _check_attack_in_range() -> void:
	var enemy_tile := Vector2i(8, 3)
	var opened := await _open_shell(_fixture_session(Vector2i(2, 3), 12, 12, [_encounter("feedback_ghouls", enemy_tile)]))
	var shell: Node = opened.shell
	var session = opened.session
	var active_id := String(session.overworld.get("active_hero_id", ""))
	_enable_battle_approach(shell)
	shell.call("validation_reset_battle_entry_state")
	var start := OverworldRules.hero_position(session)
	var movement_before := _movement(session)

	shell.call("_on_map_tile_pressed", enemy_tile)
	var order: Dictionary = shell.call("_current_primary_action")
	_check(String(order.get("id", "")) in ["advance_route", "march_selected"] and String(order.get("label", "")).contains("Battle"), "selecting the enemy offers a battle order that moves there")
	_check(_movement(session) == movement_before and OverworldRules.hero_position(session) == start and session.battle.is_empty(), "selecting the enemy neither moves nor fights")

	shell.call("_on_map_tile_pressed", enemy_tile)
	var spent := _movement(session)
	var steps := maxi(absi(enemy_tile.x - start.x), absi(enemy_tile.y - start.y))
	_check(OverworldRules.hero_position(session) == enemy_tile and spent == movement_before - steps, "the attack order walks the route and spends its movement")
	_check(String(session.battle.get("resolved_key", "")) == OverworldRules.encounter_key(_encounter("feedback_ghouls", enemy_tile)), "the battle against the ordered enemy is staged on arrival")
	_check(_battle_entry_requests(shell) == 0, "the battle screen waits for the walk")
	var map_walk: Dictionary = shell.get("_map_view").call("validation_hero_movement_presentation")
	_check(bool(map_walk.get("active", false)) and int(map_walk.get("route_step_count", 0)) == steps, "the hero walk animation plays the whole route")
	_check(shell.has_method("validation_battle_approach_pending") and bool(shell.call("validation_battle_approach_pending")), "the shell holds the battle until the walk ends")
	await _capture("battle_approach_walking")

	# Orders are refused while the hero marches in.
	shell.call("_on_map_tile_pressed", Vector2i(8, 4))
	shell.call("_on_map_tile_pressed", Vector2i(8, 4))
	shell.call("_move_south")
	_check(OverworldRules.hero_position(session) == enemy_tile and _movement(session) == spent, "no other order runs during the march")

	var frames := []
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		var walking := _walking(shell)
		var requests := _battle_entry_requests(shell)
		frames.append({"walking": walking, "requests": requests, "meter": _meter(shell, active_id)})
		if requests > 0:
			break
		await get_tree().process_frame
	var opened_frame := -1
	for index in range(frames.size()):
		if int(frames[index].requests) > 0:
			opened_frame = index
			break
	_check(opened_frame > 0, "the battle opens after the walk, on a later frame")
	_check(opened_frame > 0 and not bool(frames[opened_frame].walking) and bool(frames[0].walking), "the walk finished before the battle opened")
	var entry: Dictionary = shell.call("validation_battle_entry_snapshot")
	_check(_battle_entry_requests(shell) == 1 and bool(entry.get("last_result", {}).get("ok", false)), "exactly one battle entry, after arrival")
	var commander: Dictionary = session.battle.get("player_commander_state", {}) if session.battle.get("player_commander_state", {}) is Dictionary else {}
	_check(int(commander.get("movement", {}).get("current", -1)) == spent, "the battle carries the spent movement")
	_check(is_equal_approx(_meter(shell, active_id), float(spent)), "the portrait bar shows the spent movement when the battle opens")
	var approach: Dictionary = shell.call("validation_battle_approach_snapshot") if shell.has_method("validation_battle_approach_snapshot") else {}
	_check(String(approach.get("last", {}).get("completed_reason", "")) == "walk_finished", "the march completed by finishing the walk")
	_evidence["attack_in_range"] = {
		"steps": steps,
		"movement_before": movement_before,
		"movement_after": spent,
		"frames_until_battle": opened_frame,
		"approach": approach.get("last", {}),
		"walk_duration_ms": int(map_walk.get("duration_ms", 0)),
	}
	shell.queue_free()
	await _settle(2)

# --- random-map guard ---------------------------------------------------------------

## Random-map guards fight from a ring of engagement tiles around the painted
## stack. Clicking the stack must walk to the first ring tile, then fight.
func _check_guard_attack() -> void:
	var anchor := Vector2i(11, 3)
	var ring := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				ring.append({"x": anchor.x + dx, "y": anchor.y + dy})
	var guard := _encounter("feedback_ring_guard", anchor)
	guard["kind"] = "guard"
	guard["package_guard_engagement_tiles"] = ring
	var opened := await _open_shell(_fixture_session(Vector2i(2, 3), 14, 14, [guard]))
	var shell: Node = opened.shell
	var session = opened.session
	_enable_battle_approach(shell)
	shell.call("validation_reset_battle_entry_state")
	var start := OverworldRules.hero_position(session)
	var movement_before := _movement(session)

	shell.call("_on_map_tile_pressed", anchor)
	var entry: Vector2i = shell.get("_selected_tile")
	_check(ring.has({"x": entry.x, "y": entry.y}), "clicking the guard selects its nearest engagement tile")
	_check(_movement(session) == movement_before and session.battle.is_empty(), "selecting the guard neither moves nor fights")
	shell.call("_on_map_tile_pressed", anchor)
	var steps := maxi(absi(entry.x - start.x), absi(entry.y - start.y))
	_check(OverworldRules.hero_position(session) == entry and _movement(session) == movement_before - steps, "the guard attack walks to the engagement tile and spends its movement")
	_check(not session.battle.is_empty() and _battle_entry_requests(shell) == 0, "the guard battle is staged and waits for the walk")
	var walk_seen := false
	var started := Time.get_ticks_msec()
	while _battle_entry_requests(shell) == 0 and Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		walk_seen = walk_seen or _walking(shell)
		await get_tree().process_frame
	_check(walk_seen and _battle_entry_requests(shell) == 1, "the guard battle opens after the walk")
	_check(String(session.battle.get("resolved_key", "")) == OverworldRules.encounter_key(guard), "the battle is against the clicked guard")
	_evidence["guard_attack"] = {"entry": {"x": entry.x, "y": entry.y}, "steps": steps, "movement_after": _movement(session)}
	shell.queue_free()
	await _settle(2)

# --- attack out of range ------------------------------------------------------------

func _check_attack_out_of_range() -> void:
	var enemy_tile := Vector2i(9, 3)
	var opened := await _open_shell(_fixture_session(Vector2i(2, 3), 8, 3, [_encounter("feedback_far_ghouls", enemy_tile)]))
	var shell: Node = opened.shell
	var session = opened.session
	var active_id := String(session.overworld.get("active_hero_id", ""))
	_enable_battle_approach(shell)
	shell.call("validation_reset_battle_entry_state")
	var movement_before := _movement(session)
	_check(movement_before == 3, "fixture hero has three points for a seven-step attack")

	shell.call("_on_map_tile_pressed", enemy_tile)
	shell.call("_on_map_tile_pressed", enemy_tile)
	var stop_tile := OverworldRules.hero_position(session)
	_check(stop_tile == Vector2i(5, 3) and _movement(session) == 0, "out-of-range attack walks as far as today's movement allows")
	_check(session.battle.is_empty() and _battle_entry_requests(shell) == 0, "out-of-range attack stops short without a battle")
	_check(not (shell.has_method("validation_battle_approach_pending") and bool(shell.call("validation_battle_approach_pending"))), "no march to battle is pending")
	_check(not OverworldRules.is_encounter_resolved(session, _encounter("feedback_far_ghouls", enemy_tile)), "the enemy is still there")
	await _sample_walk(shell, active_id)
	_check(is_equal_approx(_meter(shell, active_id), 0.0), "portrait bar shows the exhausted movement")
	await _capture("portrait_after_short_attack")

	var end_turn: Dictionary = shell.call("validation_end_turn")
	await _wait_turn_playback(shell)
	_check(session.scenario_status == "in_progress" and session.battle.is_empty(), "the next day starts quietly")
	var refilled := _movement(session)
	_check(refilled >= 4 and is_equal_approx(_meter(shell, active_id), float(refilled)), "next day the portrait bar shows the refilled movement")
	shell.call("_on_map_tile_pressed", enemy_tile)
	shell.call("_on_map_tile_pressed", enemy_tile)
	_check(OverworldRules.hero_position(session) == enemy_tile and _movement(session) == refilled - 4, "continuing the attack walks the remaining steps")
	_check(not session.battle.is_empty() and _battle_entry_requests(shell) == 0, "the battle is staged on arrival and waits for the walk")
	var started := Time.get_ticks_msec()
	while _battle_entry_requests(shell) == 0 and Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		await get_tree().process_frame
	_check(_battle_entry_requests(shell) == 1, "continuing the attack opens the battle on arrival")
	_evidence["attack_out_of_range"] = {
		"stop_tile": {"x": stop_tile.x, "y": stop_tile.y},
		"end_turn_ok": bool(end_turn.get("ok", false)),
		"next_day_movement": refilled,
	}
	shell.queue_free()
	await _settle(2)

# --- helpers -------------------------------------------------------------------------

func _enable_battle_approach(shell: Node) -> void:
	# Headless runs keep the synchronous battle handoff unless a report opts in.
	if shell.has_method("validation_set_battle_approach_presentation_enabled"):
		shell.call("validation_set_battle_approach_presentation_enabled", true)

## Windowed runs play the enemy turn before the new day's refresh.
func _wait_turn_playback(shell: Node) -> void:
	var started := Time.get_ticks_msec()
	while is_instance_valid(shell.get("_turn_presenter")) and Time.get_ticks_msec() - started < 30000:
		var presenter: Node = shell.get("_turn_presenter")
		presenter.call("skip_playback")
		await get_tree().process_frame
	await _settle(4)

func _walking(shell: Node) -> bool:
	return bool(shell.get("_map_view").get("_hero_movement_active"))

func _battle_entry_requests(shell: Node) -> int:
	return int(shell.call("validation_battle_entry_snapshot").get("request_count", 0))

func _sample_walk(shell: Node, hero_id: String) -> Dictionary:
	var samples := []
	var walk_seen := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		samples.append(_meter(shell, hero_id))
		var walking := _walking(shell)
		walk_seen = walk_seen or walking
		if not walking:
			break
		await get_tree().process_frame
	await _settle(2)
	samples.append(_meter(shell, hero_id))
	var non_increasing := true
	for index in range(1, samples.size()):
		non_increasing = non_increasing and float(samples[index]) <= float(samples[index - 1])
	return {
		"walk_seen": walk_seen,
		"first": samples[0] if not samples.is_empty() else -1.0,
		"last": samples[samples.size() - 1] if not samples.is_empty() else -1.0,
		"distinct": _distinct(samples),
		"frames": samples.size(),
		"non_increasing": non_increasing,
	}

func _distinct(values: Array) -> Array:
	var distinct := []
	for value in values:
		if distinct.is_empty() or not is_equal_approx(float(distinct[distinct.size() - 1]), float(value)):
			distinct.append(value)
	return distinct

func _roster_button(shell: Node, hero_id: String) -> Button:
	for child in shell.get("_hero_actions").get_children():
		if child is Button and String(child.get_meta("hero_id", "")) == hero_id:
			return child
	return null

func _meter(shell: Node, hero_id: String) -> float:
	var button := _roster_button(shell, hero_id)
	var bar := button.get_node_or_null("Movement") as ProgressBar if button != null else null
	return bar.value if bar != null else -1.0

func _roster_instance_ids(shell: Node) -> Array:
	var ids := []
	for child in shell.get("_hero_actions").get_children():
		ids.append(child.get_instance_id())
	return ids

func _movement(session) -> int:
	return int(session.overworld.get("movement", {}).get("current", 0))

func _reserve_id(session) -> String:
	var active_id := String(session.overworld.get("active_hero_id", ""))
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) != active_id:
			return String(hero.get("id", ""))
	return ""

func _encounter(placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "encounter_id": ENCOUNTER_ID, "x": tile.x, "y": tile.y, "difficulty": "low"}

func _fixture_session(hero_tile: Vector2i, base_movement: int, movement_current: int, encounters: Array):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var width := 16
	var height := 6
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{"placement_id": "riverwatch_hold", "town_id": "town_riverwatch", "x": 0, "y": 0, "owner": "player"}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = encounters.duplicate(true)
	session.overworld["resolved_encounters"] = []
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if String(heroes[index].get("id", "")) == active_id:
			var hero: Dictionary = heroes[index]
			hero["position"] = {"x": hero_tile.x, "y": hero_tile.y}
			hero["base_movement"] = base_movement
			hero["specialties"] = []
			hero["movement"] = {"current": movement_current, "max": base_movement}
			heroes[index] = hero
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	var template := ContentService.get_hero(reserve_id)
	heroes.append({
		"id": reserve_id,
		"name": String(template.get("name", reserve_id)),
		"faction_id": String(template.get("faction_id", "")),
		"is_primary": false,
		"position": {"x": 1, "y": 5},
		"movement": {"current": 7, "max": 7},
		"base_movement": 7,
		"level": 1,
		"experience": 0,
		"specialties": [],
		"army": {"id": "%s_army" % reserve_id, "name": "Reserve Army", "stacks": []},
		"command": template.get("command", {}).duplicate(true) if template.get("command", {}) is Dictionary else {},
	})
	session.overworld["player_heroes"] = heroes
	HeroCommandRules._sync_active_hero_mirror(session)
	OverworldRules.normalize_overworld_state(session)
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = mini(movement_current, int(movement.get("max", movement_current)))
	session.overworld["movement"] = movement
	HeroCommandRules.commit_active_hero(session)
	# The whole fixture strip is scouted, so every order targets a known tile.
	var explored := []
	for _y in range(height):
		var explored_row := []
		for _x in range(width):
			explored_row.append(true)
		explored.append(explored_row)
	session.overworld["fog"] = {OverworldRules.EXPLORED_TILES_KEY: explored}
	OverworldRules.refresh_fog_of_war(session)
	return session

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _settle(3)
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _settle(frames: int) -> void:
	for _frame in range(frames):
		await get_tree().process_frame

func _capture(label: String) -> void:
	if _shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(label + ".png"))
