extends Node

const REPORT_ID := "OVERWORLD_ENCOUNTER_VICTORY_RETURN_FEEDBACK_REPORT"
const OVERWORLD_SCENE := preload("res://scenes/overworld/OverworldShell.tscn")
const TARGET_WIDTHS := [1280, 1920]
const ENCOUNTER_PLACEMENT_ID := "river_pass_hollow_mire"
const GUARDED_RESOURCE_PLACEMENT_ID := "duskfen_bastion_peatwax_front"
const PRODUCTION_STACKS := [
	{"unit_id": "unit_mireclaw_bogplate_maulers", "count": 4},
	{"unit_id": "unit_mireclaw_mudglass_slingers", "count": 3},
]

var _evidence: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for width in TARGET_WIDTHS:
		if not await _run_live_encounter_case(width):
			return
	if not _run_fail_closed_controls():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"widths": TARGET_WIDTHS,
		"encounter_placement_id": ENCOUNTER_PLACEMENT_ID,
		"guarded_resource_placement_id": GUARDED_RESOURCE_PLACEMENT_ID,
		"cases": _evidence,
		"one_shot_route_local": true,
		"guarded_resource_preserved": true,
		"save_schema_unchanged": true,
	})])
	get_tree().quit(0)

func _run_live_encounter_case(width: int) -> bool:
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	PresentationAudio.validation_reset()
	var staged := _resolved_static_encounter()
	if staged.is_empty():
		return false
	var session = staged.get("session", null)
	var outcome: Dictionary = staged.get("outcome", {})
	var guarded_resource: Dictionary = staged.get("guarded_resource", {})
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
		or _resource_by_placement(session, GUARDED_RESOURCE_PLACEMENT_ID) != guarded_resource
	):
		return _fail("Resolved static encounter did not reach an exact durable Overworld checkpoint with its guarded resource unchanged.", {
			"width": width,
			"checkpoint": checkpoint,
			"autosave": autosave_summary,
		})

	var control_session = SessionState.new_session_data()
	control_session.from_dict(authority_after_checkpoint)
	control_session = SessionState.set_active_session(control_session)
	var control_frame := Control.new()
	control_frame.name = "EncounterReturnControlFrame%d" % width
	control_frame.size = Vector2(width, 720)
	add_child(control_frame)
	var control_shell := OVERWORLD_SCENE.instantiate()
	control_frame.add_child(control_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var control_cue := _object_resolution(control_shell)
	var authority_after_ready_control: Dictionary = control_session.to_dict()
	if int(control_cue.get("serial", 0)) != 0 or String(control_cue.get("event_id", "")) != "":
		return _fail("Method-matched Overworld control published an unarmed encounter-resolution cue.", {"width": width, "cue": control_cue})
	control_frame.queue_free()
	await get_tree().process_frame

	var routed_session = SessionState.new_session_data()
	routed_session.from_dict(authority_after_checkpoint)
	session = SessionState.set_active_session(routed_session)
	var pending: Dictionary = AppRouter.arm_battle_resolution_overworld_presentation(outcome)
	var encounter: Dictionary = _encounter_by_placement(session, ENCOUNTER_PLACEMENT_ID)
	var expected_tile := {"x": int(encounter.get("x", -1)), "y": int(encounter.get("y", -1))}
	if (
		String(pending.get("event_id", "")) != "overworld_object_depleted"
		or String(pending.get("family", "")) != "encounter"
		or String(pending.get("placement_id", "")) != ENCOUNTER_PLACEMENT_ID
		or String(pending.get("content_id", "")) != String(encounter.get("encounter_id", ""))
		or pending.get("tile", {}) != expected_tile
		or String(pending.get("owner", "")) != "resolved"
		or int(pending.get("sequence", 0)) <= 0
		or not OverworldRules.is_encounter_resolved(session, encounter)
		or JSON.stringify(session.to_dict()).contains("pending_battle_resolution_overworld_presentation")
		or session.to_dict() != authority_after_checkpoint
	):
		return _fail("Durable encounter victory did not arm the exact detached route-local depleted payload.", {"width": width, "pending": pending})

	var frame := Control.new()
	frame.name = "EncounterReturnFrame%d" % width
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
		or String(cue.get("event_id", "")) != "overworld_object_depleted"
		or String(cue.get("family", "")) != "encounter"
		or String(cue.get("placement_id", "")) != ENCOUNTER_PLACEMENT_ID
		or cue.get("tile", {}) != expected_tile
		or String(cue.get("animation_state", "")) != "depleted_remove_or_dim"
		or cue.get("selected_vfx_cue_ids", []) != ["vfx_placeholder_depleted_dim"]
		or cue.get("selected_audio_cue_ids", []) != ["audio_placeholder_collect"]
		or (cue.get("audio_playback_records", []) as Array).size() != 1
		or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty()
		or session.to_dict() != authority_after_ready_control
		or _resource_by_placement(session, GUARDED_RESOURCE_PLACEMENT_ID) != guarded_resource
	):
		return _fail("Returned Overworld did not consume one exact encounter-depleted cue while preserving the guarded resource.", {"width": width, "cue": cue})
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _object_resolution(shell)
	if int(refreshed.get("serial", -1)) != serial or session.to_dict() != authority_after_ready_control:
		return _fail("Overworld refresh replayed or mutated the consumed encounter cue.", {"width": width, "before": cue, "after": refreshed})
	frame.queue_free()
	await get_tree().process_frame

	var later_frame := Control.new()
	later_frame.name = "EncounterReturnLaterFrame%d" % width
	later_frame.size = Vector2(width, 720)
	add_child(later_frame)
	var later_shell := OVERWORLD_SCENE.instantiate()
	later_frame.add_child(later_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var later_cue := _object_resolution(later_shell)
	if int(later_cue.get("serial", 0)) != 0 or String(later_cue.get("event_id", "")) != "" or session.to_dict() != authority_after_ready_control:
		return _fail("A later Overworld scene replayed the route-local encounter cue.", {"width": width, "cue": later_cue})
	later_frame.queue_free()
	await get_tree().process_frame
	_evidence.append({
		"width": width,
		"placement_id": ENCOUNTER_PLACEMENT_ID,
		"tile": expected_tile,
		"serial": serial,
		"checkpoint_saved": true,
		"rules_authority_changed": authority_after_rules != authority_after_checkpoint,
		"guarded_resource_exact": true,
		"consumed_once": true,
		"later_scene_replay": false,
	})
	return true

func _run_fail_closed_controls() -> bool:
	var staged := _resolved_static_encounter()
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
		return _fail("Malformed battle result armed an encounter return presentation.", malformed)

	var missing_identity := outcome.duplicate(true)
	missing_identity["battle_resolution_context_snapshot"].erase("encounter")
	if not AppRouter.arm_battle_resolution_overworld_presentation(missing_identity).is_empty():
		return _fail("Encounter result without detached identity armed a return presentation.", missing_identity)

	for field in ["placement_id", "encounter_id", "x", "y"]:
		var wrong_identity := outcome.duplicate(true)
		wrong_identity["battle_resolution_context_snapshot"]["encounter"][field] = "wrong" if field in ["placement_id", "encounter_id"] else -9
		if not AppRouter.arm_battle_resolution_overworld_presentation(wrong_identity).is_empty():
			return _fail("Mismatched detached encounter identity armed a return presentation.", {"field": field, "result": wrong_identity})

	var encounter_before_missing_content: Dictionary = _encounter_by_placement(session, ENCOUNTER_PLACEMENT_ID).duplicate(true)
	_set_encounter_field(session, ENCOUNTER_PLACEMENT_ID, "encounter_id", "encounter_missing_return_fixture")
	var missing_content := outcome.duplicate(true)
	missing_content["battle_resolution_context_snapshot"]["encounter"]["encounter_id"] = "encounter_missing_return_fixture"
	if not AppRouter.arm_battle_resolution_overworld_presentation(missing_content).is_empty():
		return _fail("Missing encounter content armed a return presentation despite matching detached and live ids.", missing_content)
	_replace_encounter(session, ENCOUNTER_PLACEMENT_ID, encounter_before_missing_content)

	var wrong_context := outcome.duplicate(true)
	wrong_context["battle_resolution_context_snapshot"]["context"]["type"] = "resource_assault"
	if not AppRouter.arm_battle_resolution_overworld_presentation(wrong_context).is_empty():
		return _fail("Assault context armed an encounter-depleted presentation.", wrong_context)

	var non_victory := outcome.duplicate(true)
	non_victory["state"] = "stalemate"
	if not AppRouter.arm_battle_resolution_overworld_presentation(non_victory).is_empty():
		return _fail("Non-victory outcome armed an encounter return presentation.", non_victory)

	var resolved: Array = session.overworld.get("resolved_encounters", []).duplicate(true)
	resolved.erase(ENCOUNTER_PLACEMENT_ID)
	session.overworld["resolved_encounters"] = resolved
	if not AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Unresolved live encounter armed a depleted presentation.", resolved)
	resolved.append(ENCOUNTER_PLACEMENT_ID)
	session.overworld["resolved_encounters"] = resolved

	var encounter_before_spawned_control: Dictionary = _encounter_by_placement(session, ENCOUNTER_PLACEMENT_ID).duplicate(true)
	_set_encounter_field(session, ENCOUNTER_PLACEMENT_ID, "spawned_by_faction_id", "faction_mireclaw")
	if not AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Spawned raid armed a static encounter-depleted presentation.", _encounter_by_placement(session, ENCOUNTER_PLACEMENT_ID))
	_replace_encounter(session, ENCOUNTER_PLACEMENT_ID, encounter_before_spawned_control)

	var terminal_status: String = session.scenario_status
	session.scenario_status = "victory"
	if not AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Terminal scenario armed an encounter return presentation.", session.to_dict())
	session.scenario_status = terminal_status

	var stale := AppRouter.arm_battle_resolution_overworld_presentation(outcome)
	if stale.is_empty():
		return _fail("Stale-consumption control could not arm its valid encounter payload.", outcome)
	session.day += 1
	if not AppRouter.consume_battle_resolution_overworld_presentation("overworld").is_empty() or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty():
		return _fail("Stale day payload survived fail-closed one-shot consumption.", stale)
	session.day -= 1

	if AppRouter.arm_battle_resolution_overworld_presentation(outcome).is_empty():
		return _fail("Wrong-surface control could not arm its valid encounter payload.", outcome)
	if not AppRouter.consume_battle_resolution_overworld_presentation("battle").is_empty() or not AppRouter.validation_pending_battle_resolution_overworld_presentation().is_empty():
		return _fail("Wrong surface did not clear the one-shot encounter payload.", {})
	if session.to_dict() != authority_before:
		return _fail("Fail-closed encounter presentation controls mutated resolved session authority.", {"before": authority_before, "after": session.to_dict()})
	_evidence.append({
		"fail_closed": ["malformed", "missing_identity", "wrong_placement", "wrong_content", "wrong_tile", "missing_content", "assault", "non_victory", "unresolved", "spawned_raid", "terminal", "stale", "wrong_surface"],
		"session_authority_exact": true,
	})
	return true

func _resolved_static_encounter() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	var encounter := _encounter_by_placement(session, ENCOUNTER_PLACEMENT_ID)
	var guarded_resource := _resource_by_placement(session, GUARDED_RESOURCE_PLACEMENT_ID).duplicate(true)
	if encounter.is_empty() or guarded_resource.is_empty():
		_fail("River Pass encounter fixture is missing its exact guard or guarded resource.", {"encounter": encounter, "resource": guarded_resource})
		return {}
	var encounter_tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	var route_start := encounter_tile + Vector2i(-1, 0)
	_set_active_hero_position(session, route_start)
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	movement["current"] = maxi(4, int(movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	var route_result: Dictionary = OverworldRules.try_move_along_route(session, [route_start, encounter_tile], 4)
	if not bool(route_result.get("ok", false)) or String(route_result.get("route", "")) != "battle":
		_fail("River Pass route did not enter its real post-move encounter battle.", route_result)
		return {}
	if session.battle.is_empty() or String(session.battle.get("context", {}).get("type", "")) != "encounter":
		_fail("River Pass guard did not enter a real ordinary encounter battle.", session.battle)
		return {}
	if _battle_enemy_stack_contract(session.battle) != PRODUCTION_STACKS or _battle_enemy_ability_contract(session.battle) != {
		"unit_mireclaw_bogplate_maulers": ["shielding"],
		"unit_mireclaw_mudglass_slingers": ["harry"],
	}:
		_fail("River Pass route did not enter the exact Hollow Mire production battle.", {"stacks": _battle_enemy_stack_contract(session.battle), "abilities": _battle_enemy_ability_contract(session.battle)})
		return {}
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var outcome: Dictionary = BattleRules.resolve_if_battle_ready(session)
	var snapshot: Dictionary = outcome.get("battle_resolution_context_snapshot", {}) if outcome.get("battle_resolution_context_snapshot", {}) is Dictionary else {}
	var encounter_snapshot: Dictionary = snapshot.get("encounter", {}) if snapshot.get("encounter", {}) is Dictionary else {}
	if (
		String(outcome.get("state", "")) != "victory"
		or not session.battle.is_empty()
		or String(snapshot.get("context", {}).get("type", "")) != "encounter"
		or String(encounter_snapshot.get("placement_id", "")) != ENCOUNTER_PLACEMENT_ID
		or String(encounter_snapshot.get("encounter_id", "")) != String(encounter.get("encounter_id", ""))
		or int(encounter_snapshot.get("x", -1)) != int(encounter.get("x", -2))
		or int(encounter_snapshot.get("y", -1)) != int(encounter.get("y", -2))
		or String(encounter_snapshot.get("spawned_by_faction_id", "")) != ""
		or not OverworldRules.is_encounter_resolved(session, encounter)
		or _resource_by_placement(session, GUARDED_RESOURCE_PLACEMENT_ID) != guarded_resource
	):
		_fail("Real encounter victory did not resolve with exact detached identity and preserved guarded-resource authority.", {"outcome": outcome, "encounter": encounter, "resource": _resource_by_placement(session, GUARDED_RESOURCE_PLACEMENT_ID)})
		return {}
	return {"session": session, "outcome": outcome.duplicate(true), "guarded_resource": guarded_resource}

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

func _battle_enemy_stack_contract(battle: Dictionary) -> Array:
	var result: Array = []
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("base_count", 0))})
	return result

