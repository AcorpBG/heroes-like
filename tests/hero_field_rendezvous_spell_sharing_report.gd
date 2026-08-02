extends Node

const REPORT_ID := "HERO_FIELD_RENDEZVOUS_SPELL_SHARING_REPORT"
const SAVE_SLOT := 7
const ACTIVE_SPELL_ID := "spell_beacon_path"
const ACTIVE_BASE_SPELL_ID := "spell_cinder_burst"
const RESERVE_SPELL_ID := "spell_briar_bind"
const RESERVE_BASE_SPELL_ID := "spell_graft_mend"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := await _sharing_ui_save_case()
	if result.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"save_version": SessionStateStore.SAVE_VERSION,
		"sharing_ui_save": result,
	})])
	get_tree().quit(0)

func _sharing_ui_save_case() -> Dictionary:
	var fixture := _fixture()
	var session = fixture.get("session")
	var active_id := String(fixture.get("active_id", ""))
	var reserve_id := String(fixture.get("reserve_id", ""))
	var active_action_id := "field_spell_share:%s:%s:%s" % [active_id, reserve_id, ACTIVE_SPELL_ID]
	var reserve_action_id := "field_spell_share:%s:%s:%s" % [reserve_id, active_id, RESERVE_SPELL_ID]

	_set_hero_position(session, reserve_id, Vector2i(2, 1))
	var remote_before := _roster_snapshot(session)
	var remote := HeroCommandRules.teach_field_spell(session, active_id, reserve_id, ACTIVE_SPELL_ID)
	if bool(remote.get("ok", false)) or _roster_snapshot(session) != remote_before:
		return _fail("Remote spell teaching was not rejected atomically.", remote)
	_set_hero_position(session, reserve_id, Vector2i(1, 1))
	HeroCommandRules.normalize_session(session)

	var action_ids := _action_ids(OverworldRules.get_rendezvous_actions(session))
	if active_action_id not in action_ids or reserve_action_id not in action_ids:
		return _fail("Bidirectional spell-teaching actions were missing.", action_ids)
	if not _contains_prefix(action_ids, "field_transfer:") or not _contains_prefix(action_ids, "field_artifact_transfer:"):
		return _fail("Spell teaching displaced troop or artifact rendezvous orders.", action_ids)

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
		or active_action_id not in ui_action_ids \
		or reserve_action_id not in ui_action_ids:
		shell.queue_free()
		return _fail("Spell teaching was not reachable in the compact rendezvous selector.", rendezvous)
	shell.queue_free()
	await get_tree().process_frame

	var before_active_teach := _roster_snapshot(session)
	var active_teach := OverworldRules.perform_rendezvous_action(session, active_action_id)
	if not bool(active_teach.get("ok", false)) or String(active_teach.get("spell_id", "")) != ACTIVE_SPELL_ID:
		return _fail("The active commander did not teach the selected spell.", active_teach)
	if not SpellRules.knows_spell(HeroCommandRules.hero_by_id(session, active_id), ACTIVE_SPELL_ID) \
		or not SpellRules.knows_spell(HeroCommandRules.hero_by_id(session, reserve_id), ACTIVE_SPELL_ID):
		return _fail("Teaching did not preserve source knowledge and add target knowledge.")
	if not _resources_unchanged(before_active_teach, _roster_snapshot(session), active_id, reserve_id):
		return _fail("Teaching changed mana or movement.", _roster_snapshot(session))

	var stale_before := _roster_snapshot(session)
	var stale := OverworldRules.perform_rendezvous_action(session, active_action_id)
	if bool(stale.get("ok", false)) or _roster_snapshot(session) != stale_before:
		return _fail("A stale duplicate-knowledge action mutated hero state.", stale)

	var before_reserve_teach := _roster_snapshot(session)
	var reserve_teach := OverworldRules.perform_rendezvous_action(session, reserve_action_id)
	if not bool(reserve_teach.get("ok", false)) or String(reserve_teach.get("spell_id", "")) != RESERVE_SPELL_ID:
		return _fail("The reserve commander did not teach the selected spell.", reserve_teach)
	if not SpellRules.knows_spell(HeroCommandRules.hero_by_id(session, reserve_id), RESERVE_SPELL_ID) \
		or not SpellRules.knows_spell(HeroCommandRules.hero_by_id(session, active_id), RESERVE_SPELL_ID):
		return _fail("Reverse teaching did not preserve source knowledge and add target knowledge.")
	if not _resources_unchanged(before_reserve_teach, _roster_snapshot(session), active_id, reserve_id):
		return _fail("Reverse teaching changed mana or movement.", _roster_snapshot(session))

	var rejected_before := _roster_snapshot(session)
	var unknown_source := HeroCommandRules.teach_field_spell(session, active_id, reserve_id, RESERVE_BASE_SPELL_ID)
	var uncontrolled := HeroCommandRules.teach_field_spell(session, "missing_hero", reserve_id, ACTIVE_BASE_SPELL_ID)
	var malformed := OverworldRules.perform_rendezvous_action(session, "field_spell_share:missing")
	if bool(unknown_source.get("ok", false)) or bool(uncontrolled.get("ok", false)) or bool(malformed.get("ok", false)) \
		or _roster_snapshot(session) != rejected_before:
		return _fail("Invalid spell-teaching boundaries mutated hero state.", {
			"unknown_source": unknown_source,
			"uncontrolled": uncontrolled,
			"malformed": malformed,
		})

	HeroCommandRules.normalize_session(session)
	OverworldRules.normalize_overworld_state(session)
	var normalized_snapshot := _roster_snapshot(session)
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	var save_result := SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		return _fail("Spell sharing did not save and restore.", save_result)
	OverworldRules.normalize_overworld_state(restored)
	if int(restored.save_version) != int(SessionStateStore.SAVE_VERSION) \
		or _roster_snapshot(restored) != normalized_snapshot \
		or HeroCommandRules.field_rendezvous_heroes(restored).is_empty():
		return _fail("Shared spellbooks changed across save version 9.", _roster_snapshot(restored))
	return {
		"bidirectional_teaching": true,
		"source_knowledge_preserved": true,
		"mana_preserved": true,
		"movement_preserved": true,
		"remote_rejected_without_mutation": true,
		"stale_duplicate_rejected": true,
		"invalid_orders_rejected": true,
		"troop_and_artifact_orders_preserved": true,
		"compact_selector_focusable": true,
		"save_resume_preserved": true,
	}

