extends Node

const REPORT_ID := "HERO_FIELD_RENDEZVOUS_ARTIFACT_TRANSFER_REPORT"
const SAVE_SLOT := 9
const BOOTS_ID := "artifact_trailsinger_boots"
const LANTERN_ID := "artifact_milepost_lantern"
const ROD_ID := "artifact_quarry_tally_rod"
const COMPASS_ID := "artifact_waymark_compass"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var transfer_case := await _transfer_ui_save_case()
	if transfer_case.is_empty():
		return
	var duplicate_case := _duplicate_target_case()
	if duplicate_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"transfer_ui_save": transfer_case,
		"duplicate_target": duplicate_case,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _transfer_ui_save_case() -> Dictionary:
	var fixture := _fixture()
	var session = fixture.get("session")
	var active_id := String(fixture.get("active_id", ""))
	var reserve_id := String(fixture.get("reserve_id", ""))
	var boots_action_id := "field_artifact_transfer:%s:%s:%s" % [active_id, reserve_id, BOOTS_ID]
	var lantern_action_id := "field_artifact_transfer:%s:%s:%s" % [reserve_id, active_id, LANTERN_ID]

	_set_hero_position(session, reserve_id, Vector2i(2, 1))
	var remote_before := _artifact_movement_snapshot(session)
	var remote: Dictionary = HeroCommandRules.transfer_field_artifact(session, active_id, reserve_id, BOOTS_ID)
	if bool(remote.get("ok", false)) or _artifact_movement_snapshot(session) != remote_before:
		return _fail("Remote artifact handoff was not rejected atomically.", remote)
	_set_hero_position(session, reserve_id, Vector2i(1, 1))
	HeroCommandRules.normalize_session(session)

	var action_ids := _action_ids(OverworldRules.get_rendezvous_actions(session))
	if boots_action_id not in action_ids or lantern_action_id not in action_ids:
		return _fail("Bidirectional artifact handoffs were missing from rendezvous orders.", action_ids)
	if not _contains_prefix(action_ids, "field_transfer:"):
		return _fail("Artifact handoffs displaced existing troop-transfer orders.", action_ids)

	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	session = shell.get("_session")
	shell.call("validation_open_command_drawer")
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var rendezvous: Dictionary = snapshot.get("rendezvous", {}) if snapshot.get("rendezvous", {}) is Dictionary else {}
	var ui_action_ids: Array = rendezvous.get("action_ids", []) if rendezvous.get("action_ids", []) is Array else []
	if not bool(rendezvous.get("controls_visible_in_tree", false)) \
		or not bool(rendezvous.get("order_focusable", false)) \
		or not bool(rendezvous.get("transfer_focusable", false)) \
		or boots_action_id not in ui_action_ids \
		or lantern_action_id not in ui_action_ids:
		shell.queue_free()
		return _fail("Artifact handoffs were not reachable in the compact rendezvous selector.", rendezvous)
	shell.queue_free()
	await get_tree().process_frame

	var active_before := _movement(session, active_id)
	var reserve_before := _movement(session, reserve_id)
	var active_bonus_before := ArtifactRules.aggregate_bonuses(HeroCommandRules.hero_by_id(session, active_id))
	var reserve_bonus_before := ArtifactRules.aggregate_bonuses(HeroCommandRules.hero_by_id(session, reserve_id))
	var boots_result: Dictionary = OverworldRules.perform_rendezvous_action(session, boots_action_id)
	if not bool(boots_result.get("ok", false)) \
		or String(boots_result.get("target_location", "")) != "equipped" \
		or String(boots_result.get("target_slot", "")) != "boots" \
		or not bool(boots_result.get("auto_equipped", false)):
		return _fail("Equipped boots did not hand off into the empty target slot.", boots_result)
	if ArtifactRules.has_artifact(HeroCommandRules.hero_by_id(session, active_id), BOOTS_ID) \
		or String(ArtifactRules.locate_artifact(HeroCommandRules.hero_by_id(session, reserve_id), BOOTS_ID).get("slot", "")) != "boots":
		return _fail("Boot ownership was duplicated or lost after handoff.")
	if not _movement_loadout_matches(session, active_id, active_before) \
		or not _movement_loadout_matches(session, reserve_id, reserve_before) \
		or int(_movement(session, active_id).get("max", 0)) >= int(active_before.get("max", 0)) \
		or int(_movement(session, reserve_id).get("max", 0)) <= int(reserve_before.get("max", 0)):
		return _fail("Movement gear handoff did not preserve movement deficit exactly.", {
			"active_before": active_before,
			"active_after": _movement(session, active_id),
			"reserve_before": reserve_before,
			"reserve_after": _movement(session, reserve_id),
			"state": _artifact_movement_snapshot(session),
		})
	var active_bonus_after := ArtifactRules.aggregate_bonuses(HeroCommandRules.hero_by_id(session, active_id))
	var reserve_bonus_after := ArtifactRules.aggregate_bonuses(HeroCommandRules.hero_by_id(session, reserve_id))
	if int(active_bonus_after.get("overworld_movement", 0)) >= int(active_bonus_before.get("overworld_movement", 0)) \
		or int(reserve_bonus_after.get("overworld_movement", 0)) <= int(reserve_bonus_before.get("overworld_movement", 0)) \
		or int(active_bonus_after.get("scouting_radius", 0)) >= int(active_bonus_before.get("scouting_radius", 0)) \
		or int(reserve_bonus_after.get("scouting_radius", 0)) <= int(reserve_bonus_before.get("scouting_radius", 0)):
		return _fail("Equipped artifact bonuses did not follow ownership immediately.")

	var active_trinkets_before := _equipped_trinkets(HeroCommandRules.hero_by_id(session, active_id))
	var active_before_lantern := _movement(session, active_id)
	var reserve_before_lantern := _movement(session, reserve_id)
	var lantern_result: Dictionary = OverworldRules.perform_rendezvous_action(session, lantern_action_id)
	if not bool(lantern_result.get("ok", false)) \
		or String(lantern_result.get("target_location", "")) != "inventory" \
		or bool(lantern_result.get("auto_equipped", true)):
		return _fail("Full target trinket slots did not route the handoff into inventory.", lantern_result)
	if _equipped_trinkets(HeroCommandRules.hero_by_id(session, active_id)) != active_trinkets_before \
		or String(ArtifactRules.locate_artifact(HeroCommandRules.hero_by_id(session, active_id), LANTERN_ID).get("location", "")) != "inventory":
		return _fail("Artifact handoff displaced occupied target equipment.")
	if not _movement_loadout_matches(session, reserve_id, reserve_before_lantern) \
		or int(_movement(session, reserve_id).get("max", 0)) >= int(reserve_before_lantern.get("max", 0)) \
		or _movement(session, active_id) != active_before_lantern:
		return _fail("Packed artifact bonus state changed movement incorrectly.", _artifact_movement_snapshot(session))

	var stale_before := _artifact_movement_snapshot(session)
	var stale: Dictionary = OverworldRules.perform_rendezvous_action(session, lantern_action_id)
	if bool(stale.get("ok", false)) or _artifact_movement_snapshot(session) != stale_before:
		return _fail("A stale artifact order mutated rendezvous state.", stale)
	var invalid_before := _artifact_movement_snapshot(session)
	var invalid: Dictionary = OverworldRules.perform_rendezvous_action(session, "field_artifact_transfer:missing")
	if bool(invalid.get("ok", false)) or _artifact_movement_snapshot(session) != invalid_before:
		return _fail("A malformed artifact order mutated rendezvous state.", invalid)
	if _global_artifact_count(session, BOOTS_ID) != 1 or _global_artifact_count(session, LANTERN_ID) != 1:
		return _fail("Transferred artifacts were duplicated across the roster.")

	HeroCommandRules.normalize_session(session)
	OverworldRules.normalize_overworld_state(session)
	var normalized_snapshot := _artifact_movement_snapshot(session)
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		return _fail("Artifact rendezvous did not save and restore.", save_result)
	OverworldRules.normalize_overworld_state(restored)
	if int(restored.save_version) != int(SessionStateStore.SAVE_VERSION) \
		or _artifact_movement_snapshot(restored) != normalized_snapshot \
		or HeroCommandRules.field_rendezvous_heroes(restored).is_empty():
		return _fail("Artifact ownership, equipment, or movement changed across save version 9.")
	return {
		"remote_rejected_without_mutation": true,
		"bidirectional_handoffs": true,
		"empty_slot_auto_equip": true,
		"occupied_slot_inventory_fallback": true,
		"movement_deficit_preserved": true,
		"immediate_bonus_update": true,
		"troop_orders_preserved": true,
		"compact_selector_focusable": true,
		"stale_order_rejected": true,
		"invalid_order_rejected": true,
		"save_resume_preserved": true,
	}

