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
		String(snapshot.get("map_cue_text", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(snapshot.get("map_tooltip", "")),
		String(snapshot.get("primary_action", {}).get("summary", "")),
	])
	if String(route_decision.get("status", "")) != "reachable":
		_fail("Route tooltip smoke: Wood Wagon route should be reachable.", snapshot)
		return
	if String(route_decision.get("action_kind", "")) != "move/collect":
		_fail("Route tooltip smoke: Wood Wagon route should expose move/collect.", snapshot)
		return
	if not _assert_text_contains_all(
		"Route tooltip smoke",
		joined,
		[
			"Decision Brief",
			"Affected:",
			"Wood Wagon route",
			"Objective:",
			"Claim Duskfen Bastion",
			"Why it matters:",
			"Next:",
			"Commit Advance to Site now.",
			"Try: Advance to Site [Enter]",
		]
	):
		return
	if not _assert_no_ai_score_leak("Route tooltip smoke", joined):
		return
	if not _assert_town_entry_handoff_cue(shell):
		return
	if not await _assert_overworld_spell_check_cue(shell):
		return
	get_tree().quit(0)

func _assert_town_entry_handoff_cue(shell: Node) -> bool:
	var session = SessionState.ensure_active_session()
	_set_active_hero_position(session, Vector2i(1, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var snapshot: Dictionary = shell.call("validation_select_tile", 0, 2)
	var handoff: Dictionary = snapshot.get("town_entry_handoff", {})
	var readiness: Dictionary = snapshot.get("field_readiness", {})
	var readiness_handoff: Dictionary = readiness.get("town_entry_handoff", {})
	var primary_action: Dictionary = snapshot.get("primary_action", {})
	var action_handoff: Dictionary = primary_action.get("town_entry_handoff", {}) if primary_action.get("town_entry_handoff", {}) is Dictionary else {}
	var joined := "\n".join([
		String(snapshot.get("primary_action_button_text", "")),
		String(snapshot.get("primary_action_button_tooltip_text", "")),
		String(snapshot.get("selected_tile_rail_text", "")),
		String(snapshot.get("town_entry_handoff_visible_text", "")),
		String(snapshot.get("town_entry_handoff_tooltip_text", "")),
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("summary_text", "")),
		String(readiness.get("visible_text", "")),
		String(readiness.get("tooltip_text", "")),
		String(readiness_handoff.get("visible_text", "")),
		String(readiness_handoff.get("tooltip_text", "")),
		String(primary_action.get("summary", "")),
		String(action_handoff.get("tooltip_text", "")),
	])
	if String(snapshot.get("primary_action_id", "")) != "visit_town":
		_fail("Town entry handoff smoke: selected town should expose Visit Town.", snapshot)
		return false
	if not _assert_text_contains_all(
		"Town entry handoff smoke",
		joined,
		[
			"Visit Town [Enter]",
			"Town handoff:",
			"Town Entry Handoff",
			"Enter: Visit Town opens Riverwatch Hold management.",
			"Field position: active hero remains at 1,2.",
			"Movement: Move",
			"Return: Leave returns to the overworld; the day does not advance.",
			"State change:",
			"Leave returns to the field at 1,2",
			"Primary Order Check",
			"Enter/Space enters the town without ending the day",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Town entry handoff smoke", joined):
		return false
	return true

func _assert_overworld_spell_check_cue(shell: Node) -> bool:
	var session = SessionState.ensure_active_session()
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	shell.call("_refresh")

	var full_snapshot: Dictionary = shell.call("validation_snapshot")
	var full_spell_action := _action_by_id(full_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	var full_text := _spell_surface_text(full_snapshot, full_spell_action)
	if full_spell_action.is_empty() or not bool(full_spell_action.get("disabled", false)):
		_fail("Overworld spell check smoke: full movement should block Waystride.", full_snapshot)
		return false
	if not _assert_text_contains_all(
		"Overworld spell blocked check smoke",
		full_text,
		[
			"Spell check:",
			"Spell Check",
			"Blocked x0/1",
			"Waystride",
			"Mana",
			"Movement",
			"Best spell:",
			"Next practical action:",
			"Spell Cast Check",
			"State change: casting spends mana",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Overworld spell blocked check smoke", full_text):
		return false

	var start := OverworldRules.hero_position(session)
	var safe_step: Vector2i = shell.call("_first_validation_safe_step", start)
	if safe_step.x < 0:
		_fail("Overworld spell check smoke: could not find a safe step.", full_snapshot)
		return false
	shell.call("validation_select_tile", safe_step.x, safe_step.y)
	var move_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	if not bool(move_result.get("ok", false)):
		_fail("Overworld spell check smoke: movement setup failed.", move_result)
		return false
	var ready_snapshot: Dictionary = shell.call("validation_snapshot")
	var ready_spell_action := _action_by_id(ready_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	var ready_text := _spell_surface_text(ready_snapshot, ready_spell_action)
	if ready_spell_action.is_empty() or bool(ready_spell_action.get("disabled", false)):
		_fail("Overworld spell check smoke: spent movement should ready Waystride.", ready_snapshot)
		return false
	if not _assert_text_contains_all(
		"Overworld spell ready check smoke",
		ready_text,
		[
			"Spell check:",
			"Spell Check",
			"Ready x1/1",
			"Waystride",
			"Mana",
			"Movement",
			"Best spell:",
			"Next practical action:",
			"Spell Cast Check",
			"Cast now",
			"State change: casting spends mana",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Overworld spell ready check smoke", ready_text):
		return false
	return true

func _spell_surface_text(snapshot: Dictionary, spell_action: Dictionary) -> String:
	var action_surfaces := []
	for surface in (snapshot.get("spell_action_surfaces", []) if snapshot.get("spell_action_surfaces", []) is Array else []):
		if surface is Dictionary:
			action_surfaces.append("%s\n%s" % [String(surface.get("text", "")), String(surface.get("tooltip", ""))])
	return "\n".join([
		String(snapshot.get("spell_check_visible_text", "")),
		String(snapshot.get("spell_check_tooltip_text", "")),
		String(spell_action.get("spell_check_tooltip_text", "")),
		"\n".join(action_surfaces),
	])

func _action_by_id(actions: Variant, action_id: String) -> Dictionary:
	if not (actions is Array):
		return {}
	for action in actions:
		if action is Dictionary and String(action.get("id", "")) == action_id:
			return action
	return {}

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
