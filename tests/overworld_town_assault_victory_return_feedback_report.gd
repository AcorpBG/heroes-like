extends Node

const REPORT_ID := "OVERWORLD_TOWN_ASSAULT_VICTORY_RETURN_FEEDBACK_REPORT"
const OVERWORLD_SCENE := preload("res://scenes/overworld/OverworldShell.tscn")
const TARGET_WIDTHS := [1280, 1920]
const TOWN_PLACEMENT_ID := "duskfen_bastion"

var _evidence: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for width in TARGET_WIDTHS:
		if not await _run_live_assault_case(width):
			return
	if not _run_fail_closed_controls():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"widths": TARGET_WIDTHS,
		"cases": _evidence,
		"one_shot_route_local": true,
		"save_schema_unchanged": true,
	})])
	get_tree().quit(0)

func _run_live_assault_case(width: int) -> bool:
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	PresentationAudio.validation_reset()
	var staged := _resolved_town_assault()
	if staged.is_empty():
		return false
	var session = staged.get("session", null)
	var outcome: Dictionary = staged.get("outcome", {})
	session = SessionState.set_active_session(session)
	var authority_after_rules: Dictionary = session.to_dict()
	var checkpoint: Dictionary = AppRouter.checkpoint_battle_resolution_for_overworld(false)
	var authority_after_checkpoint: Dictionary = session.to_dict()
	var autosave_summary: Dictionary = SaveService.inspect_autosave()
	if (
		not bool(checkpoint.get("ok", false))
		or not bool(checkpoint.get("saved", false))
		or String(checkpoint.get("reason", "")) != "saved"
		or session.game_state != "overworld"
		or not session.battle.is_empty()
		or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty()
		or String(autosave_summary.get("resume_target", "")) != "overworld"
		or String(_town_by_placement(session, TOWN_PLACEMENT_ID).get("owner", "")) != "player"
	):
		return _fail("Resolved assault did not reach an exact durable Overworld checkpoint before presentation arming.", {
			"width": width,
			"checkpoint": checkpoint,
			"autosave": autosave_summary,
		})
	var control_session = SessionState.new_session_data()
	control_session.from_dict(authority_after_checkpoint)
	control_session = SessionState.set_active_session(control_session)
	var control_frame := Control.new()
	control_frame.name = "AssaultReturnControlFrame%d" % width
	control_frame.size = Vector2(width, 720)
	add_child(control_frame)
	var control_shell := OVERWORLD_SCENE.instantiate()
	control_frame.add_child(control_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var control_cue := _object_resolution(control_shell)
	var authority_after_ready_control: Dictionary = control_session.to_dict()
	if int(control_cue.get("serial", 0)) != 0 or String(control_cue.get("event_id", "")) != "":
		return _fail("Method-matched Overworld control published an unarmed object-resolution cue.", {"width": width, "cue": control_cue})
	control_frame.queue_free()
	await get_tree().process_frame
	var routed_session = SessionState.new_session_data()
	routed_session.from_dict(authority_after_checkpoint)
	session = SessionState.set_active_session(routed_session)
	var pending: Dictionary = AppRouter.arm_battle_resolution_overworld_presentation(outcome)
	var expected_town: Dictionary = _town_by_placement(session, TOWN_PLACEMENT_ID)
	var expected_tile := {"x": int(expected_town.get("x", -1)), "y": int(expected_town.get("y", -1))}
	if (
		String(pending.get("event_id", "")) != "overworld_object_captured"
		or String(pending.get("family", "")) != "town_capture"
		or String(pending.get("placement_id", "")) != TOWN_PLACEMENT_ID
		or String(pending.get("content_id", "")) != String(expected_town.get("town_id", ""))
		or pending.get("tile", {}) != expected_tile
		or String(pending.get("owner", "")) != "player"
		or int(pending.get("sequence", 0)) <= 0
		or JSON.stringify(session.to_dict()).contains("pending_battle_resolution_overworld_presentation")
		or session.to_dict() != authority_after_checkpoint
	):
		return _fail("Durable assault victory did not arm the exact detached route-local capture payload.", {"width": width, "pending": pending})

	var frame := Control.new()
	frame.name = "AssaultReturnFrame%d" % width
	frame.size = Vector2(width, 720)
	add_child(frame)
	var shell := OVERWORLD_SCENE.instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var cue := _object_resolution(shell)
	var serial := int(cue.get("serial", 0))
	if (
		serial <= 0
		or String(cue.get("event_id", "")) != "overworld_object_captured"
		or String(cue.get("family", "")) != "town_capture"
		or String(cue.get("placement_id", "")) != TOWN_PLACEMENT_ID
		or cue.get("tile", {}) != expected_tile
		or String(cue.get("animation_state", "")) != "ownership_capture"
		or cue.get("selected_vfx_cue_ids", []) != ["vfx_placeholder_capture_flag"]
		or cue.get("selected_audio_cue_ids", []) != ["audio_placeholder_capture"]
		or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty()
		or session.to_dict() != authority_after_ready_control
	):
		return _fail("Returned Overworld did not consume one exact hostile-town capture cue.", {"width": width, "cue": cue})
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _object_resolution(shell)
	if int(refreshed.get("serial", -1)) != serial or session.to_dict() != authority_after_ready_control:
		return _fail("Overworld refresh replayed or mutated the consumed assault-return cue.", {"width": width, "before": cue, "after": refreshed})
	frame.queue_free()
	await get_tree().process_frame

	var later_frame := Control.new()
	later_frame.name = "AssaultReturnLaterFrame%d" % width
	later_frame.size = Vector2(width, 720)
	add_child(later_frame)
	var later_shell := OVERWORLD_SCENE.instantiate()
	later_frame.add_child(later_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var later_cue := _object_resolution(later_shell)
	if int(later_cue.get("serial", 0)) != 0 or String(later_cue.get("event_id", "")) != "" or session.to_dict() != authority_after_ready_control:
		return _fail("A later Overworld scene replayed the route-local assault-return cue.", {"width": width, "cue": later_cue})
	later_frame.queue_free()
	await get_tree().process_frame
	_evidence.append({
		"width": width,
		"placement_id": TOWN_PLACEMENT_ID,
		"tile": expected_tile,
		"serial": serial,
		"checkpoint_saved": true,
		"rules_authority_changed": authority_after_rules != authority_after_checkpoint,
		"consumed_once": true,
		"later_scene_replay": false,
	})
	return true

func _run_fail_closed_controls() -> bool:
	var staged := _resolved_town_assault()
	if staged.is_empty():
		return false
	var session = staged.get("session", null)
	var outcome: Dictionary = staged.get("outcome", {})
	session = SessionState.set_active_session(session)
	session.game_state = "overworld"
	var authority_before: Dictionary = session.to_dict()

	var malformed := outcome.duplicate(true)
	malformed.erase("battle_resolution_context_snapshot")
	if not AppRouter.arm_battle_resolution_overworld_presentation(malformed).is_empty():
		return _fail("Malformed battle result armed an assault-return presentation.", malformed)

	var wrong_context := outcome.duplicate(true)
	wrong_context["battle_resolution_context_snapshot"]["context"]["type"] = "encounter"
	if not AppRouter.arm_battle_resolution_overworld_presentation(wrong_context).is_empty():
		return _fail("Non-assault battle context armed an assault-return presentation.", wrong_context)

	var wrong_owner_before := String(_town_by_placement(session, TOWN_PLACEMENT_ID).get("owner", ""))
	_set_town_owner(session, TOWN_PLACEMENT_ID, "enemy")
	if not AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Wrong-owner live town armed an assault-return presentation.", _town_by_placement(session, TOWN_PLACEMENT_ID))
	_set_town_owner(session, TOWN_PLACEMENT_ID, wrong_owner_before)

	var terminal_status: String = session.scenario_status
	session.scenario_status = "victory"
	if not AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Terminal scenario armed an assault-return presentation.", session.to_dict())
	session.scenario_status = terminal_status

	var stale := AppRouter.arm_battle_resolution_overworld_presentation(outcome)
	if stale.is_empty():
		return _fail("Stale-consumption control could not arm its valid payload.", outcome)
	session.day += 1
	if not AppRouter.consume_battle_resolution_overworld_presentation("overworld").is_empty() or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty():
		return _fail("Stale day payload survived fail-closed one-shot consumption.", stale)
	session.day -= 1

	if AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Wrong-surface control could not arm its valid payload.", outcome)
	if not AppRouter.consume_battle_resolution_overworld_presentation("battle").is_empty() or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty():
		return _fail("Wrong surface did not clear the one-shot assault-return payload.", {})
	if session.to_dict() != authority_before:
		return _fail("Fail-closed presentation controls mutated resolved session authority.", {"before": authority_before, "after": session.to_dict()})
	_evidence.append({
		"fail_closed": ["malformed", "wrong_context", "wrong_owner", "terminal", "stale", "wrong_surface"],
		"session_authority_exact": true,
	})
	return true

func _resolved_town_assault() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _town_by_placement(session, TOWN_PLACEMENT_ID)
	if town.is_empty():
		_fail("Hostile-town fixture is missing Duskfen Bastion.", {})
		return {}
	_set_active_hero_position(session, Vector2i(int(town.get("x", -1)), int(town.get("y", -1))))
	var assault: Dictionary = OverworldRules.capture_active_town(session)
	if String(assault.get("route", "")) != "battle" or String(session.battle.get("context", {}).get("type", "")) != "town_assault":
		_fail("Hostile-town fixture did not enter a real town-assault battle.", assault)
		return {}
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var outcome: Dictionary = BattleRules.resolve_if_battle_ready(session)
	var snapshot: Dictionary = outcome.get("battle_resolution_context_snapshot", {}) if outcome.get("battle_resolution_context_snapshot", {}) is Dictionary else {}
	if (
		String(outcome.get("state", "")) != "victory"
		or not session.battle.is_empty()
		or String(snapshot.get("context", {}).get("type", "")) != "town_assault"
		or String(snapshot.get("context", {}).get("town_placement_id", "")) != TOWN_PLACEMENT_ID
		or String(_town_by_placement(session, TOWN_PLACEMENT_ID).get("owner", "")) != "player"
	):
		_fail("Real town-assault battle did not resolve with exact detached context and ownership transfer.", outcome)
		return {}
	return {"session": session, "outcome": outcome.duplicate(true)}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _set_town_owner(session, placement_id: String, owner: String) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _fail(message: String, evidence: Variant) -> bool:
	push_error("%s: %s evidence=%s" % [REPORT_ID, message, JSON.stringify(evidence)])
	get_tree().quit(1)
	return false