func _duplicate_target_case() -> Dictionary:
	var fixture := _fixture()
	var session = fixture.get("session")
	var active_id := String(fixture.get("active_id", ""))
	var reserve_id := String(fixture.get("reserve_id", ""))
	var reserve := HeroCommandRules.hero_by_id(session, reserve_id)
	var duplicate_claim := ArtifactRules.claim_artifact(reserve, BOOTS_ID, "Fixture", true)
	_set_hero(session, duplicate_claim.get("hero", reserve))
	HeroCommandRules.normalize_session(session)
	var before := _artifact_movement_snapshot(session)
	var result: Dictionary = HeroCommandRules.transfer_field_artifact(session, active_id, reserve_id, BOOTS_ID)
	if bool(result.get("ok", false)) or _artifact_movement_snapshot(session) != before \
		or _global_artifact_count(session, BOOTS_ID) != 2:
		return _fail("Duplicate-target protection did not reject without mutation.", result)
	return {"rejected": true, "atomic": true}

func _fixture() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var active := HeroCommandRules.active_hero(session).duplicate(true)
	var active_id := String(active.get("id", ""))
	active["position"] = {"x": 1, "y": 1}
	for artifact_id in [BOOTS_ID, ROD_ID, COMPASS_ID]:
		var claim := ArtifactRules.claim_artifact(active, artifact_id, "Fixture", true)
		active = claim.get("hero", active)
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	var reserve := HeroCommandRules.build_hero_from_template(
		ContentService.get_hero(reserve_id),
		{"x": 1, "y": 1},
		{"id": "%s_rendezvous_army" % reserve_id, "name": "Reserve Army", "stacks": [{"unit_id": "unit_river_guard", "count": 4}]},
		session
	)
	var lantern_claim := ArtifactRules.claim_artifact(reserve, LANTERN_ID, "Fixture", true)
	reserve = lantern_claim.get("hero", reserve)
	var heroes: Array = [active, reserve]
	session.overworld["player_heroes"] = heroes
	session.overworld["active_hero_id"] = active_id
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
	session.overworld["hero_position"] = active.get("position", {}).duplicate(true)
	session.overworld["movement"] = active.get("movement", {}).duplicate(true)
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	HeroCommandRules.normalize_session(session)
	_set_movement_deficit(session, active_id, 3)
	_set_movement_deficit(session, reserve_id, 2)
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session, "active_id": active_id, "reserve_id": reserve_id}