func _battle_enemy_ability_contract(battle: Dictionary) -> Dictionary:
	var result := {}
	for stack_value in battle.get("stacks", []):
		if not stack_value is Dictionary or String(stack_value.get("side", "")) != "enemy":
			continue
		var ability_ids: Array = []
		for ability_value in stack_value.get("abilities", []):
			if ability_value is Dictionary:
				ability_ids.append(String(ability_value.get("id", "")))
		ability_ids.sort()
		result[String(stack_value.get("unit_id", ""))] = ability_ids
	return result

func _set_encounter_field(session, placement_id: String, field: String, value: Variant) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			encounter[field] = value
			encounters[index] = encounter
			break
	session.overworld["encounters"] = encounters

func _replace_encounter(session, placement_id: String, replacement: Dictionary) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			encounters[index] = replacement.duplicate(true)
			break
	session.overworld["encounters"] = encounters

func _encounter_by_placement(session, placement_id: String) -> Dictionary:
	return OverworldRules._find_encounter_by_placement(session, placement_id).get("encounter", {})

func _resource_by_placement(session, placement_id: String) -> Dictionary:
	return OverworldRules._find_resource_node_by_placement(session, placement_id).get("node", {})

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _fail(message: String, evidence: Variant) -> bool:
	push_error("%s: %s evidence=%s" % [REPORT_ID, message, JSON.stringify(evidence)])
	get_tree().quit(1)
	return false