func _fixture() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var active := HeroCommandRules.active_hero(session).duplicate(true)
	var active_id := String(active.get("id", ""))
	active["position"] = {"x": 1, "y": 1}
	active = _with_spellbook(active, [ACTIVE_BASE_SPELL_ID, ACTIVE_SPELL_ID], 3)
	active = ArtifactRules.claim_artifact(active, "artifact_trailsinger_boots", "Fixture", true).get("hero", active)

	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	var reserve := HeroCommandRules.build_hero_from_template(
		ContentService.get_hero(reserve_id),
		{"x": 1, "y": 1},
		{"id": "%s_spell_rendezvous_army" % reserve_id, "name": "Reserve Army", "stacks": [{"unit_id": "unit_river_guard", "count": 4}]},
		session
	)
	reserve = _with_spellbook(reserve, [RESERVE_SPELL_ID, RESERVE_BASE_SPELL_ID], 2)
	reserve = ArtifactRules.claim_artifact(reserve, "artifact_milepost_lantern", "Fixture", true).get("hero", reserve)
	session.overworld["player_heroes"] = [active, reserve]
	session.overworld["active_hero_id"] = active_id
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
	session.overworld["hero_position"] = active.get("position", {}).duplicate(true)
	session.overworld["movement"] = active.get("movement", {}).duplicate(true)
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	HeroCommandRules.normalize_session(session)
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session, "active_id": active_id, "reserve_id": reserve_id}

func _with_spellbook(hero: Dictionary, spell_ids: Array, spent_mana: int) -> Dictionary:
	var updated := SpellRules.ensure_hero_spellbook(hero.duplicate(true))
	var spellbook: Dictionary = updated.get("spellbook", {}).duplicate(true)
	var mana: Dictionary = spellbook.get("mana", {}).duplicate(true)
	spellbook["known_spell_ids"] = spell_ids.duplicate()
	mana["current"] = max(0, int(mana.get("max", 0)) - spent_mana)
	spellbook["mana"] = mana
	updated["spellbook"] = spellbook
	return updated

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

func _roster_snapshot(session) -> Dictionary:
	var heroes := {}
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
		heroes[String(hero.get("id", ""))] = {
			"known_spell_ids": spellbook.get("known_spell_ids", []).duplicate() if spellbook.get("known_spell_ids", []) is Array else [],
			"mana": spellbook.get("mana", {}).duplicate(true) if spellbook.get("mana", {}) is Dictionary else {},
			"movement": hero.get("movement", {}).duplicate(true) if hero.get("movement", {}) is Dictionary else {},
			"position": hero.get("position", {}).duplicate(true) if hero.get("position", {}) is Dictionary else {},
		}
	return heroes

func _resources_unchanged(before: Dictionary, after: Dictionary, active_id: String, reserve_id: String) -> bool:
	for hero_id in [active_id, reserve_id]:
		var before_hero: Dictionary = before.get(hero_id, {}) if before.get(hero_id, {}) is Dictionary else {}
		var after_hero: Dictionary = after.get(hero_id, {}) if after.get(hero_id, {}) is Dictionary else {}
		if before_hero.get("mana", {}) != after_hero.get("mana", {}) or before_hero.get("movement", {}) != after_hero.get("movement", {}):
			return false
	return true

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