func _set_hero(session, replacement: Dictionary) -> void:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(replacement.get("id", "")):
			heroes[index] = replacement.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == String(replacement.get("id", "")):
		session.overworld["hero"] = replacement.duplicate(true)
		session.overworld["movement"] = replacement.get("movement", {}).duplicate(true)

func _set_hero_position(session, hero_id: String, tile: Vector2i) -> void:
	var hero := HeroCommandRules.hero_by_id(session, hero_id).duplicate(true)
	hero["position"] = {"x": tile.x, "y": tile.y}
	_set_hero(session, hero)

func _set_movement_deficit(session, hero_id: String, deficit: int) -> void:
	var hero := HeroCommandRules.hero_by_id(session, hero_id).duplicate(true)
	var movement_max := HeroCommandRules.movement_max_for_hero(hero, session)
	hero["movement"] = {"current": max(0, movement_max - deficit), "max": movement_max}
	_set_hero(session, hero)

func _movement(session, hero_id: String) -> Dictionary:
	var hero := HeroCommandRules.hero_by_id(session, hero_id)
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	return {"current": int(movement.get("current", 0)), "max": int(movement.get("max", 0))}

func _movement_loadout_matches(session, hero_id: String, before: Dictionary) -> bool:
	var hero := HeroCommandRules.hero_by_id(session, hero_id)
	var after := _movement(session, hero_id)
	var expected_max := HeroCommandRules.movement_max_for_hero(hero, session)
	var before_deficit := int(before.get("max", 0)) - int(before.get("current", 0))
	var after_deficit := int(after.get("max", 0)) - int(after.get("current", 0))
	return int(after.get("max", 0)) == expected_max and after_deficit == before_deficit

func _equipped_trinkets(hero: Dictionary) -> Array:
	var artifacts := ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	return [
		String(artifacts.get("equipped", {}).get("trinket", "")),
		String(artifacts.get("equipped", {}).get("trinket_2", "")),
	]

func _global_artifact_count(session, artifact_id: String) -> int:
	var count := 0
	for hero_value in session.overworld.get("player_heroes", []):
		if hero_value is Dictionary and ArtifactRules.has_artifact(hero_value, artifact_id):
			count += 1
	return count

func _artifact_movement_snapshot(session) -> Dictionary:
	var heroes := {}
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		heroes[String(hero.get("id", ""))] = {
			"artifacts": ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {})),
			"movement": _movement(session, String(hero.get("id", ""))),
			"position": hero.get("position", {}).duplicate(true) if hero.get("position", {}) is Dictionary else {},
		}
	return heroes

func _action_ids(actions: Array) -> Array:
	var ids := []
	for action_value in actions:
		if action_value is Dictionary:
			ids.append(String(action_value.get("id", "")))
	return ids

func _contains_prefix(values: Array, prefix: String) -> bool:
	for value in values:
		if String(value).begins_with(prefix):
			return true
	return false

func _fail(message: String, payload: Variant = {}) -> Dictionary:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return {}
