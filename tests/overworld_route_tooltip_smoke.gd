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

	_set_active_hero_position(session, Vector2i(1, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var snapshot: Dictionary = shell.call("validation_select_tile", 1, 0)
	var route_decision: Dictionary = snapshot.get("selected_route_decision", {})
	var decision_brief: Dictionary = route_decision.get("decision_brief", {})
	var joined := "\n".join([
		String(route_decision.get("decision_brief_text", "")),
		String(decision_brief.get("affected", "")),
		String(decision_brief.get("why_it_matters", "")),
		String(decision_brief.get("next_step", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(snapshot.get("map_tooltip", "")),
		String(snapshot.get("primary_action", {}).get("summary", "")),
	])
	if String(route_decision.get("status", "")) != "reachable":
		_fail("Route tooltip smoke: Timber Wagon route should be reachable.", snapshot)
		return
	if String(route_decision.get("action_kind", "")) != "move/collect":
		_fail("Route tooltip smoke: Timber Wagon route should expose move/collect.", snapshot)
		return
	if not _assert_text_contains_all(
		"Route tooltip smoke",
		joined,
		[
			"Decision Brief",
			"Affected:",
			"Timber Wagon route",
			"Objective:",
			"Claim Duskfen Bastion",
			"Why it matters:",
			"Next:",
			"Commit Advance to Site now.",
		]
	):
		return
	if not _assert_no_ai_score_leak("Route tooltip smoke", joined):
		return
	get_tree().quit(0)

func _set_active_hero_position(session, tile: Vector2i) -> void:
	session.overworld["hero_position"] = {"x": tile.x, "y": tile.y}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = {"x": tile.x, "y": tile.y}
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = {"x": tile.x, "y": tile.y}
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _assert_text_contains_all(label: String, text: String, needles: Array) -> bool:
	for needle in needles:
		if text.find(String(needle)) < 0:
			_fail("%s missing '%s'." % [label, String(needle)], {"text": text})
			return false
	return true

func _assert_no_ai_score_leak(label: String, text: String) -> bool:
	for token in ["base_value", "persistent_income_value", "final_priority", "assignment_penalty", "route_pressure_value", "denial_value", "debug_reason", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score"]:
		if text.find(token) >= 0:
			_fail("%s leaked AI score/debug token %s." % [label, token], {"text": text})
			return false
	return true

func _fail(message: String, payload: Dictionary) -> void:
	push_error("%s payload=%s" % [message, payload])
	get_tree().quit(1)
